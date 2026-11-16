#region ============================================================
# MaPeriT.OF - REGISTRO OFFLINE
# Carga, consulta y descarga hives del disco objetivo sin arrancar el SO
# Tecnica: reg load -> Registry:: provider -> reg unload
# ============================================================

function Mount-OfflineHive {
    param(
        [string]$HivePath,
        [string]$Label = "OF"
    )
    if (-not (Test-Path $HivePath)) {
        Write-ForensicLog -Action "HIVE_NO_ENCONTRADO" -Target $HivePath -Result "WARNING"
        return $null
    }
    # Nombre unico para evitar conflictos con otros procesos
    $suffix  = [System.Guid]::NewGuid().ToString("N").Substring(0,8).ToUpper()
    $keyName = "OF_${Label}_${suffix}"
    $regKey  = "HKLM\$keyName"

    # NUNCA se monta el hive original del disco objetivo: "reg load" abre el
    # fichero en lectura-escritura y Windows puede reescribirlo (aplicar sus
    # .LOG1/.LOG2, actualizar cabeceras), lo que alteraria la evidencia y ademas
    # falla con un bloqueador de escritura. Se monta una copia de trabajo
    # temporal (con sus logs de transacciones) que se borra al desmontar.
    $workDir = Join-Path $Script:OFSession.OutputPath "Logs\_hives_trabajo\$keyName"
    try {
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workHive = Join-Path $workDir (Split-Path $HivePath -Leaf)
        foreach ($ext in @("", ".LOG1", ".LOG2")) {
            $src = "$HivePath$ext"
            if (Test-Path -LiteralPath $src) {
                Copy-Item -LiteralPath $src -Destination "$workHive$ext" -Force -ErrorAction Stop
                (Get-Item -LiteralPath "$workHive$ext" -Force).Attributes = 'Normal'
            }
        }
    } catch {
        Write-ForensicLog -Action "HIVE_ERROR_COPIA_TRABAJO" -Target $HivePath -Result "ERROR" -Detail $_.Exception.Message
        Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
        return $null
    }

    $output  = & reg load $regKey "`"$workHive`"" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $Script:LoadedHives[$regKey] = $HivePath
        $Script:HiveWorkCopies[$regKey] = $workDir
        Write-ForensicLog -Action "HIVE_CARGADO" -Target "$Label -> $keyName (copia de trabajo)" -Result "OK"
        return "Registry::$regKey"
    }
    Write-ForensicLog -Action "HIVE_ERROR_CARGA" -Target $HivePath -Result "ERROR" -Detail ($output -join " ")
    Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
    return $null
}

function Remove-OfflineHiveWorkCopy {
    # Borra la copia de trabajo temporal de un hive ya desmontado (nunca el original)
    param([string]$RegKey)
    if ($Script:HiveWorkCopies.ContainsKey($RegKey)) {
        Remove-Item -LiteralPath $Script:HiveWorkCopies[$RegKey] -Recurse -Force -ErrorAction SilentlyContinue
        [void]$Script:HiveWorkCopies.Remove($RegKey)
    }
    $base = Join-Path $Script:OFSession.OutputPath "Logs\_hives_trabajo"
    if ((Test-Path -LiteralPath $base) -and -not (Get-ChildItem -LiteralPath $base -Force -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $base -Force -ErrorAction SilentlyContinue
    }
}

function Dismount-OfflineHive {
    param([string]$RegistryPath)
    if (-not $RegistryPath) { return }
    $regKey = $RegistryPath -replace '^Registry::', ''
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    $output = & reg unload $regKey 2>&1
    if ($LASTEXITCODE -eq 0) {
        [void]$Script:LoadedHives.Remove($regKey)
        Remove-OfflineHiveWorkCopy -RegKey $regKey
        Write-ForensicLog -Action "HIVE_DESCARGADO" -Target $regKey -Result "OK"
    } else {
        Write-ForensicLog -Action "HIVE_ERROR_DESCARGA" -Target $regKey -Result "WARNING" -Detail ($output -join " ")
    }
}

function Dismount-AllOfflineHives {
    # BUG CONFIRMADO: la version anterior ignoraba el codigo de salida real de
    # "reg unload" y SIEMPRE vaciaba $Script:LoadedHives + logueaba "OK", aunque
    # el unload hubiera fallado de verdad (proceso con handle abierto, AV, etc.).
    # Es la ULTIMA red de seguridad de Main.ps1 para garantizar que ningun hive
    # queda montado en el registro del equipo forense tras la ejecucion - con el
    # bug, un hive podia quedar montado indefinidamente y el log lo ocultaba
    # afirmando "limpieza completa OK". Ahora se comprueba cada unload
    # individualmente y solo se retira del tracking lo que realmente se descargo.
    $keys = @($Script:LoadedHives.Keys)
    $failed = [System.Collections.Generic.List[string]]::new()
    foreach ($key in $keys) {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        $output = & reg unload $key 2>&1
        if ($LASTEXITCODE -eq 0) {
            [void]$Script:LoadedHives.Remove($key)
            Remove-OfflineHiveWorkCopy -RegKey $key
        } else {
            $failed.Add($key)
            Write-ForensicLog -Action "HIVE_ERROR_DESCARGA" -Target $key -Result "WARNING" -Detail ($output -join " ")
        }
    }
    if ($failed.Count -gt 0) {
        Write-ForensicLog -Action "HIVES_LIMPIEZA_INCOMPLETA" -Target ($failed -join ", ") -Result "ERROR" -Detail "Hives que siguen montados en el equipo forense - requiere intervencion manual (reg unload)"
    } else {
        Write-ForensicLog -Action "HIVES_LIMPIEZA_COMPLETA" -Result "OK"
    }
}

function Get-OfflineRegProperty {
    param([string]$HiveRoot, [string]$SubKey, [string]$Name = "")
    $fullPath = "$HiveRoot\$SubKey"
    try {
        if ($Name) {
            return (Get-ItemProperty -Path $fullPath -Name $Name -ErrorAction Stop).$Name
        } else {
            return Get-ItemProperty -Path $fullPath -ErrorAction Stop
        }
    } catch { return $null }
}

function Get-OfflineRegChildren {
    param([string]$HiveRoot, [string]$SubKey = "")
    $path = if ($SubKey) { "$HiveRoot\$SubKey" } else { $HiveRoot }
    return Get-ChildItem -Path $path -ErrorAction SilentlyContinue
}

function Get-OfflineControlSet {
    param([string]$SystemHiveRoot)
    # Lee el ControlSet activo desde Select\Current
    try {
        $current = Get-OfflineRegProperty -HiveRoot $SystemHiveRoot -SubKey "Select" -Name "Current"
        if ($current) { return "ControlSet{0:D3}" -f [int]$current }
    } catch {}
    return "ControlSet001"
}

function Export-OfflineRegSubtree {
    param(
        [string]$HiveRoot,
        [string]$SubKey,
        [string]$OutputPath,
        [string]$Phase = "OF",
        [int]$Depth = 3
    )
    $fullPath = "$HiveRoot\$SubKey"
    $results  = @()
    try {
        $keys = Get-ChildItem -Path $fullPath -Recurse -Depth $Depth -ErrorAction SilentlyContinue
        foreach ($k in $keys) {
            $props = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
            if ($props) {
                $props.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
                    $results += [PSCustomObject]@{
                        KeyPath = $k.PSPath -replace 'Microsoft\.PowerShell\.Core\\Registry::', ''
                        Name    = $_.Name
                        Value   = ($_.Value | Out-String).Trim()
                        Type    = $_.TypeNameOfValue
                    }
                }
            }
        }
        if ($results.Count -gt 0) {
            $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Force
            Write-ForensicLog -Phase $Phase -Action "REG_EXPORTADO" -Target (Split-Path $OutputPath -Leaf) -Result "OK" -Detail "$($results.Count) valores"
        }
    } catch {
        Write-ForensicLog -Phase $Phase -Action "REG_EXPORT_ERROR" -Target $SubKey -Result "ERROR" -Detail $_.Exception.Message
    }
    return $results
}
