#region ============================================================
# MaPeriT.SC - MOTOR DE CONSULTA
# Itera el esquema declarativo de SourceSchema.ps1 - no hay switch por
# categoria aqui. Trabaja sobre las DataTable ya indexadas en
# $Script:SCSession.LoadedTables (ver Core\AsyncLoader.ps1).
# ============================================================

function ConvertTo-SCDateTime {
    <#
    Las fechas en los CSV de AN son siempre string, en formatos que
    varian por fuente (confirmado leyendo el codigo: nunca hay un
    DateTime nativo). Se prueban los formatos conocidos y se cae a
    parseo generico como ultimo recurso (fechas con formato crudo del
    registro o de herramientas externas).
    #>
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }

    foreach ($fmt in $Script:SC_KnownDateFormats) {
        $parsed = [datetime]::MinValue
        if ([datetime]::TryParseExact($Value, $fmt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            return $parsed
        }
    }
    $generic = [datetime]::MinValue
    if ([datetime]::TryParse($Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$generic)) {
        return $generic
    }
    return $null
}

function Test-SCTimeOfDayMatch {
    <# Franja horaria recurrente, admite cruce de medianoche (23:00-06:00). #>
    param([datetime]$Timestamp, [TimeSpan]$FromTime, [TimeSpan]$ToTime)
    $t = $Timestamp.TimeOfDay
    if ($FromTime -le $ToTime) {
        return ($t -ge $FromTime -and $t -le $ToTime)
    }
    return ($t -ge $FromTime -or $t -le $ToTime)
}

function Format-SCFecha {
    # Fecha de un hallazgo para pantalla, informes y CSV, siempre con su zona horaria
    param($Finding)
    if ($Finding.Timestamp) { return "$($Finding.Timestamp.ToString('dd/MM/yyyy HH:mm:ss')) ($($Finding.Zona))" }
    if ($Finding.TimestampRaw) { return "$($Finding.TimestampRaw) (sin verificar)" }
    return "(sin fecha)"
}

function Resolve-SCDynamicColumns {
    <#
    Para fuentes ShimCache_*/USN_* (columnas no controladas por AN, dependen
    de fsutil / extractor externo): detecta en runtime la columna de tiempo
    y de ruta por regex sobre la cabecera real, igual que hace USNJournal.ps1
    internamente para sus propios filtros.
    #>
    param([System.Data.DataTable]$Table, [hashtable]$SourceEntry)
    $cols = @($Table.Columns | ForEach-Object { $_.ColumnName })
    $timeCol = if ($SourceEntry.DynamicTimeHint) { $cols | Where-Object { $_ -match $SourceEntry.DynamicTimeHint } | Select-Object -First 1 } else { $null }
    $pathCol = if ($SourceEntry.DynamicPathHint) { $cols | Where-Object { $_ -match $SourceEntry.DynamicPathHint } | Select-Object -First 1 } else { $null }
    return [PSCustomObject]@{ TimeCol = $timeCol; PathCol = $pathCol }
}

function Invoke-SCQuery {
    param(
        [string[]]$SourceKeys,
        [string[]]$Users        = @(),   # vacio = todos los usuarios
        [Nullable[datetime]]$DateFrom = $null,
        [Nullable[datetime]]$DateTo   = $null,
        [Nullable[TimeSpan]]$TimeFrom = $null,   # franja horaria recurrente opcional
        [Nullable[TimeSpan]]$TimeTo   = $null,
        [string]$Keyword = "",
        [string]$ExcludeKeyword = ""   # independiente de -Keyword: descarta si coincide, no requiere que -Keyword este activo
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $summary = [ordered]@{
        FuentesConsultadas               = [System.Collections.Generic.List[string]]::new()
        FuentesNoDisponibles              = [System.Collections.Generic.List[string]]::new()
        FuentesSinColumnaFecha            = [System.Collections.Generic.List[string]]::new()
        TotalFilasEvaluadas               = 0
        TotalFilasConFechaNoInterpretable = 0
        TotalFilasSinUsuarioAsociado      = 0
    }

    $usersLower   = @($Users | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() })
    $filterByUser = $usersLower.Count -gt 0
    $keywordLower = if ($Keyword) { $Keyword.ToLowerInvariant() } else { "" }
    $excludeKeywordLower = if ($ExcludeKeyword) { $ExcludeKeyword.ToLowerInvariant() } else { "" }
    $hasTimeFilter = ($null -ne $DateFrom) -or ($null -ne $DateTo) -or (($null -ne $TimeFrom) -and ($null -ne $TimeTo))

    foreach ($key in $SourceKeys) {
        $entry = Get-SCSourceEntry -Key $key
        if (-not $entry) { continue }

        $tbl = $Script:SCSession.LoadedTables[$key]
        if (-not $tbl) {
            $summary.FuentesNoDisponibles.Add($key)
            continue
        }
        $summary.FuentesConsultadas.Add($key)

        $timeCol = $entry.TimestampCol
        $pathColResolved = $entry.PathCol
        $descCols = $entry.DescCols
        if ($entry.Dynamic) {
            $dyn = Resolve-SCDynamicColumns -Table $tbl -SourceEntry $entry
            $timeCol = $dyn.TimeCol
            $pathColResolved = $dyn.PathCol
            if (-not $timeCol) { $summary.FuentesSinColumnaFecha.Add($key) }
            # Las fuentes Dynamic no tienen DescCols declaradas (no se conocen
            # sus columnas de antemano): usar todas las columnas disponibles
            # como descripcion en vez de dejarla vacia (antes se quedaba en
            # blanco siempre para ShimCache_*/USN_*, un hallazgo sin ninguna
            # informacion util mas alla de fecha/fuente/origen).
            if (-not $descCols -or $descCols.Count -eq 0) {
                $descCols = @($tbl.Columns | ForEach-Object { $_.ColumnName } | Select-Object -First 8)
            }
        }

        # La columna de ruta (RutaCompleta/RutaFichero/etc.) no estaba incluida
        # en DescCols para MFT/Amcache/USN: el hallazgo mostraba el nombre del
        # fichero pero nunca su carpeta, y el filtro de palabra clave (inclusion
        # o exclusion) no podia buscar por ruta - confirmado al probar excluir
        # "OneDrive" contra un caso real y ver que casi no quitaba resultados
        # porque la ruta nunca llegaba a evaluarse. Se añade aqui si no estaba ya.
        if ($pathColResolved -and $descCols -notcontains $pathColResolved) {
            $descCols = @($descCols) + $pathColResolved
        }

        $originPath = Join-Path $Script:SCSession.ANOutputPath $entry.RelPath

        foreach ($row in $tbl.Rows) {
            $summary.TotalFilasEvaluadas++

            # --- Fecha ---
            $dt = $null
            if ($timeCol -and $tbl.Columns.Contains($timeCol)) {
                $dt = ConvertTo-SCDateTime -Value $row[$timeCol]
            }
            if (-not $dt) {
                $summary.TotalFilasConFechaNoInterpretable++
                if ($hasTimeFilter) { continue }   # sin fecha no se puede aplicar un filtro temporal
            } else {
                if ($DateFrom -and $dt -lt $DateFrom) { continue }
                if ($DateTo   -and $dt -gt $DateTo)   { continue }
                if (($null -ne $TimeFrom) -and ($null -ne $TimeTo) -and -not (Test-SCTimeOfDayMatch -Timestamp $dt -FromTime $TimeFrom -ToTime $TimeTo)) { continue }
            }

            # --- Usuario ---
            $userInfo = Resolve-SCRowUser -Row $row -SourceEntry $entry -ResolvedPathCol $pathColResolved
            if ($userInfo.Confianza -eq 'NoDisponible') { $summary.TotalFilasSinUsuarioAsociado++ }
            if ($filterByUser) {
                if ($userInfo.Confianza -eq 'NoDisponible') { continue }
                if ($usersLower -notcontains $userInfo.Usuario.ToLowerInvariant()) { continue }
            }

            # --- Palabra clave (inclusion y exclusion, independientes entre si) ---
            $descValues = @(foreach ($dc in $descCols) { if ($tbl.Columns.Contains($dc)) { "$($dc): $($row[$dc])" } })
            if ($keywordLower -or $excludeKeywordLower) {
                $haystack = ($descValues -join ' ').ToLowerInvariant()
                if ($keywordLower -and -not $haystack.Contains($keywordLower)) { continue }
                if ($excludeKeywordLower -and $haystack.Contains($excludeKeywordLower)) { continue }
            }

            $results.Add([PSCustomObject]@{
                Timestamp    = $dt
                TimestampRaw = if ($timeCol -and $tbl.Columns.Contains($timeCol)) { "$($row[$timeCol])" } else { "" }
                Zona         = if ($entry.Zona) { $entry.Zona } else { 'UTC' }
                Fuente       = $key
                Origen       = $originPath
                Usuario      = $userInfo.Usuario
                Confianza    = $userInfo.Confianza
                Descripcion  = ($descValues -join ' | ')
                Incluir      = $true
            })
        }
    }

    $sorted = $results | Sort-Object { if ($_.Timestamp) { $_.Timestamp } else { [datetime]::MinValue } }
    return [PSCustomObject]@{ Resultados = @($sorted); Resumen = [PSCustomObject]$summary }
}

#endregion
