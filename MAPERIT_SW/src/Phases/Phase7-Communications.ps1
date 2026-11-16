#region ============================================================
# MaPeriT.SW - FASE 7: COMUNICACIONES
# ============================================================

function Invoke-Phase7-CommunicationsCollection {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.Communications
    $phaseNum = 7
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]
    $profiles = Get-UserProfiles

    # --- 7.1 Outlook PST/OST ---
    Write-StepHeader "7.1 Microsoft Outlook (PST/OST)"
    try {
        $outlookFiles = @()
        foreach ($profile in $profiles) {
            $ostDir = Join-Path $profile.ProfilePath $Script:CommunicationPaths.OutlookOST
            $pstDir = Join-Path $profile.ProfilePath $Script:CommunicationPaths.OutlookPST

            foreach ($dir in @($ostDir, $pstDir)) {
                if (Test-Path $dir) {
                    Get-ChildItem $dir -Include "*.ost","*.pst" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                        $sizeMB = [math]::Round($_.Length / 1MB, 2)
                        $outlookFiles += [PSCustomObject]@{
                            Usuario    = $profile.Username
                            Fichero    = $_.Name
                            RutaCompleta = $_.FullName
                            TamanoMB   = $sizeMB
                            Tipo       = $_.Extension.ToUpper().TrimStart(".")
                            Modificado = $_.LastWriteTime.ToString($Script:Defaults.DateFormat)
                            Creacion   = $_.CreationTime.ToString($Script:Defaults.DateFormat)
                        }

                        if ($_.Length -le ($Script:Defaults.LargeFileThresholdMB * 1MB) -or $CopyLargeFiles) {
                            $destPath = Join-Path $phasePath "Outlook\$($profile.Username)\$($_.Name)"
                            $success = Copy-ForensicFile -SourcePath $_.FullName -DestPath $destPath -Phase "FASE_7" -UseVSSFirst
                            if ($success) { $collected++ }
                        } else {
                            Write-ForensicLog -Phase "FASE_7" -Action "OUTLOOK_GRANDE" -Target "$($_.Name) ($sizeMB MB) - solo metadatos (use -CopyLargeFiles para copiar)" -Result "WARNING"
                        }
                    }
                }
            }
        }
        if ($outlookFiles.Count -gt 0) {
            Export-CollectionToCSV -Data $outlookFiles -OutputPath (Join-Path $phasePath "OutlookFiles.csv") -Phase "FASE_7" -Description "Ficheros Outlook"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_7" -Action "OUTLOOK_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 7.2 Microsoft Teams ---
    Write-StepHeader "7.2 Microsoft Teams"
    try {
        foreach ($profile in $profiles) {
            $teamsNew = Join-Path $profile.ProfilePath $Script:CommunicationPaths.TeamsNew
            $teamsClassic = Join-Path $profile.ProfilePath $Script:CommunicationPaths.TeamsClassic

            if (Test-Path $teamsNew) {
                $destDir = Join-Path $phasePath "Teams\$($profile.Username)\NewTeams"
                $dbFiles = Get-ChildItem $teamsNew -Include "*.db","*.json","*.log" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 100MB }
                foreach ($file in $dbFiles) {
                    $relPath = $file.FullName.Substring($teamsNew.Length).TrimStart("\")
                    $success = Copy-ForensicFile -SourcePath $file.FullName -DestPath (Join-Path $destDir $relPath) -Phase "FASE_7"
                    if ($success) { $collected++ }
                }
            }

            if (Test-Path $teamsClassic) {
                $destDir = Join-Path $phasePath "Teams\$($profile.Username)\ClassicTeams"
                $keyFiles = @("storage.json", "Cookies", "Local Storage", "IndexedDB")
                foreach ($keyFile in $keyFiles) {
                    $srcPath = Join-Path $teamsClassic $keyFile
                    if (Test-Path $srcPath) {
                        if ((Get-Item $srcPath).PSIsContainer) {
                            $c = Copy-ForensicDirectory -SourceDir $srcPath -DestDir (Join-Path $destDir $keyFile) -Phase "FASE_7" -Recurse
                            $collected += $c
                        } else {
                            $success = Copy-ForensicFile -SourcePath $srcPath -DestPath (Join-Path $destDir $keyFile) -Phase "FASE_7"
                            if ($success) { $collected++ }
                        }
                    }
                }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_7" -Action "TEAMS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 7.3 Skype ---
    Write-StepHeader "7.3 Skype"
    try {
        foreach ($profile in $profiles) {
            $skypePath = Join-Path $profile.ProfilePath $Script:CommunicationPaths.Skype
            if (Test-Path $skypePath) {
                $destDir = Join-Path $phasePath "Skype\$($profile.Username)"
                $dbFiles = Get-ChildItem $skypePath -Include "*.db","*.sqlite","*.json" -Recurse -ErrorAction SilentlyContinue
                foreach ($file in $dbFiles) {
                    $success = Copy-ForensicFile -SourcePath $file.FullName -DestPath (Join-Path $destDir $file.Name) -Phase "FASE_7"
                    if ($success) { $collected++ }
                }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_7" -Action "SKYPE_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 7.4 Discord ---
    Write-StepHeader "7.4 Discord"
    try {
        foreach ($profile in $profiles) {
            $discordPath = Join-Path $profile.ProfilePath $Script:CommunicationPaths.Discord
            if (Test-Path $discordPath) {
                $destDir = Join-Path $phasePath "Discord\$($profile.Username)"
                $ldbDir = Join-Path $discordPath "Local Storage\leveldb"
                if (Test-Path $ldbDir) {
                    $c = Copy-ForensicDirectory -SourceDir $ldbDir -DestDir (Join-Path $destDir "leveldb") -Phase "FASE_7"
                    $collected += $c
                }
                $cacheDir = Join-Path $discordPath "Cache\Cache_Data"
                if (Test-Path $cacheDir) {
                    Write-ForensicLog -Phase "FASE_7" -Action "DISCORD_CACHE_DETECTADO" -Target "$cacheDir (solo metadatos)" -Result "OK"
                }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_7" -Action "DISCORD_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
