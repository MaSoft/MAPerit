#region ============================================================
# MaPeriT.SW - FASE 10: MECANISMOS DE PERSISTENCIA
# ============================================================

function Invoke-Phase10-PersistenceCollection {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.Persistence
    $phaseNum = 10
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    # --- 10.1 Resumen consolidado de autoruns ---
    Write-StepHeader "10.1 Resumen Consolidado de Autoruns"
    try {
        $autoruns = @()

        $runKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServicesOnce",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
        )

        foreach ($key in $runKeys) {
            if (Test-Path $key) {
                $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
                $props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" -and $_.Name -ne "(default)" } | ForEach-Object {
                    $autoruns += [PSCustomObject]@{
                        Tipo    = "Registry Run"
                        Clave   = $key
                        Nombre  = $_.Name
                        Valor   = $_.Value
                        Riesgo  = "Media"
                    }
                }
            }
        }

        $winlogon = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue
        if ($winlogon) {
            if ($winlogon.Shell -and $winlogon.Shell -ne "explorer.exe") {
                $autoruns += [PSCustomObject]@{ Tipo="Winlogon Shell"; Clave="Winlogon"; Nombre="Shell"; Valor=$winlogon.Shell; Riesgo="Alta" }
            }
            if ($winlogon.Userinit -and $winlogon.Userinit -ne "C:\Windows\system32\userinit.exe,") {
                $autoruns += [PSCustomObject]@{ Tipo="Winlogon Userinit"; Clave="Winlogon"; Nombre="Userinit"; Valor=$winlogon.Userinit; Riesgo="Alta" }
            }
        }

        $startupFolders = @(
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp",
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\StartUp"
        )
        foreach ($folder in $startupFolders) {
            if (Test-Path $folder) {
                Get-ChildItem $folder -ErrorAction SilentlyContinue | ForEach-Object {
                    $autoruns += [PSCustomObject]@{
                        Tipo    = "Startup Folder"
                        Clave   = $folder
                        Nombre  = $_.Name
                        Valor   = $_.FullName
                        Riesgo  = "Media"
                    }
                }
            }
        }

        $suspiciousTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
            $_.Principal.UserId -ne 'SYSTEM' -and
            $_.Principal.UserId -ne 'LOCAL SERVICE' -and
            $_.Principal.UserId -ne 'NETWORK SERVICE' -and
            $_.State -ne 'Disabled'
        }
        foreach ($task in $suspiciousTasks) {
            foreach ($action in $task.Actions) {
                if ($action.Execute) {
                    $autoruns += [PSCustomObject]@{
                        Tipo    = "Scheduled Task"
                        Clave   = $task.TaskPath
                        Nombre  = $task.TaskName
                        Valor   = "$($action.Execute) $($action.Arguments)"
                        Riesgo  = if($action.Execute -match 'Users|Temp|AppData|Downloads'){"Alta"}else{"Baja"}
                    }
                }
            }
        }

        if ($autoruns.Count -gt 0) {
            Export-CollectionToCSV -Data $autoruns -OutputPath (Join-Path $phasePath "AutorunsConsolidated.csv") -Phase "FASE_10" -Description "Autoruns consolidados"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_10" -Action "AUTORUNS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 10.2 WMI Event Subscriptions ---
    Write-StepHeader "10.2 Suscripciones WMI (Persistencia)"
    try {
        $wmiPersistence = @()

        $filters = Get-CimInstance -Namespace root/subscription -ClassName __EventFilter -ErrorAction SilentlyContinue
        $consumers = Get-CimInstance -Namespace root/subscription -ClassName __EventConsumer -ErrorAction SilentlyContinue
        $bindings = Get-CimInstance -Namespace root/subscription -ClassName __FilterToConsumerBinding -ErrorAction SilentlyContinue

        if ($filters) {
            foreach ($filter in $filters) {
                $wmiPersistence += [PSCustomObject]@{
                    Tipo     = "EventFilter"
                    Nombre   = $filter.Name
                    Detalle  = $filter.QueryLanguage + ": " + $filter.Query
                    Creador  = $filter.CreatorSID
                }
            }
        }

        if ($consumers) {
            foreach ($consumer in $consumers) {
                $detail = ""
                if ($consumer.CommandLineTemplate) { $detail = "CMD: " + $consumer.CommandLineTemplate }
                elseif ($consumer.ScriptText) { $detail = "Script: " + $consumer.ScriptText.Substring(0, [Math]::Min(200, $consumer.ScriptText.Length)) }
                elseif ($consumer.ScriptFileName) { $detail = "ScriptFile: " + $consumer.ScriptFileName }

                $wmiPersistence += [PSCustomObject]@{
                    Tipo     = $consumer.CimClass.CimClassName
                    Nombre   = $consumer.Name
                    Detalle  = $detail
                    Creador  = ""
                }
            }
        }

        if ($bindings) {
            foreach ($binding in $bindings) {
                $wmiPersistence += [PSCustomObject]@{
                    Tipo     = "FilterToConsumerBinding"
                    Nombre   = "Binding"
                    Detalle  = "Filter: $($binding.Filter) -> Consumer: $($binding.Consumer)"
                    Creador  = $binding.CreatorSID
                }
            }
        }

        if ($wmiPersistence.Count -gt 0) {
            Export-CollectionToCSV -Data $wmiPersistence -OutputPath (Join-Path $phasePath "WMIPersistence.csv") -Phase "FASE_10" -Description "Persistencia WMI"
            $collected++
            Write-ForensicLog -Phase "FASE_10" -Action "WMI_PERSISTENCE_DETECTADA" -Target "$($wmiPersistence.Count) elementos" -Result "WARNING"
        } else {
            Write-ForensicLog -Phase "FASE_10" -Action "WMI_SIN_SUSCRIPCIONES" -Target "Limpio" -Result "OK"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_10" -Action "WMI_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 10.3 Alternate Data Streams ---
    Write-StepHeader "10.3 Alternate Data Streams (ADS)"
    try {
        $adsResults = @()
        $scanDirs = @(
            "C:\Windows\System32",
            "C:\Windows\SysWOW64",
            "$env:SystemDrive\Users",
            "$env:TEMP"
        )

        $adsTimeout = $Script:Defaults.ADSScanTimeoutSec
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        foreach ($dir in $scanDirs) {
            if ($sw.Elapsed.TotalSeconds -gt $adsTimeout) {
                Write-ForensicLog -Phase "FASE_10" -Action "ADS_TIMEOUT" -Target "Limite de tiempo alcanzado ($adsTimeout s)" -Result "WARNING"
                break
            }

            if (-not (Test-Path $dir)) { continue }

            try {
                Get-ChildItem $dir -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($sw.Elapsed.TotalSeconds -gt $adsTimeout) { return }
                    try {
                        $streams = Get-Item $_.FullName -Stream * -ErrorAction SilentlyContinue | Where-Object { $_.Stream -ne ':$DATA' -and $_.Stream -ne 'Zone.Identifier' }
                        foreach ($stream in $streams) {
                            $adsResults += [PSCustomObject]@{
                                Fichero = $_.FullName
                                Stream  = $stream.Stream
                                Tamano  = $stream.Length
                            }
                        }
                    } catch { }
                }
            } catch { }
        }

        if ($adsResults.Count -gt 0) {
            Export-CollectionToCSV -Data $adsResults -OutputPath (Join-Path $phasePath "AlternateDataStreams.csv") -Phase "FASE_10" -Description "ADS detectados"
            $collected++
        } else {
            Write-ForensicLog -Phase "FASE_10" -Action "ADS_LIMPIO" -Target "No se encontraron ADS sospechosos" -Result "OK"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_10" -Action "ADS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 10.4 Servicios con ejecutables sin firma ---
    Write-StepHeader "10.4 Servicios con Ejecutables Sin Firma"
    try {
        $unsignedServices = @()
        $services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -and $_.State -eq 'Running' }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        foreach ($svc in $services) {
            if ($sw.Elapsed.TotalSeconds -gt $Script:Defaults.SignatureScanTimeout) {
                Write-ForensicLog -Phase "FASE_10" -Action "SIGNATURE_TIMEOUT" -Target "Limite de tiempo para verificacion de firmas" -Result "WARNING"
                break
            }

            $exePath = Resolve-ServiceExecutablePath -PathName $svc.PathName
            if ($exePath -and (Test-Path $exePath -ErrorAction SilentlyContinue)) {
                try {
                    $sig = Get-AuthenticodeSignature $exePath -ErrorAction SilentlyContinue
                    if ($sig -and $sig.Status -ne 'Valid') {
                        $unsignedServices += [PSCustomObject]@{
                            Servicio = $svc.Name
                            NombreMostrado = $svc.DisplayName
                            Ejecutable = $exePath
                            EstadoFirma = $sig.Status.ToString()
                            CuentaServicio = $svc.StartName
                            Estado = $svc.State
                        }
                    }
                } catch { }
            } else {
                # Un servicio EN EJECUCION cuyo PathName no se puede resolver a un fichero
                # real (p.ej. ruta sin comillas con espacios que no encaja en ningun
                # candidato existente) es en si mismo un dato de interes forense y no debe
                # descartarse en silencio: antes simplemente se saltaba este servicio.
                $unsignedServices += [PSCustomObject]@{
                    Servicio = $svc.Name
                    NombreMostrado = $svc.DisplayName
                    Ejecutable = $svc.PathName
                    EstadoFirma = "RutaNoResuelta"
                    CuentaServicio = $svc.StartName
                    Estado = $svc.State
                }
            }
        }

        if ($unsignedServices.Count -gt 0) {
            Export-CollectionToCSV -Data $unsignedServices -OutputPath (Join-Path $phasePath "UnsignedServices.csv") -Phase "FASE_10" -Description "Servicios sin firma"
            $collected++
            Write-ForensicLog -Phase "FASE_10" -Action "SERVICIOS_SIN_FIRMA" -Target "$($unsignedServices.Count) servicios" -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_10" -Action "UNSIGNED_SERVICES_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 10.5 Procesos desde ubicaciones inusuales ---
    Write-StepHeader "10.5 Procesos desde Ubicaciones Inusuales"
    try {
        $suspiciousProcesses = @()
        $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ExecutablePath }

        $suspiciousPaths = @('\\Users\\', '\\Temp\\', '\\tmp\\', '\\Downloads\\', '\\AppData\\Local\\Temp\\', '\\ProgramData\\', '\\Public\\')

        foreach ($proc in $processes) {
            $isSuspicious = $false
            foreach ($pattern in $suspiciousPaths) {
                if ($proc.ExecutablePath -match [regex]::Escape($pattern)) {
                    $isSuspicious = $true
                    break
                }
            }

            if ($isSuspicious) {
                $owner = "N/A"
                try {
                    $o = Invoke-CimMethod -InputObject $proc -MethodName GetOwner -ErrorAction SilentlyContinue
                    if ($o.User) { $owner = "$($o.Domain)\$($o.User)" }
                } catch { }

                $suspiciousProcesses += [PSCustomObject]@{
                    PID         = $proc.ProcessId
                    Nombre      = $proc.Name
                    Ejecutable  = $proc.ExecutablePath
                    LineaComandos = $proc.CommandLine
                    Propietario = $owner
                    ParentPID   = $proc.ParentProcessId
                    FechaCreacion = $proc.CreationDate
                }
            }
        }

        if ($suspiciousProcesses.Count -gt 0) {
            Export-CollectionToCSV -Data $suspiciousProcesses -OutputPath (Join-Path $phasePath "SuspiciousProcesses.csv") -Phase "FASE_10" -Description "Procesos sospechosos"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_10" -Action "SUSPICIOUS_PROC_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 10.6 Nuevos servicios instalados (ultimos 30 dias) ---
    Write-StepHeader "10.6 Servicios Instalados Recientemente"
    try {
        $recentServices = @()
        $thirtyDaysAgo = (Get-Date).AddDays(-30)
        $events = Get-WinEvent -FilterHashtable @{LogName='System'; Id=7045; StartTime=$thirtyDaysAgo} -ErrorAction SilentlyContinue
        foreach ($evt in $events) {
            $xml = [xml]$evt.ToXml()
            $data = $xml.Event.EventData.Data
            $recentServices += [PSCustomObject]@{
                Timestamp   = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                NombreServicio = ($data | Where-Object { $_.Name -eq 'ServiceName' }).'#text'
                ImagePath   = ($data | Where-Object { $_.Name -eq 'ImagePath' }).'#text'
                TipoServicio= ($data | Where-Object { $_.Name -eq 'ServiceType' }).'#text'
                TipoInicio  = ($data | Where-Object { $_.Name -eq 'StartType' }).'#text'
                CuentaServicio = ($data | Where-Object { $_.Name -eq 'AccountName' }).'#text'
            }
        }
        if ($recentServices.Count -gt 0) {
            Export-CollectionToCSV -Data $recentServices -OutputPath (Join-Path $phasePath "RecentServiceInstalls.csv") -Phase "FASE_10" -Description "Servicios recientes"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_10" -Action "RECENT_SERVICES_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 10.7 Certificados raiz sospechosos ---
    Write-StepHeader "10.7 Certificados Raiz Sospechosos"
    try {
        $knownIssuers = @(
            'CN=Microsoft Root Certificate Authority*',
            'CN=Microsoft Root Authority*',
            'CN=Microsoft ECC Root*',
            'CN=DigiCert*', 'CN=GlobalSign*', 'CN=VeriSign*', 'CN=GeoTrust*',
            'CN=Comodo*', 'CN=COMODO*', 'CN=Entrust*', 'CN=Go Daddy*',
            'CN=GoDaddy*', 'CN=Thawte*', 'CN=Symantec*', 'CN=Baltimore*',
            'CN=Starfield*', 'CN=AddTrust*', 'CN=USERTrust*', 'CN=AAA Certificate*',
            'CN=D-TRUST*', 'CN=T-TeleSec*', 'CN=QuoVadis*', 'CN=IdenTrust*',
            'CN=Certum*', 'CN=Buypass*', 'CN=ISRG Root*', 'CN=Amazon Root*',
            'CN=Actalis*', 'CN=Hongkong Post*', 'CN=SecureTrust*', 'CN=XRamp*',
            'CN=AffirmTrust*', 'CN=Certigna*', 'CN=emSign*', 'CN=E-Tugra*',
            'CN=OISTE*', 'CN=SwissSign*', 'CN=Trustwave*', 'CN=TWCA*',
            'CN=SSL.com*', 'CN=Telia*', 'CN=Autoridad de Certificacion*'
        )
        $suspectCerts = @()
        Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | ForEach-Object {
            $isKnown = $false
            foreach ($pattern in $knownIssuers) {
                if ($_.Issuer -like $pattern -or $_.Subject -like $pattern) { $isKnown = $true; break }
            }
            if (-not $isKnown) {
                $suspectCerts += [PSCustomObject]@{
                    Thumbprint  = $_.Thumbprint
                    Subject     = $_.Subject
                    Issuer      = $_.Issuer
                    NotBefore   = $_.NotBefore.ToString($Script:Defaults.DateFormat)
                    NotAfter    = $_.NotAfter.ToString($Script:Defaults.DateFormat)
                    SerialNumber = $_.SerialNumber
                }
            }
        }
        if ($suspectCerts.Count -gt 0) {
            Export-CollectionToCSV -Data $suspectCerts -OutputPath (Join-Path $phasePath "SuspiciousRootCerts.csv") -Phase "FASE_10" -Description "Certificados raiz sospechosos"
            $collected++
            Write-ForensicLog -Phase "FASE_10" -Action "CERTS_SOSPECHOSOS" -Target "$($suspectCerts.Count) certificados no estandar" -Result "WARNING"
        } else {
            Write-ForensicLog -Phase "FASE_10" -Action "CERTS_LIMPIOS" -Target "Solo certificados conocidos" -Result "OK"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_10" -Action "CERTS_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 10.8 COM Hijacking ---
    Write-StepHeader "10.8 COM Hijacking"
    try {
        $comHijacks = @()
        $profiles = Get-UserProfiles
        foreach ($profile in $profiles) {
            $sid = $profile.SID
            if (-not $sid) { continue }
            $effectiveSID = Get-EffectiveHKUSID -SID $sid -Username $profile.Username
            if (-not $effectiveSID) { continue }
            $clsidPath = "Registry::HKU\$effectiveSID\Software\Classes\CLSID"
            if (Test-Path $clsidPath -ErrorAction SilentlyContinue) {
                Get-ChildItem $clsidPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $clsid = $_.PSChildName
                    foreach ($subKey in @("InprocServer32", "LocalServer32")) {
                        $serverPath = Join-Path $_.PsPath $subKey
                        if (Test-Path $serverPath -ErrorAction SilentlyContinue) {
                            $val = (Get-ItemProperty $serverPath -ErrorAction SilentlyContinue).'(default)'
                            if ($val) {
                                $comHijacks += [PSCustomObject]@{
                                    Usuario   = $profile.Username
                                    CLSID     = $clsid
                                    Tipo      = $subKey
                                    Valor     = $val
                                    Riesgo    = if ($val -match 'Users|Temp|AppData|Downloads') { "Alta" } else { "Media" }
                                }
                            }
                        }
                    }
                }
            }
        }
        if ($comHijacks.Count -gt 0) {
            Export-CollectionToCSV -Data $comHijacks -OutputPath (Join-Path $phasePath "COMHijacking.csv") -Phase "FASE_10" -Description "COM Hijacking"
            $collected++
            Write-ForensicLog -Phase "FASE_10" -Action "COM_HIJACK_DETECTADO" -Target "$($comHijacks.Count) entradas CLSID en HKCU" -Result "WARNING"
        } else {
            Write-ForensicLog -Phase "FASE_10" -Action "COM_HIJACK_LIMPIO" -Target "Sin COM hijacking en HKCU" -Result "OK"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_10" -Action "COM_HIJACK_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
