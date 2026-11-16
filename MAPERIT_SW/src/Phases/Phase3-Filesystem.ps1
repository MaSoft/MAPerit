#region ============================================================
# MaPeriT.SW - FASE 3: ARTEFACTOS DEL SISTEMA DE FICHEROS
# ============================================================

function Invoke-Phase3-FilesystemCollection {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.Filesystem
    $phaseNum = 3
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    # --- 3.1 Extraccion de la MFT ---
    Write-StepHeader "3.1 Extraccion de la MFT (Master File Table)"
    try {
        $mftOutput = Join-Path $phasePath '$MFT'
        $mftSuccess = $false

        $mftSuccess = Extract-MFTRaw -DriveLetter "C:" -OutputPath $mftOutput
        if (-not $mftSuccess -and $Script:VSSShadowPath) {
            Write-ForensicLog -Phase "FASE_3" -Action "MFT_FALLBACK_VSS" -Target "Intentando copia via VSS"
            $vssMft = $Script:VSSShadowPath + '$MFT'
            if (Test-Path $vssMft -ErrorAction SilentlyContinue) {
                Copy-Item -Path $vssMft -Destination $mftOutput -Force -ErrorAction Stop
                $mftSuccess = $true
                Write-ForensicLog -Phase "FASE_3" -Action "MFT_VSS_OK" -Target $mftOutput -Result "OK"
            }
        }

        if ($mftSuccess -and (Test-Path $mftOutput)) {
            $hash = Get-ForensicHash -FilePath $mftOutput
            $size = (Get-Item $mftOutput).Length
            Add-ChainOfCustodyEntry -SourcePath 'C:\$MFT' -DestPath $mftOutput -Hash $hash -Method "RawDisk/VSS" -FileSize $size
            $collected++
        } else {
            Write-ForensicLog -Phase "FASE_3" -Action "MFT_NO_EXTRAIDA" -Target "Todos los metodos fallaron" -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "MFT_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.2 USN Journal ---
    Write-StepHeader "3.2 USN Journal"
    try {
        $usnOutput = Join-Path $phasePath "UsnJournal.csv"
        $usnData = & fsutil usn readjournal C: csv 2>$null
        if ($usnData) {
            $usnData | Out-File -FilePath $usnOutput -Encoding UTF8
            $hash = Get-ForensicHash -FilePath $usnOutput
            $size = (Get-Item $usnOutput).Length
            Add-ChainOfCustodyEntry -SourcePath 'C:\$Extend\$UsnJrnl' -DestPath $usnOutput -Hash $hash -Method "fsutil" -FileSize $size
            Write-ForensicLog -Phase "FASE_3" -Action "USN_JOURNAL_OK" -Target "$([math]::Round($size/1MB, 2)) MB" -Result "OK"
            $collected++
        } else {
            Write-ForensicLog -Phase "FASE_3" -Action "USN_JOURNAL_VACIO" -Target "fsutil no devolvio datos" -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "USN_JOURNAL_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.3 $LogFile ---
    Write-StepHeader "3.3 NTFS LogFile"
    try {
        if ($Script:VSSShadowPath) {
            $vssLogFile = $Script:VSSShadowPath + '$LogFile'
            $logFileOutput = Join-Path $phasePath '$LogFile'
            if (Test-Path $vssLogFile -ErrorAction SilentlyContinue) {
                Copy-Item -Path $vssLogFile -Destination $logFileOutput -Force -ErrorAction Stop
                $hash = Get-ForensicHash -FilePath $logFileOutput
                $size = (Get-Item $logFileOutput).Length
                Add-ChainOfCustodyEntry -SourcePath 'C:\$LogFile' -DestPath $logFileOutput -Hash $hash -Method "VSS" -FileSize $size
                Write-ForensicLog -Phase "FASE_3" -Action "LOGFILE_COPIADO" -Target $logFileOutput -Result "OK"
                $collected++
            }
        } else {
            Write-ForensicLog -Phase "FASE_3" -Action "LOGFILE_SIN_VSS" -Target "Requiere VSS snapshot" -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "LOGFILE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.4 Prefetch ---
    Write-StepHeader "3.4 Ficheros Prefetch"
    try {
        $prefetchSrc = "C:\Windows\Prefetch"
        $prefetchDst = Join-Path $phasePath "Prefetch"
        if (Test-Path $prefetchSrc) {
            $pfCount = Copy-ForensicDirectory -SourceDir $prefetchSrc -DestDir $prefetchDst -Phase "FASE_3" -Filter "*.pf"
            Write-ForensicLog -Phase "FASE_3" -Action "PREFETCH_COPIADOS" -Target "$pfCount ficheros" -Result "OK"
            $collected += $pfCount

            $pfSummary = @()
            Get-ChildItem (Join-Path $phasePath "Prefetch") -Filter "*.pf" -ErrorAction SilentlyContinue | ForEach-Object {
                $pfSummary += [PSCustomObject]@{
                    Nombre      = $_.Name
                    Tamano      = $_.Length
                    Creacion    = $_.CreationTime.ToString($Script:Defaults.DateFormat)
                    Modificado  = $_.LastWriteTime.ToString($Script:Defaults.DateFormat)
                    Acceso      = $_.LastAccessTime.ToString($Script:Defaults.DateFormat)
                }
            }
            if ($pfSummary.Count -gt 0) {
                Export-CollectionToCSV -Data $pfSummary -OutputPath (Join-Path $phasePath "PrefetchSummary.csv") -Phase "FASE_3" -Description "Resumen Prefetch"
                $collected++
            }
        } else {
            Write-ForensicLog -Phase "FASE_3" -Action "PREFETCH_NO_ENCONTRADO" -Target $prefetchSrc -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "PREFETCH_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.5 Ficheros recientes / LNK ---
    Write-StepHeader "3.5 Ficheros Recientes (LNK)"
    try {
        $profiles = Get-UserProfiles
        $lnkParsed = @()

        foreach ($profile in $profiles) {
            $recentDir = Join-Path $profile.ProfilePath "AppData\Roaming\Microsoft\Windows\Recent"
            if (Test-Path $recentDir) {
                $userDest = Join-Path $phasePath "RecentFiles\$($profile.Username)"
                $lnkCount = Copy-ForensicDirectory -SourceDir $recentDir -DestDir $userDest -Phase "FASE_3" -Filter "*.lnk"
                $collected += $lnkCount

                $shell = New-Object -ComObject WScript.Shell -ErrorAction SilentlyContinue
                if ($shell) {
                    Get-ChildItem $recentDir -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
                        try {
                            $shortcut = $shell.CreateShortcut($_.FullName)
                            $lnkParsed += [PSCustomObject]@{
                                Usuario        = $profile.Username
                                NombreLNK      = $_.Name
                                RutaDestino    = $shortcut.TargetPath
                                Argumentos     = $shortcut.Arguments
                                DirectorioTrabajo = $shortcut.WorkingDirectory
                                Descripcion    = $shortcut.Description
                                Creacion       = $_.CreationTime.ToString($Script:Defaults.DateFormat)
                                Modificacion   = $_.LastWriteTime.ToString($Script:Defaults.DateFormat)
                                Acceso         = $_.LastAccessTime.ToString($Script:Defaults.DateFormat)
                            }
                        } catch { }
                    }
                    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
                }
            }
        }

        if ($lnkParsed.Count -gt 0) {
            Export-CollectionToCSV -Data $lnkParsed -OutputPath (Join-Path $phasePath "LNKParsed.csv") -Phase "FASE_3" -Description "LNK parseados"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "LNK_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.6 Jump Lists ---
    Write-StepHeader "3.6 Jump Lists"
    try {
        $profiles = Get-UserProfiles
        foreach ($profile in $profiles) {
            $autoDestDir = Join-Path $profile.ProfilePath "AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations"
            $customDestDir = Join-Path $profile.ProfilePath "AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations"
            $userJumpDest = Join-Path $phasePath "JumpLists\$($profile.Username)"

            if (Test-Path $autoDestDir) {
                $c = Copy-ForensicDirectory -SourceDir $autoDestDir -DestDir (Join-Path $userJumpDest "AutomaticDestinations") -Phase "FASE_3"
                $collected += $c
            }
            if (Test-Path $customDestDir) {
                $c = Copy-ForensicDirectory -SourceDir $customDestDir -DestDir (Join-Path $userJumpDest "CustomDestinations") -Phase "FASE_3"
                $collected += $c
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "JUMPLISTS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.7 Papelera de reciclaje ---
    Write-StepHeader "3.7 Papelera de Reciclaje"
    try {
        $recycleBinPath = "C:\`$Recycle.Bin"
        $recycleOutput = Join-Path $phasePath "RecycleBin"

        if (Test-Path $recycleBinPath) {
            $sidDirs = Get-ChildItem $recycleBinPath -Directory -Force -ErrorAction SilentlyContinue
            $recycleSummary = @()

            foreach ($sidDir in $sidDirs) {
                $destSidDir = Join-Path $recycleOutput $sidDir.Name
                $iFiles = Get-ChildItem $sidDir.FullName -Filter '$I*' -Force -ErrorAction SilentlyContinue
                foreach ($iFile in $iFiles) {
                    try {
                        $iFileContent = [System.IO.File]::ReadAllBytes($iFile.FullName)
                        $originalSize = 0
                        $originalName = ""
                        $deletionTime = $null

                        if ($iFileContent.Length -ge 28) {
                            $originalSize = [BitConverter]::ToInt64($iFileContent, 8)
                            $deletionTimeTicks = [BitConverter]::ToInt64($iFileContent, 16)
                            $deletionTime = [DateTime]::FromFileTime($deletionTimeTicks)
                            $nameLength = [BitConverter]::ToInt32($iFileContent, 24)
                            if ($iFileContent.Length -ge 28 + $nameLength * 2) {
                                $originalName = [System.Text.Encoding]::Unicode.GetString($iFileContent, 28, $nameLength * 2).TrimEnd("`0")
                            }
                        }

                        $recycleSummary += [PSCustomObject]@{
                            SID             = $sidDir.Name
                            ArchivoI        = $iFile.Name
                            NombreOriginal  = $originalName
                            TamanoOriginal  = $originalSize
                            FechaEliminacion= if($deletionTime){$deletionTime.ToString($Script:Defaults.DateFormat)}else{"N/A"}
                        }
                    } catch { }
                }
                $c = Copy-ForensicDirectory -SourceDir $sidDir.FullName -DestDir $destSidDir -Phase "FASE_3"
                $collected += $c
            }

            if ($recycleSummary.Count -gt 0) {
                Export-CollectionToCSV -Data $recycleSummary -OutputPath (Join-Path $phasePath "RecycleBinSummary.csv") -Phase "FASE_3" -Description "Papelera de reciclaje"
                $collected++
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "RECYCLE_BIN_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.8 Thumbcache ---
    Write-StepHeader "3.8 Thumbcache"
    try {
        $profiles = Get-UserProfiles
        foreach ($profile in $profiles) {
            $thumbDir = Join-Path $profile.ProfilePath "AppData\Local\Microsoft\Windows\Explorer"
            if (Test-Path $thumbDir) {
                $userThumbDest = Join-Path $phasePath "Thumbcache\$($profile.Username)"
                $c = Copy-ForensicDirectory -SourceDir $thumbDir -DestDir $userThumbDest -Phase "FASE_3" -Filter "thumbcache_*.db"
                $collected += $c
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "THUMBCACHE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.9 SRUM ---
    Write-StepHeader "3.9 SRUM (System Resource Usage Monitor)"
    try {
        $srumSrc = "C:\Windows\System32\sru\SRUDB.dat"
        $srumDst = Join-Path $phasePath "SRUM\SRUDB.dat"
        if (Test-Path $srumSrc) {
            if (Copy-ForensicFile -SourcePath $srumSrc -DestPath $srumDst -Phase "FASE_3" -UseVSSFirst) { $collected++ }
        } else {
            Write-ForensicLog -Phase "FASE_3" -Action "SRUM_NO_ENCONTRADO" -Target $srumSrc -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "SRUM_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.10 Amcache ---
    Write-StepHeader "3.10 Amcache.hve"
    try {
        $amcacheSrc = "C:\Windows\AppCompat\Programs\Amcache.hve"
        $amcacheDst = Join-Path $phasePath "Amcache.hve"
        if (Test-Path $amcacheSrc) {
            if (Copy-ForensicFile -SourcePath $amcacheSrc -DestPath $amcacheDst -Phase "FASE_3" -UseVSSFirst) { $collected++ }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "AMCACHE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.11 ActivitiesCache (Windows Timeline) ---
    Write-StepHeader "3.11 ActivitiesCache (Windows Timeline)"
    try {
        $profiles = Get-UserProfiles
        foreach ($profile in $profiles) {
            $cdpBase = Join-Path $profile.ProfilePath "AppData\Local\ConnectedDevicesPlatform"
            if (Test-Path $cdpBase) {
                $dbFiles = Get-ChildItem $cdpBase -Filter "ActivitiesCache.db" -Recurse -ErrorAction SilentlyContinue
                foreach ($db in $dbFiles) {
                    $destPath = Join-Path $phasePath "ActivitiesCache\$($profile.Username)\$(Split-Path $db.Directory -Leaf)"
                    if (Copy-ForensicFile -SourcePath $db.FullName -DestPath (Join-Path $destPath "ActivitiesCache.db") -Phase "FASE_3" -UseVSSFirst) { $collected++ }
                }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "ACTIVITIES_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.12 BITS Transfer Jobs ---
    Write-StepHeader "3.12 BITS Transfer Jobs"
    try {
        $bitsOutput = & bitsadmin /list /allusers /verbose 2>$null
        if ($bitsOutput) {
            Export-CollectionToText -Content ($bitsOutput | Out-String) -OutputPath (Join-Path $phasePath "BITSJobs.txt") -Phase "FASE_3" -Description "BITS Jobs"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "BITS_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 3.13 PowerShell History ---
    Write-StepHeader "3.13 Historial de PowerShell"
    try {
        $profiles = Get-UserProfiles
        foreach ($profile in $profiles) {
            $psHistoryPath = Join-Path $profile.ProfilePath "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
            if (Test-Path $psHistoryPath) {
                $destPath = Join-Path $phasePath "PowerShellHistory\$($profile.Username)\ConsoleHost_history.txt"
                if (Copy-ForensicFile -SourcePath $psHistoryPath -DestPath $destPath -Phase "FASE_3") { $collected++ }
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "PS_HISTORY_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.14 Fichero hosts ---
    Write-StepHeader "3.14 Fichero hosts"
    try {
        $hostsSrc = "C:\Windows\System32\drivers\etc\hosts"
        if (Test-Path $hostsSrc) {
            if (Copy-ForensicFile -SourcePath $hostsSrc -DestPath (Join-Path $phasePath "hosts") -Phase "FASE_3") { $collected++ }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "HOSTS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.15 Elementos de inicio ---
    Write-StepHeader "3.15 Elementos de Inicio"
    try {
        $startupPaths = @(
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp",
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\StartUp"
        )
        $profiles = Get-UserProfiles
        foreach ($profile in $profiles) {
            $startupPaths += Join-Path $profile.ProfilePath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\StartUp"
        }

        $startupItems = @()
        foreach ($path in ($startupPaths | Select-Object -Unique)) {
            if (Test-Path $path) {
                $destDir = Join-Path $phasePath "StartupItems\$(Split-Path $path -Leaf)"
                Get-ChildItem $path -ErrorAction SilentlyContinue | ForEach-Object {
                    $startupItems += [PSCustomObject]@{
                        Ruta     = $_.FullName
                        Nombre   = $_.Name
                        Tamano   = $_.Length
                        Creacion = $_.CreationTime.ToString($Script:Defaults.DateFormat)
                    }
                }
                $c = Copy-ForensicDirectory -SourceDir $path -DestDir $destDir -Phase "FASE_3"
                $collected += $c
            }
        }

        if ($startupItems.Count -gt 0) {
            Export-CollectionToCSV -Data $startupItems -OutputPath (Join-Path $phasePath "StartupItemsSummary.csv") -Phase "FASE_3" -Description "Elementos de inicio"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "STARTUP_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.16 Informacion de volumen NTFS ---
    Write-StepHeader "3.16 Informacion del Volumen NTFS"
    try {
        $ntfsInfo = Get-NTFSVolumeInfo -DriveLetter "C:"
        if ($ntfsInfo) {
            Export-CollectionToJSON -Data $ntfsInfo -OutputPath (Join-Path $phasePath "NTFSVolumeInfo.json") -Phase "FASE_3" -Description "Info volumen NTFS"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "NTFS_INFO_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
