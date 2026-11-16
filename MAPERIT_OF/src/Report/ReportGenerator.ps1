#region ============================================================
# MaPeriT.OF - GENERADOR DEL INFORME PERICIAL HTML
# Mismo esquema visual que MaPeriT.SW
# ============================================================

function New-OFReport {
    param([string]$OutputPath, [string]$EvidenceDescription)

    $reportDir  = Join-Path $OutputPath $Script:OutputDirs.Report
    $reportFile = Join-Path $reportDir "InformePericial.html"

    $duration = if ($Script:OFSession.EndTime -and $Script:OFSession.StartTime) {
        ($Script:OFSession.EndTime - $Script:OFSession.StartTime).ToString('hh\:mm\:ss')
    } else { "N/A" }

    $totalSizeMB = [math]::Round($Script:OFSession.TotalSizeBytes / 1MB, 2)

    # BUG CONFIRMADO: CaseNumber/ExaminerName/TargetDisk/TargetComputer/TargetOS
    # se insertaban en el HTML sin HtmlEncode (a diferencia de EvidenceDescription,
    # que si lo tenia) - un caracter como &lt; &gt; &amp; " en cualquiera de estos
    # campos de texto libre del perito rompe la estructura del informe pericial.
    # Se codifican una sola vez aqui y se usan estas variables en todo el informe.
    $caseNumberEnc     = [System.Web.HttpUtility]::HtmlEncode($Script:OFSession.CaseNumber)
    $examinerNameEnc   = [System.Web.HttpUtility]::HtmlEncode($Script:OFSession.ExaminerName)
    $targetDiskEnc     = [System.Web.HttpUtility]::HtmlEncode($Script:OFSession.TargetDisk)
    $targetComputerEnc = [System.Web.HttpUtility]::HtmlEncode($Script:OFSession.TargetComputer)
    $targetOSEnc       = [System.Web.HttpUtility]::HtmlEncode($Script:OFSession.TargetOS)

    Write-ForensicLog -Action "GENERANDO_INFORME_OF" -Target $reportFile -Result "OK"

    $css = Get-OFCss
    $js  = Get-OFJs
    $html = [System.Text.StringBuilder]::new(200000)

    # ── HEAD ──────────────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Informe Forense Offline - Caso $caseNumberEnc</title>
<style>$css</style>
</head>
<body>
"@)

    # ── SIDEBAR ───────────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<nav class="sidebar">
  <div class="sb-brand">
    <div class="sb-brand-name">MaPeriT.OF</div>
    <div class="sb-brand-sub">Adquisicion Forense Offline v$($Script:TOOL_VERSION)</div>
  </div>
  <div class="sb-case">
    <strong>Caso</strong>$caseNumberEnc
    <strong style="margin-top:6px">Perito</strong>$examinerNameEnc
    <strong style="margin-top:6px">Disco objetivo</strong>$targetDiskEnc
  </div>
  <nav>
    <div class="sb-label">Informe</div>
    <a href="#cover">Portada</a>
    <a href="#sec1">1. Identificacion del Caso</a>
    <a href="#sec2">2. Metodologia</a>
    <a href="#sec3">3. Fases de Adquisicion</a>
    <a href="#sec4">4. Perfiles de Usuario</a>
    <a href="#sec5">5. Estadisticas</a>
    <a href="#sec6">6. Estructura de Salida</a>
    <div class="sb-label">Legal</div>
    <a href="#sec7">7. Aviso Legal</a>
  </nav>
  <div class="sb-footer">
    $((Get-Date).ToString('dd/MM/yyyy HH:mm'))<br>
    Duracion: $duration<br>
    $($Script:OFSession.TotalFiles) ficheros &middot; $totalSizeMB MB
  </div>
</nav>
<div class="main">
"@)

    # ── PORTADA ───────────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="cover" class="cover" data-sec>
  <div class="cover-badge">Informe Pericial Informatico Forense Offline</div>
  <h1>MaPeriT.OF</h1>
  <h2>Adquisicion Forense Offline &mdash; Caso $caseNumberEnc</h2>
  <div class="cover-grid">
    <div class="cover-item"><label>Numero de Caso</label><span>$caseNumberEnc</span></div>
    <div class="cover-item"><label>Perito Informatico</label><span>$examinerNameEnc</span></div>
    <div class="cover-item"><label>Fecha de Adquisicion</label><span>$($Script:OFSession.StartTime.ToString('dd/MM/yyyy'))</span></div>
    <div class="cover-item"><label>Tipo de Adquisicion</label><span>Offline (disco montado)</span></div>
    <div class="cover-item"><label>Disco Objetivo</label><span>$targetDiskEnc</span></div>
    <div class="cover-item"><label>Equipo Objetivo</label><span>$targetComputerEnc</span></div>
    <div class="cover-item"><label>SO del Disco</label><span>$targetOSEnc</span></div>
    <div class="cover-item"><label>Duracion</label><span>$duration</span></div>
  </div>
  <div class="cover-hash">
    SHA-256 herramienta: $($Script:OFSession.ScriptHash)
  </div>
  <div class="confidential">Documento Confidencial &mdash; Cadena de Custodia de Evidencias Digitales</div>
</div>

<div class="content">
"@)

    # ── SEC 1: IDENTIFICACION DEL CASO ────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec1" data-sec>
<div class="section-hdr"><div class="sec-num">1</div><h2>Identificacion del Caso</h2></div>
<table class="info-table">
  <tr><td>Numero de Caso</td><td><strong>$caseNumberEnc</strong></td></tr>
  <tr><td>Perito Informatico</td><td>$examinerNameEnc</td></tr>
  <tr><td>Fecha de Adquisicion</td><td>$($Script:OFSession.StartTime.ToString('dd/MM/yyyy HH:mm:ss'))</td></tr>
  <tr><td>Disco Objetivo</td><td>$targetDiskEnc</td></tr>
  <tr><td>SO del Disco Objetivo</td><td>$targetOSEnc</td></tr>
  <tr><td>Nombre del Equipo Objetivo</td><td>$targetComputerEnc</td></tr>
  <tr><td>Herramienta</td><td>$($Script:TOOL_FULL)</td></tr>
  <tr><td>Hash SHA-256 Herramienta</td><td style="font-family:monospace;font-size:12px;word-break:break-all">$($Script:OFSession.ScriptHash)</td></tr>
  <tr><td>Duracion Adquisicion</td><td>$duration</td></tr>
  <tr><td>Tipo de Adquisicion</td><td>Offline (disco montado en equipo forense)</td></tr>
  $(if ($EvidenceDescription) { "<tr><td>Descripcion del Encargo</td><td>$([System.Web.HttpUtility]::HtmlEncode($EvidenceDescription))</td></tr>" })
</table>
</div>
"@)

    # ── SEC 2: METODOLOGIA ────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec2" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">2</div><h2>Metodologia</h2></div>
<div class="alert alert-info">
  <strong>Adquisicion Offline:</strong> La presente adquisicion se ha realizado sobre un disco duro fisico
  montado en un equipo forense dedicado, sin arrancar el sistema operativo del disco objetivo.
  MaPeriT.OF no escribe en el disco objetivo; para garantizar su inalterabilidad frente al sistema
  operativo del equipo forense se recomienda un bloqueador de escritura.
</div>
<p>El presente analisis forense se ha realizado siguiendo las directrices establecidas en la
<strong>RFC 3227</strong> (Guidelines for Evidence Collection and Archiving) del IETF y la guia
<strong>NIST SP 800-86</strong> (Guide to Integrating Forensic Techniques into Incident Response).</p>
<p>En adquisicion offline no estan disponibles los datos volatiles (Fase 1: RAM, procesos activos,
conexiones de red). El resto de fases (2-10) se han ejecutado accediendo directamente a los ficheros
del disco objetivo.</p>
<p>Los hives del registro (SYSTEM, SOFTWARE, SAM, SECURITY, DEFAULT, NTUSER.DAT y UsrClass.dat) se han
copiado como evidencia. Para consultar sus valores se ha cargado con <code>reg load</code> una copia de
trabajo temporal, nunca el fichero original del disco objetivo. Todas las evidencias han sido
verificadas mediante hash SHA-256.</p>

<div class="sub-hdr">2.1 Herramienta Utilizada</div>
<table class="info-table">
  <tr><td>Herramienta</td><td><strong>$($Script:TOOL_FULL)</strong></td></tr>
  <tr><td>Hash SHA-256</td><td style="font-family:monospace;font-size:12px;word-break:break-all">$($Script:OFSession.ScriptHash)</td></tr>
  <tr><td>Normativa aplicada</td><td>RFC 3227 (IETF) &bull; NIST SP 800-86</td></tr>
</table>
</div>
"@)

    # ── SEC 3: FASES DE ADQUISICION ───────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec3" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">3</div><h2>Fases de Adquisicion</h2></div>
<table class="phases-table">
<thead><tr><th style="width:60px">Fase</th><th>Descripcion</th><th style="width:160px">Estado</th></tr></thead>
<tbody>
<tr><td>Fase 1</td><td>Datos Volatiles</td><td><span class="badge b-na">N/A (offline)</span></td></tr>
"@)

    # Estado REAL de cada fase (antes todas figuraban como completadas aunque se
    # hubieran omitido con -SkipPhases o hubieran terminado con error).
    foreach ($ph in 2..10) {
        $name = $Script:PhaseNames[$ph]
        if ($name) {
            $badge = if ($ph -in $Script:OFSession.PhasesSkipped) { "<span class='badge b-na'>Omitida (-SkipPhases)</span>" }
                     elseif ($ph -in $Script:OFSession.PhasesFailed) { "<span class='badge b-err'>Error (ver log)</span>" }
                     else { "<span class='badge b-ok'>&#10003; Completada</span>" }
            [void]$html.AppendLine("<tr><td>Fase $ph</td><td>$([System.Web.HttpUtility]::HtmlEncode($name))</td><td>$badge</td></tr>")
        }
    }

    [void]$html.AppendLine("</tbody></table></div>")

    # ── SEC 4: PERFILES DE USUARIO ────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec4" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">4</div><h2>Perfiles de Usuario Detectados</h2></div>
<p>Usuarios detectados en el disco objetivo mediante analisis de perfiles en <code>Users\</code>
y de los hives NTUSER.DAT. Total: <strong>$($Script:OFSession.ProcessedUsers.Count)</strong> perfil(es).</p>
<table class="info-table">
"@)

    foreach ($u in $Script:OFSession.ProcessedUsers) {
        [void]$html.AppendLine("<tr><td>Usuario</td><td>$([System.Web.HttpUtility]::HtmlEncode($u))</td></tr>")
    }

    [void]$html.AppendLine("</table></div>")

    # ── SEC 5: ESTADISTICAS ───────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec5" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">5</div><h2>Estadisticas de Adquisicion</h2></div>
<div class="stat-grid">
  <div class="stat-card ok">
    <div class="sv">$($Script:OFSession.TotalFiles)</div>
    <div class="sl">Ficheros Recopilados</div>
  </div>
  <div class="stat-card">
    <div class="sv">$totalSizeMB MB</div>
    <div class="sl">Volumen Total</div>
  </div>
  <div class="stat-card">
    <div class="sv">$($Script:ChainOfCustody.Count)</div>
    <div class="sl">Entradas Cadena Custodia</div>
  </div>
  <div class="stat-card $(if($Script:OFSession.Errors -gt 0){'err'}else{'ok'})">
    <div class="sv">$($Script:OFSession.Errors)</div>
    <div class="sl">Errores</div>
  </div>
  <div class="stat-card $(if($Script:OFSession.Warnings -gt 0){'warn'}else{'ok'})">
    <div class="sv">$($Script:OFSession.Warnings)</div>
    <div class="sl">Advertencias</div>
  </div>
</div>
</div>
"@)

    # ── SEC 6: ESTRUCTURA DE SALIDA ───────────────────────────────────────
    $caseName = [System.Web.HttpUtility]::HtmlEncode((Split-Path $OutputPath -Leaf))
    [void]$html.AppendLine(@"
<div id="sec6" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">6</div><h2>Estructura de Salida</h2></div>
<p>OF genera una carpeta con la misma organizacion por fases que MaPeriT.SW, compatible con MaPeriT.AN
y MaPeriT.TN:</p>
<div class="dir-tree"><span class="folder">$caseName\</span>
&#9500;&#9472;&#9472; <span class="folder">01_Volatile\</span>         (nota: N/A en adquisicion offline)
&#9500;&#9472;&#9472; <span class="folder">02_SystemInfo\</span>
&#9500;&#9472;&#9472; <span class="folder">03_Filesystem\</span>
&#9474;   &#9500;&#9472;&#9472; <span class="file">&#36;MFT, Amcache.hve</span>
&#9474;   &#9492;&#9472;&#9472; <span class="folder">Prefetch\</span>
&#9500;&#9472;&#9472; <span class="folder">04_Registry\</span>
&#9474;   &#9492;&#9472;&#9472; <span class="folder">Hives\</span>
&#9500;&#9472;&#9472; <span class="folder">05_EventLogs\</span>
&#9500;&#9472;&#9472; <span class="folder">06_Browsers\</span>
&#9500;&#9472;&#9472; <span class="folder">07_Communications\</span>
&#9500;&#9472;&#9472; <span class="folder">08_CloudStorage\</span>
&#9500;&#9472;&#9472; <span class="folder">09_USB\</span>
&#9500;&#9472;&#9472; <span class="folder">10_Persistence\</span>
&#9500;&#9472;&#9472; <span class="folder">Analysis\</span>
&#9500;&#9472;&#9472; <span class="folder">Logs\</span>
&#9474;   &#9492;&#9472;&#9472; <span class="file">ForensicLog.csv</span>
&#9500;&#9472;&#9472; <span class="folder">Report\</span>
&#9474;   &#9492;&#9472;&#9472; <span class="highlight-file">InformePericial.html</span>
&#9492;&#9472;&#9472; <span class="highlight-file">HashManifest.csv</span></div>
<div class="alert alert-info">MaPeriT.AN y MaPeriT.TN pueden apuntar directamente a esta carpeta. La Fase 1
incluye una nota explicativa porque en una adquisicion offline no hay datos volatiles.</div>
</div>
"@)

    # ── SEC 7: AVISO LEGAL ────────────────────────────────────────────────
    $dateStr = (Get-Date).ToString("dd 'de' MMMM 'de' yyyy")
    [void]$html.AppendLine(@"
<div id="sec7" data-sec class="page-break">
<div class="section-hdr"><div class="sec-num">7</div><h2>Aviso Legal</h2></div>
<div class="alert alert-warn">
  <strong>AVISO LEGAL:</strong> El uso de esta herramienta debe estar autorizado por el propietario
  del equipo o por orden judicial. Todas las operaciones realizadas son de SOLO LECTURA sobre el
  disco objetivo. El uso no autorizado puede constituir un delito conforme a la legislacion vigente.
</div>
<p>Todas las evidencias han sido adquiridas siguiendo las directrices de la RFC 3227 y NIST SP 800-86,
manteniendo la cadena de custodia documentada y verificada mediante hashes SHA-256. La integridad
puede ser verificada en cualquier momento mediante el manifiesto incluido.</p>

<div class="sig-grid">
  <div class="sig-item">
    <div class="sig-line">En _______________________, a $dateStr<br><br>$examinerNameEnc<br><em>Perito Informatico</em></div>
  </div>
  <div class="sig-item">
    <div class="sig-line">Recibido: ___________________<br><br>&nbsp;<br><em>Firma y sello</em></div>
  </div>
</div>
</div>

</div><!-- /content -->

<div class="report-footer">
  Informe generado por <strong>$($Script:TOOL_FULL)</strong><br>
  Caso: $caseNumberEnc &bull; Perito: $examinerNameEnc &bull; Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')<br>
  Hash herramienta: <code style="font-size:10px">$($Script:OFSession.ScriptHash)</code>
</div>

</div><!-- /main -->
<script>$js</script>
</body>
</html>
"@)

    $html.ToString() | Out-File -FilePath $reportFile -Encoding UTF8 -Force
    Write-ForensicLog -Action "INFORME_OF_GENERADO" -Target "InformePericial.html" -Result "OK"
    return $reportFile
}
