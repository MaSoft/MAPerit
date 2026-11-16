#region ============================================================
# MaPeriT.SW - FASE 1: DATOS VOLATILES
# RFC 3227 - Orden de volatilidad (mas volatil primero)
# ============================================================

function Invoke-Phase1-VolatileCollection {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.Volatile
    $phaseNum = 1
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    # --- 1.1 Fecha/Hora del sistema ---
    Write-StepHeader "1.1 Fecha, Hora y Zona Horaria del Sistema"
    try {
        $timeInfo = [PSCustomObject]@{
            FechaHoraLocal   = (Get-Date).ToString($Script:Defaults.TimeZoneFormat)
            FechaHoraUTC     = (Get-Date).ToUniversalTime().ToString($Script:Defaults.DateFormat)
            ZonaHoraria      = [System.TimeZoneInfo]::Local.DisplayName
            ZonaHorariaId    = [System.TimeZoneInfo]::Local.Id
            OffsetUTC        = [System.TimeZoneInfo]::Local.BaseUtcOffset.ToString()
            HorarioVerano    = [System.TimeZoneInfo]::Local.IsDaylightSavingTime((Get-Date))
            Uptime           = ((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).ToString()
            UltimoArranque   = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString($Script:Defaults.DateFormat)
            ServidorNTP      = (& w32tm /query /source 2>$null) -join ""
        }
        Export-CollectionToJSON -Data $timeInfo -OutputPath (Join-Path $phasePath "SystemTime.json") -Phase "FASE_1" -Description "Fecha/Hora del sistema"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "SYSTEM_TIME_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.2 Volcado de RAM ---
    Write-StepHeader "1.2 Volcado de Memoria RAM"
    if ($SkipRAM) {
        Write-ForensicLog -Phase "FASE_1" -Action "RAM_DUMP_OMITIDO" -Target "Parametro -SkipRAM activado" -Result "SKIP"
    } else {
    try {
        $ramDumpPath = Join-Path $phasePath "MemoryDump"
        $winpmemPaths = @(
            (Join-Path (Split-Path $Script:SessionInfo.ScriptPath -Parent) "tools\winpmem_mini_x64.exe"),
            (Join-Path (Split-Path $Script:SessionInfo.ScriptPath -Parent) "winpmem_mini_x64.exe"),
            "C:\Tools\winpmem_mini_x64.exe",
            (Join-Path $env:TEMP "winpmem_mini_x64.exe")
        )
        $winpmem = $winpmemPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $winpmem) {
            $winpmem = Get-Command winpmem_mini_x64.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        }

        if ($winpmem) {
            $ramOutput = Join-Path $ramDumpPath "memory.raw"
            Write-ForensicLog -Phase "FASE_1" -Action "RAM_DUMP_INICIO" -Target $winpmem
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            & $winpmem $ramOutput 2>&1 | Out-Null
            $sw.Stop()

            if (Test-Path $ramOutput) {
                $hash = Get-ForensicHash -FilePath $ramOutput
                $size = (Get-Item $ramOutput).Length
                Add-ChainOfCustodyEntry -SourcePath "MEMORY_DUMP" -DestPath $ramOutput -Hash $hash -Method "WinPmem" -FileSize $size
                Write-ForensicLog -Phase "FASE_1" -Action "RAM_DUMP_OK" -Target "$([math]::Round($size/1GB, 2)) GB" -Result "OK" -DurationMs $sw.ElapsedMilliseconds
                $collected++
            } else {
                Write-ForensicLog -Phase "FASE_1" -Action "RAM_DUMP_SIN_SALIDA" -Target $ramOutput -Result "WARNING"
            }
        } else {
            Write-ForensicLog -Phase "FASE_1" -Action "RAM_DUMP_WINPMEM_NO_ENCONTRADO" -Target "Coloque winpmem_mini_x64.exe en tools\" -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "RAM_DUMP_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }
    } # end if -not $SkipRAM

    # --- 1.3 Procesos en ejecucion ---
    Write-StepHeader "1.3 Procesos en Ejecucion"
    try {
        $processes = Get-CimInstance Win32_Process -ErrorAction Stop | Select-Object `
            ProcessId, Name, ParentProcessId, CommandLine, ExecutablePath,
            CreationDate, ThreadCount, HandleCount, WorkingSetSize, VirtualSize,
            @{N='SessionId';E={$_.SessionId}},
            @{N='Owner';E={
                try { $o = Invoke-CimMethod -InputObject $_ -MethodName GetOwner -ErrorAction SilentlyContinue; if($o.User){"$($o.Domain)\$($o.User)"}else{"N/A"} } catch {"N/A"}
            }}

        Export-CollectionToCSV -Data $processes -OutputPath (Join-Path $phasePath "Processes.csv") -Phase "FASE_1" -Description "Procesos en ejecucion"
        $collected++

        $processHashes = @()
        foreach ($proc in $processes) {
            if ($proc.ExecutablePath -and (Test-Path $proc.ExecutablePath -ErrorAction SilentlyContinue)) {
                try {
                    $hash = Get-ForensicHash -FilePath $proc.ExecutablePath
                    $processHashes += [PSCustomObject]@{
                        ProcessId = $proc.ProcessId
                        Name = $proc.Name
                        Path = $proc.ExecutablePath
                        SHA256 = $hash
                    }
                } catch { }
            }
        }
        if ($processHashes.Count -gt 0) {
            Export-CollectionToCSV -Data $processHashes -OutputPath (Join-Path $phasePath "ProcessHashes.csv") -Phase "FASE_1" -Description "Hashes de ejecutables"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "PROCESOS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.4 Modulos cargados por proceso ---
    Write-StepHeader "1.4 Modulos Cargados (DLLs)"
    try {
        $modules = @()
        Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
            $procName = $_.Name
            $procId = $_.Id
            try {
                $_.Modules | ForEach-Object {
                    $modules += [PSCustomObject]@{
                        ProcessId   = $procId
                        ProcessName = $procName
                        ModuleName  = $_.ModuleName
                        FileName    = $_.FileName
                        ModuleMemorySize = $_.ModuleMemorySize
                    }
                }
            } catch { }
        }
        if ($modules.Count -gt 0) {
            Export-CollectionToCSV -Data $modules -OutputPath (Join-Path $phasePath "ProcessModules.csv") -Phase "FASE_1" -Description "Modulos cargados"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "MODULOS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.5 Conexiones de red TCP ---
    Write-StepHeader "1.5 Conexiones de Red"
    try {
        $tcpConnections = Get-NetTCPConnection -ErrorAction Stop | Select-Object `
            LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess,
            CreationTime,
            @{N='ProcessName';E={
                try { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name } catch { "N/A" }
            }}
        Export-CollectionToCSV -Data $tcpConnections -OutputPath (Join-Path $phasePath "NetworkConnections_TCP.csv") -Phase "FASE_1" -Description "Conexiones TCP"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "TCP_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.6 Endpoints UDP ---
    Write-StepHeader "1.6 Endpoints UDP"
    try {
        $udpEndpoints = Get-NetUDPEndpoint -ErrorAction Stop | Select-Object `
            LocalAddress, LocalPort, OwningProcess,
            @{N='ProcessName';E={
                try { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name } catch { "N/A" }
            }}
        Export-CollectionToCSV -Data $udpEndpoints -OutputPath (Join-Path $phasePath "NetworkConnections_UDP.csv") -Phase "FASE_1" -Description "Endpoints UDP"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "UDP_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.7 Usuarios conectados ---
    Write-StepHeader "1.7 Usuarios Conectados"
    try {
        $logonSessions = Get-CimInstance Win32_LogonSession -ErrorAction SilentlyContinue
        $loggedOnUsers = @()
        foreach ($session in $logonSessions) {
            try {
                $user = Get-CimAssociatedInstance -InputObject $session -ResultClassName Win32_Account -ErrorAction SilentlyContinue
                if ($user) {
                    $loggedOnUsers += [PSCustomObject]@{
                        Usuario      = $user.Name
                        Dominio      = $user.Domain
                        SID          = $user.SID
                        TipoLogon    = $session.LogonType
                        TipoLogonDesc= $Script:LogonTypes[[int]$session.LogonType]
                        InicioSesion = $session.StartTime
                        LogonId      = $session.LogonId
                    }
                }
            } catch { }
        }
        Export-CollectionToCSV -Data $loggedOnUsers -OutputPath (Join-Path $phasePath "LoggedOnUsers.csv") -Phase "FASE_1" -Description "Usuarios conectados"
        $collected++

        $queryUser = & query user 2>$null
        if ($queryUser) {
            Export-CollectionToText -Content ($queryUser | Out-String) -OutputPath (Join-Path $phasePath "QueryUser.txt") -Phase "FASE_1" -Description "query user"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "USUARIOS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.8 Ficheros abiertos ---
    Write-StepHeader "1.8 Ficheros Abiertos y Recursos Compartidos"
    try {
        $openFiles = Get-SmbOpenFile -ErrorAction SilentlyContinue | Select-Object FileId, SessionId, Path, ShareRelativePath, ClientComputerName, ClientUserName
        if ($openFiles) {
            Export-CollectionToCSV -Data $openFiles -OutputPath (Join-Path $phasePath "OpenFiles.csv") -Phase "FASE_1" -Description "Ficheros abiertos SMB"
            $collected++
        }

        $netFile = & net file 2>$null
        if ($netFile) {
            Export-CollectionToText -Content ($netFile | Out-String) -OutputPath (Join-Path $phasePath "NetFile.txt") -Phase "FASE_1" -Description "net file"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "OPEN_FILES_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.9 Portapapeles ---
    Write-StepHeader "1.9 Contenido del Portapapeles"
    try {
        $clipboardContent = ""
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = "STA"
        $runspace.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $runspace
        [void]$ps.AddScript({
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.Clipboard]::GetText()
        })
        $clipboardContent = $ps.Invoke()
        $ps.Dispose()
        $runspace.Close()

        if ($clipboardContent) {
            Export-CollectionToText -Content ($clipboardContent | Out-String) -OutputPath (Join-Path $phasePath "Clipboard.txt") -Phase "FASE_1" -Description "Portapapeles"
            $collected++
        } else {
            Write-ForensicLog -Phase "FASE_1" -Action "CLIPBOARD_VACIO" -Target "Portapapeles vacio o sin texto" -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "CLIPBOARD_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 1.10 Cache DNS ---
    Write-StepHeader "1.10 Cache DNS"
    try {
        $dnsCache = Get-DnsClientCache -ErrorAction Stop | Select-Object Entry, Name, Type, Status, Section, TimeToLive, DataLength, Data
        Export-CollectionToCSV -Data $dnsCache -OutputPath (Join-Path $phasePath "DnsCache.csv") -Phase "FASE_1" -Description "Cache DNS"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "DNS_CACHE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.11 Cache ARP ---
    Write-StepHeader "1.11 Cache ARP"
    try {
        $arpCache = Get-NetNeighbor -ErrorAction Stop | Select-Object IPAddress, LinkLayerAddress, State, InterfaceAlias, InterfaceIndex, AddressFamily
        Export-CollectionToCSV -Data $arpCache -OutputPath (Join-Path $phasePath "ArpCache.csv") -Phase "FASE_1" -Description "Cache ARP"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "ARP_CACHE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.12 Tabla de rutas ---
    Write-StepHeader "1.12 Tabla de Rutas"
    try {
        $routes = Get-NetRoute -ErrorAction Stop | Select-Object DestinationPrefix, NextHop, InterfaceAlias, InterfaceIndex, RouteMetric, Protocol, AddressFamily
        Export-CollectionToCSV -Data $routes -OutputPath (Join-Path $phasePath "RoutingTable.csv") -Phase "FASE_1" -Description "Tabla de rutas"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "ROUTES_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.13 Shares y unidades mapeadas ---
    Write-StepHeader "1.13 Recursos Compartidos y Unidades Mapeadas"
    try {
        $shares = Get-SmbShare -ErrorAction SilentlyContinue | Select-Object Name, Path, Description, ShareType, CurrentUsers, EncryptData
        if ($shares) {
            Export-CollectionToCSV -Data $shares -OutputPath (Join-Path $phasePath "NetworkShares.csv") -Phase "FASE_1" -Description "Recursos compartidos"
            $collected++
        }

        $netUse = & net use 2>$null
        if ($netUse) {
            Export-CollectionToText -Content ($netUse | Out-String) -OutputPath (Join-Path $phasePath "MappedDrives.txt") -Phase "FASE_1" -Description "Unidades mapeadas"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "SHARES_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.14 Variables de entorno ---
    Write-StepHeader "1.14 Variables de Entorno"
    try {
        $envVars = @()
        foreach ($scope in @("Machine", "User", "Process")) {
            [System.Environment]::GetEnvironmentVariables($scope).GetEnumerator() | ForEach-Object {
                $envVars += [PSCustomObject]@{
                    Scope = $scope
                    Name  = $_.Key
                    Value = $_.Value
                }
            }
        }
        Export-CollectionToCSV -Data $envVars -OutputPath (Join-Path $phasePath "EnvironmentVariables.csv") -Phase "FASE_1" -Description "Variables de entorno"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "ENV_VARS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.15 Tareas programadas activas ---
    Write-StepHeader "1.15 Tareas Programadas Activas"
    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Disabled' } | Select-Object `
            TaskName, TaskPath, State, Description,
            @{N='Author';E={$_.Principal.UserId}},
            @{N='Actions';E={($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join "; "}}
        Export-CollectionToCSV -Data $tasks -OutputPath (Join-Path $phasePath "ActiveScheduledTasks.csv") -Phase "FASE_1" -Description "Tareas programadas activas"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "SCHED_TASKS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 1.16 Named Pipes ---
    Write-StepHeader "1.16 Named Pipes"
    try {
        $pipes = @()
        Get-ChildItem "\\.\pipe\" -ErrorAction SilentlyContinue | ForEach-Object {
            $pipes += [PSCustomObject]@{
                Nombre = $_.Name
                Tamano = $_.Length
            }
        }
        if ($pipes.Count -gt 0) {
            Export-CollectionToCSV -Data $pipes -OutputPath (Join-Path $phasePath "NamedPipes.csv") -Phase "FASE_1" -Description "Named Pipes"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "NAMED_PIPES_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
