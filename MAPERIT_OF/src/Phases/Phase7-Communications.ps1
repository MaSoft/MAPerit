#region ============================================================
# MaPeriT.OF - FASE 7: COMUNICACIONES
# Copia artefactos de Outlook, Teams, Skype, Discord desde disco objetivo
# ============================================================

function Invoke-Phase7-Communications {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.Communications
    $phaseNum  = 7
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    foreach ($user in Get-TargetUserPaths) {
        Write-StepHeader "7.x Comunicaciones - $($user.Name)"

        foreach ($app in $Script:CommunicationPaths.Keys) {
            $srcPath = Join-Path $user.Root $Script:CommunicationPaths[$app]
            if (-not (Test-Path $srcPath)) { continue }

            $destPath = Join-Path $phasePath "$($user.Name)\$app"

            # PST/OST: respetar flag -CopyLargeFiles
            if ($app -in @('OutlookOST','OutlookPST')) {
                $extensions = @('*.ost','*.pst','*.nst')
                foreach ($ext in $extensions) {
                    $files = Get-ChildItem $srcPath -Filter $ext -ErrorAction SilentlyContinue
                    foreach ($f in $files) {
                        $sizeMB = [math]::Round($f.Length / 1MB, 1)
                        if ($sizeMB -gt $Script:Defaults.LargeFileThresholdMB -and -not $CopyLargeFiles) {
                            Write-ForensicLog -Phase "FASE_7" -Action "FICHERO_GRANDE_OMITIDO" `
                                -Target "$($user.Name)\$($f.Name)" -Result "WARNING" `
                                -Detail "$sizeMB MB - Use -CopyLargeFiles para incluir"
                            continue
                        }
                        $dest = Join-Path $destPath $f.Name
                        if (Copy-ForensicFile -SourcePath $f.FullName -DestPath $dest -Phase "FASE_7" -Method "outlook_copy") {
                            $collected++
                        }
                    }
                }
            } else {
                # Teams, Skype, Discord: copiar directorio de configuracion y logs
                $n = Copy-ForensicDirectory -SourceDir $srcPath -DestDir $destPath -Phase "FASE_7" `
                    -Filter "*.json" -Recurse -MaxSizeMB 50
                $n += Copy-ForensicDirectory -SourceDir $srcPath -DestDir $destPath -Phase "FASE_7" `
                    -Filter "*.db" -Recurse -MaxSizeMB 100
                $n += Copy-ForensicDirectory -SourceDir $srcPath -DestDir $destPath -Phase "FASE_7" `
                    -Filter "*.log" -Recurse -MaxSizeMB 20
                if ($n -gt 0) { $collected += $n }
            }
        }
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
