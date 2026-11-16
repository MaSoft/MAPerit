#region ============================================================
# MaPeriT.SC - INFORME PERICIAL FORMAL
# Mismo diseno visual que los informes de MaPeriT.SW/AN. Se alimenta de
# los mismos $Findings que el informe en lenguaje llano (ReportLlano.ps1)
# para garantizar que ambos documentos describan los mismos hechos.
# ============================================================

function Get-SCCategoryForSource {
    param([string]$SourceKey)
    foreach ($ck in $Script:SC_Categories.Keys) {
        if ($Script:SC_Categories[$ck].Sources -contains $SourceKey) { return $Script:SC_Categories[$ck].Label }
    }
    return "Otros"
}

function New-SCReportPericial {
    param(
        [string]$OutputDir,
        [array]$Findings,
        [PSCustomObject]$Criteria
    )

    $reportFile = Join-Path $OutputDir "Informe_Pericial_SC.html"
    $css = Get-SCCss; $js = Get-SCJs
    $dateStr = (Get-Date).ToString("dd 'de' MMMM 'de' yyyy")
    $meta = Get-SCProjectMetadata -Path $Script:SCSession.ProjectPath
    # Valores procedentes de las evidencias: se codifican antes de insertarlos en el HTML
    $meta = [PSCustomObject]@{
        CaseNumber   = [System.Web.HttpUtility]::HtmlEncode($meta.CaseNumber)
        ComputerName = [System.Web.HttpUtility]::HtmlEncode($meta.ComputerName)
        Examiner     = [System.Web.HttpUtility]::HtmlEncode($meta.Examiner)
    }

    $html = [System.Text.StringBuilder]::new(150000)

    [void]$html.AppendLine(@"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>MaPeriT.SC - Informe Pericial de Consulta - Caso $($meta.CaseNumber)</title>
<style>$css</style>
</head>
<body>
<nav class="sidebar">
  <div class="sb-brand">
    <div class="sb-brand-name">MaPeriT.SC</div>
    <div class="sb-brand-sub">Informe Pericial de Consulta v$($Script:SC_Version)</div>
  </div>
  <div class="sb-case">
    <strong>Caso</strong>$($meta.CaseNumber)
    <strong style="margin-top:6px">Equipo</strong>$($meta.ComputerName)
    <strong style="margin-top:6px">Perito</strong>$($meta.Examiner)
  </div>
  <nav>
    <div class="sb-label">Informe</div>
    <a href="#sec1">1. Resumen Ejecutivo</a>
    <a href="#sec2">2. Metodologia de la Consulta</a>
    <a href="#sec3">3. Hallazgos por Categoria</a>
    <a href="#sec4">4. Conclusiones</a>
  </nav>
  <div class="sb-footer">
    Consulta: $(Get-Date -Format 'dd/MM/yyyy HH:mm')<br>
    Hallazgos incluidos: $($Findings.Count)
  </div>
</nav>
<div class="main">

<div class="cover">
  <div class="cover-badge">Informe Pericial de Consulta Guiada</div>
  <h1>MaPeriT.SC</h1>
  <h2>Consulta Guiada sobre Evidencias Analizadas &mdash; Caso $($meta.CaseNumber)</h2>
  <div class="cover-grid">
    <div class="cover-item"><label>Caso</label><span>$($meta.CaseNumber)</span></div>
    <div class="cover-item"><label>Equipo Analizado</label><span>$($meta.ComputerName)</span></div>
    <div class="cover-item"><label>Perito</label><span>$($meta.Examiner)</span></div>
    <div class="cover-item"><label>Hallazgos Incluidos</label><span>$($Findings.Count)</span></div>
  </div>
</div>

<div class="content">
<div id="sec1">
<div class="section-hdr"><div class="sec-num">1</div><h2>Resumen Ejecutivo</h2></div>
<p>Este informe presenta el resultado de una consulta guiada realizada con <strong>MaPeriT.SC</strong> sobre las
evidencias ya analizadas por <strong>MaPeriT.AN</strong> para el caso <strong>$($meta.CaseNumber)</strong>.
MaPeriT.SC no modifica ni reanaliza ninguna evidencia: aplica filtros de usuario, categoria y ventana temporal
sobre los resultados ya generados y presenta los hallazgos que cumplen los criterios seleccionados por el
solicitante de la consulta. Cada fecha indica su zona horaria: UTC en las fuentes analizadas por MaPeriT.AN y
hora local del equipo analizado en el registro de cambios del sistema de ficheros (USN Journal).</p>
<div class="stat-grid">
  <div class="stat-card"><div class="sv">$($Findings.Count)</div><div class="sl">Hallazgos incluidos en este informe</div></div>
</div>
</div>
"@)

    # ── SEC 2: METODOLOGIA ─────────────────────────────────────────────
    $usuariosTxt = ($Criteria.Usuarios -join ', ')
    $catsTxt     = ($Criteria.Categorias -join '; ')
    $fromTxt     = if ($Criteria.DateFrom) { $Criteria.DateFrom.ToString("dd/MM/yyyy") } else { "sin limite" }
    $toTxt       = if ($Criteria.DateTo)   { $Criteria.DateTo.ToString("dd/MM/yyyy") }   else { "sin limite" }
    $timeTxt     = if ($Criteria.TimeFrom) { "$($Criteria.TimeFrom.ToString('hh\:mm')) a $($Criteria.TimeTo.ToString('hh\:mm')), todos los dias del rango" } else { "sin restriccion horaria" }
    $kwTxt       = if ($Criteria.Keyword) { $Criteria.Keyword } else { "(ninguna)" }
    $exKwTxt     = if ($Criteria.ExcludeKeyword) { $Criteria.ExcludeKeyword } else { "(ninguna)" }
    $resumen     = $Criteria.Resumen

    [void]$html.AppendLine(@"
<div id="sec2" class="page-break">
<div class="section-hdr"><div class="sec-num">2</div><h2>Metodologia de la Consulta</h2></div>
<p>Se detallan a continuacion los criterios exactos aplicados, para que este informe sea verificable y
reproducible por un tercero con acceso a las mismas evidencias.</p>
<table class="info-table">
  <tr><td>Usuario(s)</td><td>$([System.Web.HttpUtility]::HtmlEncode($usuariosTxt))</td></tr>
  <tr><td>Categorias consultadas</td><td>$([System.Web.HttpUtility]::HtmlEncode($catsTxt))</td></tr>
  <tr><td>Rango de fechas</td><td>$fromTxt &mdash; $toTxt</td></tr>
  <tr><td>Franja horaria</td><td>$([System.Web.HttpUtility]::HtmlEncode($timeTxt))</td></tr>
  <tr><td>Palabra clave adicional</td><td>$([System.Web.HttpUtility]::HtmlEncode($kwTxt))</td></tr>
  <tr><td>Excluir si contiene</td><td>$([System.Web.HttpUtility]::HtmlEncode($exKwTxt))</td></tr>
  <tr><td>Fuentes consultadas</td><td>$($resumen.FuentesConsultadas -join ', ')</td></tr>
  <tr><td>Fuentes no disponibles en el proyecto</td><td>$(if ($resumen.FuentesNoDisponibles.Count -gt 0) { $resumen.FuentesNoDisponibles -join ', ' } else { 'Ninguna' })</td></tr>
  <tr><td>Filas evaluadas en total</td><td>$($resumen.TotalFilasEvaluadas)</td></tr>
  <tr><td>Filas con fecha no interpretable</td><td>$($resumen.TotalFilasConFechaNoInterpretable)</td></tr>
  <tr><td>Filas sin usuario asociado en su fuente</td><td>$($resumen.TotalFilasSinUsuarioAsociado)</td></tr>
</table>
<div class="alert alert-info">
  <strong>Sobre la columna "Confianza" de los hallazgos</strong>
  <em>Confirmado</em> significa que el usuario proviene directamente de un campo de la fuente original
  (por ejemplo, el usuario de un evento de inicio de sesion). <em>Inferido</em> significa que el usuario se ha
  deducido de la ruta del fichero (patron <code>\Users\&lt;usuario&gt;\</code>) porque esa fuente no registra
  usuario de forma nativa. Esta distincion debe tenerse en cuenta al valorar cada hallazgo.
</div>
"@)
    if ($Findings.Count -gt 0) {
        $inferidoCount = @($Findings | Where-Object { $_.Confianza -eq 'Inferido' }).Count
        $inferidoPct = [math]::Round(100.0 * $inferidoCount / $Findings.Count, 0)
        if ($inferidoPct -gt 50) {
            [void]$html.AppendLine(@"
<div class="alert alert-warn">
  <strong>Aviso: mas de la mitad de los hallazgos tienen usuario Inferido, no Confirmado</strong>
  El $inferidoPct% de los hallazgos incluidos ($inferidoCount de $($Findings.Count)) atribuyen el usuario por
  deduccion de ruta, no por un campo directo del log. Esto es habitual en fuentes como MFT o Amcache, que no
  registran usuario de forma nativa, pero debe tenerse en cuenta al ponderar el valor probatorio del conjunto.
</div>
"@)
        }
    }
    [void]$html.AppendLine(@"
</div>
"@)

    # ── SEC 3: HALLAZGOS POR CATEGORIA ─────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec3" class="page-break">
<div class="section-hdr"><div class="sec-num">3</div><h2>Hallazgos por Categoria</h2></div>
<p>Cada hallazgo indica la fuente de datos exacta y la ruta del fichero de origen dentro del analisis de
MaPeriT.AN, para permitir su verificacion directa.</p>
"@)
    $grouped = $Findings | Group-Object { Get-SCCategoryForSource $_.Fuente }
    foreach ($g in $grouped) {
        if ($g.Name -eq (Get-SCCategoryForSource 'EVTX_Procesos')) {
            $correlations = @(Get-SCProgramCorrelations -Findings $g.Group)
            if ($correlations.Count -gt 0) {
                [void]$html.AppendLine("<div class='alert alert-info'><strong>Ejecucion confirmada por varias fuentes independientes</strong>")
                [void]$html.AppendLine("<ul style='margin:8px 0 0 20px'>")
                foreach ($c in $correlations) {
                    [void]$html.AppendLine("<li><strong>$([System.Web.HttpUtility]::HtmlEncode($c.Programa))</strong> &mdash; confirmado por $($c.Fuentes.Count) fuentes ($($c.Fuentes -join ', ')), $($c.NumRegistros) registro(s) en total</li>")
                }
                [void]$html.AppendLine("</ul></div>")
            }
        }
        Add-SCFindingsTable -Html $html -Findings @($g.Group) -Title $g.Name -Collapsible
    }
    if ($Findings.Count -eq 0) {
        [void]$html.AppendLine("<div class='alert alert-warn'>No se han incluido hallazgos en este informe (todos fueron descartados durante la revision, o la consulta no obtuvo resultados con los criterios aplicados).</div>")
    }
    [void]$html.AppendLine("</div>")

    # ── SEC 4: CONCLUSIONES ────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec4" class="page-break">
<div class="section-hdr"><div class="sec-num">4</div><h2>Conclusiones</h2></div>
<p>La consulta guiada realizada sobre el caso <strong>$($meta.CaseNumber)</strong> con los criterios descritos
en la seccion 2 ha identificado <strong>$($Findings.Count) hallazgo(s)</strong> que cumplen dichos criterios.</p>
<p>Este documento es un informe de consulta derivado del analisis pericial completo de MaPeriT.AN y debe
interpretarse conjuntamente con dicho informe y con el informe pericial de MaPeriT.SW. La ausencia de un
hallazgo en este informe no implica ausencia de actividad: unicamente indica que no se encontraron registros
que cumplan los criterios de busqueda seleccionados dentro de las fuentes consultadas.</p>

<div style="margin-top:60px;display:grid;grid-template-columns:1fr 1fr;gap:48px;padding-top:32px;border-top:2px solid #e2e8f0">
  <div style="text-align:center"><div style="border-top:1px solid #94a3b8;margin-top:70px;padding-top:8px;font-size:13px">En __________, a $dateStr<br><br>$($meta.Examiner)<br><em>Perito Informatico</em></div></div>
  <div style="text-align:center"><div style="border-top:1px solid #94a3b8;margin-top:70px;padding-top:8px;font-size:13px">Recibido: _______________<br><br>&nbsp;<br><em>Firma y sello</em></div></div>
</div>
</div>

</div><!-- /content -->

<div class="report-footer">
  Informe generado por <strong>MaPeriT.SC v$($Script:SC_Version)</strong> &bull;
  Caso: $($meta.CaseNumber) &bull;
  Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
</div>

</div><!-- /main -->
<script>$js</script>
</body></html>
"@)

    $html.ToString() | Out-File -FilePath $reportFile -Encoding UTF8
    return $reportFile
}

#endregion
