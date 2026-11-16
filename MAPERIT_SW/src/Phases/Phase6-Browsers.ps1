#region ============================================================
# MaPeriT.SW - FASE 6: NAVEGADORES WEB
# ============================================================

function Invoke-Phase6-BrowserCollection {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.Browsers
    $phaseNum = 6
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    $profiles = Get-UserProfiles

    # --- 6.1 Google Chrome ---
    Write-StepHeader "6.1 Google Chrome"
    try {
        foreach ($profile in $profiles) {
            $chromePath = Join-Path $profile.ProfilePath $Script:BrowserPaths.Chrome
            if (Test-Path $chromePath) {
                $chromeProfiles = @("Default") + (Get-ChildItem $chromePath -Directory -Filter "Profile *" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
                foreach ($chromeProfile in $chromeProfiles) {
                    $profileDir = Join-Path $chromePath $chromeProfile
                    if (-not (Test-Path $profileDir)) { continue }
                    $destDir = Join-Path $phasePath "Chrome\$($profile.Username)\$chromeProfile"

                    foreach ($file in $Script:ChromiumFiles) {
                        $srcFile = Join-Path $profileDir $file
                        if (Test-Path $srcFile) {
                            $success = Copy-ForensicFile -SourcePath $srcFile -DestPath (Join-Path $destDir $file) -Phase "FASE_6" -UseVSSFirst
                            if ($success) { $collected++ }
                        }
                    }

                    $extDir = Join-Path $profileDir "Extensions"
                    if (Test-Path $extDir) {
                        $extData = @()
                        Get-ChildItem $extDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                            $extId = $_.Name
                            $manifestFiles = Get-ChildItem $_.FullName -Recurse -Filter "manifest.json" -ErrorAction SilentlyContinue | Select-Object -First 1
                            if ($manifestFiles) {
                                try {
                                    $manifest = Get-Content $manifestFiles.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
                                    $extData += [PSCustomObject]@{
                                        Usuario  = $profile.Username
                                        Perfil   = $chromeProfile
                                        ExtID    = $extId
                                        Nombre   = $manifest.name
                                        Version  = $manifest.version
                                        Desc     = if($manifest.description.Length -gt 100){$manifest.description.Substring(0,100)}else{$manifest.description}
                                    }
                                } catch { }
                            }
                        }
                        if ($extData.Count -gt 0) {
                            Export-CollectionToCSV -Data $extData -OutputPath (Join-Path $destDir "Extensions.csv") -Phase "FASE_6" -Description "Extensiones Chrome"
                            $collected++
                        }
                    }
                }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_6" -Action "CHROME_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 6.2 Microsoft Edge ---
    Write-StepHeader "6.2 Microsoft Edge"
    try {
        foreach ($profile in $profiles) {
            $edgePath = Join-Path $profile.ProfilePath $Script:BrowserPaths.Edge
            if (Test-Path $edgePath) {
                $edgeProfiles = @("Default") + (Get-ChildItem $edgePath -Directory -Filter "Profile *" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
                foreach ($edgeProfile in $edgeProfiles) {
                    $profileDir = Join-Path $edgePath $edgeProfile
                    if (-not (Test-Path $profileDir)) { continue }
                    $destDir = Join-Path $phasePath "Edge\$($profile.Username)\$edgeProfile"

                    foreach ($file in $Script:ChromiumFiles) {
                        $srcFile = Join-Path $profileDir $file
                        if (Test-Path $srcFile) {
                            $success = Copy-ForensicFile -SourcePath $srcFile -DestPath (Join-Path $destDir $file) -Phase "FASE_6" -UseVSSFirst
                            if ($success) { $collected++ }
                        }
                    }
                }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_6" -Action "EDGE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 6.3 Brave ---
    Write-StepHeader "6.3 Brave"
    try {
        foreach ($profile in $profiles) {
            $bravePath = Join-Path $profile.ProfilePath $Script:BrowserPaths.Brave
            if (Test-Path $bravePath) {
                $braveProfiles = @("Default") + (Get-ChildItem $bravePath -Directory -Filter "Profile *" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
                foreach ($braveProfile in $braveProfiles) {
                    $profileDir = Join-Path $bravePath $braveProfile
                    if (-not (Test-Path $profileDir)) { continue }
                    $destDir = Join-Path $phasePath "Brave\$($profile.Username)\$braveProfile"
                    foreach ($file in $Script:ChromiumFiles) {
                        $srcFile = Join-Path $profileDir $file
                        if (Test-Path $srcFile) {
                            $success = Copy-ForensicFile -SourcePath $srcFile -DestPath (Join-Path $destDir $file) -Phase "FASE_6" -UseVSSFirst
                            if ($success) { $collected++ }
                        }
                    }
                }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_6" -Action "BRAVE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 6.4 Mozilla Firefox ---
    Write-StepHeader "6.4 Mozilla Firefox"
    try {
        foreach ($profile in $profiles) {
            $ffPath = Join-Path $profile.ProfilePath $Script:BrowserPaths.Firefox
            if (Test-Path $ffPath) {
                $ffProfiles = Get-ChildItem $ffPath -Directory -ErrorAction SilentlyContinue
                foreach ($ffProfile in $ffProfiles) {
                    $destDir = Join-Path $phasePath "Firefox\$($profile.Username)\$($ffProfile.Name)"
                    foreach ($file in $Script:FirefoxFiles) {
                        $srcFile = Join-Path $ffProfile.FullName $file
                        if (Test-Path $srcFile) {
                            $success = Copy-ForensicFile -SourcePath $srcFile -DestPath (Join-Path $destDir $file) -Phase "FASE_6" -UseVSSFirst
                            if ($success) { $collected++ }
                        }
                    }
                }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_6" -Action "FIREFOX_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 6.5 Internet Explorer ---
    Write-StepHeader "6.5 Internet Explorer / Legacy"
    try {
        foreach ($profile in $profiles) {
            $iePath = Join-Path $profile.ProfilePath $Script:BrowserPaths.IE
            if (Test-Path $iePath) {
                $webCacheFile = Join-Path $iePath "WebCacheV01.dat"
                if (Test-Path $webCacheFile) {
                    $destDir = Join-Path $phasePath "InternetExplorer\$($profile.Username)"
                    $success = Copy-ForensicFile -SourcePath $webCacheFile -DestPath (Join-Path $destDir "WebCacheV01.dat") -Phase "FASE_6" -UseVSSFirst
                    if ($success) { $collected++ }
                }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_6" -Action "IE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 6.6 Resumen de navegadores detectados ---
    Write-StepHeader "6.6 Resumen de Navegadores Detectados"
    try {
        $browserSummary = @()
        foreach ($profile in $profiles) {
            foreach ($browser in @("Chrome","Edge","Brave","Firefox","InternetExplorer")) {
                $browserDir = Join-Path $phasePath "$browser\$($profile.Username)"
                if (Test-Path $browserDir) {
                    $fileCount = (Get-ChildItem $browserDir -Recurse -File -ErrorAction SilentlyContinue).Count
                    $totalSize = (Get-ChildItem $browserDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                    $browserSummary += [PSCustomObject]@{
                        Usuario       = $profile.Username
                        Navegador     = $browser
                        FicherosCopiados = $fileCount
                        TamanoTotalMB = [math]::Round($totalSize / 1MB, 2)
                    }
                }
            }
        }
        if ($browserSummary.Count -gt 0) {
            Export-CollectionToCSV -Data $browserSummary -OutputPath (Join-Path $phasePath "BrowserSummary.csv") -Phase "FASE_6" -Description "Resumen navegadores"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_6" -Action "BROWSER_SUMMARY_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
