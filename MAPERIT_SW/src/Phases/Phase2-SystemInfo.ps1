#region ============================================================
# MaPeriT.SW - FASE 2: INFORMACION DEL SISTEMA
# ============================================================

function Invoke-Phase2-SystemInfoCollection {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.SystemInfo
    $phaseNum = 2
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    # --- 2.1 Inventario de hardware ---
    Write-StepHeader "2.1 Inventario de Hardware"
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, SocketDesignation, ProcessorId
        $ram = Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop | Select-Object Manufacturer, PartNumber, SerialNumber, Capacity, Speed, ConfiguredClockSpeed, DeviceLocator
        $disks = Get-CimInstance Win32_DiskDrive -ErrorAction Stop | Select-Object Model, SerialNumber, InterfaceType, MediaType, Size, Partitions, DeviceID, FirmwareRevision
        $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop | Select-Object Manufacturer, Name, SerialNumber, SMBIOSBIOSVersion, ReleaseDate, Version
        $board = Get-CimInstance Win32_BaseBoard -ErrorAction Stop | Select-Object Manufacturer, Product, SerialNumber, Version
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object Name, DriverVersion, AdapterRAM, VideoProcessor
        $nics = Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, InterfaceDescription, MacAddress, Status, LinkSpeed, MediaType, DriverVersion, DriverProvider

        $hardware = [PSCustomObject]@{
            CPU         = $cpu
            RAM         = $ram
            RAMTotalGB  = [math]::Round(($ram | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
            Discos      = $disks
            BIOS        = $bios
            PlacaBase   = $board
            GPU         = $gpu
            Adaptadores = $nics
        }
        Export-CollectionToJSON -Data $hardware -OutputPath (Join-Path $phasePath "HardwareInventory.json") -Phase "FASE_2" -Description "Inventario de hardware"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "HARDWARE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 2.2 Informacion del SO ---
    Write-StepHeader "2.2 Informacion del Sistema Operativo"
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop

        $osInfo = [PSCustomObject]@{
            NombreEquipo        = $cs.Name
            Dominio             = $cs.Domain
            TipoSistema         = $cs.SystemType
            Fabricante          = $cs.Manufacturer
            Modelo              = $cs.Model
            SO                  = $os.Caption
            Version             = $os.Version
            Build               = $os.BuildNumber
            ServicePack         = $os.ServicePackMajorVersion
            Arquitectura        = $os.OSArchitecture
            FechaInstalacion    = $os.InstallDate
            UltimoArranque      = $os.LastBootUpTime
            DirectorioWindows   = $os.WindowsDirectory
            DirectorioSistema   = $os.SystemDirectory
            NumeroSerie         = $os.SerialNumber
            ProductoID          = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).ProductId
            EdicionID           = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).EditionID
            DisplayVersion      = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).DisplayVersion
            UBR                 = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).UBR
        }
        Export-CollectionToJSON -Data $osInfo -OutputPath (Join-Path $phasePath "OSInfo.json") -Phase "FASE_2" -Description "Informacion del SO"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "OS_INFO_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 2.3 Informacion de discos y particiones ---
    Write-StepHeader "2.3 Discos y Particiones"
    try {
        $volumes = Get-Volume -ErrorAction SilentlyContinue | Select-Object DriveLetter, FileSystemLabel, FileSystem, DriveType, HealthStatus, SizeRemaining, Size, OperationalStatus
        $partitions = Get-Partition -ErrorAction SilentlyContinue | Select-Object DiskNumber, PartitionNumber, DriveLetter, Size, Type, IsActive, IsBoot, IsSystem, GptType
        Export-CollectionToCSV -Data $volumes -OutputPath (Join-Path $phasePath "Volumes.csv") -Phase "FASE_2" -Description "Volumenes"
        Export-CollectionToCSV -Data $partitions -OutputPath (Join-Path $phasePath "Partitions.csv") -Phase "FASE_2" -Description "Particiones"
        $collected += 2
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "DISKS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 2.4 Usuarios y grupos locales ---
    Write-StepHeader "2.4 Usuarios y Grupos Locales"
    try {
        $users = Get-LocalUser -ErrorAction Stop | Select-Object Name, Enabled, SID, LastLogon, PasswordLastSet, PasswordRequired, PasswordChangeableDate, PasswordExpires, AccountExpires, Description, FullName
        Export-CollectionToCSV -Data $users -OutputPath (Join-Path $phasePath "LocalUsers.csv") -Phase "FASE_2" -Description "Usuarios locales"
        $collected++

        $groupData = @()
        Get-LocalGroup -ErrorAction SilentlyContinue | ForEach-Object {
            $groupName = $_.Name
            $members = @()
            try {
                $members = Get-LocalGroupMember -Group $groupName -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
            } catch { }
            $groupData += [PSCustomObject]@{
                Grupo    = $groupName
                SID      = $_.SID
                Miembros = ($members -join "; ")
            }
        }
        Export-CollectionToCSV -Data $groupData -OutputPath (Join-Path $phasePath "LocalGroups.csv") -Phase "FASE_2" -Description "Grupos locales"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "USERS_GROUPS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 2.5 Software instalado ---
    Write-StepHeader "2.5 Software Instalado"
    try {
        $regPaths = @($Script:RegistryPaths.UninstallHKLM, $Script:RegistryPaths.UninstallWow64, $Script:RegistryPaths.UninstallHKCU)
        $software = @()
        foreach ($regPath in $regPaths) {
            if (Test-Path $regPath) {
                Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                    if ($props.DisplayName) {
                        $software += [PSCustomObject]@{
                            Nombre     = $props.DisplayName
                            Version    = $props.DisplayVersion
                            Editor     = $props.Publisher
                            FechaInst  = $props.InstallDate
                            Ubicacion  = $props.InstallLocation
                            Origen     = $regPath -replace 'HKLM:\\|HKCU:\\', ''
                        }
                    }
                }
            }
        }
        Export-CollectionToCSV -Data ($software | Sort-Object Nombre -Unique) -OutputPath (Join-Path $phasePath "InstalledSoftware.csv") -Phase "FASE_2" -Description "Software instalado"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "SOFTWARE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 2.6 Servicios de Windows ---
    Write-StepHeader "2.6 Servicios de Windows"
    try {
        $services = Get-CimInstance Win32_Service -ErrorAction Stop | Select-Object `
            Name, DisplayName, State, StartMode, PathName, StartName, ProcessId, ServiceType, Description,
            @{N='Firmado';E={
                if ($_.PathName) {
                    $exePath = Resolve-ServiceExecutablePath -PathName $_.PathName
                    if ($exePath -and (Test-Path $exePath -ErrorAction SilentlyContinue)) {
                        try { (Get-AuthenticodeSignature $exePath -ErrorAction SilentlyContinue).Status.ToString() } catch { "N/A" }
                    } else { "PathNotFound" }
                } else { "N/A" }
            }}
        Export-CollectionToCSV -Data $services -OutputPath (Join-Path $phasePath "Services.csv") -Phase "FASE_2" -Description "Servicios de Windows"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "SERVICES_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 2.7 Tareas programadas (completo) ---
    Write-StepHeader "2.7 Tareas Programadas (Completo)"
    try {
        $allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Select-Object `
            TaskName, TaskPath, State, Description, Author, Date,
            @{N='Trigger';E={($_.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join "; "}},
            @{N='Actions';E={($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join "; "}},
            @{N='RunAs';E={$_.Principal.UserId}},
            @{N='RunLevel';E={$_.Principal.RunLevel}}
        Export-CollectionToCSV -Data $allTasks -OutputPath (Join-Path $phasePath "ScheduledTasks.csv") -Phase "FASE_2" -Description "Tareas programadas"
        $collected++

        $xmlDir = Join-Path $phasePath "ScheduledTasksXML"
        if (-not (Test-Path $xmlDir)) { New-Item -ItemType Directory -Path $xmlDir -Force | Out-Null }
        $xmlCount = 0
        Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $xmlContent = Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue
                if ($xmlContent) {
                    $safeName = ($_.TaskPath + $_.TaskName) -replace '[\\/:*?"<>|]', '_'
                    $xmlContent | Out-File -FilePath (Join-Path $xmlDir "$safeName.xml") -Encoding UTF8
                    $xmlCount++
                }
            } catch { }
        }
        if ($xmlCount -gt 0) {
            Write-ForensicLog -Phase "FASE_2" -Action "SCHED_TASKS_XML" -Target "$xmlCount tareas exportadas como XML" -Result "OK"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "SCHED_TASKS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 2.8 Drivers cargados ---
    Write-StepHeader "2.8 Drivers Cargados"
    try {
        $drivers = Get-CimInstance Win32_SystemDriver -ErrorAction Stop | Select-Object Name, DisplayName, State, StartMode, PathName, ServiceType, Description
        Export-CollectionToCSV -Data $drivers -OutputPath (Join-Path $phasePath "Drivers.csv") -Phase "FASE_2" -Description "Drivers cargados"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "DRIVERS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 2.9 Historial de Windows Update ---
    Write-StepHeader "2.9 Historial de Windows Update"
    try {
        $hotfixes = Get-HotFix -ErrorAction SilentlyContinue | Select-Object HotFixID, Description, InstalledBy, InstalledOn
        Export-CollectionToCSV -Data $hotfixes -OutputPath (Join-Path $phasePath "WindowsUpdates.csv") -Phase "FASE_2" -Description "Actualizaciones instaladas"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "UPDATES_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 2.10 Configuracion de red ---
    Write-StepHeader "2.10 Configuracion de Red"
    try {
        $ipConfig = Get-NetIPConfiguration -Detailed -ErrorAction SilentlyContinue
        $ipAddresses = Get-NetIPAddress -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, InterfaceIndex, IPAddress, PrefixLength, AddressFamily, Type, PrefixOrigin, SuffixOrigin
        Export-CollectionToCSV -Data $ipAddresses -OutputPath (Join-Path $phasePath "IPAddresses.csv") -Phase "FASE_2" -Description "Direcciones IP"
        $collected++

        $wifiProfiles = @()
        try {
            # Limitado a 2 partes: un SSID puede contener ':' (p.ej. "Office:Guest"); sin el
            # limite, -split parte por TODAS las ocurrencias de ':' en la linea y [1] solo
            # recoge el fragmento hasta el segundo ':', truncando/corrompiendo el nombre real
            # de la red y haciendo que la consulta posterior de detalle del perfil falle o,
            # peor, coincida con un perfil distinto de igual prefijo.
            # netsh traduce la etiqueta segun el idioma del sistema: "All User Profile"
            # (ingles) y "Perfil de todos los usuarios" (espanol). Antes solo se buscaba
            # la inglesa y en un Windows en espanol no se recogia ningun perfil.
            $profileNames = (& netsh wlan show profiles 2>$null) | Select-String -Pattern "All User Profile|Perfil de todos los usuarios" | ForEach-Object { ($_ -split ":\s*", 2)[1].Trim() }
            foreach ($profile in $profileNames) {
                $detail = & netsh wlan show profile name="$profile" key=clear 2>$null
                $wifiProfiles += [PSCustomObject]@{
                    Nombre = $profile
                    Detalle = ($detail | Out-String)
                }
            }
            if ($wifiProfiles.Count -gt 0) {
                Export-CollectionToCSV -Data $wifiProfiles -OutputPath (Join-Path $phasePath "WiFiProfiles.csv") -Phase "FASE_2" -Description "Perfiles WiFi"
                $collected++
            }
        } catch {
            Write-ForensicLog -Phase "FASE_2" -Action "WIFI_WARNING" -Target "Sin adaptador WiFi o sin perfiles" -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "NETWORK_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 2.11 Reglas de Firewall ---
    Write-StepHeader "2.11 Reglas de Firewall"
    try {
        $fwRules = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq 'True' } | Select-Object `
            Name, DisplayName, Direction, Action, Profile, Enabled,
            @{N='LocalPort';E={
                try { ($_ | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue).LocalPort } catch { "N/A" }
            }},
            @{N='RemotePort';E={
                try { ($_ | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue).RemotePort } catch { "N/A" }
            }},
            @{N='Protocol';E={
                try { ($_ | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue).Protocol } catch { "N/A" }
            }},
            @{N='Program';E={
                try { ($_ | Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue).Program } catch { "N/A" }
            }}
        Export-CollectionToCSV -Data $fwRules -OutputPath (Join-Path $phasePath "FirewallRules.csv") -Phase "FASE_2" -Description "Reglas de firewall activas"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "FIREWALL_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 2.12 BitLocker ---
    Write-StepHeader "2.12 Estado de BitLocker"
    try {
        $bitlocker = Get-BitLockerVolume -ErrorAction SilentlyContinue | Select-Object MountPoint, VolumeStatus, ProtectionStatus, EncryptionMethod, EncryptionPercentage, LockStatus, AutoUnlockEnabled, VolumeType
        if ($bitlocker) {
            Export-CollectionToJSON -Data $bitlocker -OutputPath (Join-Path $phasePath "BitLocker.json") -Phase "FASE_2" -Description "Estado BitLocker"
            $collected++
        } else {
            Write-ForensicLog -Phase "FASE_2" -Action "BITLOCKER_NO_ENCONTRADO" -Target "BitLocker no activo" -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "BITLOCKER_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 2.13 Antivirus ---
    Write-StepHeader "2.13 Estado del Antivirus"
    try {
        $avProducts = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction SilentlyContinue | Select-Object displayName, instanceGuid, pathToSignedProductExe, pathToSignedReportingExe, productState, timestamp

        $defenderStatus = $null
        try {
            $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue | Select-Object `
                AMEngineVersion, AMProductVersion, AMServiceEnabled, AMServiceVersion,
                AntispywareEnabled, AntispywareSignatureLastUpdated, AntivirusEnabled,
                AntivirusSignatureLastUpdated, BehaviorMonitorEnabled, FullScanAge,
                IoavProtectionEnabled, NISEnabled, OnAccessProtectionEnabled,
                QuickScanAge, RealTimeProtectionEnabled, TamperProtectionSource
        } catch { }

        $defenderThreats = @()
        try {
            $defenderThreats = Get-MpThreatDetection -ErrorAction SilentlyContinue | Select-Object `
                ThreatID, @{N='ThreatName';E={
                    try { (Get-MpThreat -ThreatID $_.ThreatID -ErrorAction SilentlyContinue).ThreatName } catch { "N/A" }
                }},
                InitialDetectionTime, LastThreatStatusChangeTime, ProcessName, DomainUser, ActionSuccess
        } catch { }

        $avInfo = [PSCustomObject]@{
            ProductosAV  = $avProducts
            DefenderStatus = $defenderStatus
            AmenazasDetectadas = $defenderThreats
        }
        Export-CollectionToJSON -Data $avInfo -OutputPath (Join-Path $phasePath "AntivirusStatus.json") -Phase "FASE_2" -Description "Estado del antivirus"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "ANTIVIRUS_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 2.14 Politica de seguridad ---
    Write-StepHeader "2.14 Politicas de Seguridad"
    try {
        $secPolPath = Join-Path $phasePath "SecurityPolicy.inf"
        & secedit /export /cfg $secPolPath /quiet 2>$null
        if (Test-Path $secPolPath) {
            $hash = Get-ForensicHash -FilePath $secPolPath
            Add-ChainOfCustodyEntry -SourcePath "secedit" -DestPath $secPolPath -Hash $hash -Method "secedit export" -FileSize (Get-Item $secPolPath).Length
            Write-ForensicLog -Phase "FASE_2" -Action "SECPOL_EXPORTADA" -Target $secPolPath -Result "OK"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "SECPOL_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 2.15 Resultado de Politicas de Grupo ---
    Write-StepHeader "2.15 Resultado de Politicas de Grupo"
    try {
        $gpHtml = Join-Path $phasePath "GPResult.html"
        & gpresult /H $gpHtml /F 2>$null
        if (Test-Path $gpHtml) {
            $hash = Get-ForensicHash -FilePath $gpHtml
            Add-ChainOfCustodyEntry -SourcePath "gpresult" -DestPath $gpHtml -Hash $hash -Method "gpresult /H" -FileSize (Get-Item $gpHtml).Length
            $collected++
        }

        $gpText = & gpresult /R 2>$null
        if ($gpText) {
            Export-CollectionToText -Content ($gpText | Out-String) -OutputPath (Join-Path $phasePath "GPResult.txt") -Phase "FASE_2" -Description "gpresult /R"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_2" -Action "GPRESULT_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
