#region ============================================================
# MaPeriT.OF - FASE 4: REGISTRO DE WINDOWS OFFLINE
# Carga hives del disco objetivo y exporta artefactos clave
# ============================================================

function Invoke-Phase4-Registry {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.Registry
    $phaseNum  = 4
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    $sysHivePath = Join-Path $Script:TargetRoot $Script:HiveFiles.SYSTEM
    $sftHivePath = Join-Path $Script:TargetRoot $Script:HiveFiles.SOFTWARE

    # --- 4.0 Copia en bruto de los hives como evidencia (antes OF no los
    # conservaba: solo extraia algunos valores). Misma ubicacion que MaPeriT.SW.
    Write-StepHeader "4.0 Copia de Hives del Sistema y de Usuario"
    $hivesDest = Join-Path $phasePath "Hives"
    foreach ($h in @("SYSTEM", "SOFTWARE", "SAM", "SECURITY", "DEFAULT")) {
        $src = Join-Path $Script:TargetRoot "Windows\System32\config\$h"
        foreach ($ext in @("", ".LOG1", ".LOG2")) {
            if (Test-Path -LiteralPath "$src$ext") {
                if (Copy-ForensicFileBackup -SourcePath "$src$ext" -DestPath (Join-Path $hivesDest "$h$ext") -Phase "FASE_4") { $collected++ }
            }
        }
    }
    foreach ($user in Get-TargetUserPaths) {
        $userDest = Join-Path $hivesDest "Users\$($user.Name)"
        foreach ($rel in @($Script:HiveFiles.NTUSER, $Script:HiveFiles.UsrClass)) {
            $src = Join-Path $user.Root $rel
            foreach ($ext in @("", ".LOG1", ".LOG2")) {
                if (Test-Path -LiteralPath "$src$ext") {
                    $leaf = (Split-Path $src -Leaf) + $ext
                    if (Copy-ForensicFileBackup -SourcePath "$src$ext" -DestPath (Join-Path $userDest $leaf) -Phase "FASE_4") { $collected++ }
                }
            }
        }
    }

    $sysHive = Mount-OfflineHive -HivePath $sysHivePath -Label "SYS4"
    $sftHive = Mount-OfflineHive -HivePath $sftHivePath -Label "SFT4"

    try {
        $cs = if ($sysHive) { Get-OfflineControlSet -SystemHiveRoot $sysHive } else { "ControlSet001" }

        # --- 4.1 Claves Run/RunOnce (SYSTEM-wide) ---
        Write-StepHeader "4.1 Autoarranque - Run/RunOnce (SOFTWARE)"
        if ($sftHive) {
            foreach ($runKey in @('Microsoft\Windows\CurrentVersion\Run', 'Microsoft\Windows\CurrentVersion\RunOnce',
                                  'Microsoft\Windows\CurrentVersion\Policies\Explorer\Run')) {
                $vals = Get-OfflineRegProperty -HiveRoot $sftHive -SubKey $runKey
                if ($vals) {
                    $rows = @($vals.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } |
                        ForEach-Object { [PSCustomObject]@{ Hive='SOFTWARE'; Key=$runKey; Name=$_.Name; Value=$_.Value } })
                    $outFile = Join-Path $phasePath "Run_SOFTWARE_$(($runKey -split '\\')[-1]).csv"
                    $rows | Export-Csv $outFile -NoTypeInformation -Encoding UTF8 -Force
                    Write-ForensicLog -Phase "FASE_4" -Action "RUN_KEY" -Target $runKey -Result "OK" -Detail "$($rows.Count) entradas"
                    $collected++
                }
            }
        }

        # --- 4.2 Winlogon ---
        Write-StepHeader "4.2 Winlogon"
        if ($sftHive) {
            try {
                $wl = Get-OfflineRegProperty -HiveRoot $sftHive -SubKey 'Microsoft\Windows NT\CurrentVersion\Winlogon'
                if ($wl) {
                    $wl.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } |
                        ForEach-Object { [PSCustomObject]@{ Name=$_.Name; Value=$_.Value } } |
                        Export-Csv (Join-Path $phasePath "Winlogon.csv") -NoTypeInformation -Encoding UTF8 -Force
                    Write-ForensicLog -Phase "FASE_4" -Action "WINLOGON" -Target "Winlogon" -Result "OK"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_4" -Action "WINLOGON_ERROR" -Target $_.Exception.Message -Result "WARNING"
            }
        }

        # --- 4.3 Servicios instalados ---
        Write-StepHeader "4.3 Servicios"
        if ($sysHive) {
            try {
                $services = @()
                $svcKeys  = Get-OfflineRegChildren -HiveRoot $sysHive -SubKey "$cs\Services"
                foreach ($k in $svcKeys) {
                    $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
                    if ($p) {
                        $services += [PSCustomObject]@{
                            ServiceName  = $k.PSChildName
                            DisplayName  = $p.DisplayName
                            ImagePath    = $p.ImagePath
                            Start        = $p.Start
                            Type         = $p.Type
                            Description  = $p.Description
                        }
                    }
                }
                if ($services.Count -gt 0) {
                    Export-CollectionToCSV -Data $services -OutputPath (Join-Path $phasePath "Services.csv") -Phase "FASE_4" -Description "Servicios"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_4" -Action "SERVICES_ERROR" -Target $_.Exception.Message -Result "ERROR"
            }
        }

        # --- 4.4 Ultima sesion de usuario (LastLoggedOn) ---
        Write-StepHeader "4.4 Ultimo Usuario con Sesion"
        if ($sftHive) {
            try {
                $ll = Get-OfflineRegProperty -HiveRoot $sftHive `
                    -SubKey 'Microsoft\Windows\CurrentVersion\Authentication\LogonUI'
                if ($ll) {
                    [PSCustomObject]@{
                        LastLoggedOnUser          = $ll.LastLoggedOnUser
                        LastLoggedOnDisplayName   = $ll.LastLoggedOnDisplayName
                        LastLoggedOnSAMUser       = $ll.LastLoggedOnSAMUser
                    } | Export-Csv (Join-Path $phasePath "LastLoggedOn.csv") -NoTypeInformation -Encoding UTF8 -Force
                    Write-ForensicLog -Phase "FASE_4" -Action "LAST_LOGON" -Target "$($ll.LastLoggedOnUser)" -Result "OK"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_4" -Action "LAST_LOGON_ERROR" -Target $_.Exception.Message -Result "WARNING"
            }
        }

        # --- 4.5 AppCompatCache (ShimCache) ---
        Write-StepHeader "4.5 AppCompatCache (ShimCache)"
        if ($sysHive) {
            try {
                $acc = Get-OfflineRegProperty -HiveRoot $sysHive `
                    -SubKey "$cs\Control\Session Manager\AppCompatCache" -Name "AppCompatCache"
                if ($acc) {
                    $binPath = Join-Path $phasePath "AppCompatCache.bin"
                    [System.IO.File]::WriteAllBytes($binPath, [byte[]]$acc)
                    $hash = Get-ForensicHash -FilePath $binPath
                    Add-ChainOfCustodyEntry -SourcePath "REGISTRY:AppCompatCache" -DestPath $binPath -Hash $hash -Method "reg load" -FileSize ([byte[]]$acc).Length
                    # BUG CONFIRMADO: los parentesis estaban mal colocados -
                    # "$([byte[]]$acc).Length bytes" interpola el ARRAY DE
                    # BYTES completo como texto (todos los bytes en decimal,
                    # potencialmente varios MB) y concatena ".Length bytes"
                    # como texto literal detras, en vez de evaluar la longitud.
                    Write-ForensicLog -Phase "FASE_4" -Action "SHIMCACHE_EXTRAIDO" -Target "AppCompatCache.bin" -Result "OK" -Detail "$(([byte[]]$acc).Length) bytes"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_4" -Action "SHIMCACHE_ERROR" -Target $_.Exception.Message -Result "WARNING"
            }
        }

        # --- 4.6 NTUSER.DAT por usuario ---
        Write-StepHeader "4.6 Registro de Usuarios (NTUSER.DAT)"
        foreach ($user in Get-TargetUserPaths) {
            $ntuserPath = Join-Path $user.Root $Script:HiveFiles.NTUSER
            if (-not (Test-Path $ntuserPath)) {
                Write-ForensicLog -Phase "FASE_4" -Action "NTUSER_NO_ENCONTRADO" -Target "$($user.Name)\NTUSER.DAT" -Result "WARNING"
                continue
            }
            $ntHive = Mount-OfflineHive -HivePath $ntuserPath -Label "NT_$($user.Name)"
            if (-not $ntHive) { continue }
            try {
                $userRegPath = Join-Path $phasePath "Users\$($user.Name)"
                if (-not (Test-Path $userRegPath)) { New-Item -ItemType Directory -Path $userRegPath -Force | Out-Null }

                # Run/RunOnce de usuario
                foreach ($runKey in @('Software\Microsoft\Windows\CurrentVersion\Run', 'Software\Microsoft\Windows\CurrentVersion\RunOnce')) {
                    $vals = Get-OfflineRegProperty -HiveRoot $ntHive -SubKey $runKey
                    if ($vals) {
                        $rows = @($vals.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } |
                            ForEach-Object { [PSCustomObject]@{ Usuario=$user.Name; Key=$runKey; Name=$_.Name; Value=$_.Value } })
                        $rows | Export-Csv (Join-Path $userRegPath "Run_$($user.Name).csv") -NoTypeInformation -Encoding UTF8 -Force
                        Write-ForensicLog -Phase "FASE_4" -Action "USER_RUN_KEY" -Target "$($user.Name)" -Result "OK" -Detail "$($rows.Count) entradas"
                        $collected++
                    }
                }

                # RecentDocs
                try {
                    $rd    = Get-OfflineRegChildren -HiveRoot $ntHive -SubKey 'Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs'
                    $rdRows = @()
                    foreach ($k in $rd) {
                        $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
                        if ($p) { $rdRows += [PSCustomObject]@{ Extension=$k.PSChildName; MRUListEx=$p.MRUListEx } }
                    }
                    if ($rdRows.Count -gt 0) {
                        $rdRows | Export-Csv (Join-Path $userRegPath "RecentDocs_$($user.Name).csv") -NoTypeInformation -Encoding UTF8 -Force
                        Write-ForensicLog -Phase "FASE_4" -Action "RECENT_DOCS" -Target $user.Name -Result "OK"
                        $collected++
                    }
                } catch {}

                # TypedPaths (Explorer address bar)
                try {
                    $tp = Get-OfflineRegProperty -HiveRoot $ntHive -SubKey 'Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths'
                    if ($tp) {
                        $tp.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } |
                            ForEach-Object { [PSCustomObject]@{ Usuario=$user.Name; Entrada=$_.Name; Ruta=$_.Value } } |
                            Export-Csv (Join-Path $userRegPath "TypedPaths_$($user.Name).csv") -NoTypeInformation -Encoding UTF8 -Force
                        Write-ForensicLog -Phase "FASE_4" -Action "TYPED_PATHS" -Target $user.Name -Result "OK"
                        $collected++
                    }
                } catch {}

                # RDP Client - servidores a los que se ha conectado
                try {
                    $rdpServers = Get-OfflineRegChildren -HiveRoot $ntHive -SubKey 'Software\Microsoft\Terminal Server Client\Servers'
                    if ($rdpServers) {
                        $rdpServers | Select-Object @{N='Usuario';E={$user.Name}}, @{N='Servidor';E={$_.PSChildName}} |
                            Export-Csv (Join-Path $userRegPath "RDP_Servers_$($user.Name).csv") -NoTypeInformation -Encoding UTF8 -Force
                        Write-ForensicLog -Phase "FASE_4" -Action "RDP_SERVERS" -Target $user.Name -Result "OK"
                        $collected++
                    }
                } catch {}

            } finally {
                Dismount-OfflineHive -RegistryPath $ntHive
            }
        }

    } finally {
        if ($sysHive) { Dismount-OfflineHive -RegistryPath $sysHive }
        if ($sftHive) { Dismount-OfflineHive -RegistryPath $sftHive }
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
