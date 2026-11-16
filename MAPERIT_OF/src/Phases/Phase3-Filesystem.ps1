#region ============================================================
# MaPeriT.OF - FASE 3: SISTEMA DE FICHEROS
# Copia $MFT del disco objetivo (misma ruta que SW -> AN puede procesarlo)
# ============================================================

function Invoke-Phase3-Filesystem {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.Filesystem
    $phaseNum  = 3
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    # --- 3.1 Copia del $MFT ---
    Write-StepHeader "3.1 Copia del `$MFT (Master File Table)"
    try {
        $sw      = [System.Diagnostics.Stopwatch]::StartNew()
        $mftSrc  = Join-Path $Script:TargetRoot '$MFT'
        $mftDest = Join-Path $phasePath '$MFT'

        $ok = Copy-ForensicFileBackup -SourcePath $mftSrc -DestPath $mftDest -Phase "FASE_3"
        $sw.Stop()

        if ($ok) {
            $sizeMB = [math]::Round((Get-Item $mftDest).Length / 1MB, 1)
            Write-ForensicLog -Phase "FASE_3" -Action "MFT_COPIADO" -Target '$MFT' -Result "OK" `
                -Detail "$sizeMB MB en $($sw.ElapsedMilliseconds)ms" -DurationMs $sw.ElapsedMilliseconds
            $collected++
        } else {
            Write-ForensicLog -Phase "FASE_3" -Action "MFT_NO_COPIADO" -Target $mftSrc -Result "WARNING" `
                -Detail "Requiere privilegios de administrador y volumen accesible"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "MFT_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.2 Listado de directorios raiz ---
    Write-StepHeader "3.2 Listado de Directorios Raiz"
    try {
        $dirs = Get-ChildItem -Path $Script:TargetRoot -ErrorAction SilentlyContinue |
            Select-Object Name, FullName, Attributes, CreationTime, LastWriteTime, LastAccessTime,
                @{N='SizeKB';E={ if ($_.PSIsContainer) { 0 } else { [math]::Round($_.Length/1KB,1) } }}
        Export-CollectionToCSV -Data $dirs -OutputPath (Join-Path $phasePath "RootDirectories.csv") -Phase "FASE_3" -Description "Directorios raiz"
        $collected++
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "ROOTDIRS_ERROR" -Target $_.Exception.Message -Result "ERROR"
    }

    # --- 3.3 Prefetch ---
    Write-StepHeader "3.3 Ficheros Prefetch"
    try {
        $prefetchSrc  = Join-Path $Script:TargetRoot $Script:TargetPaths.Prefetch
        $prefetchDest = Join-Path $phasePath "Prefetch"
        if (Test-Path $prefetchSrc) {
            $n = Copy-RobocopyDir -SourceDir $prefetchSrc -DestDir $prefetchDest -Filter "*.pf" -Phase "FASE_3"
            if ($n -gt 0) { $collected++ }
        } else {
            Write-ForensicLog -Phase "FASE_3" -Action "PREFETCH_NO_ENCONTRADO" -Target $prefetchSrc -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "PREFETCH_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 3.4 Ficheros recientes modificados (ultimos 30 dias) ---
    Write-StepHeader "3.4 Ficheros Recientes del Sistema"
    try {
        $since  = (Get-Date).AddDays(-30)
        $sysDir = Join-Path $Script:TargetRoot "Windows\System32"
        $recent = @(Get-ChildItem -Path $sysDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $since -and $_.Extension -in @('.exe','.dll','.sys','.ps1','.bat','.cmd') } |
            Select-Object Name, FullName, Extension, Length, CreationTime, LastWriteTime, Attributes |
            Sort-Object LastWriteTime -Descending | Select-Object -First 500)
        if ($recent.Count -gt 0) {
            Export-CollectionToCSV -Data $recent -OutputPath (Join-Path $phasePath "RecentSystemFiles.csv") -Phase "FASE_3" -Description "Ficheros sistema recientes"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "RECENT_FILES_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 3.5 Ejecutables en ubicaciones sospechosas ---
    Write-StepHeader "3.5 Ejecutables en Ubicaciones Sospechosas"
    try {
        # Cada Join-Path entre parentesis: sin ellos, dentro de @() la coma une los
        # argumentos y PowerShell lo interpreta como UN solo Join-Path con un array
        # de rutas hijas, que lanza una excepcion. Este paso no funcionaba nunca.
        $suspiciousPaths = @(
            (Join-Path $Script:TargetRoot "Users\*\AppData\Roaming"),
            (Join-Path $Script:TargetRoot "Users\*\AppData\Local\Temp"),
            (Join-Path $Script:TargetRoot "Windows\Temp"),
            (Join-Path $Script:TargetRoot "ProgramData")
        )
        $exes = @()
        foreach ($pattern in $suspiciousPaths) {
            $exes += Get-ChildItem -Path $pattern -Include @('*.exe','*.dll','*.ps1','*.bat','*.vbs') `
                -Recurse -ErrorAction SilentlyContinue -Depth 3 |
                Select-Object Name, FullName, Length, CreationTime, LastWriteTime
        }
        if ($exes.Count -gt 0) {
            Export-CollectionToCSV -Data $exes -OutputPath (Join-Path $phasePath "SuspiciousExecutables.csv") -Phase "FASE_3" -Description "Ejecutables sospechosos"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "SUSPICIOUS_EXE_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 3.5b Amcache.hve (inventario de ejecucion; MaPeriT.AN lo analiza) ---
    Write-StepHeader "3.5b Amcache.hve"
    try {
        $amSrc = Join-Path $Script:TargetRoot "Windows\AppCompat\Programs\Amcache.hve"
        if (Test-Path -LiteralPath $amSrc) {
            foreach ($ext in @("", ".LOG1", ".LOG2")) {
                if (Test-Path -LiteralPath "$amSrc$ext") {
                    if (Copy-ForensicFileBackup -SourcePath "$amSrc$ext" -DestPath (Join-Path $phasePath "Amcache.hve$ext") -Phase "FASE_3") { $collected++ }
                }
            }
        } else {
            Write-ForensicLog -Phase "FASE_3" -Action "AMCACHE_NO_ENCONTRADO" -Target $amSrc -Result "WARNING"
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "AMCACHE_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    # --- 3.6 Papelera de reciclaje ---
    Write-StepHeader "3.6 Papelera de Reciclaje"
    try {
        $recyclers = @()
        # -Force: las carpetas por SID de $Recycle.Bin tienen atributos Oculto+Sistema;
        # sin -Force Get-ChildItem no devuelve ninguna (comprobado) y la papelera
        # quedaba siempre vacia en el resultado.
        $recyclePaths = Get-ChildItem -LiteralPath (Join-Path $Script:TargetRoot '$Recycle.Bin') -Directory -Force -ErrorAction SilentlyContinue
        foreach ($sid in $recyclePaths) {
            # Copia de la carpeta del SID ($I y $R) como evidencia, igual que MaPeriT.SW
            $collected += Copy-RobocopyDir -SourceDir $sid.FullName -DestDir (Join-Path $phasePath "RecycleBin\$($sid.Name)") -Phase "FASE_3" -Recurse

            # Solo los ficheros $I describen el borrado (nombre y ruta original, tamano
            # y fecha de eliminacion, mismo formato que interpreta MaPeriT.SW). Antes se
            # listaba cualquier fichero y se ponia su fecha de modificacion como "fecha
            # de borrado", lo que no es cierto para los $R (contenido del fichero).
            $items = Get-ChildItem $sid.FullName -File -Force -Filter '$I*' -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                $originalName = ""; $originalSize = 0; $deletedTime = ""
                try {
                    $b = [System.IO.File]::ReadAllBytes($item.FullName)
                    if ($b.Length -ge 28) {
                        $originalSize = [BitConverter]::ToInt64($b, 8)
                        $deletedTime  = [DateTime]::FromFileTimeUtc([BitConverter]::ToInt64($b, 16)).ToString($Script:Defaults.DateFormat)
                        $nameLength   = [BitConverter]::ToInt32($b, 24)
                        if ($b.Length -ge 28 + $nameLength * 2) {
                            $originalName = [System.Text.Encoding]::Unicode.GetString($b, 28, $nameLength * 2).TrimEnd("`0")
                        }
                    }
                } catch {}
                $recyclers += [PSCustomObject]@{
                    SID                 = $sid.Name
                    FicheroI            = $item.Name
                    RutaOriginal        = $originalName
                    TamanoOriginal      = $originalSize
                    FechaEliminacionUTC = $deletedTime
                    RutaEnPapelera      = $item.FullName
                }
            }
        }
        if ($recyclers.Count -gt 0) {
            Export-CollectionToCSV -Data $recyclers -OutputPath (Join-Path $phasePath "RecycleBin.csv") -Phase "FASE_3" -Description "Papelera de reciclaje"
            $collected++
        }
    } catch {
        Write-ForensicLog -Phase "FASE_3" -Action "RECYCLEBIN_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
