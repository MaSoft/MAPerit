#region ============================================================
# MaPeriT.SW - FASE 9: DISPOSITIVOS USB/EXTERNOS
# ============================================================

function Invoke-Phase9-USBCollection {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.USB
    $phaseNum = 9
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    # --- 9.1 USBSTOR del registro (consolidado) ---
    Write-StepHeader "9.1 Dispositivos USBSTOR"
    try {
        $usbDevices = @()
        if (Test-Path $Script:RegistryPaths.USBSTOR) {
            Get-ChildItem $Script:RegistryPaths.USBSTOR -ErrorAction SilentlyContinue | ForEach-Object {
                $deviceClass = $_.PSChildName
                $parts = $deviceClass -split '&'
                $vendor = ""
                $product = ""
                $revision = ""
                if ($parts.Count -ge 2) { $vendor = $parts[1] -replace 'Ven_', '' }
                if ($parts.Count -ge 3) { $product = $parts[2] -replace 'Prod_', '' }
                if ($parts.Count -ge 4) { $revision = $parts[3] -replace 'Rev_', '' }

                Get-ChildItem $_.PsPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                    $usbDevices += [PSCustomObject]@{
                        Clase           = $deviceClass
                        Fabricante      = $vendor
                        Producto        = $product
                        Revision        = $revision
                        NumeroSerie     = $_.PSChildName
                        NombreAmigable  = $props.FriendlyName
                        ContainerID     = $props.ContainerID
                        HardwareID      = ($props.HardwareID | Select-Object -First 1)
                    }
                }
            }
        }

        if (Test-Path $Script:RegistryPaths.USB) {
            Get-ChildItem $Script:RegistryPaths.USB -ErrorAction SilentlyContinue | ForEach-Object {
                $vidPid = $_.PSChildName
                if ($vidPid -match 'VID_(\w+)&PID_(\w+)') {
                    Get-ChildItem $_.PsPath -ErrorAction SilentlyContinue | ForEach-Object {
                        $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                        $usbDevices += [PSCustomObject]@{
                            Clase           = "USB"
                            Fabricante      = "VID_$($Matches[1])"
                            Producto        = "PID_$($Matches[2])"
                            Revision        = ""
                            NumeroSerie     = $_.PSChildName
                            NombreAmigable  = $props.FriendlyName
                            ContainerID     = $props.ContainerID
                            HardwareID      = ($props.HardwareID | Select-Object -First 1)
                        }
                    }
                }
            }
        }

        if ($usbDevices.Count -gt 0) {
            Export-CollectionToCSV -Data $usbDevices -OutputPath (Join-Path $phasePath "USBDevices.csv") -Phase "FASE_9" -Description "Dispositivos USB"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_9" -Action "USBSTOR_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 9.2 SetupAPI logs ---
    Write-StepHeader "9.2 SetupAPI Logs"
    try {
        $setupApiLog = "C:\Windows\INF\setupapi.dev.log"
        if (Test-Path $setupApiLog) {
            $destPath = Join-Path $phasePath "setupapi.dev.log"
            if (Copy-ForensicFile -SourcePath $setupApiLog -DestPath $destPath -Phase "FASE_9") { $collected++ }

            # Lectura en streaming linea a linea en vez de Get-Content (que carga el
            # fichero COMPLETO en memoria de una vez): setupapi.dev.log puede acumular
            # cientos de MB en equipos con muchos años de uso, y solo necesitamos
            # inspeccionar linea a linea, nunca el contenido completo a la vez.
            $usbInstallEvents = @()
            $currentSection = ""
            $currentTimestamp = ""
            $fs = [System.IO.File]::Open($setupApiLog, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete)
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
                            Timestamp  = $currentTimestamp
                            Seccion    = $currentSection.Trim('> []')
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
        }
    } catch {
        Write-ForensicLog -Phase "FASE_9" -Action "SETUPAPI_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 9.3 MountPoints2 ---
    Write-StepHeader "9.3 MountPoints2 por Usuario"
    try {
        $mountPoints = @()
        $profiles = Get-UserProfiles

        foreach ($profile in $profiles) {
            $sid = $profile.SID
            if (-not $sid) { continue }
            $effectiveSID = Get-EffectiveHKUSID -SID $sid -Username $profile.Username
            if (-not $effectiveSID) { continue }
            $mpPath = "Registry::HKU\$effectiveSID\$($Script:RegistryPaths.MountPoints2)"
            if (Test-Path $mpPath -ErrorAction SilentlyContinue) {
                Get-ChildItem $mpPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $mountPoints += [PSCustomObject]@{
                        Usuario = $profile.Username
                        SID     = $sid
                        Volume  = $_.PSChildName
                    }
                }
            }
        }

        if ($mountPoints.Count -gt 0) {
            Export-CollectionToCSV -Data $mountPoints -OutputPath (Join-Path $phasePath "MountPoints2.csv") -Phase "FASE_9" -Description "MountPoints2"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_9" -Action "MOUNTPOINTS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 9.4 Dispositivos de disco actuales ---
    Write-StepHeader "9.4 Discos Conectados Actualmente"
    try {
        $currentDisks = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object `
            DeviceID, Model, InterfaceType, MediaType, SerialNumber, Size,
            @{N='TamanoGB';E={[math]::Round($_.Size/1GB, 2)}},
            Partitions, FirmwareRevision, PNPDeviceID

        $usbDisks = $currentDisks | Where-Object { $_.InterfaceType -eq 'USB' -or $_.PNPDeviceID -like '*USBSTOR*' }

        if ($currentDisks) {
            Export-CollectionToCSV -Data $currentDisks -OutputPath (Join-Path $phasePath "CurrentDisks.csv") -Phase "FASE_9" -Description "Discos actuales"
            $collected++
        }

        if ($usbDisks) {
            Export-CollectionToCSV -Data $usbDisks -OutputPath (Join-Path $phasePath "CurrentUSBDisks.csv") -Phase "FASE_9" -Description "Discos USB actuales"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_9" -Action "CURRENT_DISKS_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 9.5 Timeline de conexiones USB ---
    Write-StepHeader "9.5 Timeline de Conexiones USB"
    try {
        $usbTimeline = @()

        $usbEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-DriverFrameworks-UserMode/Operational'
        } -MaxEvents 5000 -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($usbEvents).Count -MaxEvents 5000 -Phase "FASE_9" -LogDescription "DriverFrameworks-UserMode Operational"

        if ($usbEvents) {
            foreach ($evt in $usbEvents) {
                if ($evt.Message -match 'USB|USBSTOR|mass storage') {
                    $usbTimeline += [PSCustomObject]@{
                        Timestamp = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                        EventID   = $evt.Id
                        Origen    = "DriverFrameworks"
                        Mensaje   = ($evt.Message -split "`n" | Select-Object -First 1)
                    }
                }
            }
        }

        $pnpEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-Kernel-PnP/Configuration'
        } -MaxEvents 5000 -ErrorAction SilentlyContinue
        Test-EventQueryTruncated -Count @($pnpEvents).Count -MaxEvents 5000 -Phase "FASE_9" -LogDescription "Kernel-PnP Configuration"

        if ($pnpEvents) {
            foreach ($evt in $pnpEvents) {
                if ($evt.Message -match 'USB|USBSTOR') {
                    $usbTimeline += [PSCustomObject]@{
                        Timestamp = $evt.TimeCreated.ToString($Script:Defaults.DateFormat)
                        EventID   = $evt.Id
                        Origen    = "Kernel-PnP"
                        Mensaje   = ($evt.Message -split "`n" | Select-Object -First 1)
                    }
                }
            }
        }

        if ($usbTimeline.Count -gt 0) {
            $usbTimeline = $usbTimeline | Sort-Object Timestamp
            Export-CollectionToCSV -Data $usbTimeline -OutputPath (Join-Path $phasePath "USBTimeline.csv") -Phase "FASE_9" -Description "Timeline USB"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_9" -Action "USB_TIMELINE_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
