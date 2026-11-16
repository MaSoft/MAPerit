#region ============================================================
# MaPeriT.SW - FASE 8: ALMACENAMIENTO EN LA NUBE
# ============================================================

function Invoke-Phase8-CloudStorageCollection {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.CloudStorage
    $phaseNum = 8
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]
    $profiles = Get-UserProfiles

    # --- 8.1 OneDrive ---
    Write-StepHeader "8.1 Microsoft OneDrive"
    try {
        foreach ($profile in $profiles) {
            $oneDriveLogs = Join-Path $profile.ProfilePath $Script:CloudPaths.OneDriveLogs
            $oneDriveSettings = Join-Path $profile.ProfilePath $Script:CloudPaths.OneDriveSettings

            if (Test-Path $oneDriveLogs) {
                $destDir = Join-Path $phasePath "OneDrive\$($profile.Username)\logs"
                $c = Copy-ForensicDirectory -SourceDir $oneDriveLogs -DestDir $destDir -Phase "FASE_8" -Filter "*.log" -Recurse
                $collected += $c
            }

            if (Test-Path $oneDriveSettings) {
                $destDir = Join-Path $phasePath "OneDrive\$($profile.Username)\settings"
                $c = Copy-ForensicDirectory -SourceDir $oneDriveSettings -DestDir $destDir -Phase "FASE_8" -Filter "*.ini" -Recurse
                $collected += $c
                $c2 = Copy-ForensicDirectory -SourceDir $oneDriveSettings -DestDir $destDir -Phase "FASE_8" -Filter "*.dat" -Recurse
                $collected += $c2
            }

            # Configuracion de OneDrive del registro DE ESE PERFIL (HKU\<SID>), no del
            # HKCU del perito que ejecuta la herramienta: antes se leia HKCU y se
            # atribuia la cuenta del perito a cada perfil del equipo. Solo esta
            # disponible para perfiles con sesion iniciada (los hives offline se
            # montan unicamente durante la Fase 4); el NTUSER.DAT completo de todos
            # los perfiles ya se conserva en 04_Registry\Hives\Users.
            $hkuSid = if ($profile.SID -and (Test-Path "Registry::HKU\$($profile.SID)" -ErrorAction SilentlyContinue)) { $profile.SID } else { $null }
            if ($hkuSid) {
                $oneDriveReg = Get-ItemProperty "Registry::HKU\$hkuSid\Software\Microsoft\OneDrive\Accounts\*" -ErrorAction SilentlyContinue
                if ($oneDriveReg) {
                    $odInfo = @($oneDriveReg | Select-Object UserEmail, UserFolder, ServiceEndpointUri, Business, LastSignInTime)
                    $odDir = Join-Path $phasePath "OneDrive\$($profile.Username)"
                    if (-not (Test-Path $odDir)) { New-Item -ItemType Directory -Path $odDir -Force | Out-Null }
                    Export-CollectionToJSON -Data $odInfo -OutputPath (Join-Path $odDir "OneDriveConfig.json") -Phase "FASE_8" -Description "Config OneDrive"
                    $collected++
                }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_8" -Action "ONEDRIVE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 8.2 Google Drive ---
    Write-StepHeader "8.2 Google Drive"
    try {
        foreach ($profile in $profiles) {
            $gdrivePath = Join-Path $profile.ProfilePath $Script:CloudPaths.GoogleDrive
            if (Test-Path $gdrivePath) {
                $destDir = Join-Path $phasePath "GoogleDrive\$($profile.Username)"
                $metadataFiles = Get-ChildItem $gdrivePath -Include "*.db","*.sqlite","*.journal","metadata_sqlite_db*" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 100MB }
                foreach ($file in $metadataFiles) {
                    $relPath = $file.FullName.Substring($gdrivePath.Length).TrimStart("\")
                    $success = Copy-ForensicFile -SourcePath $file.FullName -DestPath (Join-Path $destDir $relPath) -Phase "FASE_8" -UseVSSFirst
                    if ($success) { $collected++ }
                }

                $logFiles = Get-ChildItem $gdrivePath -Filter "*.log" -Recurse -ErrorAction SilentlyContinue
                foreach ($file in $logFiles) {
                    $relPath = $file.FullName.Substring($gdrivePath.Length).TrimStart("\")
                    $success = Copy-ForensicFile -SourcePath $file.FullName -DestPath (Join-Path $destDir $relPath) -Phase "FASE_8"
                    if ($success) { $collected++ }
                }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_8" -Action "GDRIVE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 8.3 Dropbox ---
    Write-StepHeader "8.3 Dropbox"
    try {
        foreach ($profile in $profiles) {
            $dropboxLocal = Join-Path $profile.ProfilePath $Script:CloudPaths.Dropbox
            $dropboxRoaming = Join-Path $profile.ProfilePath $Script:CloudPaths.DropboxInfo

            foreach ($dbxPath in @($dropboxLocal, $dropboxRoaming)) {
                if (Test-Path $dbxPath) {
                    $destDir = Join-Path $phasePath "Dropbox\$($profile.Username)"
                    $dbFiles = Get-ChildItem $dbxPath -Include "*.db","*.dbx","*.json","*.log" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 50MB }
                    foreach ($file in $dbFiles) {
                        $relPath = $file.FullName.Substring($dbxPath.Length).TrimStart("\")
                        $success = Copy-ForensicFile -SourcePath $file.FullName -DestPath (Join-Path $destDir $relPath) -Phase "FASE_8"
                        if ($success) { $collected++ }
                    }
                }
            }

            $dropboxInfoJson = Join-Path $profile.ProfilePath "AppData\Roaming\Dropbox\info.json"
            if (Test-Path $dropboxInfoJson) {
                $success = Copy-ForensicFile -SourcePath $dropboxInfoJson -DestPath (Join-Path $phasePath "Dropbox\$($profile.Username)\info.json") -Phase "FASE_8"
                if ($success) { $collected++ }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_8" -Action "DROPBOX_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 8.4 Resumen ---
    Write-StepHeader "8.4 Resumen de Almacenamiento en la Nube"
    try {
        $cloudSummary = @()
        foreach ($service in @("OneDrive","GoogleDrive","Dropbox")) {
            $serviceDir = Join-Path $phasePath $service
            if (Test-Path $serviceDir) {
                $files = Get-ChildItem $serviceDir -Recurse -File -ErrorAction SilentlyContinue
                $cloudSummary += [PSCustomObject]@{
                    Servicio    = $service
                    Ficheros    = $files.Count
                    TamanoTotalMB = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                    Detectado   = "Si"
                }
            } else {
                $cloudSummary += [PSCustomObject]@{
                    Servicio    = $service
                    Ficheros    = 0
                    TamanoTotalMB = 0
                    Detectado   = "No"
                }
            }
        }
        Export-CollectionToCSV -Data $cloudSummary -OutputPath (Join-Path $phasePath "CloudStorageSummary.csv") -Phase "FASE_8" -Description "Resumen cloud"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_8" -Action "CLOUD_SUMMARY_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
