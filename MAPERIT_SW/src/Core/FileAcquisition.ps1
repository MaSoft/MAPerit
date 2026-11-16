#region ============================================================
# MaPeriT.SW - ADQUISICION DE FICHEROS
# VSS snapshots, copia de ficheros bloqueados, raw copy
# ============================================================

function New-ForensicVSSSnapshot {
    param(
        [string]$Volume = "C:\"
    )
    Write-ForensicLog -Phase "VSS" -Action "CREANDO_SNAPSHOT" -Target $Volume

    try {
        $shadowResult = Invoke-CimMethod -Namespace root/cimv2 -ClassName Win32_ShadowCopy -MethodName Create -Arguments @{Volume=$Volume; Context="ClientAccessible"} -ErrorAction Stop

        if ($shadowResult.ReturnValue -eq 0) {
            $shadowId = $shadowResult.ShadowID
            $shadow = Get-CimInstance -ClassName Win32_ShadowCopy | Where-Object { $_.ID -eq $shadowId }

            if ($shadow) {
                $Script:VSSSnapshot = @{
                    ID         = $shadow.ID
                    CimObject  = $shadow
                    DevicePath = $shadow.DeviceObject
                    VolumeName = $Volume
                    Created    = Get-Date
                }

                $Script:VSSShadowPath = $shadow.DeviceObject + "\"
                Write-ForensicLog -Phase "VSS" -Action "SNAPSHOT_CREADO" -Target $shadow.DeviceObject -Result "OK"
                return $true
            }
        }

        Write-ForensicLog -Phase "VSS" -Action "SNAPSHOT_FALLIDO" -Target "ReturnValue: $($shadowResult.ReturnValue)" -Result "ERROR"
        return $false
    } catch {
        Write-ForensicLog -Phase "VSS" -Action "SNAPSHOT_ERROR" -Target $Volume -Result "ERROR" -ErrorMessage $_.Exception.Message

        try {
            Write-ForensicLog -Phase "VSS" -Action "INTENTANDO_VSSADMIN" -Target $Volume
            $output = & vssadmin create shadow /for=$Volume 2>&1
            $matchPath = $output | Select-String "Shadow Copy Volume Name"
            $matchId   = $output | Select-String "Shadow Copy ID:\s*(\{[^}]+\})"
            if ($matchPath) {
                $devicePath = ($matchPath -split ":\s+")[1].Trim()
                $shadowGuid = if ($matchId -and $matchId.Matches.Count -gt 0) { $matchId.Matches[0].Groups[1].Value } else { $null }
                $Script:VSSSnapshot = @{
                    ID         = if ($shadowGuid) { $shadowGuid } else { "vssadmin" }
                    CimObject  = $null
                    DevicePath = $devicePath
                    VolumeName = $Volume
                    Created    = Get-Date
                }
                $Script:VSSShadowPath = $devicePath + "\"
                Write-ForensicLog -Phase "VSS" -Action "SNAPSHOT_CREADO_VSSADMIN" -Target $devicePath -Result "OK"
                return $true
            }
        } catch {
            Write-ForensicLog -Phase "VSS" -Action "VSSADMIN_ERROR" -Target $Volume -Result "ERROR" -ErrorMessage $_.Exception.Message
        }

        return $false
    }
}

function Remove-ForensicVSSSnapshot {
    if (-not $Script:VSSSnapshot) {
        return
    }

    Write-ForensicLog -Phase "VSS" -Action "ELIMINANDO_SNAPSHOT" -Target $Script:VSSSnapshot.DevicePath

    try {
        if ($Script:VSSSnapshot.CimObject) {
            Invoke-CimMethod -InputObject $Script:VSSSnapshot.CimObject -MethodName Delete -ErrorAction SilentlyContinue | Out-Null
        } elseif ($Script:VSSSnapshot.ID -and $Script:VSSSnapshot.ID -ne "vssadmin") {
            & vssadmin delete shadows /shadow="$($Script:VSSSnapshot.ID)" /quiet 2>&1 | Out-Null
        } else {
            & vssadmin delete shadows /for=$($Script:VSSSnapshot.VolumeName) /oldest /quiet 2>&1 | Out-Null
        }
        Write-ForensicLog -Phase "VSS" -Action "SNAPSHOT_ELIMINADO" -Target $Script:VSSSnapshot.DevicePath -Result "OK"
    } catch {
        Write-ForensicLog -Phase "VSS" -Action "SNAPSHOT_ELIMINAR_ERROR" -Target $Script:VSSSnapshot.DevicePath -Result "WARNING" -ErrorMessage $_.Exception.Message
    }
}

function Copy-ForensicFile {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$Phase = "COPY",
        [switch]$UseVSSFirst
    )

    if (Test-PathExcluded -Path $SourcePath) {
        Write-ForensicLog -Phase $Phase -Action "EXCLUIDO_POR_PARAMETRO" -Target $SourcePath -Result "SKIP"
        return $false
    }

    if (-not (Test-Path $SourcePath)) {
        Write-ForensicLog -Phase $Phase -Action "FICHERO_NO_ENCONTRADO" -Target $SourcePath -Result "WARNING"
        return $false
    }

    $destDir = Split-Path $DestPath -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $method = "DirectCopy"

    if ($UseVSSFirst -and $Script:VSSShadowPath) {
        $success = Copy-FromVSS -SourcePath $SourcePath -DestPath $DestPath -Phase $Phase
        if ($success) { return $true }
    }

    try {
        Copy-Item -Path $SourcePath -Destination $DestPath -Force -ErrorAction Stop
        $method = "DirectCopy"
    } catch {
        if ($Script:VSSShadowPath) {
            $success = Copy-FromVSS -SourcePath $SourcePath -DestPath $DestPath -Phase $Phase
            if ($success) { return $true }
        }

        try {
            Copy-WithRawStream -SourcePath $SourcePath -DestPath $DestPath
            $method = "RawStream"
        } catch {
            Write-ForensicLog -Phase $Phase -Action "COPIA_FALLIDA" -Target $SourcePath -Result "ERROR" -ErrorMessage $_.Exception.Message
            return $false
        }
    }

    try {
        $hash = Get-ForensicHash -FilePath $DestPath
        $size = (Get-Item $DestPath).Length
        Add-ChainOfCustodyEntry -SourcePath $SourcePath -DestPath $DestPath -Hash $hash -Method $method -FileSize $size

        if ($hash -notmatch '^[A-Fa-f0-9]{64}$') {
            # El fichero se copio pero su hash no se pudo verificar (p.ej. un antivirus lo
            # elimino/puso en cuarentena justo tras la copia). Ya queda constancia en la
            # cadena de custodia (marcado INVALIDO), pero esta copia NO se considera fiable
            # y no debe contarse como evidencia correctamente adquirida.
            Write-ForensicLog -Phase $Phase -Action "HASH_POST_COPIA_NO_VALIDO" -Target "$DestPath ('$hash')" -Result "ERROR"
            return $false
        }

        Write-ForensicLog -Phase $Phase -Action "COPIADO" -Target (Split-Path $SourcePath -Leaf) -Result "OK"
        return $true
    } catch {
        Write-ForensicLog -Phase $Phase -Action "HASH_POST_COPIA_ERROR" -Target $DestPath -Result "ERROR" -ErrorMessage $_.Exception.Message
        return $false
    }
}

function Copy-FromVSS {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$Phase = "VSS"
    )

    if (-not $Script:VSSShadowPath) { return $false }

    # Esta funcion solo sabe traducir rutas locales con letra de unidad (p.ej. "C:\...").
    # Si en el futuro se le pasa una ruta UNC u otro formato, abortar de forma explicita
    # en vez de construir una ruta VSS incorrecta a partir de un Substring mal alineado.
    if ($SourcePath.Length -lt 3 -or $SourcePath[1] -ne ':') {
        Write-ForensicLog -Phase $Phase -Action "VSS_RUTA_NO_SOPORTADA" -Target $SourcePath -Result "WARNING" -ErrorMessage "Copy-FromVSS solo admite rutas locales con letra de unidad (X:\...)."
        return $false
    }

    try {
        $relativePath = $SourcePath.Substring(2)
        $vssPath = $Script:VSSShadowPath + $relativePath.TrimStart("\")

        if (Test-Path $vssPath) {
            Copy-Item -Path $vssPath -Destination $DestPath -Force -ErrorAction SilentlyContinue
            if (Test-Path $DestPath) {
                $hash = Get-ForensicHash -FilePath $DestPath
                $size = (Get-Item $DestPath).Length
                Add-ChainOfCustodyEntry -SourcePath $SourcePath -DestPath $DestPath -Hash $hash -Method "VSS" -FileSize $size
                if ($hash -notmatch '^[A-Fa-f0-9]{64}$') {
                    Write-ForensicLog -Phase $Phase -Action "VSS_HASH_NO_VALIDO" -Target "$DestPath ('$hash')" -Result "ERROR"
                    return $false
                }
                Write-ForensicLog -Phase $Phase -Action "COPIADO_VSS" -Target (Split-Path $SourcePath -Leaf) -Result "OK"
                return $true
            }
        }
    } catch {
        Write-ForensicLog -Phase $Phase -Action "VSS_COPIA_ERROR" -Target $SourcePath -Result "WARNING" -ErrorMessage $_.Exception.Message
    }

    return $false
}

function Copy-WithRawStream {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [int]$BufferSize = 1048576
    )

    $sourceStream = $null
    $destStream = $null

    try {
        $sourceStream = [System.IO.File]::Open(
            $SourcePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
        )
        $destStream = [System.IO.File]::Create($DestPath)

        $buffer = New-Object byte[] $BufferSize
        while (($read = $sourceStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $destStream.Write($buffer, 0, $read)
        }
    } finally {
        if ($sourceStream) { $sourceStream.Close(); $sourceStream.Dispose() }
        if ($destStream) { $destStream.Close(); $destStream.Dispose() }
    }
}

function Copy-ForensicDirectory {
    param(
        [string]$SourceDir,
        [string]$DestDir,
        [string]$Phase,
        [string]$Filter = "*",
        [switch]$Recurse
    )

    if (-not (Test-Path $SourceDir)) {
        Write-ForensicLog -Phase $Phase -Action "DIRECTORIO_NO_ENCONTRADO" -Target $SourceDir -Result "WARNING"
        return 0
    }

    if (-not (Test-Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }

    $copied = 0
    $params = @{
        Path = $SourceDir
        Filter = $Filter
        File = $true
        ErrorAction = "SilentlyContinue"
    }
    if ($Recurse) { $params.Recurse = $true }

    $files = Get-ChildItem @params
    foreach ($file in $files) {
        # Comprobar exclusion ANTES de crear la carpeta destino: antes se creaba la
        # estructura de directorios completa para cada fichero (incluidos los excluidos
        # por -ExcludePaths) y solo Copy-ForensicFile comprobaba la exclusion despues,
        # dejando carpetas vacias residuales en la salida para rutas que el propio
        # parametro pedia minimizar.
        if (Test-PathExcluded -Path $file.FullName) {
            Write-ForensicLog -Phase $Phase -Action "EXCLUIDO_POR_PARAMETRO" -Target $file.FullName -Result "SKIP"
            continue
        }

        $relativePath = $file.FullName.Substring($SourceDir.Length).TrimStart("\")
        $destPath = Join-Path $DestDir $relativePath
        $destFileDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destFileDir)) {
            New-Item -ItemType Directory -Path $destFileDir -Force | Out-Null
        }

        $success = Copy-ForensicFile -SourcePath $file.FullName -DestPath $destPath -Phase $Phase
        if ($success) { $copied++ }
    }

    return $copied
}

function Get-UserProfiles {
    $profiles = @()
    $usersDir = "$env:SystemDrive\Users"

    if (-not (Test-Path $usersDir)) { return $profiles }

    $excludeDirs = @("Public", "Default", "Default User", "All Users")
    $dirs = Get-ChildItem -Path $usersDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin $excludeDirs }

    foreach ($dir in $dirs) {
        $ntuser = Join-Path $dir.FullName "NTUSER.DAT"
        $sid = ""
        try {
            $userObj = New-Object System.Security.Principal.NTAccount($dir.Name)
            $sid = $userObj.Translate([System.Security.Principal.SecurityIdentifier]).Value
        } catch { }

        $profiles += [PSCustomObject]@{
            Username    = $dir.Name
            ProfilePath = $dir.FullName
            SID         = $sid
            HasNTUSER   = Test-Path $ntuser
        }
    }

    return $profiles
}

$Script:LoadedHives = @()

function Mount-OfflineUserHives {
    $profiles = Get-UserProfiles
    foreach ($profile in $profiles) {
        $sid = $profile.SID
        if (-not $sid) { continue }
        if (Test-Path "Registry::HKU\$sid" -ErrorAction SilentlyContinue) { continue }

        $ntuser = Join-Path $profile.ProfilePath "NTUSER.DAT"
        if (-not (Test-Path $ntuser)) { continue }

        $tempKey = "HKU\MAPE_$($profile.Username)"

        # Si una ejecucion anterior interrumpida dejo esta clave montada, intentar liberarla
        # primero. Si no se puede, no seguir: cargar sobre una clave ya existente falla y
        # antes simplemente se perdia el usuario en silencio sin ningun aviso.
        if (Test-Path "Registry::$tempKey" -ErrorAction SilentlyContinue) {
            Write-ForensicLog -Phase "REGISTRY" -Action "HIVE_YA_MONTADO_PREVIO" -Target "$tempKey (residuo de una ejecucion anterior)" -Result "WARNING"
            & reg.exe unload $tempKey 2>&1 | Out-Null
            if (Test-Path "Registry::$tempKey" -ErrorAction SilentlyContinue) {
                Write-ForensicLog -Phase "REGISTRY" -Action "HIVE_MONTAR_OMITIDO" -Target $profile.Username -Result "ERROR" -ErrorMessage "No se pudo liberar el montaje residual $tempKey; se omite este usuario en Fase 4/10 (UserAssist, MRU, RDP History, COM Hijacking)."
                continue
            }
        }

        # NUNCA se monta el NTUSER.DAT original del equipo analizado: "reg load" abre el
        # fichero en lectura-escritura y Windows puede reescribirlo al cargarlo o al
        # desmontarlo (aplicar sus .LOG1/.LOG2, actualizar cabeceras). Se monta una copia
        # de trabajo en la carpeta de salida, que se borra al desmontar.
        $workDir = Join-Path $Script:SessionInfo.OutputPath "Logs\_hives_trabajo\$($profile.Username)"
        try {
            New-Item -ItemType Directory -Path $workDir -Force | Out-Null
            $workHive = Join-Path $workDir "NTUSER.DAT"
            foreach ($ext in @("", ".LOG1", ".LOG2")) {
                if (Test-Path -LiteralPath "$ntuser$ext") {
                    Copy-Item -LiteralPath "$ntuser$ext" -Destination "$workHive$ext" -Force -ErrorAction Stop
                    (Get-Item -LiteralPath "$workHive$ext" -Force).Attributes = 'Normal'
                }
            }
        } catch {
            Write-ForensicLog -Phase "REGISTRY" -Action "HIVE_COPIA_TRABAJO_FALLIDA" -Target $profile.Username -Result "ERROR" -ErrorMessage $_.Exception.Message
            Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
            continue
        }

        try {
            $result = & reg.exe load $tempKey $workHive 2>&1
            if ($LASTEXITCODE -eq 0) {
                $Script:LoadedHives += @{ Username = $profile.Username; Key = $tempKey; SID = $sid; MountedSID = "MAPE_$($profile.Username)"; WorkDir = $workDir }
                Write-ForensicLog -Phase "REGISTRY" -Action "HIVE_MONTADO" -Target "$($profile.Username) -> $tempKey (copia de trabajo)" -Result "OK"
            } else {
                Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
                # reg.exe fallando con codigo de salida no nulo NO lanza excepcion en PowerShell,
                # asi que sin este else el fallo pasaba totalmente desapercibido: el usuario
                # quedaba excluido de UserAssist/MRU/RDP History/COM Hijacking sin ningun aviso.
                Write-ForensicLog -Phase "REGISTRY" -Action "HIVE_MONTAR_FALLIDO" -Target $profile.Username -Result "ERROR" -ErrorMessage "reg.exe load devolvio codigo $LASTEXITCODE : $($result -join ' ')"
            }
        } catch {
            Write-ForensicLog -Phase "REGISTRY" -Action "HIVE_MONTAR_ERROR" -Target $profile.Username -Result "ERROR" -ErrorMessage $_.Exception.Message
        }
    }
}

$Script:HivesNoDesmontadas = @()

function Dismount-OfflineUserHives {
    foreach ($hive in $Script:LoadedHives) {
        $unloaded = $false
        try {
            [gc]::Collect()
            Start-Sleep -Milliseconds 500
            & reg.exe unload $hive.Key 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $unloaded = $true
            } else {
                Write-ForensicLog -Phase "REGISTRY" -Action "HIVE_DESMONTAR_REINTENTO" -Target $hive.Key -Result "WARNING"
                [gc]::Collect()
                Start-Sleep -Seconds 2
                & reg.exe unload $hive.Key 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $unloaded = $true
                } else {
                    # Tercer y ultimo intento con una espera mayor antes de declarar el fallo.
                    [gc]::Collect()
                    Start-Sleep -Seconds 3
                    & reg.exe unload $hive.Key 2>&1 | Out-Null
                    $unloaded = ($LASTEXITCODE -eq 0)
                }
            }
        } catch {
            Write-ForensicLog -Phase "REGISTRY" -Action "HIVE_DESMONTAR_ERROR" -Target $hive.Key -Result "WARNING" -ErrorMessage $_.Exception.Message
        }

        if ($unloaded) {
            Write-ForensicLog -Phase "REGISTRY" -Action "HIVE_DESMONTADO" -Target $hive.Key -Result "OK"
            if ($hive.WorkDir) { Remove-Item -LiteralPath $hive.WorkDir -Recurse -Force -ErrorAction SilentlyContinue }
        } else {
            # CRITICO: sin esta comprobacion, un fallo en el reintento se registraba solo como
            # WARNING y la clave HKEY_USERS\MAPE_<usuario> podia quedar montada de forma
            # PERMANENTE en el registro vivo del equipo analizado -- una escritura/modificacion
            # real del sistema objetivo, en contra de la promesa de "solo lectura" de la
            # herramienta, y sin ningun ERROR que lo delatase. Ademas puede impedir que el
            # perfil de ese usuario cargue correctamente tras la adquisicion.
            $Script:HivesNoDesmontadas += $hive.Key
            if ($Script:SessionInfo) { $Script:SessionInfo.TotalErrors++ }
            Write-ForensicLog -Phase "REGISTRY" -Action "HIVE_DESMONTAR_FALLO_PERMANENTE" -Target $hive.Key -Result "ERROR" -ErrorMessage "La clave $($hive.Key) sigue montada en HKEY_USERS del equipo analizado tras 3 intentos. Requiere desmontaje manual con 'reg unload $($hive.Key)' antes de devolver el equipo. Es una copia de trabajo (el NTUSER.DAT original no se ha montado), pero la clave sigue presente en el registro del equipo."
        }
    }
    $Script:LoadedHives = @()
    # Carpeta de copias de trabajo: se elimina si ha quedado vacia
    $wb = Join-Path $Script:SessionInfo.OutputPath "Logs\_hives_trabajo"
    if ((Test-Path -LiteralPath $wb) -and -not (Get-ChildItem -LiteralPath $wb -Force -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $wb -Force -ErrorAction SilentlyContinue
    }
}

function Get-EffectiveHKUSID {
    param([string]$SID, [string]$Username)
    if (Test-Path "Registry::HKU\$SID" -ErrorAction SilentlyContinue) { return $SID }
    $mounted = $Script:LoadedHives | Where-Object { $_.Username -eq $Username }
    if ($mounted) { return $mounted.MountedSID }
    return $null
}

function Save-RegistryHive {
    param(
        [string]$HiveKey,
        [string]$OutputPath,
        [string]$Phase = "REGISTRY"
    )

    try {
        $destDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        $result = & reg.exe save $HiveKey $OutputPath /y 2>&1
        if ($LASTEXITCODE -eq 0) {
            $hash = Get-ForensicHash -FilePath $OutputPath
            $size = (Get-Item $OutputPath).Length
            Add-ChainOfCustodyEntry -SourcePath $HiveKey -DestPath $OutputPath -Hash $hash -Method "reg.exe save" -FileSize $size
            Write-ForensicLog -Phase $Phase -Action "HIVE_GUARDADO" -Target $HiveKey -Result "OK"
            return $true
        } else {
            Write-ForensicLog -Phase $Phase -Action "HIVE_REG_FALLIDO" -Target $HiveKey -Result "WARNING" -ErrorMessage ($result -join " ")
            return $false
        }
    } catch {
        Write-ForensicLog -Phase $Phase -Action "HIVE_ERROR" -Target $HiveKey -Result "ERROR" -ErrorMessage $_.Exception.Message
        return $false
    }
}
