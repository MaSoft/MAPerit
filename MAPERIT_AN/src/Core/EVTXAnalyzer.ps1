#region ============================================================
# MaPeriT.AN - ANALIZADOR EVTX PROFUNDO
# Usa System.Diagnostics.Eventing.Reader sobre los .evtx copiados.
# Sin limite de eventos. Sin dependencias externas.
# ============================================================

function Invoke-EVTXAnalysis {
    param(
        [string]$EventLogsPath,
        [string]$OutputPath
    )

    Write-ANSection "ANALISIS EVTX - LOGS DE EVENTOS"
    $evtxOut = Join-Path $OutputPath $Script:AN_Dirs.EVTX

    $evtxFiles = @(Get-ChildItem $EventLogsPath -Filter "*.evtx" -Recurse -ErrorAction SilentlyContinue)
    if ($evtxFiles.Count -eq 0) {
        Write-ANLog -Phase "EVTX" -Action "NO_HAY_EVTX" -Target $EventLogsPath -Result "WARNING"
        return
    }

    Write-ANLog -Phase "EVTX" -Action "EVTX_ENCONTRADOS" -Target "$($evtxFiles.Count) ficheros .evtx" -Result "OK"

    # Organizar por fichero clave
    $keyFiles = @{
        Security  = $evtxFiles | Where-Object { $_.Name -eq "Security.evtx" } | Select-Object -First 1
        System    = $evtxFiles | Where-Object { $_.Name -eq "System.evtx" }   | Select-Object -First 1
        PowerShell= $evtxFiles | Where-Object { $_.Name -like "*PowerShell*Operational*" } | Select-Object -First 1
        PSCore    = $evtxFiles | Where-Object { $_.Name -eq "PowerShellCore%4Operational.evtx" } | Select-Object -First 1
        Sysmon    = $evtxFiles | Where-Object { $_.Name -like "*Sysmon*" }     | Select-Object -First 1
        WMI       = $evtxFiles | Where-Object { $_.Name -like "*WMI-Activity*Operational*" } | Select-Object -First 1
        TaskSched = $evtxFiles | Where-Object { $_.Name -like "*TaskScheduler*Operational*" } | Select-Object -First 1
        Defender  = $evtxFiles | Where-Object { $_.Name -like "*Windows Defender*Operational*" } | Select-Object -First 1
    }

    $allEvents = [System.Collections.Generic.List[object]]::new()

    # ── Procesar Security.evtx ─────────────────────────────────────────
    if ($keyFiles.Security) {
        Write-Host "  [*] Procesando Security.evtx..." -ForegroundColor Yellow
        $secEvents = Read-EVTXEvents -FilePath $keyFiles.Security.FullName -EventIDs ($Script:EventIDs.Logon + $Script:EventIDs.AccountMgmt + $Script:EventIDs.AuditLog + $Script:EventIDs.Services + $Script:EventIDs.Process)
        foreach ($e in $secEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "SECURITY_PROCESADO" -Target "$($secEvents.Count) eventos relevantes" -Result "OK"
    }

    # ── Procesar Security Archives ─────────────────────────────────────
    $archiveSec = @($evtxFiles | Where-Object { $_.Name -like "Archive-Security-*.evtx" })
    if ($archiveSec.Count -gt 0) {
        Write-Host "  [*] Procesando $($archiveSec.Count) archives de Security (XPath)..." -ForegroundColor Yellow
        # Solo eventos criticos en archives — IDs de alta prioridad unicamente
        $archiveIDs = @(1102, 1104, 4624, 4625, 4648, 4672, 4697, 4698, 4720, 4726, 4728, 4732, 4740, 7045)
        $archiveCount = 0; $archIdx = 0
        foreach ($arch in $archiveSec) {
            $archIdx++
            if ($archIdx % 25 -eq 0) { Write-Host "`r  [*] Archives: $archIdx/$($archiveSec.Count)..." -NoNewline -ForegroundColor Yellow }
            $archEvents = @(Read-EVTXEvents -FilePath $arch.FullName -EventIDs $archiveIDs)
            foreach ($e in $archEvents) { $allEvents.Add($e) }
            $archiveCount += $archEvents.Count
        }
        Write-Host ""
        Write-ANLog -Phase "EVTX" -Action "ARCHIVES_PROCESADOS" -Target "$archiveCount eventos de $($archiveSec.Count) archives" -Result "OK"
    }

    # ── Procesar System.evtx ───────────────────────────────────────────
    if ($keyFiles.System) {
        Write-Host "  [*] Procesando System.evtx..." -ForegroundColor Yellow
        $sysEvents = Read-EVTXEvents -FilePath $keyFiles.System.FullName -EventIDs ($Script:EventIDs.Services + $Script:EventIDs.System)
        foreach ($e in $sysEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "SYSTEM_PROCESADO" -Target "$($sysEvents.Count) eventos relevantes" -Result "OK"
    }

    # ── Procesar PowerShell ────────────────────────────────────────────
    foreach ($psFile in @($keyFiles.PowerShell, $keyFiles.PSCore) | Where-Object { $_ }) {
        Write-Host "  [*] Procesando $($psFile.Name)..." -ForegroundColor Yellow
        $psEvents = Read-EVTXEvents -FilePath $psFile.FullName -EventIDs $Script:EventIDs.PowerShell
        foreach ($e in $psEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "POWERSHELL_PROCESADO" -Target "$($psEvents.Count) eventos" -Result "OK"
    }

    # ── Procesar WMI ──────────────────────────────────────────────────
    if ($keyFiles.WMI) {
        $wmiEvents = Read-EVTXEvents -FilePath $keyFiles.WMI.FullName -EventIDs $Script:EventIDs.WMI
        foreach ($e in $wmiEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "WMI_PROCESADO" -Target "$($wmiEvents.Count) eventos" -Result "OK"
    }

    # ── Procesar Defender ─────────────────────────────────────────────
    if ($keyFiles.Defender) {
        $defEvents = Read-EVTXEvents -FilePath $keyFiles.Defender.FullName -EventIDs $Script:EventIDs.Defender
        foreach ($e in $defEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "DEFENDER_PROCESADO" -Target "$($defEvents.Count) eventos" -Result "OK"
    }

    # ── Procesar TaskScheduler ────────────────────────────────────────
    if ($keyFiles.TaskSched) {
        $tsEvents = Read-EVTXEvents -FilePath $keyFiles.TaskSched.FullName -EventIDs $Script:EventIDs.Scheduled
        foreach ($e in $tsEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "TASKSCHEDULER_PROCESADO" -Target "$($tsEvents.Count) eventos" -Result "OK"
    }

    # ── Ordenar y exportar ────────────────────────────────────────────
    $sorted = @($allEvents | Sort-Object TimeCreated_UTC)
    $Script:ANSession.EVTXEvents = $sorted.Count

    Export-ANData -Data $sorted -Path (Join-Path $evtxOut "EVTX_Timeline.csv") -Description "Timeline EVTX consolidada"

    # Exportar subconjuntos de interes
    # @(): con un unico evento, Where-Object devuelve un objeto suelto cuyo .Count es
    # $null en PowerShell 5.1 y la alerta correspondiente no saltaba (un unico borrado
    # del log de auditoria pasaba sin alerta).
    $logons  = @($sorted | Where-Object { $_.EventID -in @(4624,4625,4634,4648) })
    $failed  = @($sorted | Where-Object { $_.EventID -eq 4625 })
    $newSvc  = @($sorted | Where-Object { $_.EventID -in @(7045,4697) })
    $psBlock = @($sorted | Where-Object { $_.EventID -eq 4104 })
    # Solo 1102 es "log de auditoria borrado". 1100 (servicio de registro de eventos
    # detenido) y 1104 (log de seguridad lleno) se conservan en la timeline con su
    # propia descripcion, pero no se presentan como borrado.
    $logCleared = @($sorted | Where-Object { $_.EventID -eq 1102 })
    $processes  = @($sorted | Where-Object { $_.EventID -eq 4688 })

    Export-ANData -Data $logons      -Path (Join-Path $evtxOut "EVTX_Logons.csv")         -Description "Logons"
    Export-ANData -Data $failed      -Path (Join-Path $evtxOut "EVTX_FailedLogons.csv")   -Description "Logons fallidos"
    Export-ANData -Data $newSvc      -Path (Join-Path $evtxOut "EVTX_NuevosServicios.csv")-Description "Nuevos servicios"
    Export-ANData -Data $psBlock     -Path (Join-Path $evtxOut "EVTX_PowerShell4104.csv") -Description "ScriptBlock PowerShell"
    Export-ANData -Data $logCleared  -Path (Join-Path $evtxOut "EVTX_LogBorrado.csv")     -Description "Log auditoria borrado"
    Export-ANData -Data $processes   -Path (Join-Path $evtxOut "EVTX_Procesos.csv")       -Description "Procesos creados (4688)"

    Write-ANLog -Phase "EVTX" -Action "ANALISIS_COMPLETO" -Target "Total $($sorted.Count) eventos relevantes extraidos" -Result "OK"

    # ── Alertas ───────────────────────────────────────────────────────
    if ($logCleared.Count -gt 0) {
        Write-ANLog -Phase "EVTX" -Action "ALERTA_LOG_BORRADO" -Target "$($logCleared.Count) eventos de borrado de log" -Result "WARNING"
    }
    if ($failed.Count -gt 5) {
        Write-ANLog -Phase "EVTX" -Action "ALERTA_LOGONS_FALLIDOS" -Target "$($failed.Count) logons fallidos detectados" -Result "WARNING"
    }
    if ($newSvc.Count -gt 0) {
        Write-ANLog -Phase "EVTX" -Action "ALERTA_NUEVOS_SERVICIOS" -Target "$($newSvc.Count) servicios nuevos instalados" -Result "WARNING"
    }
}

function Read-EVTXEvents {
    param(
        [string]$FilePath,
        [int[]]$EventIDs
    )

    $results = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path $FilePath)) { return $results }

    # BUG CONFIRMADO #1: el filtro XPath se limitaba SIEMPRE a los primeros 15
    # IDs de $EventIDs, descartando el resto sin ningun aviso ni bucle que los
    # procesara despues. La llamada real desde Invoke-EVTXAnalysis concatena
    # hasta 31 IDs para Security.evtx (Logon+AccountMgmt+AuditLog+Services+
    # Process); los que caian tras el 15 - incluyendo 1102 (log de auditoria
    # borrado) y 4688 (proceso creado), usados explicitamente mas abajo para
    # EVTX_LogBorrado.csv/EVTX_Procesos.csv y la alerta de log borrado - nunca
    # se consultaban contra Security.evtx, mientras el log seguia registrando
    # "SECURITY_PROCESADO OK", dando falsa sensacion de cobertura completa.
    # Ahora se trocea en lotes de <=15 y se ejecuta una consulta XPath por lote.
    $eventIdSet = [System.Collections.Generic.HashSet[int]]::new([int[]]$EventIDs)
    $batches = [System.Collections.Generic.List[object]]::new()
    for ($bi = 0; $bi -lt $EventIDs.Count; $bi += 15) {
        $end = [Math]::Min($bi + 14, $EventIDs.Count - 1)
        $batches.Add(@($EventIDs[$bi..$end]))
    }
    if ($batches.Count -eq 0) { $batches.Add(@()) }

    foreach ($batch in $batches) {
    try {
        $reader = $null
        try {
            if ($batch.Count -eq 0) { throw "sin IDs, forzar fallback sin XPath" }
            $xpathIds = ($batch | ForEach-Object { "EventID=$_" }) -join " or "
            $xpath    = "*[System[($xpathIds)]]"
            $query    = New-Object System.Diagnostics.Eventing.Reader.EventLogQuery(
                            $FilePath,
                            [System.Diagnostics.Eventing.Reader.PathType]::FilePath,
                            $xpath)
            $reader   = New-Object System.Diagnostics.Eventing.Reader.EventLogReader($query)
        } catch {
            # Fallback sin XPath (lee todo). BUG CONFIRMADO #2: el comentario
            # original decia "filtra en PS" pero esa comprobacion nunca
            # existia - se anadia CUALQUIER evento del log a los resultados,
            # ignorando por completo $EventIDs. Ahora si se filtra de verdad
            # mas abajo (comprobacion $eventIdSet.Contains($eid)).
            $reader = New-Object System.Diagnostics.Eventing.Reader.EventLogReader(
                          $FilePath,
                          [System.Diagnostics.Eventing.Reader.PathType]::FilePath)
        }

        while ($true) {
            try {
                $event = $reader.ReadEvent()
                if ($null -eq $event) { break }

                $eid = $event.Id
                if ($eventIdSet.Count -gt 0 -and -not $eventIdSet.Contains($eid)) { $event.Dispose(); continue }

                $props = @{}
                try {
                    $xml = [xml]$event.ToXml()
                    $eventData = $xml.Event.EventData.Data
                    if ($eventData) {
                        foreach ($d in $eventData) {
                            if ($d.Name) { $props[$d.Name] = $d.'#text' }
                        }
                    }
                } catch {}

                $obj = [PSCustomObject]@{
                    TimeCreated_UTC = $event.TimeCreated.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
                    EventID         = $eid
                    Categoria       = Get-EventCategory $eid
                    Log             = $event.LogName
                    ComputerName    = $event.MachineName
                    UserID          = if ($event.UserId) { $event.UserId.Value } else { "" }
                    TargetUser      = $props["TargetUserName"]
                    TargetDomain    = $props["TargetDomainName"]
                    SubjectUser     = $props["SubjectUserName"]
                    LogonType       = if ($props["LogonType"]) { "$($props['LogonType']) ($($Script:LogonTypes[[int]$props['LogonType']]))" } else { "" }
                    WorkstationName = $props["WorkstationName"]
                    IPAddress       = $props["IpAddress"]
                    ProcessName     = $props["NewProcessName"]
                    CommandLine     = $props["CommandLine"]
                    ServiceName     = if ($props["ServiceName"]) { $props["ServiceName"] } elseif ($props["param1"]) { $props["param1"] } else { "" }
                    ScriptBlock     = if ($props["ScriptBlockText"]) { $props["ScriptBlockText"].Substring(0, [math]::Min(500, $props["ScriptBlockText"].Length)) } else { "" }
                    Description     = Get-EventDescription $eid $props
                }

                $results.Add($obj)
                $event.Dispose()
            } catch { break }
        }
        $reader.Dispose()
    } catch {
        Write-ANLog -Phase "EVTX" -Action "ERROR_LEYENDO" -Target (Split-Path $FilePath -Leaf) -Result "WARNING" -Detail $_.Exception.Message
    }
    } # fin foreach ($batch in $batches)

    return $results
}

function Get-EventCategory {
    param([int]$ID)
    switch ($ID) {
        {$_ -in @(4624,4625,4634,4647,4648,4672,4778,4779)} { "Autenticacion" }
        {$_ -in @(4688,4689)}                                { "Proceso" }
        {$_ -in @(4697,7045)}                                { "Servicio Nuevo" }
        {$_ -in @(7034,7035,7036,7040)}                      { "Servicio" }
        {$_ -in @(4698,4702,4699,106,140,141,200,201)}       { "Tarea Programada" }
        {$_ -in @(4103,4104,4105,4106,400,403,600)}          { "PowerShell" }
        1102                                                 { "Log Borrado" }
        {$_ -in @(1100,1104)}                                { "Registro de Eventos" }
        {$_ -in @(6005,6006,6008,41)}                        { "Arranque/Apagado" }
        {$_ -in @(5860,5861,5857,5858,5859)}                 { "WMI" }
        {$_ -in @(1116,1117,1118,1119,5001,5004)}            { "Defender" }
        {$_ -in @(4720,4722,4724,4725,4726,4728,4732,4733,4735,4738,4740,4756)} { "Gestion Cuentas" }
        default                                               { "Otro" }
    }
}

function Get-EventDescription {
    param([int]$ID, [hashtable]$Props)
    switch ($ID) {
        4624 { "Logon exitoso: $($Props['TargetUserName'])@$($Props['TargetDomainName']) Tipo=$($Props['LogonType'])" }
        4625 { "Logon FALLIDO: $($Props['TargetUserName'])@$($Props['TargetDomainName']) Tipo=$($Props['LogonType'])" }
        4634 { "Logoff: $($Props['TargetUserName'])" }
        4648 { "Logon con credenciales explicitas: $($Props['TargetUserName'])" }
        4672 { "Privilegios especiales asignados: $($Props['SubjectUserName'])" }
        4688 { "Proceso creado: $($Props['NewProcessName'])" }
        4697 { "Servicio instalado: $($Props['ServiceName'])" }
        4698 { "Tarea programada creada: $($Props['TaskName'])" }
        4720 { "Cuenta creada: $($Props['TargetUserName'])" }
        4726 { "Cuenta eliminada: $($Props['TargetUserName'])" }
        4728 { "Usuario anadido a grupo global: $($Props['TargetUserName'])" }
        4732 { "Usuario anadido a grupo local (Administrators?): $($Props['TargetUserName'])" }
        4740 { "Cuenta bloqueada: $($Props['TargetUserName'])" }
        1100 { "Servicio de registro de eventos detenido (apagado del sistema o detencion del servicio)" }
        1102 { "Log de auditoria borrado por $($Props['SubjectUserName'])" }
        1104 { "Log de seguridad lleno: no se registran mas eventos" }
        7045 { "Nuevo servicio instalado: $($Props['param1']) Ruta: $($Props['param2'])" }
        4104 { "Script PowerShell ejecutado (ScriptBlock)" }
        6005 { "Inicio del sistema (Event Log Service iniciado)" }
        6006 { "Apagado del sistema" }
        6008 { "Apagado inesperado" }
        41   { "Kernel-Power: reinicio sin apagado correcto" }
        default { "" }
    }
}
