#region ============================================================
# MaPeriT.OF - FASE 10: MECANISMOS DE PERSISTENCIA
# Tareas programadas, servicios, Winlogon, DLL hijacking, etc.
# ============================================================

function Invoke-Phase10-Persistence {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.Persistence
    $phaseNum  = 10
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    $sftHivePath = Join-Path $Script:TargetRoot $Script:HiveFiles.SOFTWARE
    $sysHivePath = Join-Path $Script:TargetRoot $Script:HiveFiles.SYSTEM
    $sftHive     = Mount-OfflineHive -HivePath $sftHivePath -Label "SFT10"
    $sysHive     = Mount-OfflineHive -HivePath $sysHivePath -Label "SYS10"

    try {
        $cs = if ($sysHive) { Get-OfflineControlSet -SystemHiveRoot $sysHive } else { "ControlSet001" }

        # --- 10.1 Tareas programadas (XML en disco) ---
        Write-StepHeader "10.1 Tareas Programadas"
        try {
            $tasksSrc  = Join-Path $Script:TargetRoot $Script:TargetPaths.Tasks
            $tasksDest = Join-Path $phasePath "ScheduledTasks"
            if (Test-Path $tasksSrc) {
                $n = Copy-RobocopyDir -SourceDir $tasksSrc -DestDir $tasksDest -Filter "*" -Phase "FASE_10" -Recurse
                # Parsear XMLs para resumen
                $taskSummary = @()
                # Las tareas de Windows\System32\Tasks son XML SIN extension: antes se
                # filtraba "*.xml" y este resumen no se generaba nunca.
                Get-ChildItem $tasksDest -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        [xml]$xml = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction Stop
                        if (-not $xml.Task) { return }
                        $taskSummary += [PSCustomObject]@{
                            TaskName    = $_.FullName.Substring($tasksDest.TrimEnd('\').Length + 1)
                            Author      = $xml.Task.RegistrationInfo.Author
                            Description = $xml.Task.RegistrationInfo.Description
                            Command     = $xml.Task.Actions.Exec.Command
                            Arguments   = $xml.Task.Actions.Exec.Arguments
                            Enabled     = $xml.Task.Settings.Enabled
                        }
                    } catch {}
                }
                if ($taskSummary.Count -gt 0) {
                    Export-CollectionToCSV -Data $taskSummary -OutputPath (Join-Path $phasePath "ScheduledTasksSummary.csv") -Phase "FASE_10" -Description "Resumen tareas"
                    $collected++
                }
                if ($n -gt 0) { $collected++ }
            } else {
                Write-ForensicLog -Phase "FASE_10" -Action "TASKS_NO_ENCONTRADO" -Target $tasksSrc -Result "WARNING"
            }
        } catch {
            Write-ForensicLog -Phase "FASE_10" -Action "TASKS_ERROR" -Target $_.Exception.Message -Result "ERROR"
        }

        # --- 10.2 Image File Execution Options (IFEO) - inyeccion de debugger ---
        Write-StepHeader "10.2 Image File Execution Options"
        if ($sftHive) {
            try {
                $ifeoKeys = Get-OfflineRegChildren -HiveRoot $sftHive -SubKey 'Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
                $ifeoRows = @()
                foreach ($k in $ifeoKeys) {
                    $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
                    if ($p -and $p.Debugger) {
                        $ifeoRows += [PSCustomObject]@{ Executable=$k.PSChildName; Debugger=$p.Debugger; GlobalFlag=$p.GlobalFlag }
                    }
                }
                if ($ifeoRows.Count -gt 0) {
                    Export-CollectionToCSV -Data $ifeoRows -OutputPath (Join-Path $phasePath "IFEO_Debuggers.csv") -Phase "FASE_10" -Description "IFEO Debuggers"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_10" -Action "IFEO_ERROR" -Target $_.Exception.Message -Result "WARNING"
            }
        }

        # --- 10.3 AppInit_DLLs ---
        Write-StepHeader "10.3 AppInit_DLLs"
        if ($sftHive) {
            try {
                $appInit = Get-OfflineRegProperty -HiveRoot $sftHive `
                    -SubKey 'Microsoft\Windows NT\CurrentVersion\Windows' -Name "AppInit_DLLs"
                if ($appInit) {
                    [PSCustomObject]@{ AppInit_DLLs = $appInit } |
                        Export-Csv (Join-Path $phasePath "AppInit_DLLs.csv") -NoTypeInformation -Encoding UTF8 -Force
                    Write-ForensicLog -Phase "FASE_10" -Action "APPINIT_DLLS" -Target "$appInit" -Result "OK"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_10" -Action "APPINIT_ERROR" -Target $_.Exception.Message -Result "WARNING"
            }
        }

        # --- 10.4 LSA Providers ---
        Write-StepHeader "10.4 LSA Security Packages"
        if ($sysHive) {
            try {
                $lsa = Get-OfflineRegProperty -HiveRoot $sysHive -SubKey "$cs\Control\Lsa"
                if ($lsa) {
                    [PSCustomObject]@{
                        AuthenticationPackages = ($lsa.Authentication_Packages | Out-String).Trim()
                        SecurityPackages       = ($lsa.Security_Packages | Out-String).Trim()
                        NotificationPackages   = ($lsa.Notification_Packages | Out-String).Trim()
                    } | Export-Csv (Join-Path $phasePath "LSA_Providers.csv") -NoTypeInformation -Encoding UTF8 -Force
                    Write-ForensicLog -Phase "FASE_10" -Action "LSA_PROVIDERS" -Target "LSA" -Result "OK"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_10" -Action "LSA_ERROR" -Target $_.Exception.Message -Result "WARNING"
            }
        }

        # --- 10.5 BAM/DAM (Background Activity Monitor) ---
        Write-StepHeader "10.5 BAM - Background Activity Monitor"
        if ($sysHive) {
            try {
                $bamRoot = Get-OfflineRegChildren -HiveRoot $sysHive -SubKey "$cs\Services\bam\State\UserSettings"
                $bamRows = @()
                foreach ($sidKey in $bamRoot) {
                    $p = Get-ItemProperty $sidKey.PSPath -ErrorAction SilentlyContinue
                    if ($p) {
                        $p.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' -and $_.Name -match '\\' } | ForEach-Object {
                            $bamRows += [PSCustomObject]@{ SID=$sidKey.PSChildName; Executable=$_.Name }
                        }
                    }
                }
                if ($bamRows.Count -gt 0) {
                    Export-CollectionToCSV -Data $bamRows -OutputPath (Join-Path $phasePath "BAM.csv") -Phase "FASE_10" -Description "BAM"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_10" -Action "BAM_ERROR" -Target $_.Exception.Message -Result "WARNING"
            }
        }

        # --- 10.6 Run keys de usuarios ---
        Write-StepHeader "10.6 Run Keys de Usuarios (NTUSER)"
        foreach ($user in Get-TargetUserPaths) {
            $ntuserPath = Join-Path $user.Root $Script:HiveFiles.NTUSER
            if (-not (Test-Path $ntuserPath)) { continue }
            $ntHive = Mount-OfflineHive -HivePath $ntuserPath -Label "NT10_$($user.Name)"
            if (-not $ntHive) { continue }
            try {
                foreach ($runKey in @('Software\Microsoft\Windows\CurrentVersion\Run','Software\Microsoft\Windows\CurrentVersion\RunOnce')) {
                    $vals = Get-OfflineRegProperty -HiveRoot $ntHive -SubKey $runKey
                    if ($vals) {
                        $vals.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } |
                            ForEach-Object { [PSCustomObject]@{ Usuario=$user.Name; Key=$runKey; Name=$_.Name; Value=$_.Value } } |
                            Export-Csv (Join-Path $phasePath "Run_$($user.Name)_Persistence.csv") -NoTypeInformation -Encoding UTF8 -Append -Force
                        Write-ForensicLog -Phase "FASE_10" -Action "USER_RUN_PERSISTENCE" -Target $user.Name -Result "OK"
                        $collected++
                    }
                }
            } finally {
                Dismount-OfflineHive -RegistryPath $ntHive
            }
        }

    } finally {
        if ($sftHive) { Dismount-OfflineHive -RegistryPath $sftHive }
        if ($sysHive) { Dismount-OfflineHive -RegistryPath $sysHive }
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
