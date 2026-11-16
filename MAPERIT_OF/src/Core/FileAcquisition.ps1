#region ============================================================
# MaPeriT.OF - ADQUISICION DE FICHEROS OFFLINE
# Copia ficheros del disco objetivo con hash y cadena de custodia
# ============================================================

function Test-PathExcluded {
    <#
        Comprueba si una ruta coincide con alguno de los fragmentos indicados en
        -ExcludePaths (comparacion por subcadena, sin distinguir mayusculas/minusculas).
        Mismo patron ya usado en MaPeriT.SW para minimizacion de datos cuando la
        autorizacion/orden judicial delimita el alcance de la adquisicion. Las
        exclusiones quedan siempre registradas como SKIP, nunca se omiten en silencio.
    #>
    param([string]$Path)
    if (-not $Script:ExcludePathPatterns -or $Script:ExcludePathPatterns.Count -eq 0) { return $false }
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    foreach ($pattern in $Script:ExcludePathPatterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        if ($Path.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }
    return $false
}

function Copy-ForensicFile {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$Phase = "OF",
        [string]$Method = "CopyItem"
    )
    if (Test-PathExcluded -Path $SourcePath) {
        Write-ForensicLog -Phase $Phase -Action "EXCLUIDO_POR_PARAMETRO" -Target $SourcePath -Result "SKIP"
        return $false
    }
    if (-not (Test-Path $SourcePath)) {
        Write-ForensicLog -Phase $Phase -Action "FICHERO_NO_ENCONTRADO" -Target $SourcePath -Result "WARNING"
        return $false
    }
    try {
        $dir = Split-Path $DestPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item -Path $SourcePath -Destination $DestPath -Force -ErrorAction Stop
        $hash = Get-ForensicHash -FilePath $DestPath
        $size = (Get-Item $DestPath).Length
        Add-ChainOfCustodyEntry -SourcePath $SourcePath -DestPath $DestPath -Hash $hash -Method $Method -FileSize $size
        $Script:OFSession.TotalFiles++
        $Script:OFSession.TotalSizeBytes += $size
        return $true
    } catch {
        Write-ForensicLog -Phase $Phase -Action "COPIA_ERROR" -Target $SourcePath -Result "ERROR" -Detail $_.Exception.Message
        return $false
    }
}

function Copy-ForensicDirectory {
    param(
        [string]$SourceDir,
        [string]$DestDir,
        [string]$Phase    = "OF",
        [string]$Filter   = "*",
        [switch]$Recurse,
        [long]$MaxSizeMB  = 0
    )
    if (-not (Test-Path $SourceDir)) {
        Write-ForensicLog -Phase $Phase -Action "DIR_NO_ENCONTRADO" -Target $SourceDir -Result "WARNING"
        return 0
    }
    $copied = 0
    try {
        $getParams = @{ Path = $SourceDir; Filter = $Filter; File = $true; ErrorAction = "SilentlyContinue" }
        if ($Recurse) { $getParams.Recurse = $true }
        $files = Get-ChildItem @getParams
        if ($MaxSizeMB -gt 0 -and -not $CopyLargeFiles) {
            $threshold = $MaxSizeMB * 1MB
            $files = $files | Where-Object { $_.Length -le $threshold }
        }
        foreach ($f in $files) {
            # Comprobar exclusion antes de construir la ruta destino: evita crear
            # carpetas vacias residuales para ficheros que -ExcludePaths pide
            # minimizar (Copy-ForensicFile tambien lo comprueba, pero aqui se evita
            # incluso el Join-Path/creacion de estructura para el caso excluido).
            if (Test-PathExcluded -Path $f.FullName) { continue }
            $relative = $f.FullName.Substring($SourceDir.TrimEnd('\').Length + 1)
            $dest     = Join-Path $DestDir $relative
            if (Copy-ForensicFile -SourcePath $f.FullName -DestPath $dest -Phase $Phase -Method "CopyDir") {
                $copied++
            }
        }
    } catch {
        Write-ForensicLog -Phase $Phase -Action "COPIA_DIR_ERROR" -Target $SourceDir -Result "ERROR" -Detail $_.Exception.Message
    }
    return $copied
}

function Copy-ForensicFileBackup {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$Phase = "OF"
    )
    # Copia con privilegio de backup para ficheros del sistema (como $MFT)
    # Usa robocopy /B como metodo primario
    $srcDir  = Split-Path $SourcePath -Parent
    $srcFile = Split-Path $SourcePath -Leaf
    $destDir = Split-Path $DestPath -Parent

    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

    $roboArgs = @($srcDir, $destDir, $srcFile, '/B', '/R:0', '/W:0', '/NJH', '/NJS', '/NFL', '/NDL')
    $result   = & robocopy @roboArgs 2>&1
    $exitCode = $LASTEXITCODE

    # Robocopy: exit codes 0-7 son exito; >=8 error
    if ($exitCode -le 7 -and (Test-Path $DestPath)) {
        $hash = Get-ForensicHash -FilePath $DestPath
        $size = (Get-Item $DestPath).Length
        Add-ChainOfCustodyEntry -SourcePath $SourcePath -DestPath $DestPath -Hash $hash -Method "robocopy/B" -FileSize $size
        $Script:OFSession.TotalFiles++
        $Script:OFSession.TotalSizeBytes += $size
        Write-ForensicLog -Phase $Phase -Action "BACKUP_COPY_OK" -Target $srcFile -Result "OK" -Detail "$([math]::Round($size/1MB,1)) MB"
        return $true
    }

    # Fallback: Copy-Item directo (puede funcionar en discos no-sistema)
    try {
        Copy-Item -Path $SourcePath -Destination $DestPath -Force -ErrorAction Stop
        if (Test-Path $DestPath) {
            $hash = Get-ForensicHash -FilePath $DestPath
            $size = (Get-Item $DestPath).Length
            Add-ChainOfCustodyEntry -SourcePath $SourcePath -DestPath $DestPath -Hash $hash -Method "CopyItem/Fallback" -FileSize $size
            $Script:OFSession.TotalFiles++
            $Script:OFSession.TotalSizeBytes += $size
            Write-ForensicLog -Phase $Phase -Action "BACKUP_COPY_FALLBACK_OK" -Target $srcFile -Result "OK"
            return $true
        }
    } catch {}

    Write-ForensicLog -Phase $Phase -Action "BACKUP_COPY_FALLO" -Target $SourcePath -Result "WARNING" -Detail "RoboCopy=$exitCode"
    return $false
}

function Copy-RobocopyDir {
    param(
        [string]$SourceDir,
        [string]$DestDir,
        [string]$Filter  = "*.*",
        [string]$Phase   = "OF",
        [switch]$Recurse
    )
    if (-not (Test-Path $SourceDir)) {
        Write-ForensicLog -Phase $Phase -Action "DIR_NO_ENCONTRADO" -Target $SourceDir -Result "WARNING"
        return 0
    }
    if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir -Force | Out-Null }

    $roboArgs = @($SourceDir, $DestDir, $Filter, '/B', '/R:0', '/W:0', '/NJH', '/NJS', '/COPY:DAT')
    if ($Recurse) { $roboArgs += '/S' }

    $output   = & robocopy @roboArgs 2>&1
    $exitCode = $LASTEXITCODE

    # BUG CONFIRMADO: esta funcion copiaba con robocopy pero NUNCA hasheaba
    # ni registraba los ficheros en la cadena de custodia (a diferencia de
    # Copy-ForensicDirectory/Copy-ForensicFile, que si lo hacen siempre). Se
    # usa para Prefetch (Phase3) y Tareas Programadas (Phase10): esa evidencia
    # quedaba fuera de HashManifest.csv, sin SHA-256 verificable - compromete
    # su validez probatoria. Se hashea y registra cada fichero copiado.
    # -Force: robocopy conserva los atributos Oculto/Sistema; sin -Force esos
    # ficheros copiados no se hasheaban ni entraban en la cadena de custodia.
    $copiedFileObjs = @(Get-ChildItem -LiteralPath $DestDir -Filter $Filter -Recurse:$Recurse -File -Force -ErrorAction SilentlyContinue)
    foreach ($cf in $copiedFileObjs) {
        $relative = $cf.FullName.Substring($DestDir.TrimEnd('\').Length + 1)
        $srcPath  = Join-Path $SourceDir $relative
        try {
            $hash = Get-ForensicHash -FilePath $cf.FullName
            Add-ChainOfCustodyEntry -SourcePath $srcPath -DestPath $cf.FullName -Hash $hash -Method "robocopy" -FileSize $cf.Length
            $Script:OFSession.TotalFiles++
            $Script:OFSession.TotalSizeBytes += $cf.Length
        } catch {
            Write-ForensicLog -Phase $Phase -Action "HASH_ROBOCOPY_ERROR" -Target $cf.FullName -Result "WARNING" -Detail $_.Exception.Message
        }
    }
    $copiedFiles = $copiedFileObjs.Count
    if ($exitCode -le 7) {
        Write-ForensicLog -Phase $Phase -Action "ROBOCOPY_OK" -Target (Split-Path $SourceDir -Leaf) -Result "OK" -Detail "$copiedFiles ficheros"
    } else {
        Write-ForensicLog -Phase $Phase -Action "ROBOCOPY_PARCIAL" -Target (Split-Path $SourceDir -Leaf) -Result "WARNING" -Detail "ExitCode=$exitCode"
    }
    return $copiedFiles
}
