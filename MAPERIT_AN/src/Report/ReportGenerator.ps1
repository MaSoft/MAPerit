#region ============================================================
# MaPeriT.AN - GENERADOR DEL INFORME AN HTML
# ============================================================

function New-ANReport {
    param(
        [string]$ANOutputPath,
        [string]$EvidencePath,
        [hashtable]$SWInfo,
        [hashtable]$CorrelationData
    )

    $reportFile = Join-Path $ANOutputPath "$($Script:AN_Dirs.Report)\InformeAN.html"
    $css = Get-ANCss; $js = Get-ANJs
    $dur = if ($Script:ANSession.EndTime) {
               ($Script:ANSession.EndTime - $Script:ANSession.StartTime).ToString('hh\:mm\:ss')
           } else { "En curso" }

    # Campos de sesion (numero de caso, equipo, perito, SO, ruta de evidencias)
    # interpolados en HTML: deben ir codificados. Add-ANSection (tablas CSV)
    # ya lo hacia de forma consistente; esta era la unica excepcion, mismo
    # patron de bug ya corregido en MaPeriT.SW.
    $caseNumberEnc = [System.Web.HttpUtility]::HtmlEncode($Script:ANSession.SWCaseNumber)
    $examinerEnc   = [System.Web.HttpUtility]::HtmlEncode($Script:ANSession.ExaminerName)
    $evidencePathEnc = [System.Web.HttpUtility]::HtmlEncode($Script:ANSession.EvidencePath)
    $computerNameEnc = [System.Web.HttpUtility]::HtmlEncode($SWInfo.ComputerName)
    $osVersionEnc    = [System.Web.HttpUtility]::HtmlEncode($SWInfo.OSVersion)

    Write-ANLog -Phase "INFORME" -Action "GENERANDO_INFORME_AN" -Target $reportFile -Result "OK"

    $html = [System.Text.StringBuilder]::new(300000)

    [void]$html.AppendLine(@"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>MaPeriT.AN - Informe de Analisis - Caso $caseNumberEnc</title>
<style>$css</style>
</head>
<body>
"@)

    # ── SIDEBAR ────────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<nav class="sidebar">
  <div class="sb-brand">
    <div class="sb-brand-name">MaPeriT.AN</div>
    <div class="sb-brand-sub">Analizador Forense Offline v$($Script:AN_VERSION)</div>
  </div>
  <div class="sb-case">
    <strong>Caso SW</strong>$caseNumberEnc
    <strong style="margin-top:6px">Equipo</strong>$computerNameEnc
    <strong style="margin-top:6px">Perito AN</strong>$examinerEnc
  </div>
  <nav>
    <div class="sb-label">Analisis</div>
    <a href="#sec1">1. Resumen Ejecutivo AN</a>
    <a href="#sec2">2. Analisis MFT</a>
    <a href="#sec3">3. Timestomping</a>
    <a href="#sec4">4. Ficheros Borrados</a>
    <a href="#sec5">5. Logs EVTX Profundos</a>
    <a href="#sec6">6. Navegadores (SQLite)</a>
    <a href="#sec6b">6b. ShimCache / Amcache</a>
    <a href="#sec6c">6c. USN Journal</a>
    <a href="#sec7">7. Timeline Correlacionada</a>
    <a href="#sec8">8. Risk Scores</a>
    <a href="#sec9">9. Conclusiones AN</a>
  </nav>
  <div class="sb-footer">
    Analisis: $(Get-Date -Format 'dd/MM/yyyy HH:mm')<br>
    Duracion: $dur<br>
    Errores: $($Script:ANSession.Errors) / Avisos: $($Script:ANSession.Warnings)
  </div>
</nav>
<div class="main">
"@)

    # ── PORTADA ────────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div class="cover">
  <div class="cover-badge">Informe de Analisis Forense Profundo</div>
  <h1>MaPeriT.AN</h1>
  <h2>Analisis Offline de Evidencias &mdash; Caso $caseNumberEnc</h2>
  <div class="cover-grid">
    <div class="cover-item"><label>Caso SW</label><span>$caseNumberEnc</span></div>
    <div class="cover-item"><label>Equipo Analizado</label><span>$computerNameEnc</span></div>
    <div class="cover-item"><label>SO</label><span>$osVersionEnc</span></div>
    <div class="cover-item"><label>Perito AN</label><span>$examinerEnc</span></div>
    <div class="cover-item"><label>Registros MFT</label><span>$($Script:ANSession.MFTRecords)</span></div>
    <div class="cover-item"><label>Timestomping detectado</label><span>$($Script:ANSession.MFTTimestomped)</span></div>
    <div class="cover-item"><label>Eventos EVTX analizados</label><span>$($Script:ANSession.EVTXEvents)</span></div>
    <div class="cover-item"><label>URLs de navegacion</label><span>$($Script:ANSession.BrowserURLs)</span></div>
  </div>
</div>

<div class="content">
"@)

    # ── SEC 1: RESUMEN EJECUTIVO AN ────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec1">
<div class="section-hdr"><div class="sec-num">1</div><h2>Resumen Ejecutivo AN</h2></div>
<p>Este informe complementa el informe pericial de MaPeriT.SW con un analisis profundo offline.
Trabaja sobre las evidencias ya recopiladas en <strong>$evidencePathEnc</strong>
sin modificar ninguna de ellas: los resultados se escriben en la carpeta de salida del analisis y los
hives se consultan sobre copias de trabajo temporales. Todas las fechas se expresan en UTC salvo las
procedentes de la timeline de MaPeriT.SW (hora local del equipo adquirido, indicada en cada fila).</p>

<div class="stat-grid">
  <div class="stat-card ok"><div class="sv">$($Script:ANSession.MFTRecords)</div><div class="sl">Registros MFT validos</div></div>
  <div class="stat-card $(if($Script:ANSession.MFTTimestomped -gt 0){'ts'}else{'ok'})">
    <div class="sv">$($Script:ANSession.MFTTimestomped)</div><div class="sl">Sospecha de Timestomping</div>
  </div>
  <div class="stat-card del"><div class="sv">$($Script:ANSession.MFTDeleted)</div><div class="sl">Ficheros Borrados (MFT)</div></div>
  <div class="stat-card"><div class="sv">$($Script:ANSession.EVTXEvents)</div><div class="sl">Eventos EVTX relevantes</div></div>
  <div class="stat-card"><div class="sv">$($Script:ANSession.BrowserURLs)</div><div class="sl">URLs de navegacion</div></div>
  <div class="stat-card $(if($Script:ANSession.Errors -gt 0){'ts'}else{'ok'})">
    <div class="sv">$($Script:ANSession.Errors)</div><div class="sl">Errores de analisis</div>
  </div>
</div>
</div>
"@)

    # ── SEC 2: ANALISIS MFT ────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec2" class="page-break">
<div class="section-hdr"><div class="sec-num">2</div><h2>Analisis MFT — Master File Table</h2></div>
<p>El fichero <code>&#36;MFT</code> binario fue extraido en la adquisicion SW mediante acceso raw al dispositivo.
Se han parseado los atributos <code>&#36;STANDARD_INFORMATION</code> y <code>&#36;FILE_NAME</code> de cada File Record (1024 bytes).</p>

<div class="alert alert-info">
  <strong>&#36;STANDARD_INFORMATION (SI)</strong>: timestamps que el SO actualiza en operaciones normales y que <em>pueden ser manipulados</em> por herramientas antiforensicas.<br>
  <strong>&#36;FILE_NAME (FN)</strong>: timestamps mantenidos por NTFS, <em>mas dificiles de falsificar</em> sin acceso a bajo nivel.
  La discrepancia entre ambos es indicador de timestomping.
</div>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Completo.csv") -Title "2.1 Todos los registros MFT (muestra)" -MaxRows 500 -Collapsible -HighlightCol "Timestomping" -HighlightVal "True" -HighlightClass "ts-row"
    [void]$html.AppendLine("</div>")

    # ── SEC 3: TIMESTOMPING ────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec3" class="page-break">
<div class="section-hdr"><div class="sec-num">3</div><h2>Timestomping Detectado</h2></div>
<p>Indicadores fiables: timestamps <code>&#36;STANDARD_INFORMATION</code> anteriores a <code>&#36;FILE_NAME</code>
(imposible sin manipulacion directa). Se excluyen heuristicas de sub-segundo que generan falsos positivos
en ficheros del instalador de Windows.</p>
"@)
    if ($Script:ANSession.MFTTimestomped -gt 0) {
        [void]$html.AppendLine("<div class='alert alert-warn'>Se detectaron <strong>$($Script:ANSession.MFTTimestomped) ficheros</strong> con indicadores de timestomping.</div>")
        # Mostrar primero los que NO son de sistema (mas relevantes para la investigacion)
        [void]$html.AppendLine("<div class='sub-hdr'>3.1 Ficheros fuera de rutas de sistema (prioridad alta)</div>")
        $tsFile = Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Timestomping.csv"
        if (Test-Path $tsFile) {
            # @() para que los recuentos del titulo sean correctos tambien con una sola fila;
            # las rutas de ficheros borrados llevan el prefijo "[BORRADO] " (MFTParser).
            $tsAll     = @(Import-Csv $tsFile -ErrorAction SilentlyContinue)
            $sysRe     = '^(\[BORRADO\] )?(Windows\\|Program Files|ProgramData)'
            $tsNoSys   = @($tsAll | Where-Object { $_.RutaCompleta -notmatch $sysRe } | Select-Object -First 200)
            $tsSys     = @($tsAll | Where-Object { $_.RutaCompleta -match $sysRe }    | Select-Object -First 100)
            $tmpNoSys  = Join-Path $env:TEMP "ts_nosys_$(Get-Random).csv"
            $tmpSys    = Join-Path $env:TEMP "ts_sys_$(Get-Random).csv"
            $tsNoSys | Export-Csv $tmpNoSys -NoTypeInformation -Encoding UTF8 -Force
            $tsSys    | Export-Csv $tmpSys  -NoTypeInformation -Encoding UTF8 -Force
            Add-ANSection -Html $html -FilePath $tmpNoSys -Title "3.1 Timestomping fuera de rutas sistema ($($tsNoSys.Count) de $($tsAll.Count))" -MaxRows 200 -HighlightClass "ts-row"
            Add-ANSection -Html $html -FilePath $tmpSys   -Title "3.2 Timestomping en rutas sistema ($($tsSys.Count)) — menor prioridad" -MaxRows 50 -Collapsible
            Remove-Item $tmpNoSys,$tmpSys -Force -ErrorAction SilentlyContinue
        }
    } else {
        [void]$html.AppendLine("<div class='alert alert-ok'>No se detectaron indicadores fiables de timestomping.</div>")
    }
    [void]$html.AppendLine("</div>")

    # ── SEC 4: FICHEROS BORRADOS ───────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec4" class="page-break">
<div class="section-hdr"><div class="sec-num">4</div><h2>Ficheros Borrados (MFT)</h2></div>
<p>El MFT conserva los File Records de ficheros borrados hasta que la posicion es reutilizada.
Se han identificado <strong>$($Script:ANSession.MFTDeleted) ficheros borrados</strong> con nombre recuperable.</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Borrados.csv") -Title "4.1 Ficheros borrados (muestra)" -MaxRows 300 -Collapsible -HighlightClass "del-row"
    [void]$html.AppendLine("</div>")

    # ── SEC 5: EVTX ───────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec5" class="page-break">
<div class="section-hdr"><div class="sec-num">5</div><h2>Logs EVTX — Analisis Profundo</h2></div>
<p>Procesados <strong>$($Script:ANSession.EVTXEvents) eventos</strong> relevantes de todos los ficheros .evtx copiados,
sin limite de eventos (a diferencia del analisis preliminar de SW).</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_LogBorrado.csv")      -Title "5.1 ALERTA: Log de Auditoria Borrado" -MaxRows 50
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_NuevosServicios.csv") -Title "5.2 ALERTA: Nuevos Servicios Instalados" -MaxRows 50
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_FailedLogons.csv")    -Title "5.3 Logons Fallidos" -MaxRows 100
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_Logons.csv")          -Title "5.4 Logons Exitosos" -MaxRows 100
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_PowerShell4104.csv")  -Title "5.5 Scripts PowerShell (ScriptBlock 4104)" -MaxRows 50
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_Procesos.csv")        -Title "5.6 Procesos Creados (4688)" -MaxRows 100 -Collapsible
    [void]$html.AppendLine("</div>")

    # ── SEC 6: NAVEGADORES ─────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec6" class="page-break">
<div class="section-hdr"><div class="sec-num">6</div><h2>Navegadores Web (SQLite)</h2></div>
<p>Historial completo extraido directamente de los ficheros SQLite copiados. <strong>$($Script:ANSession.BrowserURLs) URLs</strong> recuperadas.</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.Browsers)\Browser_Busquedas.csv")  -Title "6.1 Terminos de Busqueda" -MaxRows 200
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.Browsers)\Browser_Descargas.csv")  -Title "6.2 Descargas" -MaxRows 100
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.Browsers)\Browser_Historial.csv")  -Title "6.3 Historial de Navegacion" -MaxRows 500 -Collapsible
    [void]$html.AppendLine("</div>")

    # ── SEC 6b: SHIMCACHE / AMCACHE ───────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec6b" class="page-break">
<div class="section-hdr"><div class="sec-num">6b</div><h2>ShimCache / Amcache — Programas Registrados</h2></div>
<p>Estas fuentes registran la presencia de ejecutables en el equipo aunque no existan Event IDs 4688
(proceso creado) en los logs de auditoria. Son indicios, no prueba concluyente de ejecucion: en Windows 10/11
el ShimCache incluye programas solo examinados, su fecha es la ultima modificacion del fichero y la de Amcache
es la de compilacion (LinkDate) o instalacion (InstallDate), nunca la de ejecucion.</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\ShimCache_Sospechosos.csv") -Title "6b.1 ShimCache - Ejecutables fuera de rutas estandar" -MaxRows 200
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\Amcache_Recientes.csv")     -Title "6b.2 Amcache - Ejecutables mas recientes por fecha de referencia" -MaxRows 200
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\ShimCache_Completo.csv")   -Title "6b.3 ShimCache completo" -MaxRows 500 -Collapsible
    [void]$html.AppendLine("</div>")

    # ── SEC 6c: USN JOURNAL ────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec6c" class="page-break">
<div class="section-hdr"><div class="sec-num">6c</div><h2>USN Journal — Operaciones en Sistema de Ficheros</h2></div>
<p>El USN Journal registra cada operacion NTFS (creacion, modificacion, renombrado, borrado).
Es la fuente mas completa para reconstruir actividad en el disco.</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\USN_Resumen.csv")          -Title "6c.0 Resumen USN Journal" -MaxRows 10
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\USN_Borrados.csv")         -Title "6c.1 Operaciones de Borrado" -MaxRows 200
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\USN_Renombrados.csv")      -Title "6c.2 Operaciones de Renombrado" -MaxRows 200
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\USN_Ejecutables.csv")      -Title "6c.3 Operaciones sobre Ejecutables" -MaxRows 300
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\USN_RutasSospechosas.csv") -Title "6c.4 Actividad en Rutas Sospechosas (Temp, Downloads)" -MaxRows 200
    [void]$html.AppendLine("</div>")

    # ── SEC 7: TIMELINE CORRELACIONADA ─────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec7" class="page-break">
<div class="section-hdr"><div class="sec-num">7</div><h2>Timeline Correlacionada</h2></div>
<p>Cronologia unificada que integra eventos EVTX, timestamps MFT, ficheros borrados y timeline de MaPeriT.SW.</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "Correlacion_Timeline.csv") -Title "7.1 Timeline completa" -MaxRows 500 -Collapsible
    [void]$html.AppendLine("</div>")

    # ── SEC 8: RISK SCORES ─────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec8" class="page-break">
<div class="section-hdr"><div class="sec-num">8</div><h2>Risk Scores por Entidad</h2></div>
<p>Puntuacion de riesgo acumulada por usuario/entidad segun eventos EVTX (log borrado=90pts, servicio nuevo=80pts, etc.).</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "Correlacion_RiskScores.csv") -Title "8.1 Puntuacion de riesgo" -MaxRows 50
    [void]$html.AppendLine("</div>")

    # ── SEC 9: CONCLUSIONES AN ─────────────────────────────────────────
    $dateStr = (Get-Date).ToString("dd 'de' MMMM 'de' yyyy")
    [void]$html.AppendLine(@"
<div id="sec9" class="page-break">
<div class="section-hdr"><div class="sec-num">9</div><h2>Conclusiones AN</h2></div>
<p>El analisis profundo offline sobre las evidencias del caso <strong>$caseNumberEnc</strong>
ha procesado <strong>$($Script:ANSession.MFTRecords) registros MFT</strong>,
<strong>$($Script:ANSession.EVTXEvents) eventos de log</strong> y
<strong>$($Script:ANSession.BrowserURLs) URLs de navegacion</strong>.</p>

$(if ($Script:ANSession.MFTTimestomped -gt 0) {
"<div class='alert alert-crit'>Se han detectado <strong>$($Script:ANSession.MFTTimestomped) ficheros con indicadores de timestomping</strong>. Esto puede indicar manipulacion deliberada de timestamps para ocultar actividad. Se recomienda investigacion adicional de los ficheros listados en la seccion 3.</div>"
})

<p>Este informe debe interpretarse conjuntamente con el Informe Pericial de MaPeriT.SW.
Ambos documentos forman la evidencia tecnica completa del caso.</p>

<div style="margin-top:60px;display:grid;grid-template-columns:1fr 1fr;gap:48px;padding-top:32px;border-top:2px solid #e2e8f0">
  <div style="text-align:center"><div style="border-top:1px solid #94a3b8;margin-top:70px;padding-top:8px;font-size:13px">En __________, a $dateStr<br><br>$examinerEnc<br><em>Perito Informatico</em></div></div>
  <div style="text-align:center"><div style="border-top:1px solid #94a3b8;margin-top:70px;padding-top:8px;font-size:13px">Recibido: _______________<br><br>&nbsp;<br><em>Firma y sello</em></div></div>
</div>
</div>

</div><!-- /content -->

<div class="report-footer">
  Informe generado por <strong>MaPeriT.AN v$($Script:AN_VERSION)</strong> &bull;
  Caso: $caseNumberEnc &bull;
  Perito: $examinerEnc &bull;
  Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
</div>

</div><!-- /main -->
<script>$js</script>
</body></html>
"@)

    $html.ToString() | Out-File -FilePath $reportFile -Encoding UTF8
    Write-ANLog -Phase "INFORME" -Action "INFORME_AN_GENERADO" -Target $reportFile -Result "OK"
    return $reportFile
}

function Add-ANSection {
    param(
        [System.Text.StringBuilder]$Html,
        [string]$FilePath,
        [string]$Title,
        [int]$MaxRows      = 100,
        [switch]$Collapsible,
        [string]$HighlightCol   = "",
        [string]$HighlightVal   = "",
        [string]$HighlightClass = ""
    )

    $safeId = "t_" + ($Title -replace '[^a-zA-Z0-9]','_')

    if ($Collapsible) {
        [void]$Html.AppendLine("<details><summary>$([System.Web.HttpUtility]::HtmlEncode($Title))</summary><div class='det-body'>")
    } else {
        [void]$Html.AppendLine("<div class='sub-hdr'>$([System.Web.HttpUtility]::HtmlEncode($Title))</div>")
    }

    if (-not (Test-Path $FilePath)) {
        [void]$Html.AppendLine("<p><em style='color:#94a3b8'>Sin datos disponibles.</em></p>")
        if ($Collapsible) { [void]$Html.AppendLine("</div></details>") }
        return
    }

    try {
        $data = @(Import-Csv $FilePath -ErrorAction Stop | Select-Object -First $MaxRows)
        $totalInFile = @(Import-Csv $FilePath -ErrorAction SilentlyContinue).Count

        if ($data.Count -eq 0) {
            [void]$Html.AppendLine("<p><em style='color:#94a3b8'>Sin registros.</em></p>")
        } else {
            $cols = $data[0].PSObject.Properties.Name
            $showSearch = $totalInFile -gt 15
            $searchId = $safeId + "_s"
            $tableId  = $safeId + "_tbl"
            $monoCols = @('Hash','SHA256','SHA-256','RutaCompleta','FullPath','URL','CommandLine','ScriptBlock','SI_Creado_UTC','SI_Modificado_UTC','FN_Creado_UTC','FN_Modificado_UTC')
            $wrapCols = @('Descripcion','Description','Detalle','RazonTimestomp','TimestompReason','ScriptBlock')

            [void]$Html.AppendLine("<div class='tcard'>")
            [void]$Html.AppendLine("<div class='ttoolbar'>")
            [void]$Html.AppendLine("  <span class='ttoolbar-label'>$($data.Count) / $totalInFile registros</span>")
            if ($showSearch) {
                [void]$Html.AppendLine("  <input class='tsearch' id='$searchId' type='text' placeholder='Filtrar...' oninput=""filterTable('$searchId','$tableId')"">")
            }
            [void]$Html.AppendLine("</div><div class='twrap'>")
            [void]$Html.AppendLine("<table class='dtable' id='$tableId'><thead><tr>")
            foreach ($col in $cols) { [void]$Html.AppendLine("<th>$([System.Web.HttpUtility]::HtmlEncode($col))</th>") }
            [void]$Html.AppendLine("</tr></thead><tbody>")

            foreach ($row in $data) {
                $rowClass = ""
                if ($HighlightCol -and $HighlightClass) {
                    if ($row.$HighlightCol -eq $HighlightVal) { $rowClass = " class='$HighlightClass'" }
                } elseif ($HighlightClass) { $rowClass = " class='$HighlightClass'" }

                [void]$Html.Append("<tr$rowClass>")
                foreach ($col in $cols) {
                    $raw = if ($null -eq $row.$col) { "" } else { $row.$col.ToString() }
                    $enc = [System.Web.HttpUtility]::HtmlEncode($raw)
                    $cls = ""
                    if ($monoCols -contains $col) { $cls = " class='mono'" }
                    elseif ($wrapCols -contains $col) { $cls = " class='w'" }
                    $titleAttr = if ($raw.Length -gt 60 -and $cls -notlike "*w*") { " title='$([System.Web.HttpUtility]::HtmlEncode($raw))'" } else { "" }
                    if ($enc.Length -gt 80 -and $cls -notlike "*w*") { $enc = $enc.Substring(0,77) + "&#8230;" }
                    [void]$Html.Append("<td$cls$titleAttr>$enc</td>")
                }
                [void]$Html.AppendLine("</tr>")
            }
            [void]$Html.AppendLine("</tbody></table></div>")
            if ($totalInFile -gt $MaxRows) {
                [void]$Html.AppendLine("<div class='tnote'>Mostrando $MaxRows de $totalInFile. Fichero completo: $(Split-Path $FilePath -Leaf)</div>")
            }
            [void]$Html.AppendLine("</div>")
        }
    } catch {
        [void]$Html.AppendLine("<div class='alert alert-warn'>Error al leer: $([System.Web.HttpUtility]::HtmlEncode($_.Exception.Message))</div>")
    }

    if ($Collapsible) { [void]$Html.AppendLine("</div></details>") }
}
