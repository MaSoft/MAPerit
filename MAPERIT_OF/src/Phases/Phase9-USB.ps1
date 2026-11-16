#region ============================================================
# MaPeriT.OF - FASE 9: DISPOSITIVOS USB
# Lee USBSTOR, USB y MountedDevices desde hive SYSTEM del disco objetivo
# ============================================================

function Invoke-Phase9-USB {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.USB
    $phaseNum  = 9
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    $sysHivePath = Join-Path $Script:TargetRoot $Script:HiveFiles.SYSTEM
    $sysHive     = Mount-OfflineHive -HivePath $sysHivePath -Label "SYS9"

    if (-not $sysHive) {
        Write-ForensicLog -Phase "FASE_9" -Action "HIVE_NO_DISPONIBLE" -Target "SYSTEM" -Result "ERROR"
        Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected 0
        return 0
    }

    try {
        $cs = Get-OfflineControlSet -SystemHiveRoot $sysHive

        # --- 9.1 USBSTOR (historial de dispositivos USB de almacenamiento) ---
        Write-StepHeader "9.1 USBSTOR - Dispositivos de Almacenamiento USB"
        try {
            $usbstorDevices = @()
            $usbstorKeys    = Get-OfflineRegChildren -HiveRoot $sysHive -SubKey "$cs\Enum\USBSTOR"
            foreach ($typeKey in $usbstorKeys) {
                $deviceKeys = Get-ChildItem $typeKey.PSPath -ErrorAction SilentlyContinue
                foreach ($devKey in $deviceKeys) {
                    $p = Get-ItemProperty $devKey.PSPath -ErrorAction SilentlyContinue
                    if ($p) {
                        $usbstorDevices += [PSCustomObject]@{
                            DeviceType       = $typeKey.PSChildName
                            SerialNumber     = $devKey.PSChildName
                            FriendlyName     = $p.FriendlyName
                            Manufacturer     = ($typeKey.PSChildName -split '&')[0]
                            Model            = ($typeKey.PSChildName -split '&')[1]
                            HardwareID       = ($p.HardwareID | Out-String).Trim()
                            Service          = $p.Service
                            ContainerID      = $p.ContainerID
                        }
                    }
                }
            }
            if ($usbstorDevices.Count -gt 0) {
                Export-CollectionToCSV -Data $usbstorDevices -OutputPath (Join-Path $phasePath "USBSTOR.csv") -Phase "FASE_9" -Description "Dispositivos USBSTOR"
                $collected++
            }
        } catch {
            Write-ForensicLog -Phase "FASE_9" -Action "USBSTOR_ERROR" -Target $_.Exception.Message -Result "ERROR"
        }

        # --- 9.2 USB (todos los dispositivos USB) ---
        Write-StepHeader "9.2 USB - Todos los Dispositivos USB"
        try {
            $usbDevices = @()
            $usbKeys    = Get-OfflineRegChildren -HiveRoot $sysHive -SubKey "$cs\Enum\USB"
            foreach ($vidKey in $usbKeys) {
                $pidKeys = Get-ChildItem $vidKey.PSPath -ErrorAction SilentlyContinue
                foreach ($pidKey in $pidKeys) {
                    $instanceKeys = Get-ChildItem $pidKey.PSPath -ErrorAction SilentlyContinue
                    foreach ($inst in $instanceKeys) {
                        $p = Get-ItemProperty $inst.PSPath -ErrorAction SilentlyContinue
                        if ($p) {
                            $usbDevices += [PSCustomObject]@{
                                VID_PID      = "$($vidKey.PSChildName)&$($pidKey.PSChildName)"
                                Instance     = $inst.PSChildName
                                FriendlyName = $p.FriendlyName
                                Manufacturer = $p.Mfg
                                Service      = $p.Service
                                ContainerID  = $p.ContainerID
                            }
                        }
                    }
                }
            }
            if ($usbDevices.Count -gt 0) {
                Export-CollectionToCSV -Data $usbDevices -OutputPath (Join-Path $phasePath "USB_Devices.csv") -Phase "FASE_9" -Description "Dispositivos USB"
                $collected++
            }
        } catch {
            Write-ForensicLog -Phase "FASE_9" -Action "USB_ERROR" -Target $_.Exception.Message -Result "WARNING"
        }

        # --- 9.3 MountedDevices (asignacion de letras de unidad) ---
        Write-StepHeader "9.3 MountedDevices"
        try {
            $md    = Get-OfflineRegProperty -HiveRoot $sysHive -SubKey "MountedDevices"
            if ($md) {
                $mdRows = $md.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } |
                    ForEach-Object {
                        [PSCustomObject]@{
                            DriveLetter = $_.Name
                            DataSize    = if ($_.Value -is [byte[]]) { ([byte[]]$_.Value).Length } else { 0 }
                            DataHex     = if ($_.Value -is [byte[]]) { [System.BitConverter]::ToString([byte[]]$_.Value) -replace '-','' } else { $_.Value }
                        }
                    }
                Export-CollectionToCSV -Data $mdRows -OutputPath (Join-Path $phasePath "MountedDevices.csv") -Phase "FASE_9" -Description "MountedDevices"
                $collected++
            }
        } catch {
            Write-ForensicLog -Phase "FASE_9" -Action "MOUNTED_DEVICES_ERROR" -Target $_.Exception.Message -Result "WARNING"
        }

    } finally {
        Dismount-OfflineHive -RegistryPath $sysHive
    }

    # --- 9.4 SetupAPI log (evidencia cruda, para paridad con MaPeriT.SW) ---
    # Antes esta fase solo leia el registro (USBSTOR/USB/MountedDevices) pero no
    # preservaba setupapi.dev.log en si -- SW si lo copia y parsea en su Fase 9.
    # Se copia el fichero completo (cadena de custodia) y se extraen los eventos de
    # instalacion USB en streaming linea a linea, sin cargar el log completo en
    # memoria (puede acumular cientos de MB en equipos con muchos anos de uso).
    Write-StepHeader "9.4 SetupAPI Log"
    try {
        $setupApiSrc = Join-Path $Script:TargetRoot "Windows\INF\setupapi.dev.log"
        if (Test-Path $setupApiSrc) {
            $setupApiDest = Join-Path $phasePath "setupapi.dev.log"
            if (Copy-ForensicFile -SourcePath $setupApiSrc -DestPath $setupApiDest -Phase "FASE_9" -Method "setupapi_copy") {
                $collected++
            }

            $usbInstallEvents = @()
            $currentSection = ""
            $currentTimestamp = ""
            $fs = [System.IO.File]::Open($setupApiSrc, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete)
            $streamReader = [System.IO.StreamReader]::new($fs)
            try {
                while (($line = $streamReader.ReadLine()) -ne $null) {
                    if ($line -match '>>>  \[Device Install') {
                        $currentSection = $line
                    }
                    elseif ($line -match '>>>  Section start (\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})') {
                        $currentTimestamp = $Matches[1]
                    }
                    elseif ($line -match 'USBSTOR|USB\\VID_' -and $currentSection) {
                        $usbInstallEvents += [PSCustomObject]@{
                            Timestamp   = $currentTimestamp
                            Seccion     = $currentSection.Trim('> []')
                            Dispositivo = $line.Trim()
                        }
                    }
                }
            } finally {
                $streamReader.Dispose()
                $fs.Dispose()
            }

            if ($usbInstallEvents.Count -gt 0) {
                Export-CollectionToCSV -Data $usbInstallEvents -OutputPath (Join-Path $phasePath "SetupAPIUSBEvents.csv") -Phase "FASE_9" -Description "USB install events"
                $collected++
            }
        } else {
            Write-ForensicLog -Phase "FASE_9" -Action "SETUPAPI_NO_ENCONTRADO" -Target $setupApiSrc -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_9" -Action "SETUPAPI_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
