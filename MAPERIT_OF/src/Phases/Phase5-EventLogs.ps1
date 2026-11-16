#region ============================================================
# MaPeriT.OF - FASE 5: LOGS DE EVENTOS
# Copia directa de .evtx desde el disco objetivo (misma ruta que SW)
# ============================================================

function Invoke-Phase5-EventLogs {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.EventLogs
    $phaseNum  = 5
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    $evtxSource = Join-Path $Script:TargetRoot $Script:TargetPaths.EventLogs

    if (-not (Test-Path $evtxSource)) {
        Write-ForensicLog -Phase "FASE_5" -Action "EVTX_DIR_NO_ENCONTRADO" -Target $evtxSource -Result "WARNING"
        Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected 0
        return 0
    }

    Write-StepHeader "5.1 Copia de ficheros .evtx"

    $evtxFiles = Get-ChildItem $evtxSource -Filter "*.evtx" -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending

    Write-ForensicLog -Phase "FASE_5" -Action "EVTX_ENCONTRADOS" -Target "$($evtxFiles.Count) ficheros" -Result "OK"

    # Priorizar logs de seguridad y sistema
    $priority = @("Security.evtx","System.evtx","Application.evtx",
                  "Microsoft-Windows-PowerShell%4Operational.evtx",
                  "Microsoft-Windows-TaskScheduler%4Operational.evtx",
                  "Microsoft-Windows-TerminalServices-RemoteConnectionManager%4Operational.evtx",
                  "Microsoft-Windows-Sysmon%4Operational.evtx",
                  "Microsoft-Windows-Windows Defender%4Operational.evtx")

    $ordered = @()
    foreach ($p in $priority) {
        $match = $evtxFiles | Where-Object { $_.Name -eq $p }
        if ($match) { $ordered += $match }
    }
    $ordered += $evtxFiles | Where-Object { $_.Name -notin $priority }

    $limitFiles = [Math]::Min($ordered.Count, $Script:Defaults.MaxEvtxFiles)
    $sw         = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($evtx in $ordered | Select-Object -First $limitFiles) {
        $dest = Join-Path $phasePath $evtx.Name
        if (Copy-ForensicFile -SourcePath $evtx.FullName -DestPath $dest -Phase "FASE_5" -Method "evtx_copy") {
            $collected++
        }
    }
    $sw.Stop()

    if ($ordered.Count -gt $limitFiles) {
        Write-ForensicLog -Phase "FASE_5" -Action "EVTX_LIMITE" -Target "$limitFiles de $($ordered.Count)" -Result "WARNING" `
            -Detail "Limite de $($Script:Defaults.MaxEvtxFiles) ficheros alcanzado"
    }

    Write-ForensicLog -Phase "FASE_5" -Action "EVTX_COMPLETADO" -Target "$collected ficheros copiados" -Result "OK" -DurationMs $sw.ElapsedMilliseconds

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
