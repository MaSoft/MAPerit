#region ============================================================
# MaPeriT.SW - CADENA DE CUSTODIA
# ============================================================

function New-ChainOfCustodyReport {
    param([string]$OutputPath)

    $reportPath = Join-Path $OutputPath $Script:OutputDirs.Report
    $custodyFile = Join-Path $OutputPath "$($Script:OutputDirs.Logs)\ChainOfCustody.csv"

    if (-not (Test-Path $custodyFile)) {
        Write-ForensicLog -Phase "INFORME" -Action "CUSTODIA_SIN_DATOS" -Target $custodyFile -Result "WARNING"
        return
    }

    $custodyData = @(Import-Csv $custodyFile -ErrorAction SilentlyContinue)
    $totalEvidences = $custodyData.Count

    # Campos de entrada del perito (CaseNumber, ExaminerName, EvidenceDescription) o del
    # equipo analizado (ComputerName, OSVersion/Build) interpolados en HTML: deben ir
    # codificados igual que ya se hace en la tabla de evidencias mas abajo.
    $caseNumberEnc   = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.CaseNumber)
    $examinerNameEnc = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.ExaminerName)
    $evidenceDescEnc = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.EvidenceDescription)
    $computerNameEnc = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.ComputerName)
    $osVersionEnc    = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.OSVersion)
    $osBuildEnc      = [System.Web.HttpUtility]::HtmlEncode($Script:SessionInfo.OSBuild)

    $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Cadena de Custodia - Caso $caseNumberEnc</title>
<style>
    @page { size: A4; margin: 2cm; }
    @media print { .no-print { display: none; } body { font-size: 10pt; } }
    body { font-family: 'Georgia', 'Times New Roman', serif; color: #1a1a1a; margin: 0; padding: 20px; background: #fff; line-height: 1.4; }
    .header { text-align: center; border: 3px double #333; padding: 20px; margin-bottom: 30px; }
    .header h1 { font-size: 22px; margin: 0; letter-spacing: 2px; }
    .header h2 { font-size: 16px; margin: 5px 0; color: #555; font-weight: normal; }
    .confidential { background: #fee; border: 1px solid #c00; padding: 8px; text-align: center; font-weight: bold; color: #c00; margin: 15px 0; font-size: 12px; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    .info-table td { padding: 8px 12px; border: 1px solid #ccc; }
    .info-table td:first-child { background: #f5f5f5; font-weight: bold; width: 200px; }
    .evidence-table { width: 100%; border-collapse: collapse; margin: 20px 0; font-size: 9pt; }
    .evidence-table th { background: #2c3e50; color: white; padding: 8px 6px; text-align: left; font-size: 9pt; }
    .evidence-table td { padding: 6px; border: 1px solid #ddd; word-break: break-all; }
    .evidence-table tr:nth-child(even) { background: #f9f9f9; }
    .evidence-table tr:hover { background: #eef; }
    .section-title { background: #2c3e50; color: white; padding: 10px 15px; margin: 25px 0 10px 0; font-size: 14px; }
    .signatures { margin-top: 50px; page-break-inside: avoid; }
    .sig-row { display: flex; justify-content: space-between; margin-top: 40px; }
    .sig-block { width: 45%; text-align: center; }
    .sig-line { border-top: 1px solid #333; margin-top: 50px; padding-top: 5px; }
    .footer { text-align: center; font-size: 9px; color: #888; margin-top: 30px; border-top: 1px solid #ccc; padding-top: 10px; }
    .hash-note { font-family: 'Courier New', monospace; font-size: 8pt; color: #555; word-break: break-all; }
</style>
</head>
<body>

<div class="header">
    <h1>ACTA DE CADENA DE CUSTODIA</h1>
    <h2>Evidencias Digitales - Analisis Forense Informatico</h2>
</div>

<div class="confidential">DOCUMENTO CONFIDENCIAL - CADENA DE CUSTODIA DE EVIDENCIAS DIGITALES</div>

<div class="section-title">1. DATOS DEL CASO</div>
<table class="info-table">
    <tr><td>Numero de Caso</td><td>$caseNumberEnc</td></tr>
    <tr><td>Perito Informatico</td><td>$examinerNameEnc</td></tr>
    <tr><td>Descripcion</td><td>$evidenceDescEnc</td></tr>
    <tr><td>Fecha de Inicio</td><td>$($Script:SessionInfo.StartTime.ToString($Script:Defaults.TimeZoneFormat))</td></tr>
    <tr><td>Fecha de Fin</td><td>$($Script:SessionInfo.EndTime.ToString($Script:Defaults.TimeZoneFormat))</td></tr>
    <tr><td>Equipo Analizado</td><td>$computerNameEnc</td></tr>
    <tr><td>Sistema Operativo</td><td>$osVersionEnc (Build $osBuildEnc)</td></tr>
</table>

<div class="section-title">2. HERRAMIENTA UTILIZADA</div>
<table class="info-table">
    <tr><td>Herramienta</td><td>$($Script:SessionInfo.ToolName) v$($Script:SessionInfo.ToolVersion)</td></tr>
    <tr><td>Hash SHA-256</td><td class="hash-note">$($Script:SessionInfo.ScriptHash)</td></tr>
    <tr><td>PowerShell</td><td>$($Script:SessionInfo.PSVersion)</td></tr>
</table>

<div class="section-title">3. INVENTARIO DE EVIDENCIAS ($totalEvidences elementos)</div>
<table class="evidence-table">
<thead>
    <tr><th>ID</th><th>Timestamp</th><th>Origen</th><th>Destino</th><th>SHA-256</th><th>Metodo</th><th>Tamano</th></tr>
</thead>
<tbody>
"@

    # StringBuilder en vez de concatenacion de string en bucle (+=): con miles de evidencias
    # la concatenacion repetida es O(n^2) y podia hacer muy lenta la generacion del acta.
    $rowsSb = [System.Text.StringBuilder]::new()
    $rowErrors = 0

    foreach ($entry in $custodyData) {
        try {
            $sourcePath = if ($null -eq $entry.SourcePath) { "" } else { $entry.SourcePath }
            $destPath   = if ($null -eq $entry.DestinationPath) { "" } else { $entry.DestinationPath }
            $hashValue  = if ($null -eq $entry.SHA256Hash) { "" } else { $entry.SHA256Hash }

            $shortSource = if ($sourcePath.Length -gt 50) { "..." + $sourcePath.Substring($sourcePath.Length - 47) } else { $sourcePath }
            $shortDest   = if ($destPath.Length -gt 50) { "..." + $destPath.Substring($destPath.Length - 47) } else { $destPath }
            $shortHash   = if ($hashValue.Length -gt 16) { $hashValue.Substring(0, 16) + "..." } else { $hashValue }
            $sizeParsed  = 0L
            [void][long]::TryParse($entry.FileSize, [ref]$sizeParsed)
            $sizeFormatted = Format-FileSize -Bytes $sizeParsed

            [void]$rowsSb.AppendLine(@"
    <tr>
        <td>$($entry.EvidenceID)</td>
        <td style="white-space:nowrap">$($entry.Timestamp)</td>
        <td title="$([System.Web.HttpUtility]::HtmlEncode($sourcePath))">$([System.Web.HttpUtility]::HtmlEncode($shortSource))</td>
        <td title="$([System.Web.HttpUtility]::HtmlEncode($destPath))">$([System.Web.HttpUtility]::HtmlEncode($shortDest))</td>
        <td class="hash-note" title="$([System.Web.HttpUtility]::HtmlEncode($hashValue))">$([System.Web.HttpUtility]::HtmlEncode($shortHash))</td>
        <td>$([System.Web.HttpUtility]::HtmlEncode($entry.Method))</td>
        <td style="white-space:nowrap">$sizeFormatted</td>
    </tr>
"@)
        } catch {
            # Antes, una unica fila con datos inesperados (p.ej. FileSize no numerico) lanzaba
            # una excepcion no capturada que abortaba la generacion de TODO el acta de cadena
            # de custodia (documento legal), sin generar ningun HTML. Ahora esa fila se marca
            # como error y se continua con el resto de evidencias.
            $rowErrors++
            [void]$rowsSb.AppendLine("<tr><td colspan='7' style='color:#c00'>[Error al procesar esta entrada de evidencia: $([System.Web.HttpUtility]::HtmlEncode($_.Exception.Message))]</td></tr>")
            Write-ForensicLog -Phase "INFORME" -Action "CUSTODIA_FILA_ERROR" -Target "$($entry.EvidenceID)" -Result "ERROR" -ErrorMessage $_.Exception.Message
        }
    }
    $html += $rowsSb.ToString()
    if ($rowErrors -gt 0) {
        Write-ForensicLog -Phase "INFORME" -Action "CUSTODIA_FILAS_CON_ERROR" -Target "$rowErrors de $totalEvidences filas no se pudieron formatear correctamente" -Result "WARNING"
    }

    $html += @"
</tbody>
</table>

<div class="section-title">4. VERIFICACION DE INTEGRIDAD</div>
<table class="info-table">
    <tr><td>Total de Evidencias</td><td>$totalEvidences</td></tr>
    <tr><td>Manifiesto de Hashes</td><td>Logs\HashManifest.csv</td></tr>
    <tr><td>Algoritmo</td><td>SHA-256 (FIPS 180-4)</td></tr>
    <tr><td>Nota</td><td>Todos los hashes han sido calculados sobre los ficheros de evidencia en el momento de su adquisicion. Para verificar la integridad, recalcule los hashes y compare con el manifiesto.</td></tr>
</table>

<div class="signatures">
<div class="section-title">5. FIRMAS</div>
<p>Con la presente acta se certifica que las evidencias digitales listadas han sido adquiridas siguiendo los procedimientos establecidos en la RFC 3227 y NIST SP 800-86, manteniendo la cadena de custodia en todo momento.</p>

<div class="sig-row">
    <div class="sig-block">
        <div class="sig-line">Perito Informatico<br><strong>$examinerNameEnc</strong><br>Fecha: $($Script:SessionInfo.EndTime.ToString('dd/MM/yyyy'))</div>
    </div>
    <div class="sig-block">
        <div class="sig-line">Testigo / Custodio<br><br>Fecha: ___/___/______</div>
    </div>
</div>
</div>

<div class="footer">
    Documento generado por $($Script:TOOL_FULL) v$($Script:TOOL_VERSION)<br>
    Caso: $caseNumberEnc | Fecha: $($Script:SessionInfo.EndTime.ToString('dd/MM/yyyy HH:mm'))
</div>

</body>
</html>
"@

    $custodyHtmlPath = Join-Path $reportPath "CadenaCustodia.html"
    $html | Out-File -FilePath $custodyHtmlPath -Encoding UTF8
    Write-ForensicLog -Phase "INFORME" -Action "CADENA_CUSTODIA_GENERADA" -Target $custodyHtmlPath -Result "OK"
}

function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}
