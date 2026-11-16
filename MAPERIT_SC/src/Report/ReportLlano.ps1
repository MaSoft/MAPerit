#region ============================================================
# MaPeriT.SC - INFORME EN LENGUAJE LLANO
# Mismos hallazgos que Informe_Pericial_SC.html (ReportPericial.ps1),
# redactados para un lector sin conocimientos tecnicos. La tabla de
# detalle se mantiene igual (misma trazabilidad de fuente/ubicacion)
# para que este informe siga siendo verificable contra el pericial.
# ============================================================

function New-SCReportLlano {
    param(
        [string]$OutputDir,
        [array]$Findings,
        [PSCustomObject]$Criteria
    )

    $reportFile = Join-Path $OutputDir "Informe_Resumen_Facil_SC.html"
    $css = Get-SCCss; $js = Get-SCJs
    $meta = Get-SCProjectMetadata -Path $Script:SCSession.ProjectPath
    # Valores procedentes de las evidencias: se codifican antes de insertarlos en el HTML
    $meta = [PSCustomObject]@{
        CaseNumber   = [System.Web.HttpUtility]::HtmlEncode($meta.CaseNumber)
        ComputerName = [System.Web.HttpUtility]::HtmlEncode($meta.ComputerName)
        Examiner     = [System.Web.HttpUtility]::HtmlEncode($meta.Examiner)
    }

    $usuariosTxt = ($Criteria.Usuarios -join ', ')
    $fromTxt = if ($Criteria.DateFrom) { $Criteria.DateFrom.ToString("dd/MM/yyyy") } else { "el principio" }
    $toTxt   = if ($Criteria.DateTo)   { $Criteria.DateTo.ToString("dd/MM/yyyy") }   else { "el final del periodo analizado" }
    $rangoTxt = "desde $fromTxt hasta $toTxt"
    $timeTxt  = if ($Criteria.TimeFrom) { " y solo entre las $($Criteria.TimeFrom.ToString('hh\:mm')) y las $($Criteria.TimeTo.ToString('hh\:mm')) de cada dia" } else { "" }

    $inferidoWarnHtml = ""
    if ($Findings.Count -gt 0) {
        $inferidoCount = @($Findings | Where-Object { $_.Confianza -eq 'Inferido' }).Count
        $inferidoPct = [math]::Round(100.0 * $inferidoCount / $Findings.Count, 0)
        if ($inferidoPct -gt 50) {
            $inferidoWarnHtml = "<div class='alert alert-warn'><strong>Aviso:</strong> en mas de la mitad de estos resultados ($inferidoPct%) el usuario no viene confirmado directamente, se ha deducido de la carpeta donde estaba el fichero. Tenlo en cuenta al valorarlos.</div>"
        }
    }

    $html = [System.Text.StringBuilder]::new(120000)

    [void]$html.AppendLine(@"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Resumen facil de la consulta - Caso $($meta.CaseNumber)</title>
<style>$css</style>
</head>
<body>
<nav class="sidebar">
  <div class="sb-brand">
    <div class="sb-brand-name">MaPeriT.SC</div>
    <div class="sb-brand-sub">Resumen en lenguaje sencillo</div>
  </div>
  <div class="sb-case">
    <strong>Caso</strong>$($meta.CaseNumber)
    <strong style="margin-top:6px">Equipo</strong>$($meta.ComputerName)
  </div>
  <nav>
    <div class="sb-label">Contenido</div>
    <a href="#sec1">Que se ha buscado</a>
    <a href="#sec2">Lo que se ha encontrado</a>
    <a href="#sec3">Como leer el detalle</a>
  </nav>
  <div class="sb-footer">
    Consulta: $(Get-Date -Format 'dd/MM/yyyy HH:mm')<br>
    $($Findings.Count) resultado(s)
  </div>
</nav>
<div class="main">

<div class="cover">
  <div class="cover-badge">Resumen en lenguaje sencillo</div>
  <h1>Que se ha encontrado</h1>
  <h2>Caso $($meta.CaseNumber) &mdash; explicado sin tecnicismos</h2>
</div>

<div class="content">
<div id="sec1">
<div class="section-hdr"><div class="sec-num">1</div><h2>Que se ha buscado</h2></div>
<p>Este documento resume, en lenguaje sencillo, el resultado de una busqueda concreta dentro de toda la
informacion recogida y analizada previamente del equipo del caso <strong>$($meta.CaseNumber)</strong>.</p>
<p>Se ha buscado la actividad de <strong>$([System.Web.HttpUtility]::HtmlEncode($usuariosTxt))</strong>,
$rangoTxt$timeTxt, relacionada con: <strong>$([System.Web.HttpUtility]::HtmlEncode(($Criteria.Categorias -join ', ')))</strong>.
$(if ($Criteria.Keyword) { "Ademas, solo se ha incluido lo que menciona &laquo;<strong>$([System.Web.HttpUtility]::HtmlEncode($Criteria.Keyword))</strong>&raquo;." })
$(if ($Criteria.ExcludeKeyword) { "Se ha excluido todo lo que menciona &laquo;<strong>$([System.Web.HttpUtility]::HtmlEncode($Criteria.ExcludeKeyword))</strong>&raquo;." })</p>
<div class="alert alert-info">
  Este resumen no sustituye al informe pericial tecnico (<code>Informe_Pericial_SC.html</code>), que contiene
  la misma informacion con el formato y el lenguaje formal necesarios para un procedimiento judicial. Ambos
  documentos describen exactamente los mismos hechos. Las horas llevan indicada su zona horaria: casi todas
  estan en UTC (en Espana, una hora menos que la hora oficial en invierno y dos menos en verano).
</div>
$inferidoWarnHtml
</div>

<div id="sec2" class="page-break">
<div class="section-hdr"><div class="sec-num">2</div><h2>Lo que se ha encontrado</h2></div>
"@)

    if ($Findings.Count -eq 0) {
        [void]$html.AppendLine("<div class='alert alert-warn'>No se ha encontrado ningun registro que cumpla los criterios de busqueda indicados arriba.</div>")
    } else {
        [void]$html.AppendLine("<div class='stat-grid'><div class='stat-card'><div class='sv'>$($Findings.Count)</div><div class='sl'>Resultado(s) encontrados</div></div></div>")
        # Listado real de hallazgos en frases legibles, no solo un recuento por
        # categoria: un simple "se han encontrado 40 registros" no dice nada
        # util a un lector no tecnico. Se limita a 100 por categoria para no
        # hacer el informe inmanejable; el resto queda en el detalle tecnico
        # de la seccion 3 (misma lista completa, sin recortar).
        $grouped = $Findings | Group-Object { Get-SCCategoryForSource $_.Fuente }
        foreach ($g in $grouped) {
            $catLabel = $g.Name
            if ($catLabel -eq (Get-SCCategoryForSource 'EVTX_Procesos')) {
                $correlations = @(Get-SCProgramCorrelations -Findings $g.Group)
                if ($correlations.Count -gt 0) {
                    [void]$html.AppendLine("<div class='alert alert-info'><strong>Estos programas se confirman por varias fuentes distintas, no solo una:</strong>")
                    [void]$html.AppendLine("<ul style='margin:8px 0 0 20px'>")
                    foreach ($c in $correlations) {
                        [void]$html.AppendLine("<li><strong>$([System.Web.HttpUtility]::HtmlEncode($c.Programa))</strong> &mdash; visto por $($c.Fuentes.Count) fuentes distintas ($($c.NumRegistros) registros en total)</li>")
                    }
                    [void]$html.AppendLine("</ul></div>")
                }
            }
            [void]$html.AppendLine("<div class='sub-hdr'>$([System.Web.HttpUtility]::HtmlEncode($catLabel)) &mdash; $($g.Count) resultado(s)</div>")
            [void]$html.AppendLine("<ul style='margin:6px 0 18px 24px;line-height:1.9;font-size:13.5px'>")
            $sorted = $g.Group | Sort-Object { if ($_.Timestamp) { $_.Timestamp } else { [datetime]::MinValue } }
            $runs = Group-SCFindingRuns -SortedFindings $sorted
            $shownItems = 0
            $shownLines = 0
            foreach ($run in $runs) {
                if ($shownLines -ge 100) {
                    [void]$html.AppendLine("<li><em>&hellip; y $($g.Count - $shownItems) resultado(s) mas de esta categoria. Estan todos en el detalle tecnico de la seccion 3.</em></li>")
                    break
                }
                if ($run.Collapsed) {
                    $first = $run.Items[0]; $last = $run.Items[-1]
                    $fechaIni = if ($first.Timestamp) { $first.Timestamp.ToString("dd/MM/yyyy HH:mm") } else { "(sin fecha)" }
                    $fechaFin = if ($last.Timestamp) { $last.Timestamp.ToString("dd/MM/yyyy HH:mm") } else { "(sin fecha)" }
                    $frase = Get-SCPlainSentence -Finding $first
                    [void]$html.AppendLine("<li><strong>$fechaIni a $fechaFin</strong> &mdash; $($run.Items.Count) veces, patron similar: $([System.Web.HttpUtility]::HtmlEncode($frase))</li>")
                } else {
                    $f = $run.Items[0]
                    $fecha = if ($f.Timestamp) { $f.Timestamp.ToString("dd/MM/yyyy HH:mm") } else { "(fecha no verificada)" }
                    $frase = Get-SCPlainSentence -Finding $f
                    [void]$html.AppendLine("<li><strong>$fecha</strong> &mdash; $([System.Web.HttpUtility]::HtmlEncode($frase))</li>")
                }
                $shownItems += $run.Items.Count
                $shownLines++
            }
            [void]$html.AppendLine("</ul>")
        }
    }
    [void]$html.AppendLine("</div>")

    # ── DETALLE (misma tabla que el informe pericial) ─────────────────
    [void]$html.AppendLine(@"
<div id="sec3" class="page-break">
<div class="section-hdr"><div class="sec-num">3</div><h2>Detalle, para quien quiera comprobarlo</h2></div>
<p>Esta tabla es el detalle tecnico de cada resultado: la fecha exacta, en que parte de los datos analizados
se ha encontrado (columna &laquo;Fuente&raquo;) y la ruta del fichero donde se puede verificar (columna
&laquo;Origen&raquo;). La columna &laquo;Confianza&raquo; indica si el nombre de usuario venia registrado
directamente (<strong>Confirmado</strong>) o se ha deducido de la carpeta donde estaba el fichero
(<strong>Inferido</strong>).</p>
"@)
    $grouped2 = $Findings | Group-Object { Get-SCCategoryForSource $_.Fuente }
    foreach ($g in $grouped2) {
        Add-SCFindingsTable -Html $html -Findings @($g.Group) -Title $g.Name -Collapsible
    }
    [void]$html.AppendLine("</div>")

    [void]$html.AppendLine(@"
</div><!-- /content -->
<div class="report-footer">
  Resumen generado por <strong>MaPeriT.SC v$($Script:SC_Version)</strong> &bull;
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
