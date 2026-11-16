#region ============================================================
# MaPeriT.SC - PLANTILLAS CSS/JS Y TABLA DE HALLAZGOS DE LOS INFORMES
# Adaptado de MaPeriT.AN (Get-ANCss/Get-ANJs/Add-ANSection) para
# coherencia visual con el resto del ecosistema. Copiado y adaptado,
# no referenciado en caliente (SC es un script compilado aparte).
# ============================================================

function Get-SCCss {
    return @'
:root{--sw:230px;--c-bg:#f1f5f9;--c-surface:#fff;--c-border:#e2e8f0;--c-text:#1e293b;--c-muted:#64748b;--c-accent:#1d4ed8;--c-nav:#0f172a;--c-nav-t:#94a3b8;--c-ts:#dc2626;--c-del:#ea580c;--c-ok:#16a34a;--r:6px;--sh:0 1px 3px rgba(0,0,0,.1),0 1px 2px rgba(0,0,0,.06)}
*{box-sizing:border-box;margin:0;padding:0}html{scroll-behavior:smooth}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif;font-size:14px;line-height:1.6;color:var(--c-text);background:var(--c-bg);display:flex;min-height:100vh}
.sidebar{width:var(--sw);min-height:100vh;background:var(--c-nav);position:fixed;top:0;left:0;overflow-y:auto;z-index:100;display:flex;flex-direction:column;border-right:1px solid rgba(255,255,255,.05)}
.sb-brand{padding:20px 18px 16px;border-bottom:1px solid rgba(255,255,255,.08)}
.sb-brand-name{font-size:17px;font-weight:700;color:#fff}.sb-brand-sub{font-size:11px;color:#64748b;margin-top:3px}
.sb-case{padding:10px 18px;border-bottom:1px solid rgba(255,255,255,.06);font-size:11px;color:#64748b}
.sb-case strong{color:#94a3b8;display:block;font-size:10px;text-transform:uppercase;letter-spacing:.8px;margin-bottom:2px}
nav{padding:10px 0}.sb-label{padding:8px 18px 3px;font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:1px;color:#334155}
nav a{display:block;padding:6px 18px;color:var(--c-nav-t);text-decoration:none;font-size:12.5px;border-left:3px solid transparent;transition:all .12s}
nav a:hover,nav a.active{color:#fff;border-left-color:#3b82f6;background:rgba(255,255,255,.04)}
.sb-footer{margin-top:auto;padding:14px 18px;border-top:1px solid rgba(255,255,255,.06);font-size:10px;color:#334155;line-height:1.6}
.main{margin-left:var(--sw);flex:1;min-width:0}
.cover{background:linear-gradient(135deg,#0f172a 0%,#1a3a5c 50%,#0f172a 100%);color:#fff;padding:72px 64px;min-height:420px;display:flex;flex-direction:column;justify-content:center}
.cover-badge{display:inline-block;background:rgba(59,130,246,.2);border:1px solid rgba(59,130,246,.4);color:#93c5fd;padding:4px 14px;border-radius:20px;font-size:11px;font-weight:600;letter-spacing:1.2px;text-transform:uppercase;margin-bottom:28px}
.cover h1{font-size:40px;font-weight:800;letter-spacing:-1px;line-height:1.1}.cover h2{font-size:16px;font-weight:400;color:#94a3b8;margin-top:8px}
.cover-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px 48px;margin-top:44px;padding-top:32px;border-top:1px solid rgba(255,255,255,.12)}
.cover-item label{font-size:10px;text-transform:uppercase;letter-spacing:1px;color:#64748b}.cover-item span{display:block;font-size:14px;font-weight:600;color:#e2e8f0;margin-top:2px}
.content{padding:48px 56px;max-width:1060px}
.section-hdr{display:flex;align-items:center;gap:14px;padding-bottom:14px;border-bottom:2px solid var(--c-border);margin:48px 0 28px}
.sec-num{background:var(--c-accent);color:#fff;width:34px;height:34px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:700;flex-shrink:0}
.section-hdr h2{font-size:22px;font-weight:700}
.sub-hdr{font-size:13px;font-weight:600;color:var(--c-text);padding:9px 14px;margin:24px 0 10px;background:var(--c-surface);border-left:3px solid var(--c-accent);border-radius:0 var(--r) var(--r) 0;box-shadow:var(--sh)}
.stat-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:14px;margin:24px 0}
.stat-card{background:var(--c-surface);border:1px solid var(--c-border);border-radius:var(--r);padding:18px;box-shadow:var(--sh);border-top:3px solid var(--c-accent)}
.stat-card.ts{border-top-color:var(--c-ts)}.stat-card.del{border-top-color:var(--c-del)}.stat-card.ok{border-top-color:var(--c-ok)}
.sv{font-size:32px;font-weight:800;line-height:1;color:var(--c-accent)}.stat-card.ts .sv{color:var(--c-ts)}.stat-card.del .sv{color:var(--c-del)}.stat-card.ok .sv{color:var(--c-ok)}
.sl{font-size:12px;color:var(--c-muted);margin-top:6px}
.info-table{width:100%;border-collapse:collapse;background:var(--c-surface);border-radius:var(--r);box-shadow:var(--sh);overflow:hidden}
.info-table tr{border-bottom:1px solid var(--c-border)}.info-table tr:last-child{border-bottom:none}
.info-table td:first-child{background:#f8fafc;font-weight:600;font-size:11.5px;color:var(--c-muted);width:200px;padding:10px 14px;text-transform:uppercase;letter-spacing:.3px;white-space:nowrap}
.info-table td{padding:10px 14px;font-size:13px;word-break:break-word}
.tcard{background:var(--c-surface);border-radius:var(--r);box-shadow:var(--sh);border:1px solid var(--c-border);overflow:hidden;margin:10px 0 20px}
.ttoolbar{padding:10px 14px;background:#f8fafc;border-bottom:1px solid var(--c-border);display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:8px}
.ttoolbar-label{font-size:11px;font-weight:600;color:var(--c-muted);text-transform:uppercase;letter-spacing:.5px}
.tsearch{padding:5px 10px;border:1px solid var(--c-border);border-radius:4px;font-size:12px;width:190px;background:#fff;color:var(--c-text)}
.tsearch:focus{outline:none;border-color:var(--c-accent);box-shadow:0 0 0 2px rgba(29,78,216,.15)}
.twrap{overflow-x:auto;-webkit-overflow-scrolling:touch}
.dtable{width:100%;border-collapse:collapse;font-size:12.5px;min-width:400px}
.dtable thead{background:#1e293b;position:sticky;top:0;z-index:2}
.dtable th{padding:9px 12px;text-align:left;font-weight:600;color:#e2e8f0;font-size:11px;letter-spacing:.3px;white-space:nowrap;border-right:1px solid rgba(255,255,255,.06)}
.dtable th:last-child{border-right:none}
.dtable td{padding:7px 12px;border-bottom:1px solid #f1f5f9;vertical-align:top;max-width:280px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.dtable tbody tr:hover{background:#f0f7ff}.dtable tbody tr:last-child td{border-bottom:none}
.dtable td.w{white-space:normal;word-break:break-word;max-width:none}
.dtable td.mono{font-family:'Cascadia Code','Fira Code','Courier New',monospace;font-size:11px;color:#475569}
.tnote{padding:7px 14px;background:#fffbeb;border-top:1px solid #fef3c7;font-size:11px;color:#92400e}
.badge{display:inline-flex;align-items:center;padding:2px 9px;border-radius:4px;font-size:11px;font-weight:600;white-space:nowrap}
.b-ok{background:#dcfce7;color:#15803d}.b-warn{background:#fef9c3;color:#a16207}.b-err{background:#fee2e2;color:#b91c1c}
.alert{padding:10px 14px;border-radius:var(--r);margin:10px 0;font-size:13px}
.alert-warn{background:#fffbeb;border:1px solid #fef3c7;color:#92400e}.alert-info{background:#eff6ff;border:1px solid #dbeafe;color:#1d4ed8}.alert-ok{background:#f0fdf4;border:1px solid #dcfce7;color:#15803d}.alert-crit{background:#fef2f2;border:1px solid #fecaca;color:#991b1b}
details{margin:6px 0}
summary{display:flex;align-items:center;gap:8px;padding:10px 14px;background:#f8fafc;border:1px solid var(--c-border);border-radius:var(--r);cursor:pointer;font-weight:600;font-size:13px;list-style:none;user-select:none}
summary::before{content:'\25B6';font-size:10px;transition:transform .15s;flex-shrink:0}
details[open]>summary::before{transform:rotate(90deg)}details[open]>summary{border-radius:var(--r) var(--r) 0 0;border-bottom-color:transparent}
details[open]>.det-body{border:1px solid var(--c-border);border-top:none;border-radius:0 0 var(--r) var(--r);padding:14px;background:var(--c-surface)}
p{margin:8px 0}.report-footer{text-align:center;font-size:11px;color:var(--c-muted);border-top:1px solid var(--c-border);padding:20px 56px}
@media print{.sidebar{display:none}.main{margin-left:0}.content{padding:20px}.page-break{page-break-before:always}.dtable thead{background:#1e293b!important;-webkit-print-color-adjust:exact;print-color-adjust:exact}}
@page{size:A4;margin:1.5cm}
'@
}

function Get-SCJs {
    return @'
(function(){
  window.filterTable=function(inputId,tableId){
    var f=document.getElementById(inputId).value.toUpperCase();
    document.getElementById(tableId).querySelectorAll('tbody tr').forEach(function(tr){
      tr.style.display=tr.textContent.toUpperCase().indexOf(f)>-1?'':'none';
    });
  };
})();
'@
}

function ConvertFrom-SCDescription {
    <# Descripcion viene como "Clave: valor | Clave: valor" (ver QueryEngine.ps1). Se
       parsea a hashtable para poder construir frases en lenguaje llano por fuente. #>
    param([string]$Descripcion)
    $map = @{}
    if ($Descripcion) {
        foreach ($part in ($Descripcion -split '\|')) {
            $kv = $part.Split(':', 2)
            if ($kv.Count -eq 2) { $map[$kv[0].Trim()] = $kv[1].Trim() }
        }
    }
    return $map
}

function Get-SCPlainSentence {
    <#
    Traduce un hallazgo a una frase en lenguaje llano segun su fuente, para el
    informe facil (Report\ReportLlano.ps1). Sin esto, el informe facil solo
    podia dar un recuento por categoria ("se han encontrado N registros"), sin
    decir que se encontro realmente - insuficiente para un lector no tecnico.
    #>
    param([PSCustomObject]$Finding)
    $d = ConvertFrom-SCDescription -Descripcion $Finding.Descripcion
    $quien = if ($Finding.Usuario) { $Finding.Usuario } else { "un usuario no identificado" }

    switch ($Finding.Fuente) {
        'EVTX_Logons'         { return "$quien inicio sesion en el equipo" + $(if ($d['LogonType']) { " ($($d['LogonType']))" } else { "" }) }
        'EVTX_FailedLogons'   { return "Intento fallido de inicio de sesion" + $(if ($Finding.Usuario) { " para $quien" } else { "" }) }
        'EVTX_Procesos'       { $p = if ($d['ProcessName']) { $d['ProcessName'] } else { "un programa" }; return "$quien ejecuto: $p" }
        'Amcache_Ejecutables' { $p = if ($d['Nombre']) { $d['Nombre'] } else { "un programa" }; return "Amcache tiene registrado el programa: $p" + $(if ($d['Publisher']) { " (editor: $($d['Publisher']))" } else { "" }) + $(if ($d['RutaFichero']) { " [$($d['RutaFichero'])]" } else { "" }) + " (Amcache no guarda la fecha de ejecucion)" }
        'ShimCache_Completo'  { return "Programa registrado en la cache de compatibilidad (ShimCache; por si solo no prueba su ejecucion)" + $(if ($Finding.Descripcion) { ": $($Finding.Descripcion)" } else { "" }) }
        'USN_Ejecutables'     { return "Actividad sobre un fichero ejecutable" + $(if ($Finding.Descripcion) { ": $($Finding.Descripcion)" } else { "" }) }
        'EVTX_NuevosServicios'{ $s = if ($d['ServiceName']) { $d['ServiceName'] } else { "un servicio" }; return "Se instalo un nuevo servicio en el equipo: $s" }
        'EVTX_PowerShell4104' { return "$quien ejecuto un script de PowerShell" }
        'EVTX_LogBorrado'     { return "Se borro el registro de auditoria de seguridad del sistema" }
        'MFT_Completo'        { $n = if ($d['NombreFichero']) { $d['NombreFichero'] } else { "un fichero" }; $est = if ($d['Estado'] -eq 'BORRADO') { "borrado" } else { "creado o modificado" }; return "Fichero ${est}: $n" + $(if ($d['RutaCompleta']) { " [$($d['RutaCompleta'])]" } else { "" }) }
        'MFT_Borrados'        { $n = if ($d['NombreFichero']) { $d['NombreFichero'] } else { "un fichero" }; return "Fichero borrado: $n" + $(if ($d['RutaCompleta']) { " [$($d['RutaCompleta'])]" } else { "" }) }
        'MFT_Timestomping'    { $n = if ($d['NombreFichero']) { $d['NombreFichero'] } else { "un fichero" }; return "Posible manipulacion de la fecha de un fichero: $n" + $(if ($d['RutaCompleta']) { " [$($d['RutaCompleta'])]" } else { "" }) }
        'USN_Borrados'        { return "Un fichero fue borrado" + $(if ($Finding.Descripcion) { ": $($Finding.Descripcion)" } else { "" }) }
        'USN_Renombrados'     { return "Un fichero fue renombrado" + $(if ($Finding.Descripcion) { ": $($Finding.Descripcion)" } else { "" }) }
        'USN_RutasSospechosas'{ return "Actividad en una carpeta temporal o de descargas" + $(if ($Finding.Descripcion) { ": $($Finding.Descripcion)" } else { "" }) }
        'Browser_Historial'   { $t = if ($d['Titulo']) { $d['Titulo'] } elseif ($d['URL']) { $d['URL'] } else { "una pagina web" }; return "$quien visito: $t" }
        'Browser_Descargas'   { $r = if ($d['RutaDestino']) { $d['RutaDestino'] } else { "un fichero" }; return "$quien descargo: $r" }
        'Browser_Busquedas'   { $b = if ($d['Busqueda']) { $d['Busqueda'] } else { "algo" }; return "$quien busco en internet: `"$b`"" }
        default               { if ($Finding.Descripcion) { return $Finding.Descripcion } else { return "Actividad registrada en $($Finding.Fuente)" } }
    }
}

$Script:SC_ProgramSources = @('EVTX_Procesos','Amcache_Ejecutables','ShimCache_Completo','USN_Ejecutables')

function Get-SCProgramCorrelations {
    <#
    Detecta el mismo programa confirmado por varias fuentes distintas dentro
    de la categoria "Programas ejecutados" (ShimCache/Amcache/EVTX_Procesos/
    USN_Ejecutables pueden registrar la misma ejecucion cada una por su
    lado). Corroborar con 2+ fuentes independientes refuerza el hallazgo -
    se muestra como aviso destacado, sin alterar ni sustituir la tabla de
    detalle completa (que sigue mostrando cada hallazgo individual, intacta,
    para no perder informacion pericial).
    #>
    param([array]$Findings)
    $progFindings = $Findings | Where-Object { $Script:SC_ProgramSources -contains $_.Fuente }
    if (-not $progFindings) { return @() }

    $groups = $progFindings | Group-Object {
        $d = ConvertFrom-SCDescription -Descripcion $_.Descripcion
        $raw = if ($d['ProcessName']) { $d['ProcessName'] } elseif ($d['Nombre']) { $d['Nombre'] } else { $_.Descripcion }
        $leaf = $null
        try { $leaf = Split-Path $raw -Leaf -ErrorAction Stop } catch {}
        if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = $raw }
        $leaf.ToLowerInvariant().Trim()
    }

    # Nota: la propiedad se llama "NumRegistros", NUNCA "Count" - si el objeto
    # de salida tuviera una propiedad literal "Count", cuando esta funcion
    # devuelve exactamente 1 correlacion, PowerShell aplana el array de salida
    # a un escalar al capturarlo (return @($x) con 1 elemento se enumera en
    # la pipeline), y "$resultado.Count" pasaria a leer esa propiedad del
    # objeto en vez de contar elementos del array - confirmado con una prueba
    # dirigida con exactamente 1 correlacion.
    $correlated = $groups | Where-Object { ($_.Group.Fuente | Select-Object -Unique).Count -ge 2 }
    return @($correlated | ForEach-Object {
        [PSCustomObject]@{
            Programa     = $_.Name
            Fuentes      = @($_.Group.Fuente | Select-Object -Unique | Sort-Object)
            NumRegistros = $_.Group.Count
            Primero      = ($_.Group | Sort-Object { if ($_.Timestamp) { $_.Timestamp } else { [datetime]::MaxValue } } | Select-Object -First 1).Timestamp
        }
    } | Sort-Object Programa)
}

function Get-SCFindingSignature {
    <# Normaliza la descripcion de un hallazgo sustituyendo numeros por # para
       detectar repeticiones casi identicas del mismo patron (por ejemplo,
       varios ficheros de log de OneDrive que solo difieren en la marca de
       tiempo/numero de secuencia de su nombre). #>
    param([PSCustomObject]$Finding)
    if (-not $Finding.Descripcion) { return "$($Finding.Fuente)|" }
    return "$($Finding.Fuente)|" + ($Finding.Descripcion -replace '\d+', '#')
}

function Group-SCFindingRuns {
    <#
    Agrupa hallazgos YA ORDENADOS POR FECHA en tramos consecutivos que
    comparten la misma firma normalizada (Get-SCFindingSignature). Un tramo
    de $Threshold hallazgos o mas se devuelve colapsado en un unico resumen
    (Collapsed=$true, con el rango de fechas y el contador); por debajo del
    umbral se devuelve tal cual, hallazgo a hallazgo (Collapsed=$false).
    Pensado para el informe en lenguaje llano: listar 40 lineas casi
    identicas ("NucleusLocal-...odl" de OneDrive escribiendose cada pocos
    minutos, por ejemplo) no aporta nada a un lector no tecnico - una sola
    linea con el rango y el conteo es mucho mas legible. El detalle completo,
    sin colapsar, sigue disponible en la tabla tecnica de ambos informes.
    #>
    param([array]$SortedFindings, [int]$Threshold = 5)
    $runs = [System.Collections.Generic.List[object]]::new()
    $current = $null
    foreach ($f in $SortedFindings) {
        $sig = Get-SCFindingSignature -Finding $f
        if ($current -and $current.Sig -eq $sig) {
            $current.Items.Add($f)
        } else {
            if ($current) { $runs.Add($current) }
            $current = [PSCustomObject]@{ Sig = $sig; Items = [System.Collections.Generic.List[object]]::new() }
            [void]$current.Items.Add($f)
        }
    }
    if ($current) { $runs.Add($current) }

    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($run in $runs) {
        if ($run.Items.Count -ge $Threshold) {
            $out.Add([PSCustomObject]@{ Collapsed = $true; Items = @($run.Items) })
        } else {
            foreach ($item in $run.Items) {
                $out.Add([PSCustomObject]@{ Collapsed = $false; Items = @($item) })
            }
        }
    }
    return $out
}

function Add-SCFindingsTable {
    <#
    Vuelca los hallazgos confirmados (ya filtrados/incluidos por el usuario en
    el wizard) a una tabla HTML. A diferencia de Add-ANSection (que lee un CSV
    del disco), aqui los datos ya estan en memoria - es la misma lista que
    alimenta ambos informes, para garantizar que sean el mismo hecho con dos
    redacciones distintas.
    #>
    param(
        [System.Text.StringBuilder]$Html,
        [array]$Findings,
        [string]$Title,
        [switch]$Collapsible
    )

    $safeId   = "t_" + ($Title -replace '[^a-zA-Z0-9]','_')
    $searchId = $safeId + "_s"
    $tableId  = $safeId + "_tbl"

    if ($Collapsible) {
        [void]$Html.AppendLine("<details><summary>$([System.Web.HttpUtility]::HtmlEncode($Title))</summary><div class='det-body'>")
    } else {
        [void]$Html.AppendLine("<div class='sub-hdr'>$([System.Web.HttpUtility]::HtmlEncode($Title))</div>")
    }

    if (-not $Findings -or $Findings.Count -eq 0) {
        [void]$Html.AppendLine("<p><em style='color:#94a3b8'>Sin hallazgos en esta categoria con los criterios aplicados.</em></p>")
        if ($Collapsible) { [void]$Html.AppendLine("</div></details>") }
        return
    }

    $cols = @('Fecha','Fuente','Usuario','Confianza','Descripcion','Origen')
    [void]$Html.AppendLine("<div class='tcard'>")
    [void]$Html.AppendLine("<div class='ttoolbar'>")
    [void]$Html.AppendLine("  <span class='ttoolbar-label'>$($Findings.Count) hallazgo(s)</span>")
    [void]$Html.AppendLine("  <input class='tsearch' id='$searchId' type='text' placeholder='Filtrar...' oninput=""filterTable('$searchId','$tableId')"">")
    [void]$Html.AppendLine("</div><div class='twrap'>")
    [void]$Html.AppendLine("<table class='dtable' id='$tableId'><thead><tr>")
    foreach ($col in $cols) { [void]$Html.AppendLine("<th>$col</th>") }
    [void]$Html.AppendLine("</tr></thead><tbody>")

    foreach ($f in $Findings) {
        $fecha = Format-SCFecha $f
        $usuario = if ($f.Usuario) { $f.Usuario } else { "(sin usuario asociado)" }
        $confClass = switch ($f.Confianza) { 'Confirmado' { 'b-ok' } 'Inferido' { 'b-warn' } default { 'b-err' } }
        [void]$Html.Append("<tr>")
        [void]$Html.Append("<td class='mono'>$([System.Web.HttpUtility]::HtmlEncode($fecha))</td>")
        [void]$Html.Append("<td>$([System.Web.HttpUtility]::HtmlEncode($f.Fuente))</td>")
        [void]$Html.Append("<td>$([System.Web.HttpUtility]::HtmlEncode($usuario))</td>")
        [void]$Html.Append("<td><span class='badge $confClass'>$($f.Confianza)</span></td>")
        [void]$Html.Append("<td class='w'>$([System.Web.HttpUtility]::HtmlEncode($f.Descripcion))</td>")
        [void]$Html.Append("<td class='mono w'>$([System.Web.HttpUtility]::HtmlEncode($f.Origen))</td>")
        [void]$Html.AppendLine("</tr>")
    }
    [void]$Html.AppendLine("</tbody></table></div></div>")
    if ($Collapsible) { [void]$Html.AppendLine("</div></details>") }
}

#endregion
