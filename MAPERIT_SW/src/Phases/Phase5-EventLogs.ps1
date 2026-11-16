#region ============================================================
# MaPeriT.SW - FASE 5: LOGS DE EVENTOS
# ============================================================

function Invoke-Phase5-EventLogCollection {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.EventLogs
    $rawPath = Join-Path $phasePath "RawLogs"
    $analysisPath = Join-Path $phasePath "Analysis"
    $phaseNum = 5
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    # --- 5.1 Copia de todos los .evtx ---
    Write-StepHeader "5.1 Copia de Logs de Eventos (.evtx)"
    try {
        $evtxSource = "C:\Windows\System32\winevt\Logs"
        if (Test-Path $evtxSource) {
            $evtxFiles = Get-ChildItem $evtxSource -Filter "*.evtx" -ErrorAction SilentlyContinue
            $total = $evtxFiles.Count
            $current = 0
            foreach ($file in $evtxFiles) {
                $current++
                if ($current % 25 -eq 0) {
                    Write-Host "`r  [*] Copiando logs: $current/$total" -NoNewline -ForegroundColor Yellow
                }
                $destFile = Join-Path $rawPath $file.Name
                $success = Copy-ForensicFile -SourcePath $file.FullName -DestPath $destFile -Phase "FASE_5"
                if ($success) { $collected++ }
            }
            Write-Host "`r  [+] $collected logs copiados de $total                    " -ForegroundColor Green
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "EVTX_COPY_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 5.2 Analisis de eventos de seguridad: Logon ---
    Write-StepHeader "5.2 Eventos de Inicio de Sesion"
    try {
        $logonEvents = [System.Collections.ArrayList]::new()
        $events = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents $Script:Defaults.MaxEventsPerQuery -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($events).Count -MaxEvents $Script:Defaults.MaxEventsPerQuery -Phase "FASE_5" -LogDescription "Security 4624 (Logon exitoso)"
        foreach ($evt in $events) {
            $p = $evt.Properties
            $logonType = if ($p.Count -gt 8) { $p[8].Value } else { 0 }
            [void]$logonEvents.Add([PSCustomObject]@{
                Timestamp       = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                EventID         = $evt.Id
                UsuarioDestino  = if ($p.Count -gt 5) { $p[5].Value } else { "" }
                DominioDestino  = if ($p.Count -gt 6) { $p[6].Value } else { "" }
                TipoLogon       = $logonType
                TipoLogonDesc   = $Script:LogonTypes[[int]$logonType]
                IPOrigen        = if ($p.Count -gt 18) { $p[18].Value } else { "" }
                ProcesoLogon    = if ($p.Count -gt 9) { $p[9].Value } else { "" }
                PaqueteAuth     = if ($p.Count -gt 10) { $p[10].Value } else { "" }
                LogonID         = if ($p.Count -gt 7) { $p[7].Value } else { "" }
            })
        }
        if ($logonEvents.Count -gt 0) {
            Export-CollectionToCSV -Data $logonEvents -OutputPath (Join-Path $analysisPath "SecurityLogon.csv") -Phase "FASE_5" -Description "Eventos logon exitoso (4624)"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "LOGON_EVENTS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 5.3 Logons fallidos ---
    Write-StepHeader "5.3 Intentos de Sesion Fallidos"
    try {
        $failedLogons = [System.Collections.ArrayList]::new()
        $events = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} -MaxEvents $Script:Defaults.MaxEventsPerQuery -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($events).Count -MaxEvents $Script:Defaults.MaxEventsPerQuery -Phase "FASE_5" -LogDescription "Security 4625 (Logon fallido)"
        foreach ($evt in $events) {
            $p = $evt.Properties
            [void]$failedLogons.Add([PSCustomObject]@{
                Timestamp       = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                UsuarioDestino  = if ($p.Count -gt 5) { $p[5].Value } else { "" }
                DominioDestino  = if ($p.Count -gt 6) { $p[6].Value } else { "" }
                TipoLogon       = if ($p.Count -gt 10) { $p[10].Value } else { "" }
                RazonFallo      = if ($p.Count -gt 8) { $p[8].Value } else { "" }
                Status          = if ($p.Count -gt 7) { "0x{0:X}" -f $p[7].Value } else { "" }
                SubStatus       = if ($p.Count -gt 9) { "0x{0:X}" -f $p[9].Value } else { "" }
                IPOrigen        = if ($p.Count -gt 19) { $p[19].Value } else { "" }
                ProcesoLogon    = if ($p.Count -gt 11) { $p[11].Value } else { "" }
            })
        }
        if ($failedLogons.Count -gt 0) {
            Export-CollectionToCSV -Data $failedLogons -OutputPath (Join-Path $analysisPath "SecurityFailedLogon.csv") -Phase "FASE_5" -Description "Logons fallidos (4625)"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "FAILED_LOGON_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 5.4 Cambios en cuentas ---
    Write-StepHeader "5.4 Gestion de Cuentas"
    try {
        $accountIds = $Script:SecurityEventIDs.AccountCreated + $Script:SecurityEventIDs.AccountEnabled +
                      $Script:SecurityEventIDs.PasswordChange + $Script:SecurityEventIDs.AccountDisabled +
                      $Script:SecurityEventIDs.AccountDeleted + $Script:SecurityEventIDs.AccountChanged +
                      $Script:SecurityEventIDs.AccountLocked
        $accountEvents = [System.Collections.ArrayList]::new()
        $events = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=$accountIds} -MaxEvents $Script:Defaults.MaxEventsPerQuery -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($events).Count -MaxEvents $Script:Defaults.MaxEventsPerQuery -Phase "FASE_5" -LogDescription "Security (Gestion de cuentas)"
        foreach ($evt in $events) {
            $p = $evt.Properties
            [void]$accountEvents.Add([PSCustomObject]@{
                Timestamp      = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                EventID        = $evt.Id
                Descripcion    = $evt.Message -split "`n" | Select-Object -First 1
                CuentaObjetivo = if ($p.Count -gt 0) { $p[0].Value } else { "" }
                CuentaOrigen   = if ($p.Count -gt 4) { $p[4].Value } else { "" }
            })
        }
        if ($accountEvents.Count -gt 0) {
            Export-CollectionToCSV -Data $accountEvents -OutputPath (Join-Path $analysisPath "SecurityAccountChanges.csv") -Phase "FASE_5" -Description "Gestion de cuentas"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "ACCOUNT_EVENTS_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 5.5 Eventos de sistema: Servicios ---
    Write-StepHeader "5.5 Eventos de Servicios del Sistema"
    try {
        $serviceIds = $Script:SystemEventIDs.ServiceInstalled + $Script:SystemEventIDs.ServiceCrash +
                      $Script:SystemEventIDs.ServiceStartChange
        $serviceEvents = @()
        $events = Get-WinEvent -FilterHashtable @{LogName='System'; Id=$serviceIds} -MaxEvents $Script:Defaults.MaxEventsPerQuery -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($events).Count -MaxEvents $Script:Defaults.MaxEventsPerQuery -Phase "FASE_5" -LogDescription "System (Eventos de servicios)"
        foreach ($evt in $events) {
            $serviceEvents += [PSCustomObject]@{
                Timestamp   = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                EventID     = $evt.Id
                Proveedor   = $evt.ProviderName
                Mensaje     = ($evt.Message -split "`n" | Select-Object -First 2) -join " "
            }
        }
        if ($serviceEvents.Count -gt 0) {
            Export-CollectionToCSV -Data $serviceEvents -OutputPath (Join-Path $analysisPath "SystemServices.csv") -Phase "FASE_5" -Description "Eventos de servicios"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "SERVICE_EVENTS_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 5.6 Shutdowns/Startups ---
    Write-StepHeader "5.6 Arranques y Apagados"
    try {
        $shutdownIds = $Script:SystemEventIDs.ShutdownInitiated + $Script:SystemEventIDs.EventLogStarted +
                       $Script:SystemEventIDs.EventLogStopped + $Script:SystemEventIDs.UnexpectedShutdown +
                       $Script:SystemEventIDs.SystemBoot
        $shutdownEvents = @()
        $events = Get-WinEvent -FilterHashtable @{LogName='System'; Id=$shutdownIds} -MaxEvents 5000 -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($events).Count -MaxEvents 5000 -Phase "FASE_5" -LogDescription "System (Arranques/Apagados)"
        foreach ($evt in $events) {
            $shutdownEvents += [PSCustomObject]@{
                Timestamp   = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                EventID     = $evt.Id
                Tipo        = switch ($evt.Id) {
                    1074 { "Apagado/Reinicio iniciado" }
                    6005 { "Servicio de log de eventos iniciado" }
                    6006 { "Servicio de log de eventos detenido" }
                    6008 { "APAGADO INESPERADO" }
                    6009 { "Arranque del sistema" }
                    default { "Otro" }
                }
                Mensaje     = ($evt.Message -split "`n" | Select-Object -First 1)
            }
        }
        if ($shutdownEvents.Count -gt 0) {
            Export-CollectionToCSV -Data $shutdownEvents -OutputPath (Join-Path $analysisPath "SystemShutdowns.csv") -Phase "FASE_5" -Description "Arranques y apagados"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "SHUTDOWN_EVENTS_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 5.7 PowerShell Script Block Logging ---
    Write-StepHeader "5.7 PowerShell Script Block Logging"
    try {
        $psEvents = [System.Collections.ArrayList]::new()
        $events = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PowerShell/Operational'; Id=4104} -MaxEvents 10000 -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($events).Count -MaxEvents 10000 -Phase "FASE_5" -LogDescription "PowerShell Operational 4104 (Script Block Logging)"
        foreach ($evt in $events) {
            $p = $evt.Properties
            [void]$psEvents.Add([PSCustomObject]@{
                Timestamp   = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                ScriptBlock = if ($p.Count -gt 2) { $p[2].Value } else { "" }
                ScriptPath  = if ($p.Count -gt 4) { $p[4].Value } else { "" }
                Level       = $evt.Level
            })
        }
        if ($psEvents.Count -gt 0) {
            Export-CollectionToCSV -Data $psEvents -OutputPath (Join-Path $analysisPath "PowerShellScripts.csv") -Phase "FASE_5" -Description "PowerShell scripts ejecutados"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "POWERSHELL_EVENTS_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 5.7b PowerShell Module Logging (4103) ---
    Write-StepHeader "5.7b PowerShell Module Logging"
    try {
        $psModEvents = [System.Collections.ArrayList]::new()
        $events = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PowerShell/Operational'; Id=4103} -MaxEvents 10000 -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($events).Count -MaxEvents 10000 -Phase "FASE_5" -LogDescription "PowerShell Operational 4103 (Module Logging)"
        foreach ($evt in $events) {
            $p = $evt.Properties
            [void]$psModEvents.Add([PSCustomObject]@{
                Timestamp  = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                Payload    = if ($p.Count -gt 0) { $p[0].Value } else { "" }
                ContextInfo = if ($p.Count -gt 2) {
                    $ctx = $p[2].Value.ToString()
                    if ($ctx.Length -gt 300) { $ctx.Substring(0, 300) + "..." } else { $ctx }
                } else { "" }
                Level      = $evt.Level
            })
        }
        if ($psModEvents.Count -gt 0) {
            Export-CollectionToCSV -Data $psModEvents -OutputPath (Join-Path $analysisPath "PowerShellModuleLog.csv") -Phase "FASE_5" -Description "PowerShell Module Logging (4103)"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "PS_MODULE_LOG_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 5.8 Task Scheduler ---
    Write-StepHeader "5.8 Eventos del Programador de Tareas"
    try {
        $taskIds = $Script:TaskSchedulerEventIDs.TaskRegistered + $Script:TaskSchedulerEventIDs.TaskUpdated + $Script:TaskSchedulerEventIDs.TaskDeleted +
                   $Script:TaskSchedulerEventIDs.TaskStarted + $Script:TaskSchedulerEventIDs.TaskCompleted
        $taskEvents = @()
        $events = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; Id=$taskIds} -MaxEvents 10000 -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($events).Count -MaxEvents 10000 -Phase "FASE_5" -LogDescription "TaskScheduler Operational"
        foreach ($evt in $events) {
            $taskEvents += [PSCustomObject]@{
                Timestamp = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                EventID   = $evt.Id
                Accion    = switch ($evt.Id) {
                    106 { "Tarea registrada" }
                    140 { "Tarea actualizada" }
                    141 { "Tarea eliminada" }
                    200 { "Tarea iniciada" }
                    201 { "Tarea completada" }
                    default { "Otro" }
                }
                Mensaje   = ($evt.Message -split "`n" | Select-Object -First 1)
            }
        }
        if ($taskEvents.Count -gt 0) {
            Export-CollectionToCSV -Data $taskEvents -OutputPath (Join-Path $analysisPath "TaskScheduler.csv") -Phase "FASE_5" -Description "Eventos del programador"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "TASK_SCHEDULER_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 5.9 Windows Defender ---
    Write-StepHeader "5.9 Eventos de Windows Defender"
    try {
        $defenderEvents = @()
        $events = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Windows Defender/Operational'} -MaxEvents 5000 -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($events).Count -MaxEvents 5000 -Phase "FASE_5" -LogDescription "Windows Defender Operational"
        foreach ($evt in $events) {
            $defenderEvents += [PSCustomObject]@{
                Timestamp = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                EventID   = $evt.Id
                Level     = $evt.LevelDisplayName
                Mensaje   = ($evt.Message -split "`n" | Select-Object -First 2) -join " "
            }
        }
        if ($defenderEvents.Count -gt 0) {
            Export-CollectionToCSV -Data $defenderEvents -OutputPath (Join-Path $analysisPath "DefenderEvents.csv") -Phase "FASE_5" -Description "Eventos Defender"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "DEFENDER_EVENTS_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 5.10 RDP/Terminal Services ---
    Write-StepHeader "5.10 Eventos RDP/Terminal Services"
    try {
        $rdpEvents = @()
        $rdpLogs = @(
            "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational",
            "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational"
        )
        foreach ($logName in $rdpLogs) {
            $events = Get-WinEvent -FilterHashtable @{LogName=$logName} -MaxEvents 5000 -ErrorAction SilentlyContinue
            Test-EventQueryTruncated -Count @($events).Count -MaxEvents 5000 -Phase "FASE_5" -LogDescription $logName
            foreach ($evt in $events) {
                $rdpEvents += [PSCustomObject]@{
                    Timestamp = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                    Log       = $logName -replace 'Microsoft-Windows-', ''
                    EventID   = $evt.Id
                    Accion    = switch ($evt.Id) {
                        21 { "Sesion RDP iniciada" }
                        22 { "Shell RDP iniciado" }
                        23 { "Sesion RDP cerrada" }
                        24 { "Sesion RDP desconectada" }
                        25 { "Sesion RDP reconectada" }
                        default { "Evento RDP $($evt.Id)" }
                    }
                    Mensaje   = ($evt.Message -split "`n" | Select-Object -First 1)
                }
            }
        }
        if ($rdpEvents.Count -gt 0) {
            Export-CollectionToCSV -Data $rdpEvents -OutputPath (Join-Path $analysisPath "RDPSessions.csv") -Phase "FASE_5" -Description "Eventos RDP"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "RDP_EVENTS_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 5.11 Sysmon (si disponible) ---
    Write-StepHeader "5.11 Eventos Sysmon (si disponible)"
    try {
        $sysmonEvents = @()
        $events = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Sysmon/Operational'} -MaxEvents 20000 -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($events).Count -MaxEvents 20000 -Phase "FASE_5" -LogDescription "Sysmon Operational"
        if ($events) {
            foreach ($evt in $events) {
                $sysmonEvents += [PSCustomObject]@{
                    Timestamp = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                    EventID   = $evt.Id
                    Tipo      = switch ($evt.Id) {
                        1  { "Proceso creado" }
                        3  { "Conexion de red" }
                        5  { "Proceso terminado" }
                        7  { "Imagen cargada" }
                        8  { "CreateRemoteThread" }
                        11 { "Fichero creado" }
                        12 { "Registro modificado" }
                        13 { "Valor registro cambiado" }
                        22 { "Consulta DNS" }
                        default { "Evento $($evt.Id)" }
                    }
                    Mensaje   = ($evt.Message -split "`n" | Select-Object -First 2) -join " "
                }
            }
            Export-CollectionToCSV -Data $sysmonEvents -OutputPath (Join-Path $analysisPath "Sysmon.csv") -Phase "FASE_5" -Description "Eventos Sysmon"
            $collected++
        } else {
            Write-ForensicLog -Phase "FASE_5" -Action "SYSMON_NO_INSTALADO" -Target "Sysmon no detectado" -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "SYSMON_NO_DISPONIBLE" -Target "Log de Sysmon no existe" -Result "WARNING"
    }

    # --- 5.12 Application crashes ---
    Write-StepHeader "5.12 Errores de Aplicacion"
    try {
        $crashIds = $Script:AppEventIDs.AppCrash + $Script:AppEventIDs.WER + $Script:AppEventIDs.AppHang
        $crashEvents = @()
        $events = Get-WinEvent -FilterHashtable @{LogName='Application'; Id=$crashIds} -MaxEvents 5000 -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($events).Count -MaxEvents 5000 -Phase "FASE_5" -LogDescription "Application (Crashes)"
        foreach ($evt in $events) {
            $crashEvents += [PSCustomObject]@{
                Timestamp = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                EventID   = $evt.Id
                Tipo      = switch ($evt.Id) { 1000 {"Crash"} 1001 {"WER"} 1002 {"Hang"} default {"Otro"} }
                Mensaje   = ($evt.Message -split "`n" | Select-Object -First 3) -join " "
            }
        }
        if ($crashEvents.Count -gt 0) {
            Export-CollectionToCSV -Data $crashEvents -OutputPath (Join-Path $analysisPath "AppCrashes.csv") -Phase "FASE_5" -Description "Crashes de aplicacion"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_5" -Action "APP_CRASH_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
