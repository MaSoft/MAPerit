#region ============================================================
# MaPeriT.SW - GENERADOR DEL INFORME PERICIAL HTML
# ============================================================

function New-ForensicReport {
    param([string]$OutputPath)

    $reportPath = Join-Path $OutputPath $Script:OutputDirs.Report
    $reportFile = Join-Path $reportPath "InformePericial.html"
    $duration   = if ($Script:SessionInfo.EndTime) {
                      ($Script:SessionInfo.EndTime - $Script:SessionInfo.StartTime).ToString('hh\:mm\:ss')
                  } else { "En curso" }

    Write-ForensicLog -Phase "INFORME" -Action "GENERANDO_INFORME" -Target $reportFile
    $css = Get-ReportCSS
    $js  = Get-ReportJS
    $S   = $Script:ReportStrings

    # Campos que provienen de entrada de linea de comandos del perito (CaseNumber,
    # ExaminerName) o de datos del equipo analizado (ComputerName, Domain, OSVersion,
    # ScriptPath) y se interpolan en HTML: deben ir siempre codificados. El resto del
    # informe (tablas CSV/JSON, anomalias) ya usaba HtmlEncode de forma consistente;
    # estos campos de cabecera/portada/pie eran la unica excepcion.
    $caseNumberEnc   = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.CaseNumber)
    $examinerNameEnc = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.ExaminerName)
    $computerNameEnc = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.ComputerName)
    $domainEnc       = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.Domain)
    $osVersionEnc    = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.OSVersion)
    $osBuildEnc      = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.OSBuild)
    $scriptPathEnc   = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.ScriptPath)
    $outputPathEnc   = [System.Web.HttpUtility]::HtmlEncode($OutputPath)

    $html = [System.Text.StringBuilder]::new(600000)

    # ── Contar evidencias y anomalías ──────────────────────────────────────
    $totalFiles   = (Get-ChildItem (Join-Path $OutputPath "*") -Recurse -File -ErrorAction SilentlyContinue |
                      Where-Object { $_.DirectoryName -notlike "*Report*" }).Count
    $totalSizeMB  = [math]::Round(
        (Get-ChildItem (Join-Path $OutputPath "*") -Recurse -File -ErrorAction SilentlyContinue |
         Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    $anomalyFile  = Join-Path $OutputPath "$($Script:OutputDirs.Analysis)\Anomalies.json"
    $anomalyCount = 0; $criticalCount = 0; $highCount = 0
    if (Test-Path $anomalyFile) {
        # Dos pasos (no @(... | ConvertFrom-Json)): en PowerShell 5.1 ConvertFrom-Json
        # emite un array JSON como UN objeto y @() lo anidaria. @($x) sobre la
        # variable ya asignada si da el recuento correcto, tambien con un unico
        # elemento (antes una sola anomalia contaba como 0).
        $aData = Get-Content $anomalyFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        $aData = @($aData | Where-Object { $_ })
        if ($aData.Count -gt 0) {
            $anomalyCount  = $aData.Count
            $criticalCount = @($aData | Where-Object { $_.Severidad -eq $Script:AnomalySeverity.Critical }).Count
            $highCount     = @($aData | Where-Object { $_.Severidad -eq $Script:AnomalySeverity.High }).Count
        }
    }

    # ── HTML head ──────────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Informe Pericial - Caso $caseNumberEnc</title>
<style>$css</style>
</head>
<body>
"@)

    # ── SIDEBAR ────────────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<nav class="sidebar">
  <div class="sb-brand">
    <div class="sb-brand-name">$($Script:TOOL_NAME)</div>
    <div class="sb-brand-sub">Peritacion Forense v$($Script:TOOL_VERSION)</div>
  </div>
  <div class="sb-case">
    <strong>Caso</strong>$caseNumberEnc
    <strong style="margin-top:6px">Perito</strong>$examinerNameEnc
    <strong style="margin-top:6px">Equipo</strong>$computerNameEnc
  </div>
  <nav>
    <div class="sb-label">Informe</div>
    <a href="#cover">Portada</a>
    <a href="#sec1">1. Resumen Ejecutivo</a>
    <a href="#sec2">2. Metodologia</a>
    <a href="#sec3">3. Cadena de Custodia</a>
    <a href="#sec4">4. Identificacion del Sistema</a>
    <div class="sb-label">Hallazgos</div>
    <a href="#sec5">5. Evidencias Recopiladas</a>
    <a href="#sec6">6. Hallazgos</a>
    <a href="#sec7">7. Linea Temporal</a>
    <a href="#sec8">8. Anomalias $(if($criticalCount -gt 0){"($criticalCount criticas)"})</a>
    <div class="sb-label">Cierre</div>
    <a href="#sec9">9. Conclusiones</a>
    <a href="#sec10">10. Anexos</a>
  </nav>
  <div class="sb-footer">
    $($Script:SessionInfo.StartTime.ToString('dd/MM/yyyy HH:mm'))<br>
    Duracion: $duration<br>
    $totalFiles ficheros &middot; $totalSizeMB MB
  </div>
</nav>
<div class="main">
"@)

    # ── PORTADA ────────────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="cover" class="cover" data-sec>
  <div class="cover-badge">Informe Pericial Informatico</div>
  <h1>$($S.Title)</h1>
  <h2>$($S.Subtitle)</h2>
  <div class="cover-grid">
    <div class="cover-item"><label>Numero de Caso</label><span>$caseNumberEnc</span></div>
    <div class="cover-item"><label>Perito</label><span>$examinerNameEnc</span></div>
    <div class="cover-item"><label>Fecha de Analisis</label><span>$($Script:SessionInfo.StartTime.ToString('dd/MM/yyyy'))</span></div>
    <div class="cover-item"><label>Equipo Analizado</label><span>$computerNameEnc</span></div>
    <div class="cover-item"><label>Sistema Operativo</label><span>$osVersionEnc</span></div>
    <div class="cover-item"><label>Duracion</label><span>$duration</span></div>
    <div class="cover-item"><label>Evidencias</label><span>$($Script:SessionInfo.TotalEvidences)</span></div>
    <div class="cover-item"><label>Anomalias</label><span>$anomalyCount$(if($criticalCount -gt 0){" ($criticalCount criticas)"})</span></div>
  </div>
  <div class="cover-hash">
    SHA-256 herramienta: $($Script:SessionInfo.ScriptHash)
  </div>
  <div class="confidential">Documento Confidencial &mdash; Cadena de Custodia de Evidencias Digitales</div>
</div>

<div class="content">
"@)

    # ── SEC 1: RESUMEN EJECUTIVO ───────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec1" data-sec>
<div class="section-hdr"><div class="sec-num">1</div><h2>$($S.ExecutiveSummary)</h2></div>

<p>Se ha realizado un analisis forense informatico completo del equipo <strong>$computerNameEnc</strong>
(SO: $osVersionEnc, Build $osBuildEnc, Dominio: <strong>$domainEnc</strong>).</p>
<p>Analisis iniciado el <strong>$($Script:SessionInfo.StartTime.ToString('dd/MM/yyyy a las HH:mm:ss'))</strong>
y finalizado el <strong>$(if($Script:SessionInfo.EndTime){$Script:SessionInfo.EndTime.ToString('dd/MM/yyyy a las HH:mm:ss')}else{'En curso'})</strong>
&mdash; duracion total: <strong>$duration</strong>.</p>

<div class="stat-grid">
  <div class="stat-card ok">
    <div class="sv">$($Script:SessionInfo.TotalEvidences)</div>
    <div class="sl">Evidencias Recopiladas</div>
  </div>
  <div class="stat-card">
    <div class="sv">$totalFiles</div>
    <div class="sl">Ficheros Generados</div>
  </div>
  <div class="stat-card">
    <div class="sv">$totalSizeMB MB</div>
    <div class="sl">Volumen Total</div>
  </div>
  <div class="stat-card $(if($criticalCount -gt 0){'crit'}elseif($anomalyCount -gt 0){'warn'}else{'ok'})">
    <div class="sv">$anomalyCount</div>
    <div class="sl">Anomalias$(if($criticalCount -gt 0){" &bull; $criticalCount CRITICAS"}elseif($highCount -gt 0){" &bull; $highCount ALTAS"})</div>
  </div>
</div>

$(if ($Script:ChainOfCustodyStrictMode -and $Script:StrictCustodyFailures -and $Script:StrictCustodyFailures.Count -gt 0) {
@"
<div class="alert alert-crit">
  <strong>CHEQUEO FINAL DE INTEGRIDAD: FALLIDO</strong> (-ChainOfCustodyStrictMode) &mdash;
  $($Script:StrictCustodyFailures.Count) evidencia(s) quedaron con un hash SHA-256 no valido
  tras la copia. Revise las entradas marcadas <code>INVALIDO:</code> en
  <strong>Logs\ChainOfCustody.csv</strong> antes de dar la adquisicion por concluida.
</div>
"@
})
$(if ($Script:HivesNoDesmontadas -and $Script:HivesNoDesmontadas.Count -gt 0) {
@"
<div class="alert alert-crit">
  <strong>AVISO: EL EQUIPO ANALIZADO HA QUEDADO MODIFICADO</strong> &mdash;
  $($Script:HivesNoDesmontadas.Count) clave(s) de registro de usuario montadas temporalmente
  para la Fase 4 no se pudieron desmontar y siguen cargadas en <code>HKEY_USERS</code> del
  equipo analizado. Debe desmontarlas manualmente (<code>reg unload &lt;clave&gt;</code>)
  antes de devolver o reiniciar el equipo. Vea el log de ejecucion (Accion
  HIVE_DESMONTAR_FALLO_PERMANENTE) para el detalle de las claves afectadas.
</div>
"@
})

<p>Se ejecutaron las 10 fases de adquisicion siguiendo el orden de volatilidad RFC 3227.
<strong>$($Script:SessionInfo.PhasesCompleted.Count)</strong> fases se completaron satisfactoriamente$(
if($Script:SessionInfo.PhasesFailed.Count -gt 0){
    ", <strong>$($Script:SessionInfo.PhasesFailed.Count)</strong> fases con errores parciales (los datos se recopilaron igualmente)"
}).</p>
</div>
"@)

    # ── SEC 2: METODOLOGIA ─────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec2" data-sec>
<div class="section-hdr"><div class="sec-num">2</div><h2>$($S.Methodology)</h2></div>
<p>$($S.MethodologyText)</p>

<div class="sub-hdr">2.1 Herramienta Utilizada</div>
<table class="info-table">
  <tr><td>Herramienta</td><td><strong>$($Script:SessionInfo.ToolName) v$($Script:SessionInfo.ToolVersion)</strong></td></tr>
  <tr><td>Hash SHA-256</td><td style="font-family:monospace;font-size:12px;word-break:break-all">$($Script:SessionInfo.ScriptHash)</td></tr>
  <tr><td>PowerShell</td><td>$($Script:SessionInfo.PSVersion)</td></tr>
  <tr><td>Ruta del script</td><td style="word-break:break-all">$scriptPathEnc</td></tr>
  <tr><td>Normativa aplicada</td><td>RFC 3227 (IETF) &bull; NIST SP 800-86</td></tr>
</table>

<div class="sub-hdr">2.2 Fases de Adquisicion</div>
<table class="phases-table">
<thead><tr><th style="width:60px">Fase</th><th>Descripcion</th><th style="width:140px">Estado</th></tr></thead>
<tbody>
"@)

    for ($i = 1; $i -le 10; $i++) {
        $status = if ($i -in $Script:SessionInfo.PhasesCompleted) { '<span class="badge b-ok">Completada</span>' }
                  elseif ($i -in $Script:SessionInfo.PhasesFailed) { '<span class="badge b-err">Error parcial</span>' }
                  elseif ($i -in $Script:SessionInfo.PhasesSkipped) { '<span class="badge b-skip">Omitida</span>' }
                  else { '<span class="badge b-info">N/A</span>' }
        [void]$html.AppendLine("<tr><td>Fase $i</td><td>$($Script:PhaseNames[$i])</td><td>$status</td></tr>")
    }
    [void]$html.AppendLine("</tbody></table></div>")

    # ── SEC 3: CADENA DE CUSTODIA ──────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec3" data-sec>
<div class="section-hdr"><div class="sec-num">3</div><h2>$($S.ChainOfCustody)</h2></div>
<p>La cadena de custodia completa esta documentada en <strong>CadenaCustodia.html</strong>.
Se verificaron con SHA-256 un total de <strong>$($Script:SessionInfo.TotalEvidences)</strong> evidencias en el momento de su adquisicion.</p>
<div class="alert alert-info">El manifiesto completo de hashes se encuentra en <strong>Logs\HashManifest.csv</strong>.
Para verificar la integridad en cualquier momento: <code>.\MaPeriT.SW.ps1 -VerifyPath "$outputPathEnc"</code></div>
</div>
"@)

    # ── SEC 4: IDENTIFICACION DEL SISTEMA ─────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec4" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">4</div><h2>$($S.SystemID)</h2></div>
"@)
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.SystemInfo)\OSInfo.json"       -Title "4.1 Sistema Operativo"        -Type "json-table"
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.SystemInfo)\HardwareInventory.json" -Title "4.2 Hardware"            -Type "json-summary"
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.SystemInfo)\LocalUsers.csv"    -Title "4.3 Usuarios Locales"         -Type "csv" -MaxRows 30
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.SystemInfo)\IPAddresses.csv"   -Title "4.4 Configuracion de Red"     -Type "csv" -MaxRows 20
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.SystemInfo)\BitLocker.json"    -Title "4.5 Estado BitLocker"         -Type "json-table"
    [void]$html.AppendLine("</div>")

    # ── SEC 5: EVIDENCIAS RECOPILADAS ──────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec5" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">5</div><h2>$($S.CollectedEvidence)</h2></div>
<table class="phases-table">
<thead><tr><th>Directorio</th><th style="width:100px;text-align:right">Ficheros</th><th style="width:100px;text-align:right">Tamano</th></tr></thead>
<tbody>
"@)
    foreach ($d in ($Script:OutputDirs.GetEnumerator() | Sort-Object Value)) {
        $dp    = Join-Path $OutputPath $d.Value
        if (-not (Test-Path $dp)) { continue }
        $files = Get-ChildItem $dp -Recurse -File -ErrorAction SilentlyContinue
        $mb    = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        [void]$html.AppendLine("<tr><td><code>$($d.Value)/</code></td><td style='text-align:right'>$($files.Count)</td><td style='text-align:right'>$mb MB</td></tr>")
    }
    [void]$html.AppendLine("</tbody></table></div>")

    # ── SEC 6: HALLAZGOS ───────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec6" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">6</div><h2>$($S.Findings)</h2></div>
"@)
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.EventLogs)\Analysis\SecurityLogon.csv"       -Title "6.1 Inicios de Sesion"              -Type "csv" -MaxRows 50
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.EventLogs)\Analysis\SecurityFailedLogon.csv" -Title "6.2 Intentos Fallidos de Sesion"    -Type "csv" -MaxRows 50
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Volatile)\NetworkConnections_TCP.csv"        -Title "6.3 Conexiones de Red (TCP)"        -Type "csv" -MaxRows 50
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.SystemInfo)\InstalledSoftware.csv"           -Title "6.4 Software Instalado"             -Type "csv" -MaxRows 100
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.USB)\USBDevices.csv"                         -Title "6.5 Dispositivos USB"               -Type "csv"
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Browsers)\BrowserSummary.csv"               -Title "6.6 Navegadores Web"                -Type "csv"
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Communications)\OutlookFiles.csv"            -Title "6.7 Ficheros de Correo"             -Type "csv"
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.CloudStorage)\CloudStorageSummary.csv"       -Title "6.8 Almacenamiento en la Nube"      -Type "csv"
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Persistence)\AutorunsConsolidated.csv"       -Title "6.9 Mecanismos de Persistencia"     -Type "csv" -MaxRows 50
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Registry)\ExtractedValues\UserAssist.csv"    -Title "6.10 Programas Ejecutados (UserAssist)" -Type "csv" -MaxRows 50
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Registry)\ExtractedValues\BAM_DAM.csv"       -Title "6.11 Actividad BAM/DAM"             -Type "csv" -MaxRows 50
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Registry)\ExtractedValues\RDPHistory.csv"    -Title "6.12 Historial RDP"                 -Type "csv"
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Persistence)\WMIPersistence.csv"            -Title "6.13 Persistencia WMI"              -Type "csv"
    [void]$html.AppendLine("</div>")

    # ── SEC 7: LINEA TEMPORAL ──────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec7" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">7</div><h2>$($S.Timeline)</h2></div>
<p>Timeline unificada de multiples fuentes (logs de eventos, registro, prefetch, papelera, USB, etc.) en orden cronologico.</p>
"@)
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Analysis)\Timeline_Last7Days.csv" -Title "7.1 Ultimos 7 Dias" -Type "csv" -MaxRows 200
    [void]$html.AppendLine("<p class='alert alert-info'>Timeline completa: <strong>Analysis\Timeline.csv</strong></p></div>")

    # ── SEC 8: ANOMALIAS ───────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec8" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">8</div><h2>$($S.Anomalies)</h2></div>
"@)
    if (Test-Path $anomalyFile) {
        $anomalies = Get-Content $anomalyFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        $anomalies = @($anomalies | Where-Object { $_ })
        if ($anomalies.Count -gt 0) {
            $sorted = $anomalies | Sort-Object { switch($_.Severidad){'CRITICA'{0}'ALTA'{1}'MEDIA'{2}'BAJA'{3}default{4}} }
            foreach ($a in $sorted) {
                $sevClass = switch ($a.Severidad) {'CRITICA'{'sc'}'ALTA'{'sh'}'MEDIA'{'sm'}'BAJA'{'sl'}default{''}}
                $titleEnc = [System.Web.HttpUtility]::HtmlEncode($a.Titulo)
                $descEnc  = [System.Web.HttpUtility]::HtmlEncode($a.Descripcion)
                $recEnc   = [System.Web.HttpUtility]::HtmlEncode($a.Recomendacion)
                $catEnc   = [System.Web.HttpUtility]::HtmlEncode($a.Categoria)
                [void]$html.AppendLine(@"
<div class="anom-card $sevClass">
  <div class="anom-hdr">
    <span class="sev $($a.Severidad)">$($a.Severidad)</span>
    <span class="anom-id">$($a.ID)</span>
    <span class="anom-title">$titleEnc</span>
  </div>
  <div class="anom-body">
    <p><strong>Categoria:</strong> $catEnc</p>
    <p>$descEnc</p>
    <p><strong>Recomendacion:</strong> $recEnc</p>
  </div>
</div>
"@)
            }
        } else {
            [void]$html.AppendLine("<div class='alert alert-ok'>No se detectaron anomalias significativas.</div>")
        }
    } else {
        [void]$html.AppendLine("<p>Fichero de anomalias no encontrado.</p>")
    }
    [void]$html.AppendLine("</div>")

    # ── SEC 9: CONCLUSIONES ────────────────────────────────────────────────
    $dateStr = "$($Script:SessionInfo.StartTime.ToString('dd')) de $($Script:SessionInfo.StartTime.ToString('MMMM')) de $($Script:SessionInfo.StartTime.ToString('yyyy'))"
    [void]$html.AppendLine(@"
<div id="sec9" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">9</div><h2>$($S.Conclusions)</h2></div>
<p>Tras la realizacion del analisis forense informatico del equipo <strong>$computerNameEnc</strong>,
se han recopilado y verificado un total de <strong>$($Script:SessionInfo.TotalEvidences)</strong> evidencias digitales,
generando <strong>$totalFiles</strong> ficheros con un volumen total de <strong>$totalSizeMB MB</strong>.</p>

<p>El motor de deteccion automatica ha identificado <strong>$anomalyCount anomalias</strong>$(
if($criticalCount -gt 0){
    ", de las cuales <strong>$criticalCount son de severidad CRITICA</strong> y requieren atencion inmediata"
}elseif($highCount -gt 0){
    ", de las cuales <strong>$highCount son de severidad ALTA</strong>"
}).</p>

<p>Todas las evidencias han sido adquiridas siguiendo las directrices de la RFC 3227 y NIST SP 800-86,
manteniendo la cadena de custodia documentada y verificada mediante hashes SHA-256.
La integridad puede ser verificada en cualquier momento mediante el manifiesto incluido.</p>

<p>El presente informe se emite a los efectos oportunos, quedando a disposicion del solicitante
para cuantas aclaraciones sean necesarias.</p>

<div class="sig-grid">
  <div class="sig-item">
    <div class="sig-line">En _______________________, a $dateStr<br><br>$examinerNameEnc<br><em>Perito Informatico</em></div>
  </div>
  <div class="sig-item">
    <div class="sig-line">Recibido: ___________________<br><br>&nbsp;<br><em>Firma y sello</em></div>
  </div>
</div>
</div>
"@)

    # ── SEC 10: ANEXOS ─────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec10" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">10</div><h2>$($S.Appendices)</h2></div>
"@)
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Volatile)\Processes.csv"                       -Title "Anexo A: Procesos en Ejecucion"          -Type "csv" -MaxRows 200 -Collapsible
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.SystemInfo)\Services.csv"                       -Title "Anexo B: Servicios de Windows"           -Type "csv" -MaxRows 200 -Collapsible
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.EventLogs)\Analysis\SystemShutdowns.csv"        -Title "Anexo C: Arranques y Apagados"           -Type "csv" -MaxRows 100 -Collapsible
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.EventLogs)\Analysis\PowerShellScripts.csv"      -Title "Anexo D: Scripts PowerShell Ejecutados"  -Type "csv" -MaxRows 100 -Collapsible
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.EventLogs)\Analysis\DefenderEvents.csv"         -Title "Anexo E: Eventos Windows Defender"       -Type "csv" -MaxRows 100 -Collapsible
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Registry)\ExtractedValues\USBSTORDevices.csv"   -Title "Anexo F: Historial USB (USBSTOR)"        -Type "csv" -MaxRows 100 -Collapsible
    Add-ReportSection -Html $html -OutputPath $OutputPath -DataFile "$($Script:OutputDirs.Persistence)\COMHijacking.csv"                  -Title "Anexo G: Entradas COM en HKCU"          -Type "csv" -MaxRows 100 -Collapsible
    [void]$html.AppendLine("</div>")

    # ── FOOTER ─────────────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
</div><!-- /content -->

<div class="report-footer">
  Informe generado por <strong>$($Script:TOOL_FULL) v$($Script:TOOL_VERSION)</strong><br>
  Caso: $caseNumberEnc &bull; Perito: $examinerNameEnc &bull; Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')<br>
  Hash herramienta: <code style="font-size:10px">$($Script:SessionInfo.ScriptHash)</code>
</div>

</div><!-- /main -->
<script>$js</script>
</body>
</html>
"@)

    $html.ToString() | Out-File -FilePath $reportFile -Encoding UTF8
    Write-ForensicLog -Phase "INFORME" -Action "INFORME_GENERADO" -Target $reportFile -Result "OK"
}

# ── Helper: sección de datos ───────────────────────────────────────────────
function Add-ReportSection {
    param(
        [System.Text.StringBuilder]$Html,
        [string]$OutputPath,
        [string]$DataFile,
        [string]$Title,
        [string]$Type    = "csv",
        [int]$MaxRows    = 100,
        [switch]$Collapsible
    )

    $filePath = Join-Path $OutputPath $DataFile
    $safeId   = "t_" + ($Title -replace '[^a-zA-Z0-9]','_')

    if ($Collapsible) {
        [void]$Html.AppendLine("<details><summary>$([System.Web.HttpUtility]::HtmlEncode($Title))</summary><div class='det-body'>")
    } else {
        [void]$Html.AppendLine("<div class='sub-hdr'>$([System.Web.HttpUtility]::HtmlEncode($Title))</div>")
    }

    if (-not (Test-Path $filePath)) {
        [void]$Html.AppendLine("<p><em style='color:#94a3b8'>Sin datos disponibles.</em></p>")
        if ($Collapsible) { [void]$Html.AppendLine("</div></details>") }
        return
    }

    try {
        switch ($Type) {

            "csv" {
                $data = @(Import-Csv $filePath -ErrorAction Stop | Select-Object -First $MaxRows)
                if ($data.Count -eq 0) {
                    [void]$Html.AppendLine("<p><em style='color:#94a3b8'>Sin registros.</em></p>")
                } else {
                    $cols    = $data[0].PSObject.Properties.Name
                    $totalInFile = @(Import-Csv $filePath -ErrorAction SilentlyContinue).Count
                    $showSearch  = $totalInFile -gt 15
                    $searchId    = $safeId + "_s"
                    $tableId     = $safeId + "_tbl"

                    [void]$Html.AppendLine("<div class='tcard'>")
                    [void]$Html.AppendLine("<div class='ttoolbar'>")
                    [void]$Html.AppendLine("  <span class='ttoolbar-label'>$($data.Count) / $totalInFile registros</span>")
                    if ($showSearch) {
                        [void]$Html.AppendLine("  <input class='tsearch' id='$searchId' type='text' placeholder='Filtrar...' oninput=""filterTable('$searchId','$tableId')"">")
                    }
                    [void]$Html.AppendLine("</div>")
                    [void]$Html.AppendLine("<div class='twrap'>")
                    [void]$Html.AppendLine("<table class='dtable' id='$tableId'><thead><tr>")
                    foreach ($col in $cols) {
                        [void]$Html.AppendLine("<th>$([System.Web.HttpUtility]::HtmlEncode($col))</th>")
                    }
                    [void]$Html.AppendLine("</tr></thead><tbody>")

                    # Detectar columnas que merecen clase especial
                    $monoCols = @('Hash','SHA256','SHA-256','MD5','HMAC','Hash_SHA256')
                    $wrapCols = @('Path','Ruta','Descripcion','Description','CommandLine','Actions','Command')

                    foreach ($row in $data) {
                        [void]$Html.Append("<tr>")
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
                    [void]$Html.AppendLine("</tbody></table>")
                    [void]$Html.AppendLine("</div>")
                    if ($totalInFile -gt $MaxRows) {
                        [void]$Html.AppendLine("<div class='tnote'>Mostrando $MaxRows de $totalInFile registros. Fichero completo: $DataFile</div>")
                    }
                    [void]$Html.AppendLine("</div>")
                }
            }

            "json-table" {
                $data = Get-Content $filePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                [void]$Html.AppendLine("<table class='info-table'>")
                $data.PSObject.Properties | ForEach-Object {
                    $val = if ($_.Value -is [System.Array] -or $_.Value -is [PSCustomObject]) {
                        ($_.Value | ConvertTo-Json -Depth 2 -Compress)
                    } else { $_.Value }
                    [void]$Html.AppendLine("<tr><td>$([System.Web.HttpUtility]::HtmlEncode($_.Name))</td><td>$([System.Web.HttpUtility]::HtmlEncode($val.ToString()))</td></tr>")
                }
                [void]$Html.AppendLine("</table>")
            }

            "json-summary" {
                $data = Get-Content $filePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                [void]$Html.AppendLine("<table class='info-table'>")
                $data.PSObject.Properties |
                    Where-Object { $_.Value -isnot [System.Array] -and $_.Value -isnot [PSCustomObject] } |
                    ForEach-Object {
                        [void]$Html.AppendLine("<tr><td>$([System.Web.HttpUtility]::HtmlEncode($_.Name))</td><td>$([System.Web.HttpUtility]::HtmlEncode($_.Value.ToString()))</td></tr>")
                    }
                [void]$Html.AppendLine("</table>")
            }
        }
    } catch {
        [void]$Html.AppendLine("<div class='alert alert-warn'>Error al leer ${DataFile}: $([System.Web.HttpUtility]::HtmlEncode($_.Exception.Message))</div>")
    }

    if ($Collapsible) { [void]$Html.AppendLine("</div></details>") }
}

# Alias de compatibilidad (por si algo llama Add-ReportDataSection)
function Add-ReportDataSection {
    param(
        [System.Text.StringBuilder]$Html,
        [string]$OutputPath,
        [string]$DataFile,
        [string]$Title,
        [string]$Type    = "csv",
        [int]$MaxRows    = 100,
        [string]$TableClass = "",
        [switch]$Collapsible
    )
    Add-ReportSection -Html $Html -OutputPath $OutputPath -DataFile $DataFile -Title $Title -Type $Type -MaxRows $MaxRows -Collapsible:$Collapsible
}
