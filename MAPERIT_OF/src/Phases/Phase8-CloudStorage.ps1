#region ============================================================
# MaPeriT.OF - FASE 8: ALMACENAMIENTO EN LA NUBE
# Copia logs y configuracion de OneDrive, Google Drive, Dropbox
# ============================================================

function Invoke-Phase8-CloudStorage {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.CloudStorage
    $phaseNum  = 8
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    foreach ($user in Get-TargetUserPaths) {
        Write-StepHeader "8.x Cloud Storage - $($user.Name)"

        foreach ($service in $Script:CloudPaths.Keys) {
            $srcPath = Join-Path $user.Root $Script:CloudPaths[$service]
            if (-not (Test-Path $srcPath)) { continue }

            $destPath = Join-Path $phasePath "$($user.Name)\$service"

            # Logs y configuracion (sin datos de usuario)
            $n = 0
            foreach ($ext in @('*.log','*.txt','*.json','*.db','*.sqlite','*.xml','*.ini','*.dat')) {
                $n += Copy-ForensicDirectory -SourceDir $srcPath -DestDir $destPath `
                    -Filter $ext -Phase "FASE_8" -Recurse -MaxSizeMB 50
            }
            if ($n -gt 0) {
                $collected += $n
                Write-ForensicLog -Phase "FASE_8" -Action "CLOUD_COPIADO" -Target "$($user.Name)\$service" -Result "OK" -Detail "$n ficheros"
            }
        }

        # OneDrive: tambien guardar la base de datos de sincronizacion si existe
        $odSyncDB = Join-Path $user.Root "AppData\Local\Microsoft\OneDrive\*.db"
        $dbFiles  = Get-Item $odSyncDB -ErrorAction SilentlyContinue
        foreach ($db in $dbFiles) {
            $dest = Join-Path $phasePath "$($user.Name)\OneDriveSync\$($db.Name)"
            if (Copy-ForensicFile -SourcePath $db.FullName -DestPath $dest -Phase "FASE_8") { $collected++ }
        }
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
