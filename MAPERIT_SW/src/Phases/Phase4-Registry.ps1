#region ============================================================
# MaPeriT.SW - FASE 4: REGISTRO DE WINDOWS
# ============================================================

function Invoke-Phase4-RegistryCollection {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.Registry
    $hivesPath = Join-Path $phasePath "Hives"
    $extractedPath = Join-Path $phasePath "ExtractedValues"
    $phaseNum = 4
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    # --- Montar hives de usuarios offline ---
    Write-StepHeader "4.0 Montaje de Hives de Usuarios Offline"
    Mount-OfflineUserHives

    # --- 4.1 Copia de Hives del sistema ---
    Write-StepHeader "4.1 Copia de Hives del Sistema"
    $systemHives = @{
        "HKLM\SAM"      = Join-Path $hivesPath "SAM"
        "HKLM\SYSTEM"   = Join-Path $hivesPath "SYSTEM"
        "HKLM\SOFTWARE" = Join-Path $hivesPath "SOFTWARE"
        "HKLM\SECURITY" = Join-Path $hivesPath "SECURITY"
        "HKU\.DEFAULT"  = Join-Path $hivesPath "DEFAULT"   # el hive DEFAULT se publica en HKU\.DEFAULT (HKLM\DEFAULT no existe)
    }

    foreach ($entry in $systemHives.GetEnumerator()) {
        $success = Save-RegistryHive -HiveKey $entry.Key -OutputPath $entry.Value -Phase "FASE_4"
        if ($success) { $collected++ }
    }

    # --- 4.2 NTUSER.DAT y UsrClass.dat por usuario ---
    Write-StepHeader "4.2 Hives de Usuario (NTUSER.DAT, UsrClass.dat)"
    $profiles = Get-UserProfiles
    foreach ($profile in $profiles) {
        $userHivesDir = Join-Path $hivesPath "Users\$($profile.Username)"
        if (-not (Test-Path $userHivesDir)) { New-Item -ItemType Directory -Path $userHivesDir -Force | Out-Null }

        $ntuser = Join-Path $profile.ProfilePath "NTUSER.DAT"
        if (Test-Path $ntuser) {
            if (Copy-ForensicFile -SourcePath $ntuser -DestPath (Join-Path $userHivesDir "NTUSER.DAT") -Phase "FASE_4" -UseVSSFirst) { $collected++ }
        }

        $usrClass = Join-Path $profile.ProfilePath "AppData\Local\Microsoft\Windows\UsrClass.dat"
        if (Test-Path $usrClass) {
            if (Copy-ForensicFile -SourcePath $usrClass -DestPath (Join-Path $userHivesDir "UsrClass.dat") -Phase "FASE_4" -UseVSSFirst) { $collected++ }
        }
    }

    # --- 4.3 Hora del ultimo apagado ---
    Write-StepHeader "4.3 Ultimo Apagado"
    try {
        $shutdownReg = Get-ItemProperty $Script:RegistryPaths.ShutdownTime -ErrorAction SilentlyContinue
        if ($shutdownReg -and $shutdownReg.ShutdownTime) {
            $bytes = $shutdownReg.ShutdownTime
            if ($bytes.Length -ge 8) {
                $ticks = [BitConverter]::ToInt64($bytes, 0)
                $shutdownTime = [DateTime]::FromFileTime($ticks)
                $result = [PSCustomObject]@{
                    UltimoApagado     = $shutdownTime.ToString($Script:Defaults.DateFormat)
                    UltimoApagadoUTC  = $shutdownTime.ToUniversalTime().ToString($Script:Defaults.DateFormat)
                    RawBytes          = [BitConverter]::ToString($bytes)
                }
                Export-CollectionToJSON -Data $result -OutputPath (Join-Path $extractedPath "LastShutdown.json") -Phase "FASE_4" -Description "Ultimo apagado"
                $collected++
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "SHUTDOWN_TIME_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 4.4 Zona horaria ---
    Write-StepHeader "4.4 Zona Horaria del Registro"
    try {
        $tzReg = Get-ItemProperty $Script:RegistryPaths.TimeZone -ErrorAction SilentlyContinue
        if ($tzReg) {
            Export-CollectionToJSON -Data ($tzReg | Select-Object TimeZoneKeyName, StandardName, DaylightName, Bias, StandardBias, DaylightBias, ActiveTimeBias) -OutputPath (Join-Path $extractedPath "TimeZone.json") -Phase "FASE_4" -Description "Zona horaria"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "TIMEZONE_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 4.5 Historial de interfaces de red ---
    Write-StepHeader "4.5 Historial de Interfaces de Red"
    try {
        $networkProfiles = @()
        if (Test-Path $Script:RegistryPaths.NetworkList) {
            Get-ChildItem $Script:RegistryPaths.NetworkList -ErrorAction SilentlyContinue | ForEach-Object {
                $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                $firstConnected = $null
                $lastConnected = $null
                try {
                    if ($props.DateCreated) {
                        $bytes = $props.DateCreated
                        $year = [BitConverter]::ToUInt16($bytes, 0)
                        $month = [BitConverter]::ToUInt16($bytes, 2)
                        $day = [BitConverter]::ToUInt16($bytes, 6)
                        $hour = [BitConverter]::ToUInt16($bytes, 8)
                        $min = [BitConverter]::ToUInt16($bytes, 10)
                        $firstConnected = "{0:D4}-{1:D2}-{2:D2} {3:D2}:{4:D2}" -f $year,$month,$day,$hour,$min
                    }
                    if ($props.DateLastConnected) {
                        $bytes = $props.DateLastConnected
                        $year = [BitConverter]::ToUInt16($bytes, 0)
                        $month = [BitConverter]::ToUInt16($bytes, 2)
                        $day = [BitConverter]::ToUInt16($bytes, 6)
                        $hour = [BitConverter]::ToUInt16($bytes, 8)
                        $min = [BitConverter]::ToUInt16($bytes, 10)
                        $lastConnected = "{0:D4}-{1:D2}-{2:D2} {3:D2}:{4:D2}" -f $year,$month,$day,$hour,$min
                    }
                } catch { }

                $networkProfiles += [PSCustomObject]@{
                    NombrePerfil     = $props.ProfileName
                    Descripcion      = $props.Description
                    Gestionado       = if($props.NameType -eq 6){"Si"}else{"No"}
                    Categoria        = switch($props.Category){ 0{"Publica"} 1{"Privada"} 2{"Dominio"} default{"Desconocida"} }
                    PrimeraConexion  = $firstConnected
                    UltimaConexion   = $lastConnected
                }
            }
        }
        if ($networkProfiles.Count -gt 0) {
            Export-CollectionToCSV -Data $networkProfiles -OutputPath (Join-Path $extractedPath "NetworkProfiles.csv") -Phase "FASE_4" -Description "Perfiles de red"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "NETWORK_PROFILES_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 4.6 Historial USB (USBSTOR) ---
    Write-StepHeader "4.6 Historial de Dispositivos USB"
    try {
        $usbDevices = @()
        if (Test-Path $Script:RegistryPaths.USBSTOR) {
            Get-ChildItem $Script:RegistryPaths.USBSTOR -ErrorAction SilentlyContinue | ForEach-Object {
                $deviceClass = $_.PSChildName
                Get-ChildItem $_.PsPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                    $serial = $_.PSChildName

                    $firstInstall = $null
                    $lastConnected = $null
                    $lastRemoved = $null
                    try {
                        $devProps = Get-ItemProperty "$($_.PsPath)\Properties\{83da6326-97a6-4088-9453-a1923f573b29}" -ErrorAction SilentlyContinue
                        if (Test-Path "$($_.PsPath)\Properties\{83da6326-97a6-4088-9453-a1923f573b29}\0064") {
                            $firstInstall = (Get-ItemPropertyValue "$($_.PsPath)\Properties\{83da6326-97a6-4088-9453-a1923f573b29}\0064" -Name "(default)" -ErrorAction SilentlyContinue)
                        }
                        if (Test-Path "$($_.PsPath)\Properties\{83da6326-97a6-4088-9453-a1923f573b29}\0066") {
                            $lastConnected = (Get-ItemPropertyValue "$($_.PsPath)\Properties\{83da6326-97a6-4088-9453-a1923f573b29}\0066" -Name "(default)" -ErrorAction SilentlyContinue)
                        }
                        if (Test-Path "$($_.PsPath)\Properties\{83da6326-97a6-4088-9453-a1923f573b29}\0067") {
                            $lastRemoved = (Get-ItemPropertyValue "$($_.PsPath)\Properties\{83da6326-97a6-4088-9453-a1923f573b29}\0067" -Name "(default)" -ErrorAction SilentlyContinue)
                        }
                    } catch { }

                    $usbDevices += [PSCustomObject]@{
                        ClaseDispositivo  = $deviceClass
                        NumeroSerie       = $serial
                        NombreAmigable    = $props.FriendlyName
                        Fabricante        = $props.Mfg
                        Servicio          = $props.Service
                        PrimeraInstalacion= $firstInstall
                        UltimaConexion    = $lastConnected
                        UltimaExtraccion  = $lastRemoved
                    }
                }
            }
        }
        if ($usbDevices.Count -gt 0) {
            Export-CollectionToCSV -Data $usbDevices -OutputPath (Join-Path $extractedPath "USBSTORDevices.csv") -Phase "FASE_4" -Description "Dispositivos USBSTOR"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "USBSTOR_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 4.7 MountedDevices ---
    Write-StepHeader "4.7 MountedDevices"
    try {
        $mountedDevices = @()
        $regKey = Get-Item $Script:RegistryPaths.MountedDevices -ErrorAction SilentlyContinue
        if ($regKey) {
            $regKey.GetValueNames() | ForEach-Object {
                $valueName = $_
                $data = $regKey.GetValue($valueName)
                $dataHex = if ($data -is [byte[]]) { [BitConverter]::ToString($data[0..([Math]::Min(63, $data.Length-1))]) } else { $data.ToString() }
                $mountedDevices += [PSCustomObject]@{
                    Nombre = $valueName
                    Datos  = $dataHex
                }
            }
        }
        if ($mountedDevices.Count -gt 0) {
            Export-CollectionToCSV -Data $mountedDevices -OutputPath (Join-Path $extractedPath "MountedDevices.csv") -Phase "FASE_4" -Description "MountedDevices"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "MOUNTED_DEVICES_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 4.8 UserAssist (ROT13) ---
    Write-StepHeader "4.8 UserAssist (ROT13)"
    try {
        $userAssistData = @()
        $profiles = Get-UserProfiles

        foreach ($profile in $profiles) {
            $sid = $profile.SID
            if (-not $sid) { continue }

            $effectiveSID = Get-EffectiveHKUSID -SID $sid -Username $profile.Username
            if (-not $effectiveSID) { continue }

            $uaBasePath = "Registry::HKU\$effectiveSID\$($Script:RegistryPaths.UserAssist)"

            Get-ChildItem $uaBasePath -ErrorAction SilentlyContinue | ForEach-Object {
                $guidPath = Join-Path $_.PsPath "Count"
                if (Test-Path $guidPath) {
                    $countKey = Get-Item $guidPath -ErrorAction SilentlyContinue
                    if ($countKey) {
                        $countKey.GetValueNames() | ForEach-Object {
                            $rot13Name = $_
                            $decodedName = Convert-ROT13 -Text $rot13Name
                            $valueData = $countKey.GetValue($rot13Name)

                            $runCount = 0
                            $lastRun = $null
                            if ($valueData -is [byte[]] -and $valueData.Length -ge 72) {
                                $runCount = [BitConverter]::ToUInt32($valueData, 4)
                                $lastRunTicks = [BitConverter]::ToInt64($valueData, 60)
                                if ($lastRunTicks -gt 0) {
                                    try { $lastRun = [DateTime]::FromFileTime($lastRunTicks).ToString($Script:Defaults.DateFormat) } catch { }
                                }
                            }

                            $userAssistData += [PSCustomObject]@{
                                Usuario      = $profile.Username
                                ProgramaROT13= $rot13Name
                                Programa     = $decodedName
                                Ejecuciones  = $runCount
                                UltimaEjecucion = $lastRun
                            }
                        }
                    }
                }
            }
        }

        if ($userAssistData.Count -gt 0) {
            Export-CollectionToCSV -Data $userAssistData -OutputPath (Join-Path $extractedPath "UserAssist.csv") -Phase "FASE_4" -Description "UserAssist"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "USERASSIST_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 4.9 ShimCache (AppCompatCache) ---
    Write-StepHeader "4.9 ShimCache (AppCompatCache)"
    try {
        $shimData = Get-ItemProperty $Script:RegistryPaths.AppCompatCache -ErrorAction SilentlyContinue
        if ($shimData -and $shimData.AppCompatCache) {
            $rawBytes = $shimData.AppCompatCache
            $shimOutputRaw = Join-Path $extractedPath "AppCompatCache.bin"
            [System.IO.File]::WriteAllBytes($shimOutputRaw, $rawBytes)
            $hash = Get-ForensicHash -FilePath $shimOutputRaw
            Add-ChainOfCustodyEntry -SourcePath $Script:RegistryPaths.AppCompatCache -DestPath $shimOutputRaw -Hash $hash -Method "Registry" -FileSize $rawBytes.Length
            $collected++

            $shimEntries = @(Parse-ShimCache -Data $rawBytes)
            if ($shimEntries.Count -gt 0) {
                Export-CollectionToCSV -Data $shimEntries -OutputPath (Join-Path $extractedPath "ShimCache.csv") -Phase "FASE_4" -Description "ShimCache"
                $collected++
            }
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "SHIMCACHE_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 4.10 BAM/DAM ---
    Write-StepHeader "4.10 BAM/DAM (Background Activity Monitor)"
    try {
        $bamData = @()
        foreach ($regPath in @($Script:RegistryPaths.BAM, $Script:RegistryPaths.DAM)) {
            if (Test-Path $regPath) {
                Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $sid = $_.PSChildName
                    $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                    if ($props) {
                        $props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" -and $_.Name -ne "(default)" -and $_.Name -ne "Version" -and $_.Name -ne "SequenceNumber" } | ForEach-Object {
                            $execPath = $_.Name
                            $valueBytes = $_.Value
                            $execTime = $null
                            if ($valueBytes -is [byte[]] -and $valueBytes.Length -ge 8) {
                                $ticks = [BitConverter]::ToInt64($valueBytes, 0)
                                if ($ticks -gt 0) {
                                    try { $execTime = [DateTime]::FromFileTime($ticks).ToString($Script:Defaults.DateFormat) } catch { }
                                }
                            }
                            $bamData += [PSCustomObject]@{
                                Origen    = if($regPath -like "*bam*"){"BAM"}else{"DAM"}
                                SID       = $sid
                                Ejecutable = $execPath
                                FechaEjecucion = $execTime
                            }
                        }
                    }
                }
            }
        }
        if ($bamData.Count -gt 0) {
            Export-CollectionToCSV -Data $bamData -OutputPath (Join-Path $extractedPath "BAM_DAM.csv") -Phase "FASE_4" -Description "BAM/DAM"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "BAM_DAM_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 4.11 Autoruns del Registro ---
    Write-StepHeader "4.11 Autoruns del Registro"
    try {
        $autoruns = @()
        $autorunPaths = @(
            @{Path=$Script:RegistryPaths.RunHKLM; Scope="HKLM"},
            @{Path=$Script:RegistryPaths.RunOnceHKLM; Scope="HKLM"},
            @{Path=$Script:RegistryPaths.RunHKCU; Scope="HKCU"},
            @{Path=$Script:RegistryPaths.RunOnceHKCU; Scope="HKCU"},
            @{Path=$Script:RegistryPaths.PoliciesRun; Scope="HKLM\Policies"}
        )

        foreach ($entry in $autorunPaths) {
            if (Test-Path $entry.Path) {
                $props = Get-ItemProperty $entry.Path -ErrorAction SilentlyContinue
                $props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" -and $_.Name -ne "(default)" } | ForEach-Object {
                    $autoruns += [PSCustomObject]@{
                        Scope    = $entry.Scope
                        Clave    = $entry.Path
                        Nombre   = $_.Name
                        Valor    = $_.Value
                    }
                }
            }
        }

        $winlogon = Get-ItemProperty $Script:RegistryPaths.Winlogon -ErrorAction SilentlyContinue
        if ($winlogon) {
            foreach ($prop in @("Shell", "Userinit", "Taskman")) {
                if ($winlogon.$prop) {
                    $autoruns += [PSCustomObject]@{
                        Scope  = "HKLM\Winlogon"
                        Clave  = $Script:RegistryPaths.Winlogon
                        Nombre = $prop
                        Valor  = $winlogon.$prop
                    }
                }
            }
        }

        if ($autoruns.Count -gt 0) {
            Export-CollectionToCSV -Data $autoruns -OutputPath (Join-Path $extractedPath "Autoruns.csv") -Phase "FASE_4" -Description "Autoruns del Registro"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "AUTORUNS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 4.12 MRU Lists ---
    Write-StepHeader "4.12 Listas MRU (Elementos Recientes)"
    try {
        $mruData = @()
        $profiles = Get-UserProfiles
        foreach ($profile in $profiles) {
            $sid = $profile.SID
            if (-not $sid) { continue }
            $effectiveSID = Get-EffectiveHKUSID -SID $sid -Username $profile.Username
            if (-not $effectiveSID) { continue }
            $hkuBase = "Registry::HKU\$effectiveSID"

            $mruPaths = @(
                @{Name="RunMRU"; Path="$hkuBase\$($Script:RegistryPaths.RunMRU)"},
                @{Name="TypedPaths"; Path="$hkuBase\$($Script:RegistryPaths.TypedPaths)"},
                @{Name="TypedURLs"; Path="$hkuBase\$($Script:RegistryPaths.TypedURLs)"}
            )

            foreach ($mru in $mruPaths) {
                if (Test-Path $mru.Path -ErrorAction SilentlyContinue) {
                    $props = Get-ItemProperty $mru.Path -ErrorAction SilentlyContinue
                    $props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" -and $_.Name -ne "(default)" -and $_.Name -ne "MRUList" } | ForEach-Object {
                        $mruData += [PSCustomObject]@{
                            Usuario = $profile.Username
                            Tipo    = $mru.Name
                            Entrada = $_.Name
                            Valor   = $_.Value
                        }
                    }
                }
            }
        }
        if ($mruData.Count -gt 0) {
            Export-CollectionToCSV -Data $mruData -OutputPath (Join-Path $extractedPath "MRULists.csv") -Phase "FASE_4" -Description "Listas MRU"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "MRU_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 4.13 RDP History ---
    Write-StepHeader "4.13 Historial RDP"
    try {
        $rdpHistory = @()
        $profiles = Get-UserProfiles
        foreach ($profile in $profiles) {
            $sid = $profile.SID
            if (-not $sid) { continue }
            $effectiveSID = Get-EffectiveHKUSID -SID $sid -Username $profile.Username
            if (-not $effectiveSID) { continue }
            $hkuBase = "Registry::HKU\$effectiveSID"

            $rdpDefaultPath = "$hkuBase\Software\Microsoft\Terminal Server Client\Default"
            if (Test-Path $rdpDefaultPath -ErrorAction SilentlyContinue) {
                $props = Get-ItemProperty $rdpDefaultPath -ErrorAction SilentlyContinue
                $props.PSObject.Properties | Where-Object { $_.Name -like "MRU*" } | ForEach-Object {
                    $rdpHistory += [PSCustomObject]@{
                        Usuario  = $profile.Username
                        Tipo     = "MRU"
                        Servidor = $_.Value
                        UsuarioRDP = ""
                    }
                }
            }

            $rdpServersPath = "$hkuBase\Software\Microsoft\Terminal Server Client\Servers"
            if (Test-Path $rdpServersPath -ErrorAction SilentlyContinue) {
                Get-ChildItem $rdpServersPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $serverName = $_.PSChildName
                    $serverProps = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                    $rdpHistory += [PSCustomObject]@{
                        Usuario  = $profile.Username
                        Tipo     = "Servidor"
                        Servidor = $serverName
                        UsuarioRDP = $serverProps.UsernameHint
                    }
                }
            }
        }
        if ($rdpHistory.Count -gt 0) {
            Export-CollectionToCSV -Data $rdpHistory -OutputPath (Join-Path $extractedPath "RDPHistory.csv") -Phase "FASE_4" -Description "Historial RDP"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "RDP_HISTORY_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 4.14 Ultimo usuario logueado ---
    Write-StepHeader "4.14 Ultimo Usuario Logueado"
    try {
        $lastLogon = Get-ItemProperty $Script:RegistryPaths.LastLoggedOn -ErrorAction SilentlyContinue
        if ($lastLogon) {
            $result = [PSCustomObject]@{
                UltimoUsuario = $lastLogon.LastLoggedOnUser
                UltimoSAM     = $lastLogon.LastLoggedOnSAMUser
                UltimoDisplayName = $lastLogon.LastLoggedOnDisplayName
            }
            Export-CollectionToJSON -Data $result -OutputPath (Join-Path $extractedPath "LastLoggedOnUser.json") -Phase "FASE_4" -Description "Ultimo usuario logueado"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "LAST_LOGON_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- Desmontar hives offline ---
    Write-StepHeader "4.15 Desmontaje de Hives Offline"
    Dismount-OfflineUserHives

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}

# --- Funciones auxiliares ---

function Convert-ROT13 {
    param([string]$Text)
    $result = [System.Text.StringBuilder]::new()
    foreach ($char in $Text.ToCharArray()) {
        if ($char -ge 'A' -and $char -le 'Z') {
            [void]$result.Append([char](((([int]$char - 65 + 13) % 26) + 65)))
        } elseif ($char -ge 'a' -and $char -le 'z') {
            [void]$result.Append([char](((([int]$char - 97 + 13) % 26) + 97)))
        } else {
            [void]$result.Append($char)
        }
    }
    return $result.ToString()
}

function Parse-ShimCache {
    <#
        Formato de AppCompatCache de Windows 10/11 (comprobado byte a byte contra
        datos reales): cabecera de longitud variable, cuyo tamano indica el primer
        DWORD (0x30 o 0x34), seguida de entradas consecutivas:
          +0   firma "10ts" (4 bytes)
          +4   valor desconocido (4)
          +8   tamano de la entrada contado desde +12 (4)
          +12  longitud de la ruta en bytes (2)
          +14  ruta en UTF-16LE
          a continuacion FILETIME de ultima modificacion (8), tamano de datos y datos
        Corregido en v1.7.5: antes la longitud se leia en +8 y la ruta desde +12
        (rutas corruptas) y el contador de entradas avanzaba cada 4 bytes con un
        tope de 1024, asi que solo se recorrian los primeros ~4 KB de la cache.
        Otros formatos (Windows 7/8) no se interpretan: queda constancia en el log
        y el binario completo se conserva en AppCompatCache.bin.
    #>
    param([byte[]]$Data)

    $entries = [System.Collections.Generic.List[object]]::new()
    if ($null -eq $Data -or $Data.Length -lt 52) { return $entries }

    try {
        $offset = [int][BitConverter]::ToUInt32($Data, 0)
        if (($offset -ne 0x30 -and $offset -ne 0x34) -or [BitConverter]::ToUInt32($Data, $offset) -ne 0x73743031) {
            Write-ForensicLog -Phase "FASE_4" -Action "SHIMCACHE_FORMATO_NO_SOPORTADO" -Target ("Cabecera 0x{0:X}: solo se interpreta el formato de Windows 10/11; el binario se conserva en AppCompatCache.bin" -f $offset) -Result "WARNING"
            return $entries
        }
        $indice = 0
        while ($offset + 14 -le $Data.Length) {
            if ([BitConverter]::ToUInt32($Data, $offset) -ne 0x73743031) { break }   # "10ts"
            $entrySize  = [int][BitConverter]::ToUInt32($Data, $offset + 8)
            $pathLength = [int][BitConverter]::ToUInt16($Data, $offset + 12)
            $pathOffset = $offset + 14
            if ($entrySize -le 0 -or $pathOffset + $pathLength + 8 -gt $Data.Length) { break }

            $path    = [System.Text.Encoding]::Unicode.GetString($Data, $pathOffset, $pathLength)
            $lastMod = $null
            $ticks   = [BitConverter]::ToInt64($Data, $pathOffset + $pathLength)
            if ($ticks -gt 0) {
                try { $lastMod = [DateTime]::FromFileTime($ticks).ToString($Script:Defaults.DateFormat) } catch { }
            }

            [void]$entries.Add([PSCustomObject]@{
                Indice              = $indice
                RutaEjecutable      = $path.TrimEnd("`0")
                UltimaModificacion  = $lastMod
            })
            $indice++
            $offset = $offset + 12 + $entrySize
        }
    } catch {
        Write-ForensicLog -Phase "FASE_4" -Action "SHIMCACHE_PARSE_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    return $entries
}
