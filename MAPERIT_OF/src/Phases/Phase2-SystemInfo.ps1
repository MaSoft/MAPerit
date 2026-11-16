#region ============================================================
# MaPeriT.OF - FASE 2: INFORMACION DEL SISTEMA
# Lee hives SYSTEM y SOFTWARE del disco objetivo via reg load
# ============================================================

function Invoke-Phase2-SystemInfo {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.SystemInfo
    $phaseNum  = 2
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    $systemHivePath   = Join-Path $Script:TargetRoot $Script:HiveFiles.SYSTEM
    $softwareHivePath = Join-Path $Script:TargetRoot $Script:HiveFiles.SOFTWARE

    $sysHive = Mount-OfflineHive -HivePath $systemHivePath   -Label "SYS"
    $sftHive = Mount-OfflineHive -HivePath $softwareHivePath -Label "SFT"

    try {
        # --- 2.1 Informacion del SO ---
        Write-StepHeader "2.1 Version del Sistema Operativo"
        if ($sftHive) {
            try {
                $cv  = Get-OfflineRegProperty -HiveRoot $sftHive -SubKey 'Microsoft\Windows NT\CurrentVersion'
                $osInfo = [PSCustomObject]@{
                    Caption          = "$($cv.ProductName)"
                    Version          = "$($cv.CurrentMajorVersionNumber).$($cv.CurrentMinorVersionNumber)"
                    BuildNumber      = "$($cv.CurrentBuildNumber)"
                    UBR              = "$($cv.UBR)"
                    DisplayVersion   = "$($cv.DisplayVersion)"
                    ReleaseId        = "$($cv.ReleaseId)"
                    RegisteredOwner  = "$($cv.RegisteredOwner)"
                    RegisteredOrg    = "$($cv.RegisteredOrganization)"
                    InstallDate      = if ($cv.InstallDate) { [System.DateTimeOffset]::FromUnixTimeSeconds($cv.InstallDate).LocalDateTime.ToString($Script:Defaults.DateFormatShort) } else { "" }
                    Architecture     = if ((Test-Path (Join-Path $Script:TargetRoot "Windows\SysWOW64"))) { "64-bit" } else { "32-bit" }
                    OSType           = "OFFLINE_ACQUISITION"
                }
                $Script:OFSession.TargetOS = $osInfo.Caption
                Export-CollectionToJSON -Data $osInfo -OutputPath (Join-Path $phasePath "OSInfo.json") -Phase "FASE_2" -Description "Version SO"
                $collected++
            } catch {
                Write-ForensicLog -Phase "FASE_2" -Action "OS_INFO_ERROR" -Target $_.Exception.Message -Result "ERROR"
            }
        }

        # --- 2.2 Nombre del equipo ---
        Write-StepHeader "2.2 Nombre del Equipo"
        if ($sysHive) {
            try {
                $cs = Get-OfflineControlSet -SystemHiveRoot $sysHive
                $cn = Get-OfflineRegProperty -HiveRoot $sysHive -SubKey "$cs\Control\ComputerName\ComputerName" -Name "ComputerName"
                if ($cn) {
                    $Script:OFSession.TargetComputer = $cn
                    [PSCustomObject]@{ ComputerName = $cn } |
                        Export-Csv -Path (Join-Path $phasePath "ComputerName.csv") -NoTypeInformation -Encoding UTF8 -Force
                    Write-ForensicLog -Phase "FASE_2" -Action "COMPUTERNAME" -Target $cn -Result "OK"
                    $collected++
                }

                # Actualizar OSInfo.json con CSName para compatibilidad con AN
                $osInfoPath = Join-Path $phasePath "OSInfo.json"
                if (Test-Path $osInfoPath) {
                    $osObj = Get-Content $osInfoPath -Raw | ConvertFrom-Json
                    $osObj | Add-Member -NotePropertyName "CSName" -NotePropertyValue $cn -Force
                    $osObj | ConvertTo-Json -Depth 5 | Out-File $osInfoPath -Encoding UTF8 -Force
                }
            } catch {
                Write-ForensicLog -Phase "FASE_2" -Action "COMPUTERNAME_ERROR" -Target $_.Exception.Message -Result "ERROR"
            }
        }

        # --- 2.3 Zona horaria ---
        Write-StepHeader "2.3 Zona Horaria"
        if ($sysHive) {
            try {
                $cs  = Get-OfflineControlSet -SystemHiveRoot $sysHive
                $tz  = Get-OfflineRegProperty -HiveRoot $sysHive -SubKey "$cs\Control\TimeZoneInformation"
                if ($tz) {
                    [PSCustomObject]@{
                        TimeZoneKeyName = $tz.TimeZoneKeyName
                        Bias            = $tz.Bias
                        ActiveTimeBias  = $tz.ActiveTimeBias
                    } | Export-Csv -Path (Join-Path $phasePath "TimeZone.csv") -NoTypeInformation -Encoding UTF8 -Force
                    Write-ForensicLog -Phase "FASE_2" -Action "TIMEZONE" -Target "$($tz.TimeZoneKeyName)" -Result "OK"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_2" -Action "TIMEZONE_ERROR" -Target $_.Exception.Message -Result "WARNING"
            }
        }

        # --- 2.4 Ultimo apagado ---
        Write-StepHeader "2.4 Fecha de Ultimo Apagado"
        if ($sysHive) {
            try {
                $cs       = Get-OfflineControlSet -SystemHiveRoot $sysHive
                $shutdown = Get-OfflineRegProperty -HiveRoot $sysHive -SubKey "$cs\Control\Windows" -Name "ShutdownTime"
                if ($shutdown) {
                    $ftBytes = [byte[]]$shutdown
                    $ft      = [System.BitConverter]::ToInt64($ftBytes, 0)
                    $dt      = [System.DateTime]::FromFileTimeUtc($ft)
                    [PSCustomObject]@{ UltimoApagadoUTC = $dt.ToString($Script:Defaults.DateFormatShort) } |
                        Export-Csv -Path (Join-Path $phasePath "LastShutdown.csv") -NoTypeInformation -Encoding UTF8 -Force
                    Write-ForensicLog -Phase "FASE_2" -Action "ULTIMO_APAGADO" -Target $dt.ToString($Script:Defaults.DateFormatShort) -Result "OK"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_2" -Action "SHUTDOWN_ERROR" -Target $_.Exception.Message -Result "WARNING"
            }
        }

        # --- 2.5 Software instalado ---
        Write-StepHeader "2.5 Software Instalado"
        if ($sftHive) {
            try {
                $installed = @()
                foreach ($hiveKey in @('Microsoft\Windows\CurrentVersion\Uninstall', 'WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')) {
                    $keys = Get-OfflineRegChildren -HiveRoot $sftHive -SubKey $hiveKey
                    foreach ($k in $keys) {
                        $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
                        if ($p -and $p.DisplayName) {
                            $installed += [PSCustomObject]@{
                                DisplayName    = $p.DisplayName
                                DisplayVersion = $p.DisplayVersion
                                Publisher      = $p.Publisher
                                InstallDate    = $p.InstallDate
                                InstallLocation= $p.InstallLocation
                                UninstallString= $p.UninstallString
                                Hive           = $hiveKey -replace '.*Uninstall', 'Uninstall'
                            }
                        }
                    }
                }
                if ($installed.Count -gt 0) {
                    Export-CollectionToCSV -Data $installed -OutputPath (Join-Path $phasePath "InstalledSoftware.csv") -Phase "FASE_2" -Description "Software instalado"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_2" -Action "SOFTWARE_ERROR" -Target $_.Exception.Message -Result "ERROR"
            }
        }

        # --- 2.6 Historial de redes ---
        Write-StepHeader "2.6 Historial de Redes"
        if ($sftHive) {
            try {
                $networks = @()
                $netKeys  = Get-OfflineRegChildren -HiveRoot $sftHive -SubKey 'Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles'
                foreach ($k in $netKeys) {
                    $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
                    if ($p) {
                        $networks += [PSCustomObject]@{
                            ProfileName = $p.ProfileName
                            Description = $p.Description
                            Category    = $p.Category
                            DateCreated = $p.DateCreated
                            DateLastConnected = $p.DateLastConnected
                        }
                    }
                }
                if ($networks.Count -gt 0) {
                    Export-CollectionToCSV -Data $networks -OutputPath (Join-Path $phasePath "NetworkHistory.csv") -Phase "FASE_2" -Description "Historial redes"
                    $collected++
                }
            } catch {
                Write-ForensicLog -Phase "FASE_2" -Action "NETWORKS_ERROR" -Target $_.Exception.Message -Result "WARNING"
            }
        }

    } finally {
        if ($sysHive) { Dismount-OfflineHive -RegistryPath $sysHive }
        if ($sftHive) { Dismount-OfflineHive -RegistryPath $sftHive }
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
