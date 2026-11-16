#region ============================================================
# MaPeriT.AN - ANALISIS USN JOURNAL
# El USN Journal registra TODAS las operaciones sobre ficheros NTFS:
# creacion, modificacion, renombrado, borrado, cambio de atributos.
# Es la fuente mas completa de actividad en el sistema de ficheros.
# ============================================================

function Invoke-USNJournalAnalysis {
    param(
        [string]$EvidencePath,
        [string]$OutputPath
    )

    Write-ANSection "ANALISIS USN JOURNAL"

    $usnPath = Join-Path $EvidencePath "$($Script:SW_Dirs.Filesystem)\UsnJournal.csv"
    if (-not (Test-Path $usnPath)) {
        Write-ANLog -Phase "USN" -Action "USN_NO_ENCONTRADO" -Target $usnPath -Result "WARNING"
        return
    }

    $usnSize = [math]::Round((Get-Item $usnPath).Length / 1MB, 1)
    Write-ANLog -Phase "USN" -Action "USN_ENCONTRADO" -Target "$usnSize MB" -Result "OK"

    # Leer en chunks para no colapsar memoria con ficheros grandes
    Write-Host "  [*] Leyendo USN Journal ($usnSize MB)..." -ForegroundColor Yellow
    # @(): con una sola entrada Import-Csv devuelve un objeto suelto sin .Count en PS 5.1
    $usnData = @(Import-Csv $usnPath -ErrorAction SilentlyContinue)
    if (-not $usnData -or $usnData.Count -eq 0) {
        Write-ANLog -Phase "USN" -Action "USN_VACIO" -Target $usnPath -Result "WARNING"
        return
    }

    Write-ANLog -Phase "USN" -Action "USN_LEIDO" -Target "$($usnData.Count) entradas" -Result "OK"

    # Detectar columnas disponibles (fsutil csv puede variar)
    $cols = $usnData[0].PSObject.Properties.Name
    $reasonCol  = $cols | Where-Object { $_ -match "Reason|reason" } | Select-Object -First 1
    $nameCol    = $cols | Where-Object { $_ -match "FileName|Name|filename" } | Select-Object -First 1
    $timeCol    = $cols | Where-Object { $_ -match "TimeStamp|Time|timestamp" } | Select-Object -First 1
    $fileIdCol  = $cols | Where-Object { $_ -match "FileId|fileId" } | Select-Object -First 1

    # Limite de filas exportadas por categoria (evita CSV/HTML inmanejables).
    # El recuento del resumen SIEMPRE se calcula sobre el total real (antes de
    # truncar), y se deja constancia explicita en el log cuando se trunca -
    # antes el resumen contaba solo las 5000 exportadas sin avisar de que
    # habia mas, lo que podia hacer perder actividad relevante sin que el
    # perito supiera que existia.
    $exportLimit = 5000

    # ── Operaciones de borrado ─────────────────────────────────────────
    $deletionsAll = @($usnData | Where-Object {
        $r = if ($reasonCol) { $_.$reasonCol } else { "" }
        $r -match "DELETE|CLOSE.*DELETE|0x.*80"
    })
    $deletions = $deletionsAll | Select-Object -First $exportLimit
    Export-ANData -Data $deletions -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\USN_Borrados.csv") -Description "Operaciones de borrado en USN"
    if ($deletionsAll.Count -gt $exportLimit) {
        Write-ANLog -Phase "USN" -Action "USN_BORRADOS_TRUNCADO" -Target "$($deletionsAll.Count) totales, solo se exportaron $exportLimit" -Result "WARNING"
    }

    # ── Operaciones de renombrado (ocultan actividad) ──────────────────
    $renamesAll = @($usnData | Where-Object {
        $r = if ($reasonCol) { $_.$reasonCol } else { "" }
        $r -match "RENAME"
    })
    $renames = $renamesAll | Select-Object -First $exportLimit
    Export-ANData -Data $renames -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\USN_Renombrados.csv") -Description "Operaciones de renombrado en USN"
    if ($renamesAll.Count -gt $exportLimit) {
        Write-ANLog -Phase "USN" -Action "USN_RENOMBRADOS_TRUNCADO" -Target "$($renamesAll.Count) totales, solo se exportaron $exportLimit" -Result "WARNING"
    }

    # ── Ejecutables creados/modificados ───────────────────────────────
    $execOpsAll = @($usnData | Where-Object {
        $n = if ($nameCol) { $_.$nameCol } else { "" }
        $n -match "\.(exe|dll|sys|bat|cmd|ps1|vbs|js|msi|scr|com|pif)$"
    })
    $execOps = $execOpsAll | Select-Object -First $exportLimit
    Export-ANData -Data $execOps -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\USN_Ejecutables.csv") -Description "Operaciones sobre ejecutables en USN"
    if ($execOpsAll.Count -gt $exportLimit) {
        Write-ANLog -Phase "USN" -Action "USN_EJECUTABLES_TRUNCADO" -Target "$($execOpsAll.Count) totales, solo se exportaron $exportLimit" -Result "WARNING"
    }

    # ── Actividad en directorios temporales / sospechosos ─────────────
    $suspiciousPathsAll = @($usnData | Where-Object {
        $n = if ($nameCol) { $_.$nameCol } else { "" }
        $n -match "Temp|tmp|\\Users\\.*\\Downloads|\\AppData\\Local\\Temp|recycle|Roaming\\Microsoft\\Windows\\Recent"
    })
    $suspiciousPaths = $suspiciousPathsAll | Select-Object -First $exportLimit
    Export-ANData -Data $suspiciousPaths -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\USN_RutasSospechosas.csv") -Description "Actividad en rutas sospechosas (Temp, Downloads, etc.)"
    if ($suspiciousPathsAll.Count -gt $exportLimit) {
        Write-ANLog -Phase "USN" -Action "USN_SOSPECHOSAS_TRUNCADO" -Target "$($suspiciousPathsAll.Count) totales, solo se exportaron $exportLimit" -Result "WARNING"
    }

    # ── Resumen estadistico (sobre el TOTAL real, no lo truncado) ─────
    $summary = [PSCustomObject]@{
        TotalEntradas       = $usnData.Count
        Borrados            = $deletionsAll.Count
        Renombrados         = $renamesAll.Count
        OperacionesEjecutables = $execOpsAll.Count
        RutasSospechosas    = $suspiciousPathsAll.Count
        PrimerEvento        = if ($timeCol) { ($usnData | Select-Object -First 1).$timeCol } else { "N/A" }
        UltimoEvento        = if ($timeCol) { ($usnData | Select-Object -Last 1).$timeCol } else { "N/A" }
    }
    Export-ANData -Data @($summary) -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\USN_Resumen.csv") -Description "Resumen USN Journal"

    Write-ANLog -Phase "USN" -Action "USN_COMPLETO" -Target "Total=$($usnData.Count) Borrados=$($deletionsAll.Count) Renombrados=$($renamesAll.Count) Ejecutables=$($execOpsAll.Count)" -Result "OK"

    if ($deletionsAll.Count -gt 500) {
        Write-ANLog -Phase "USN" -Action "ALERTA_MUCHOS_BORRADOS" -Target "$($deletionsAll.Count) operaciones de borrado detectadas" -Result "WARNING"
    }
}
