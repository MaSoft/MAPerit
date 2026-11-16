#region ============================================================
# MaPeriT.SW - INICIALIZACION
# Verificacion de privilegios, estructura de directorios, sesion
# ============================================================

function Test-AdminPrivileges {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Prerequisites {
    $issues = @()

    if (-not (Test-AdminPrivileges)) {
        $issues += "Se requieren privilegios de Administrador. Ejecute el script como Administrador."
    }

    if ($PSVersionTable.PSVersion -lt $Script:MIN_PS_VER) {
        $issues += "Se requiere PowerShell $($Script:MIN_PS_VER) o superior. Version actual: $($PSVersionTable.PSVersion)"
    }

    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($osInfo -and $osInfo.Caption -notlike "*Windows*") {
        $issues += "Esta herramienta solo es compatible con sistemas Windows."
    }

    return $issues
}

function Initialize-OutputStructure {
    param(
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    foreach ($dirName in $Script:OutputDirs.Values) {
        $dirPath = Join-Path $OutputPath $dirName
        if (-not (Test-Path $dirPath)) {
            New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        }
    }

    # Subdirectorios especificos
    $subDirs = @(
        (Join-Path $OutputPath "$($Script:OutputDirs.Registry)\Hives"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Registry)\Hives\Users"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Registry)\ExtractedValues"),
        (Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\RawLogs"),
        (Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Filesystem)\Prefetch"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Filesystem)\RecentFiles"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Filesystem)\JumpLists"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Filesystem)\RecycleBin"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Filesystem)\Thumbcache"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Filesystem)\SRUM"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Filesystem)\ActivitiesCache"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Filesystem)\PowerShellHistory"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Filesystem)\StartupItems"),
        (Join-Path $OutputPath "$($Script:OutputDirs.Volatile)\MemoryDump")
    )

    foreach ($subDir in $subDirs) {
        if (-not (Test-Path $subDir)) {
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
        }
    }

    return $OutputPath
}

function Initialize-ForensicSession {
    param(
        [string]$CaseNumber,
        [string]$ExaminerName,
        [string]$OutputPath,
        [string]$ScriptPath,
        [string]$EvidenceDescription = "",
        [string]$HMACKey = ""
    )

    $computerInfo = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

    $Script:SessionInfo = @{
        CaseNumber          = $CaseNumber
        ExaminerName        = $ExaminerName
        EvidenceDescription = $EvidenceDescription
        OutputPath          = $OutputPath
        HMACKey             = $HMACKey
        StartTime           = Get-Date
        StartTimeUTC        = (Get-Date).ToUniversalTime()
        TimeZone            = [System.TimeZoneInfo]::Local.DisplayName
        TimeZoneId          = [System.TimeZoneInfo]::Local.Id
        UTCOffset           = [System.TimeZoneInfo]::Local.BaseUtcOffset.ToString()
        ComputerName        = $env:COMPUTERNAME
        Domain              = if ($computerInfo) { $computerInfo.Domain } else { "N/A" }
        OSVersion           = if ($osInfo) { $osInfo.Caption } else { "N/A" }
        OSBuild             = if ($osInfo) { $osInfo.BuildNumber } else { "N/A" }
        PSVersion           = $PSVersionTable.PSVersion.ToString()
        ToolName            = $Script:TOOL_FULL
        ToolVersion         = $Script:TOOL_VERSION
        ScriptHash          = Get-ScriptSelfHash -ScriptPath $ScriptPath
        ScriptPath          = $ScriptPath
        PhasesCompleted     = @()
        PhasesSkipped       = @()
        PhasesFailed        = @()
        TotalErrors         = 0
        TotalWarnings       = 0
        TotalEvidences      = 0
        EndTime             = $null
    }

    return $Script:SessionInfo
}

function Show-SessionBanner {
    $banner = $Script:Banner -replace '\{VERSION\}', $Script:TOOL_VERSION
    Write-Host $banner -ForegroundColor DarkCyan
    Write-Host $Script:LegalDisclaimer -ForegroundColor Yellow

    Write-Host ""
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor White
    Write-Host "  DATOS DE LA SESION PERICIAL" -ForegroundColor White
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor White
    Write-Host "  Caso:           $($Script:SessionInfo.CaseNumber)" -ForegroundColor White
    Write-Host "  Perito:         $($Script:SessionInfo.ExaminerName)" -ForegroundColor White
    Write-Host "  Equipo:         $($Script:SessionInfo.ComputerName)" -ForegroundColor White
    Write-Host "  Dominio:        $($Script:SessionInfo.Domain)" -ForegroundColor White
    Write-Host "  SO:             $($Script:SessionInfo.OSVersion) (Build $($Script:SessionInfo.OSBuild))" -ForegroundColor White
    Write-Host "  Zona Horaria:   $($Script:SessionInfo.TimeZone)" -ForegroundColor White
    Write-Host "  Hora Inicio:    $($Script:SessionInfo.StartTime.ToString($Script:Defaults.TimeZoneFormat))" -ForegroundColor White
    Write-Host "  Hora UTC:       $($Script:SessionInfo.StartTimeUTC.ToString($Script:Defaults.DateFormat))" -ForegroundColor White
    Write-Host "  Hash Script:    $($Script:SessionInfo.ScriptHash)" -ForegroundColor White
    Write-Host "  PowerShell:     $($Script:SessionInfo.PSVersion)" -ForegroundColor White
    Write-Host "  Salida:         $($Script:SessionInfo.OutputPath)" -ForegroundColor White
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor White
    Write-Host ""
}

function Complete-ForensicSession {
    $Script:SessionInfo.EndTime = Get-Date
    $Script:SessionInfo.TotalEvidences = $Script:EvidenceCounter
    $duration = $Script:SessionInfo.EndTime - $Script:SessionInfo.StartTime

    Write-Host ""
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  SESION PERICIAL COMPLETADA" -ForegroundColor Green
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  Hora Fin:       $($Script:SessionInfo.EndTime.ToString($Script:Defaults.TimeZoneFormat))" -ForegroundColor White
    Write-Host "  Duracion:       $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
    Write-Host "  Evidencias:     $($Script:SessionInfo.TotalEvidences)" -ForegroundColor White
    Write-Host "  Fases OK:       $($Script:SessionInfo.PhasesCompleted.Count)" -ForegroundColor Green
    if ($Script:SessionInfo.PhasesFailed.Count -gt 0) {
        Write-Host "  Fases FALLO:    $($Script:SessionInfo.PhasesFailed.Count)" -ForegroundColor Red
    }
    Write-Host "  Informe:        $(Join-Path $Script:SessionInfo.OutputPath "$($Script:OutputDirs.Report)\InformePericial.html")" -ForegroundColor Cyan
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
}

function Resolve-ServiceExecutablePath {
    <#
        Resuelve el ejecutable real a partir del PathName de un servicio de Windows
        (Win32_Service), incluyendo rutas SIN COMILLAS que contienen espacios y
        argumentos (el clasico patron de vulnerabilidad "unquoted service path").

        El enfoque anterior, usado en Fase 2 (verificacion de firma) y Fase 10
        (deteccion de servicios sin firma/sospechosos):
            $PathName -replace '^"([^"]+)".*','$1' -replace '\s+-.*$','' -replace '\s+/.*$',''
        solo funcionaba si el ejecutable iba entre comillas, o si los argumentos
        empezaban por "-"/"/". Con argumentos posicionales sin prefijo (p.ej.
        'C:\Program Files\App\svc.exe C:\config.xml') el resultado no era una ruta
        valida, Test-Path fallaba, y el servicio quedaba marcado "PathNotFound":
        EXCLUIDO EN SILENCIO de la verificacion de firma y del analisis de
        persistencia, justo el tipo de configuracion (ruta sin comillas con
        espacios) que un analisis forense deberia poder señalar, no ignorar.
    #>
    param([string]$PathName)

    if ([string]::IsNullOrWhiteSpace($PathName)) { return $null }

    # Caso con comillas: "C:\ruta con espacios\svc.exe" [argumentos]
    if ($PathName -match '^"([^"]+)"') {
        return $Matches[1]
    }

    # Sin espacios: toda la cadena es el ejecutable.
    if ($PathName -notmatch '\s') {
        return $PathName
    }

    # Sin comillas y CON espacios: probar limite por limite (algoritmo estandar de
    # resolucion de rutas de servicio sin comillas) hasta encontrar un fichero real.
    $tokens = $PathName -split ' '
    $candidate = $tokens[0]
    for ($i = 1; $i -lt $tokens.Count; $i++) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf -ErrorAction SilentlyContinue) {
            return $candidate
        }
        $candidate = "$candidate $($tokens[$i])"
    }
    if (Test-Path -LiteralPath $candidate -PathType Leaf -ErrorAction SilentlyContinue) {
        return $candidate
    }

    # Ultimo recurso: recorte por argumentos con prefijo -/ (comportamiento previo),
    # para no perder del todo el dato si ningun candidato intermedio existe en disco.
    return ($PathName -replace '\s+-.*$', '' -replace '\s+/.*$', '')
}

function Test-EventQueryTruncated {
    <#
        Comprueba si una consulta Get-WinEvent probablemente se trunco por haber alcanzado
        el limite -MaxEvents configurado. Antes, los CSV/el informe pericial nunca indicaban
        en ningun sitio que una fuente de eventos (Security, Sysmon, PowerShell, etc.) podia
        estar incompleta porque el sistema tenia mas eventos que el limite consultado -- un
        perito podia presentar sin saberlo un log parcial como si fuese completo.
    #>
    param(
        [int]$Count,
        [int]$MaxEvents,
        [string]$Phase,
        [string]$LogDescription
    )
    if ($Count -ge $MaxEvents) {
        Write-ForensicLog -Phase $Phase -Action "EVENTOS_POSIBLEMENTE_TRUNCADOS" -Target "${LogDescription}: se alcanzo el limite de $MaxEvents eventos consultados; puede haber eventos adicionales no capturados en esta adquisicion" -Result "WARNING"
        if ($Script:SessionInfo) { $Script:SessionInfo.TotalWarnings++ }
    }
}

function Test-NetworkIsolationState {
    <#
        Comprobacion de LECTURA UNICAMENTE: documenta el estado de red del equipo en el
        momento de la adquisicion (-NetworkIsolationCheck). No aisla ni desconecta nada;
        solo deja constancia en el acta pericial de si el equipo tenia conectividad activa,
        dato relevante para la cadena de custodia (p.ej. para descartar exfiltracion
        posterior a la incautacion).
    #>
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
        $established = @(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue)

        $result = [PSCustomObject]@{
            AdaptadoresActivos     = ($adapters | Select-Object -ExpandProperty Name) -join ", "
            NumAdaptadoresActivos  = @($adapters).Count
            ConexionesEstablecidas = $established.Count
            IPsRemotasUnicas       = ($established | Select-Object -ExpandProperty RemoteAddress -Unique | Where-Object { $_ -and $_ -ne '0.0.0.0' -and $_ -ne '::' }) -join ", "
            Timestamp              = (Get-Date).ToString($Script:Defaults.DateFormat)
        }

        if ($result.NumAdaptadoresActivos -gt 0 -or $result.ConexionesEstablecidas -gt 0) {
            Write-ForensicLog -Phase "FASE_1" -Action "RED_ACTIVA_EN_ADQUISICION" -Target "$($result.NumAdaptadoresActivos) adaptador(es) activo(s), $($result.ConexionesEstablecidas) conexion(es) TCP establecida(s)" -Result "WARNING"
        } else {
            Write-ForensicLog -Phase "FASE_1" -Action "RED_AISLADA_EN_ADQUISICION" -Target "Sin adaptadores activos ni conexiones TCP establecidas" -Result "OK"
        }
        return $result
    } catch {
        Write-ForensicLog -Phase "FASE_1" -Action "NETWORK_ISOLATION_CHECK_ERROR" -Target $_.Exception.Message -Result "WARNING"
        return $null
    }
}

function Test-PathExcluded {
    <#
        Comprueba si una ruta coincide con alguno de los fragmentos indicados en
        -ExcludePaths (comparacion por subcadena, sin distinguir mayusculas/minusculas).
        Se usa en los dos puntos centrales de copia (Copy-ForensicFile,
        Copy-ForensicDirectory) para minimizacion de datos cuando la autorizacion delimita
        el alcance de la adquisicion. Las exclusiones quedan siempre registradas como SKIP,
        nunca se omiten en silencio.
    #>
    param([string]$Path)

    if (-not $Script:ExcludePathPatterns -or $Script:ExcludePathPatterns.Count -eq 0) { return $false }
    if ([string]::IsNullOrEmpty($Path)) { return $false }

    foreach ($pattern in $Script:ExcludePathPatterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        if ($Path.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }
    return $false
}

function Invoke-DryRunPreflight {
    <#
        Modo -DryRun: chequeo de entorno de SOLO LECTURA. No crea VSS, no monta hives, no
        copia ni un solo byte. Comprueba prerrequisitos, localiza winpmem, enumera
        perfiles de usuario y verifica la presencia de las rutas de artefactos clave de
        cada fase, para detectar problemas de entorno ANTES de una adquisicion real.
    #>
    param([string]$ScriptPath)

    Write-Host ""
    Write-Host "  MaPeriT.SW - MODO DRY-RUN (simulacion de preflight, solo lectura)" -ForegroundColor Cyan
    Write-Host "  ===================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Este modo NO crea VSS, NO monta hives de registro y NO copia ningun" -ForegroundColor Yellow
    Write-Host "  fichero. Solo comprueba que el entorno esta listo para una adquisicion" -ForegroundColor Yellow
    Write-Host "  real." -ForegroundColor Yellow
    Write-Host ""

    $issues = Test-Prerequisites
    if ($issues.Count -eq 0) {
        Write-Host "  [+] Prerrequisitos: OK (Administrador, PowerShell, SO Windows)" -ForegroundColor Green
    } else {
        Write-Host "  [-] Prerrequisitos con problemas:" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "      - $_" -ForegroundColor Red }
    }

    $winpmemPaths = @(
        (Join-Path (Split-Path $ScriptPath -Parent) "tools\winpmem_mini_x64.exe"),
        (Join-Path (Split-Path $ScriptPath -Parent) "winpmem_mini_x64.exe"),
        "C:\Tools\winpmem_mini_x64.exe"
    )
    $winpmem = $winpmemPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $winpmem) { $winpmem = Get-Command winpmem_mini_x64.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source }
    if ($winpmem) {
        Write-Host "  [+] WinPmem localizado: $winpmem" -ForegroundColor Green
    } else {
        Write-Host "  [!] WinPmem NO localizado - el volcado de RAM (Fase 1.2) se omitira con WARNING" -ForegroundColor Yellow
    }

    $profiles = Get-UserProfiles
    Write-Host "  [*] Perfiles de usuario detectados: $($profiles.Count)" -ForegroundColor White
    foreach ($p in $profiles) {
        $sidTag = if ($p.SID) { $p.SID } else { "SID no resuelto" }
        Write-Host "      - $($p.Username) ($sidTag) - NTUSER.DAT: $(if($p.HasNTUSER){'Si'}else{'No'})" -ForegroundColor Gray
    }

    $keyPaths = @(
        "C:\Windows\Prefetch",
        "C:\Windows\AppCompat\Programs\Amcache.hve",
        "C:\Windows\System32\sru\SRUDB.dat",
        "C:\Windows\System32\winevt\Logs",
        "C:\Windows\INF\setupapi.dev.log",
        "C:\`$Recycle.Bin"
    )
    Write-Host "  [*] Rutas de artefactos clave:" -ForegroundColor White
    foreach ($kp in $keyPaths) {
        $exists = Test-Path $kp -ErrorAction SilentlyContinue
        $color = if ($exists) { "Green" } else { "Yellow" }
        $mark = if ($exists) { "[+]" } else { "[!]" }
        Write-Host "      $mark $kp" -ForegroundColor $color
    }

    try {
        $sysDrive = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
        if ($sysDrive) {
            Write-Host "  [*] Espacio libre en ${env:SystemDrive}: $([math]::Round($sysDrive.Free/1GB,1)) GB" -ForegroundColor White
        }
    } catch { }

    Write-Host ""
    Write-Host "  ===================================================================" -ForegroundColor Cyan
    Write-Host "  DRY-RUN COMPLETADO - ningun fichero del equipo ha sido modificado" -ForegroundColor Cyan
    Write-Host "  ===================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-SelfTest {
    <#
        Modo -SelfTest: prueba de humo de la cadena de integridad (hash + copia +
        registro de custodia) contra un fichero temporal SINTETICO PROPIO de la
        herramienta (nunca del equipo objetivo), para verificar que el mecanismo
        funciona correctamente antes de iniciar una adquisicion real.
    #>
    Write-Host ""
    Write-Host "  MaPeriT.SW - MODO SELF-TEST (prueba de la cadena de integridad)" -ForegroundColor Cyan
    Write-Host "  ===================================================================" -ForegroundColor Cyan
    Write-Host ""

    $allOk = $true
    $testDir = Join-Path $env:TEMP "MaPeriT_SelfTest_$(Get-Date -Format 'yyyyMMddHHmmss')"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    $srcFile = Join-Path $testDir "source.txt"
    $dstFile = Join-Path $testDir "dest.txt"
    $syntheticContent = "MaPeriT.SW SelfTest - $(Get-Date -Format o) - $([guid]::NewGuid())"

    try {
        $syntheticContent | Out-File -FilePath $srcFile -Encoding UTF8 -NoNewline
        $expectedHash = (Get-FileHash -Path $srcFile -Algorithm SHA256).Hash
        Write-Host "  [*] Fichero de prueba creado y hasheado: $expectedHash" -ForegroundColor White

        $Script:CustodyLogPath = Join-Path $testDir "TestCustody.csv"
        "Timestamp,EvidenceID,SourcePath,DestinationPath,SHA256Hash,AcquiredBy,Method,FileSize" | Out-File -FilePath $Script:CustodyLogPath -Encoding UTF8
        $Script:ActionLogPath = Join-Path $testDir "TestAction.csv"
        "Timestamp,Phase,Action,Target,Result,Duration_ms,ErrorMessage" | Out-File -FilePath $Script:ActionLogPath -Encoding UTF8
        $Script:EvidenceCounter = 0
        $Script:SessionInfo = @{ ExaminerName = "SelfTest"; TotalErrors = 0; TotalWarnings = 0 }

        $copySuccess = Copy-ForensicFile -SourcePath $srcFile -DestPath $dstFile -Phase "SELFTEST"
        if ($copySuccess -and (Test-Path $dstFile)) {
            Write-Host "  [+] Copy-ForensicFile: OK" -ForegroundColor Green
        } else {
            Write-Host "  [-] Copy-ForensicFile: FALLO" -ForegroundColor Red
            $allOk = $false
        }

        $actualHash = Get-ForensicHash -FilePath $dstFile
        if ($actualHash -eq $expectedHash) {
            Write-Host "  [+] Verificacion de hash SHA-256: OK ($actualHash)" -ForegroundColor Green
        } else {
            Write-Host "  [-] Verificacion de hash SHA-256: FALLO (esperado $expectedHash, obtenido $actualHash)" -ForegroundColor Red
            $allOk = $false
        }

        # @() fuerza contexto de array: si el CSV tiene EXACTAMENTE 1 fila de datos,
        # Import-Csv devuelve un unico [PSCustomObject] suelto (no envuelto en array),
        # que no expone propiedad .Count -> $custodyEntries.Count es $null y
        # "$null -ge 1" es $false, dando un falso "FALLO" aunque el hash SI coincida.
        $custodyEntries = @(Import-Csv $Script:CustodyLogPath -ErrorAction SilentlyContinue)
        if ($custodyEntries -and $custodyEntries.Count -ge 1 -and $custodyEntries[-1].SHA256Hash -eq $expectedHash) {
            Write-Host "  [+] Registro en cadena de custodia: OK ($($custodyEntries.Count) entrada(s))" -ForegroundColor Green
        } else {
            Write-Host "  [-] Registro en cadena de custodia: FALLO o no coincide" -ForegroundColor Red
            $allOk = $false
        }

        if ($Script:EvidenceCounter -ge 1) {
            Write-Host "  [+] Contador de evidencias: OK ($($Script:EvidenceCounter))" -ForegroundColor Green
        } else {
            Write-Host "  [-] Contador de evidencias: FALLO (no incremento)" -ForegroundColor Red
            $allOk = $false
        }
    } catch {
        Write-Host "  [-] EXCEPCION durante el self-test: $($_.Exception.Message)" -ForegroundColor Red
        $allOk = $false
    } finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "  ===================================================================" -ForegroundColor Cyan
    if ($allOk) {
        Write-Host "  SELF-TEST: TODOS LOS CHEQUEOS SUPERADOS" -ForegroundColor Green
    } else {
        Write-Host "  SELF-TEST: HAY FALLOS - revise los mensajes anteriores antes de" -ForegroundColor Red
        Write-Host "  iniciar una adquisicion real" -ForegroundColor Red
    }
    Write-Host "  ===================================================================" -ForegroundColor Cyan
    Write-Host ""

    return $allOk
}
