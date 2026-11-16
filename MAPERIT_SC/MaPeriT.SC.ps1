#Requires -Version 5.1
<#
    MaPeriT.SC v1.0.1 - Consulta Guiada de Evidencias del Ecosistema MaPeriT
    Compilado: 2026-11-16 12:00:00
    No editar directamente - modificar src\ y recompilar con Build.ps1
#>
#region ===== src\Main-Params.ps1 =====
#region ============================================================
# MaPeriT.SC - PARAMETROS DE ENTRADA
# ============================================================
[CmdletBinding()]
param(
    [string]$ProjectPath = ""   # Abrir directamente una carpeta de evidencias con ANALISIS_AN
)
#endregion
#endregion

#region ===== src\Config.ps1 =====
#region ============================================================
# MaPeriT.SC - CONFIGURACION Y CONSTANTES
# Fuente unica de verdad para la version:
# Build.ps1 lee $Script:SC_Version de este fichero, nunca la hardcodea.
# ============================================================

$Script:SC_Version   = "1.0.1"
$Script:SC_Title     = "MaPeriT.SC"
$Script:SC_FullTitle = "MaPeriT.SC v$Script:SC_Version — Consulta Guiada de Evidencias"

# ── Paleta unica (sin toggle dark/light: herramienta de un solo flujo
#    lineal para usuario no tecnico, no un explorador de evidencias) ──
$Script:Colors = @{
    BgPrimary   = "#F1F5F9"
    BgPanel     = "#E2E8F0"
    BgCard      = "#FFFFFF"
    BgSurface   = "#FFFFFF"
    BgHeader    = "#0F172A"
    Accent      = "#1D4ED8"
    AccentDark  = "#1E3A8A"
    AccentHover = "#2563EB"
    Text        = "#0F172A"
    TextMuted   = "#475569"
    TextDim     = "#64748B"
    Border      = "#CBD5E1"
    BorderLight = "#E2E8F0"
    Success     = "#15803D"
    Warning     = "#B45309"
    Danger      = "#DC2626"
    Info        = "#1D4ED8"
    SelectionBg = "#1D4ED8"
    SelectionFg = "#FFFFFF"
}

# ── Estructura de salida de MaPeriT.AN (debe coincidir con AN\src\Config.ps1) ──
$Script:AN_Dirs = @{
    MFT      = "MFT"
    EVTX     = "EVTX"
    Browsers = "Browsers"
    Report   = "Report"
    Logs     = "Logs"
}
$Script:AN_OutputFolderName = "ANALISIS_AN"

# Plantillas de busqueda (categorias/fechas/franja/palabras clave): se
# guardan fuera de la carpeta del proyecto/caso, en el perfil del usuario,
# para poder reutilizarlas entre casos distintos.
$Script:SC_TemplatesDir = Join-Path $env:APPDATA "MaPeriT.SC\Plantillas"

# ── Formatos de fecha conocidos en los CSV de AN (se prueban en este orden) ──
$Script:SC_KnownDateFormats = @(
    "yyyy-MM-dd HH:mm:ss.fffffff",
    "yyyy-MM-dd HH:mm:ss",
    "yyyy-MM-dd"
)

# Sin limite de filas al indexar (a diferencia de TN, que trunca a 50000
# para rendimiento de un visor): SC es un motor de consulta, no un visor.
# Truncar aqui equivaldria a un hallazgo pericial incompleto sin aviso -
# no se acepta ese riesgo. El limite de rendimiento se resuelve con
# virtualizacion de filas en el DataGrid de resultados, no recortando datos.
$Script:SC_NoRowLimit = [int]::MaxValue

# ── Sesion de consulta (estado en memoria durante la ejecucion) ──────
$Script:SCSession = @{
    ProjectPath   = ""
    ANOutputPath  = ""
    CaseNumber    = ""
    Examiner      = ""
    LoadedTables  = @{}   # Key = fuente (ver SourceSchema.ps1) -> DataTable
    SourcesFound  = @()
    SourcesMissing= @()
    StartTime     = $null
}

#endregion
#endregion

#region ===== src\Core\Initialize.ps1 =====
#region ============================================================
# MaPeriT.SC - INICIALIZACION DE ASSEMBLIES WPF
# ============================================================

function Initialize-SCApplication {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore      -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase           -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms  -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Web            -ErrorAction SilentlyContinue

    # DPI awareness para pantallas HiDPI
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class SC_DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
'@ -ErrorAction SilentlyContinue
        [SC_DpiHelper]::SetProcessDPIAware() | Out-Null
    } catch {}
}

function New-WpfBrush {
    param([string]$HexColor)
    return [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString($HexColor)
    )
}

#endregion
#endregion

#region ===== src\Core\Logging.ps1 =====
#region ============================================================
# MaPeriT.SC - LOGGING (consola)
# ============================================================

function Write-SCLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )
    $ts    = Get-Date -Format 'HH:mm:ss'
    $color = switch ($Level) {
        'WARNING' { 'Yellow'   }
        'ERROR'   { 'Red'      }
        'DEBUG'   { 'DarkGray' }
        default   { 'Cyan'     }
    }
    Write-Host "  [$ts][$Level] $Message" -ForegroundColor $color
}

#endregion
#endregion

#region ===== src\Core\ProjectLoader.ps1 =====
#region ============================================================
# MaPeriT.SC - VALIDACION Y METADATOS DEL PROYECTO
# SC solo lee resultados ya generados por MaPeriT.AN. No modifica nada
# dentro de la carpeta de evidencias ni de ANALISIS_AN.
# ============================================================

function Test-SCProject {
    <#
    Valida que $Path sea una carpeta de evidencias MaPeriT con analisis
    AN ya generado (requisito de entrada de SC).
    #>
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path $Path -PathType Container)) { return $false }

    $anPath = Join-Path $Path $Script:AN_OutputFolderName
    if (-not (Test-Path $anPath -PathType Container)) { return $false }

    # Con al menos una subcarpeta conocida o el timeline de correlacion basta
    # para considerar que AN se ejecuto correctamente sobre este proyecto.
    $hasKnownDir = @($Script:AN_Dirs.Values | Where-Object { Test-Path (Join-Path $anPath $_) }).Count -gt 0
    $hasTimeline = Test-Path (Join-Path $anPath "Correlacion_Timeline.csv")

    return ($hasKnownDir -or $hasTimeline)
}

function Get-SCProjectMetadata {
    param([string]$Path)

    $meta = [ordered]@{
        Path         = $Path
        Name         = Split-Path $Path -Leaf
        CaseNumber   = ""
        Examiner     = ""
        ComputerName = ""
        ANOutputPath = Join-Path $Path $Script:AN_OutputFolderName
    }

    $sessionCandidates = @(
        (Join-Path $Path "Logs\session.json"),
        (Join-Path $Path "session.json")
    )
    foreach ($sf in $sessionCandidates) {
        if (Test-Path $sf) {
            try {
                $s = Get-Content $sf -Raw | ConvertFrom-Json
                if ($s.CaseNumber)   { $meta.CaseNumber   = $s.CaseNumber }
                if ($s.ExaminerName) { $meta.Examiner      = $s.ExaminerName }
                if ($s.ComputerName) { $meta.ComputerName  = $s.ComputerName }
            } catch {}
            break
        }
    }

    if ([string]::IsNullOrEmpty($meta.CaseNumber)) {
        $dirName = Split-Path $Path -Leaf
        if ($dirName -match '^MaPeriT_(?:OF_)?(.+?)_\d{8}') { $meta.CaseNumber = $Matches[1] }
    }

    # Ni MaPeriT.SW ni MaPeriT.OF generan session.json: sin estos respaldos el
    # "Equipo" y el "Perito" (tambien en la firma del informe) salian SIEMPRE
    # vacios. Mismas fuentes que usa MaPeriT.AN (Get-SWSessionInfo).
    if ([string]::IsNullOrEmpty($meta.ComputerName)) {
        $osPath = Join-Path $Path "02_SystemInfo\OSInfo.json"
        if (Test-Path $osPath) {
            try {
                $os = Get-Content $osPath -Raw | ConvertFrom-Json
                $meta.ComputerName = if ($os.CSName) { $os.CSName } elseif ($os.ComputerName) { $os.ComputerName } elseif ($os.NombreEquipo) { $os.NombreEquipo } elseif ($os.SystemName) { $os.SystemName } else { "" }
            } catch {}
        }
    }
    if ([string]::IsNullOrEmpty($meta.Examiner)) {
        $reportHtml = Join-Path $Path "Report\InformePericial.html"
        if (Test-Path $reportHtml) {
            try {
                $content = Get-Content $reportHtml -Raw -ErrorAction SilentlyContinue
                # Portada de SW ("Perito") y de OF ("Perito Informatico")
                if ($content -match "<label>Perito(?: Informatico)?</label>\s*<span>([^<]{1,80})</span>") {
                    $meta.Examiner = [System.Web.HttpUtility]::HtmlDecode($Matches[1].Trim())
                }
            } catch {}
        }
    }

    return [PSCustomObject]$meta
}

#endregion
#endregion

#region ===== src\Core\AsyncLoader.ps1 =====
#region ============================================================
# MaPeriT.SC - CARGA ASINCRONA DE FUENTES (Runspace + DispatcherTimer)
# Mismo patron anti-freeze validado en MaPeriT.TN: toda la I/O pesada
# (Import-Csv de ficheros que pueden tener cientos de miles de filas)
# corre en un Runspace STA separado. El hilo de UI solo hace polling
# via DispatcherTimer y nunca bloquea. Sin closures: todo el estado
# vive en $timer.Tag. Handler: param($sender,$e).
# ============================================================

function Invoke-AsyncSourceIndexing {
    <#
    Carga en segundo plano todos los CSV de $FilePaths (rutas completas)
    a DataTable, sin truncar filas (ver nota en Config.ps1).
    UIContext  : PSCustomObject libre, se reenvia tal cual a los callbacks.
    OnProgress : scriptblock param($ui, $current, $total, $currentFileName)
    OnComplete : scriptblock param($ui, $tablesByPath, $errorsByPath)
                 $tablesByPath es [hashtable] RutaCompleta -> DataTable
    #>
    param(
        [string[]]$FilePaths,
        [PSCustomObject]$UIContext,
        [scriptblock]$OnProgress,
        [scriptblock]$OnComplete
    )

    $progress = [hashtable]::Synchronized(@{ Current = 0; Total = $FilePaths.Count; CurrentFile = "" })

    $bgScript = {
        param($paths, $prog)
        $tables = [hashtable]::Synchronized(@{})
        $errors = [hashtable]::Synchronized(@{})
        foreach ($p in $paths) {
            $prog.CurrentFile = [System.IO.Path]::GetFileName($p)
            try {
                if (-not (Test-Path $p)) { $prog.Current++; continue }
                $raw = @(Import-Csv $p -Encoding UTF8 -ErrorAction Stop)
                $tbl = [System.Data.DataTable]::new([System.IO.Path]::GetFileNameWithoutExtension($p))
                if ($raw.Count -gt 0) {
                    foreach ($colName in $raw[0].PSObject.Properties.Name) {
                        [void]$tbl.Columns.Add($colName, [string])
                    }
                    foreach ($r in $raw) {
                        $row = $tbl.NewRow()
                        foreach ($c in $tbl.Columns) {
                            $v = $r.($c.ColumnName)
                            $row[$c.ColumnName] = if ($null -ne $v) { $v.ToString() } else { "" }
                        }
                        [void]$tbl.Rows.Add($row)
                    }
                }
                $tables[$p] = $tbl
            } catch {
                $errors[$p] = $_.Exception.Message
            }
            $prog.Current++
        }
        Write-Output -NoEnumerate ([PSCustomObject]@{ Tables = $tables; Errors = $errors })
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{ paths = $FilePaths; prog = $progress })
    $handle = $ps.BeginInvoke()

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $timer.Tag = [PSCustomObject]@{
        Ps         = $ps
        Handle     = $handle
        Rs         = $rs
        Progress   = $progress
        UI         = $UIContext
        OnProgress = $OnProgress
        OnComplete = $OnComplete
    }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag

        if ($ctx.OnProgress) {
            & $ctx.OnProgress $ctx.UI $ctx.Progress.Current $ctx.Progress.Total $ctx.Progress.CurrentFile
        }

        $state = $ctx.Ps.InvocationStateInfo.State
        if ($state -in 'Completed', 'Failed', 'Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                $tablesByPath = if ($obj) { $obj.Tables } else { @{} }
                $errorsByPath = if ($obj) { $obj.Errors } else { @{} }
                & $ctx.OnComplete $ctx.UI $tablesByPath $errorsByPath
            } catch {
                & $ctx.OnComplete $ctx.UI @{} @{ "__fatal__" = $_.Exception.Message }
            } finally {
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
}

#endregion
#endregion

#region ===== src\Query\SourceSchema.ps1 =====
#region ============================================================
# MaPeriT.SC - ESQUEMA DECLARATIVO DE FUENTES
# Mapeo categoria (wizard) -> ficheros CSV de AN -> columnas reales.
# Confirmado leyendo el codigo fuente de MaPeriT.AN (MFTParser.ps1,
# EVTXAnalyzer.ps1, BrowserSQLite.ps1, ShimcacheAmcache.ps1,
# USNJournal.ps1, Correlator.ps1) - no se ha supuesto ningun nombre
# de columna.
#
# Anadir una categoria/fuente nueva = anadir una entrada aqui, no tocar
# el motor de consulta (Query\QueryEngine.ps1).
# ============================================================

<#
Cada entrada de $Script:SC_SourceCatalog es un hashtable con:
  Key           : identificador unico, tambien nombre logico de la DataTable en memoria
  RelPath       : ruta relativa dentro de ANALISIS_AN
  Dynamic       : $true si las columnas dependen de una herramienta externa
                  (fsutil / extractor ShimCache de SW) y deben detectarse en runtime
  TimestampCol  : nombre de columna de fecha (fijo) o $null si es dinamica
  TimestampBestEffort : $true si el formato de fecha no esta garantizado (Amcache)
  UserCols      : array de columnas candidatas a usuario, en orden de prioridad,
                  o $null si la fuente no tiene usuario propio
  PathCol       : columna con ruta de fichero, usada para inferir usuario
                  por patron \Users\<usuario>\ cuando UserCols es $null
  DescCols      : columnas relevantes para descripcion/detalle del hallazgo
  DynamicTimeHint / DynamicPathHint : regex para localizar columnas en fuentes Dynamic
  Zona          : zona horaria de las fechas de la fuente (por defecto 'UTC', que es
                  como las escribe MaPeriT.AN); el USN Journal va en hora local
#>
$Script:SC_SourceCatalog = @(
    @{
        Key = 'EVTX_Logons'; RelPath = 'EVTX\EVTX_Logons.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('Categoria','Description','LogonType','WorkstationName','IPAddress')
    },
    @{
        Key = 'EVTX_FailedLogons'; RelPath = 'EVTX\EVTX_FailedLogons.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('Categoria','Description','LogonType','WorkstationName','IPAddress')
    },
    @{
        Key = 'EVTX_Procesos'; RelPath = 'EVTX\EVTX_Procesos.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('ProcessName','CommandLine','Description')
    },
    @{
        Key = 'EVTX_NuevosServicios'; RelPath = 'EVTX\EVTX_NuevosServicios.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('ServiceName','Description')
    },
    @{
        Key = 'EVTX_PowerShell4104'; RelPath = 'EVTX\EVTX_PowerShell4104.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('ScriptBlock')
    },
    @{
        Key = 'EVTX_LogBorrado'; RelPath = 'EVTX\EVTX_LogBorrado.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('Description')
    },
    @{
        Key = 'Browser_Historial'; RelPath = 'Browsers\Browser_Historial.csv'; Dynamic = $false
        TimestampCol = 'FechaVisita'
        UserCols = @('Usuario'); PathCol = $null
        DescCols = @('Navegador','URL','Titulo','Visitas')
    },
    @{
        Key = 'Browser_Descargas'; RelPath = 'Browsers\Browser_Descargas.csv'; Dynamic = $false
        TimestampCol = 'Inicio'
        UserCols = @('Usuario'); PathCol = 'RutaDestino'
        DescCols = @('Navegador','RutaDestino','URLOrigen','TamanoBytes','TipoPeligro')
    },
    @{
        Key = 'Browser_Busquedas'; RelPath = 'Browsers\Browser_Busquedas.csv'; Dynamic = $false
        TimestampCol = 'Fecha'
        UserCols = @('Usuario'); PathCol = $null
        DescCols = @('Navegador','Busqueda','URL')
    },
    @{
        Key = 'MFT_Completo'; RelPath = 'MFT\MFT_Completo.csv'; Dynamic = $false
        TimestampCol = 'SI_Creado_UTC'
        UserCols = $null; PathCol = 'RutaCompleta'
        DescCols = @('Estado','NombreFichero','TamanoBytes','Timestomping')
    },
    @{
        Key = 'MFT_Borrados'; RelPath = 'MFT\MFT_Borrados.csv'; Dynamic = $false
        TimestampCol = 'SI_Modificado_UTC'
        UserCols = $null; PathCol = 'RutaCompleta'
        DescCols = @('NombreFichero','Estado','TamanoBytes')
    },
    @{
        Key = 'MFT_Timestomping'; RelPath = 'MFT\MFT_Timestomping.csv'; Dynamic = $false
        TimestampCol = 'FN_Modificado_UTC'
        UserCols = $null; PathCol = 'RutaCompleta'
        DescCols = @('NombreFichero','RazonTimestomp')
    },
    @{
        Key = 'Amcache_Ejecutables'; RelPath = 'MFT\Amcache_Ejecutables.csv'; Dynamic = $false
        # Sin columna de fecha: lo que guarda Amcache es la fecha de compilacion
        # (LinkDate) o de instalacion, nunca la de ejecucion. Antes se usaba como
        # fecha del hallazgo y se presentaba como "ejecucion" en esa fecha. Con un
        # filtro de fechas activo esta fuente no aporta filas.
        TimestampCol = $null; TimestampBestEffort = $true
        UserCols = $null; PathCol = 'RutaFichero'
        DescCols = @('Nombre','Publisher','SHA1','Version','FechaReferencia','TipoFecha')
    },
    @{
        Key = 'ShimCache_Completo'; RelPath = 'MFT\ShimCache_Completo.csv'; Dynamic = $true
        DynamicTimeHint = 'Time|TimeStamp|Fecha|timestamp'
        DynamicPathHint = 'Ruta|Path|FileName|Nombre'
        UserCols = $null; DescCols = @()
    },
    @{
        Key = 'USN_Borrados'; RelPath = 'MFT\USN_Borrados.csv'; Dynamic = $true
        Zona = 'hora local del equipo'   # fsutil escribe la hora local del equipo adquirido
        DynamicTimeHint = 'TimeStamp|Time|timestamp'
        DynamicPathHint = 'FileName|Name|filename'
        UserCols = $null; DescCols = @()
    },
    @{
        Key = 'USN_Renombrados'; RelPath = 'MFT\USN_Renombrados.csv'; Dynamic = $true
        Zona = 'hora local del equipo'   # fsutil escribe la hora local del equipo adquirido
        DynamicTimeHint = 'TimeStamp|Time|timestamp'
        DynamicPathHint = 'FileName|Name|filename'
        UserCols = $null; DescCols = @()
    },
    @{
        Key = 'USN_Ejecutables'; RelPath = 'MFT\USN_Ejecutables.csv'; Dynamic = $true
        Zona = 'hora local del equipo'   # fsutil escribe la hora local del equipo adquirido
        DynamicTimeHint = 'TimeStamp|Time|timestamp'
        DynamicPathHint = 'FileName|Name|filename'
        UserCols = $null; DescCols = @()
    },
    @{
        Key = 'USN_RutasSospechosas'; RelPath = 'MFT\USN_RutasSospechosas.csv'; Dynamic = $true
        Zona = 'hora local del equipo'   # fsutil escribe la hora local del equipo adquirido
        DynamicTimeHint = 'TimeStamp|Time|timestamp'
        DynamicPathHint = 'FileName|Name|filename'
        UserCols = $null; DescCols = @()
    }
)

# ── Categorias del wizard (paso 3) -> claves de $SC_SourceCatalog ────
$Script:SC_Categories = [ordered]@{
    'Sesiones'         = @{ Label = 'Inicios y cierres de sesion';                       Sources = @('EVTX_Logons','EVTX_FailedLogons') }
    'Programas'        = @{ Label = 'Programas ejecutados o registrados';                              Sources = @('EVTX_Procesos','Amcache_Ejecutables','ShimCache_Completo','USN_Ejecutables') }
    'Navegacion'       = @{ Label = 'Navegacion web (historial, descargas, busquedas)';   Sources = @('Browser_Historial','Browser_Descargas','Browser_Busquedas') }
    'Ficheros'         = @{ Label = 'Ficheros creados, borrados o renombrados';           Sources = @('MFT_Completo','MFT_Borrados','USN_Borrados','USN_Renombrados') }
    'Persistencia'     = @{ Label = 'Servicios nuevos y persistencia';                    Sources = @('EVTX_NuevosServicios') }
    'Manipulacion'     = @{ Label = 'Indicios de manipulacion (timestomping, log borrado)'; Sources = @('MFT_Timestomping','EVTX_LogBorrado') }
    'Scripts'          = @{ Label = 'Scripts de PowerShell ejecutados';                   Sources = @('EVTX_PowerShell4104') }
    'RutasSospechosas' = @{ Label = 'Actividad en rutas sospechosas (Temp, Descargas)';    Sources = @('USN_RutasSospechosas') }
}

function Get-SCSourceEntry {
    param([string]$Key)
    return $Script:SC_SourceCatalog | Where-Object { $_.Key -eq $Key } | Select-Object -First 1
}

function Get-SCSourcesForCategories {
    <# Devuelve la lista de Keys de fuente (sin duplicados) para un conjunto de categorias del wizard. #>
    param([string[]]$CategoryKeys)
    $keys = [System.Collections.Generic.List[string]]::new()
    foreach ($ck in $CategoryKeys) {
        if (-not $Script:SC_Categories.Contains($ck)) { continue }
        foreach ($sk in $Script:SC_Categories[$ck].Sources) {
            if (-not $keys.Contains($sk)) { $keys.Add($sk) }
        }
    }
    return $keys
}

#endregion
#endregion

#region ===== src\Query\UserInference.ps1 =====
#region ============================================================
# MaPeriT.SC - NORMALIZACION E INFERENCIA DE USUARIO
# No existe un campo "Usuario" comun entre fuentes de AN (confirmado
# leyendo el codigo: EVTX tiene TargetUser/SubjectUser, navegadores
# tienen Usuario, MFT/ShimCache/Amcache/USN no tienen ningun campo de
# usuario). Esta capa homogeneiza eso para el motor de consulta,
# marcando siempre si el usuario es Confirmado (viene de un campo del
# log) o Inferido (deducido de una ruta \Users\<usuario>\), porque esa
# distincion es la que sostiene la credibilidad pericial del hallazgo.
# ============================================================

# Sin exigir un caracter concreto antes de "Users": las rutas reales de
# MFT_Completo.csv en produccion vienen SIN letra de unidad ("Users\nombre\...",
# no "C:\Users\nombre\..."), y las de ficheros borrados llevan el prefijo
# "[BORRADO] " (espacio antes de "Users", no barra invertida). Exigir "\Users\"
# literal (con barra invertida obligatoria delante) dejaba SIEMPRE sin
# resolver el usuario en MFT/Amcache/ShimCache/USN reales - confirmado en
# produccion contra un caso real donde MFT_Completo tenia 9698 coincidencias
# sin filtro de usuario y 0 con filtro, porque la inferencia nunca acertaba.
$Script:SC_UserPathRegex = '(?i)(?<![\w])Users\\([^\\]+)\\'

function Get-SCUserFromPath {
    param([string]$PathValue)
    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
    if ($PathValue -match $Script:SC_UserPathRegex) {
        $u = $Matches[1]
        # Descartar perfiles de sistema, no son "usuarios" investigables
        if ($u -in @('Public','Default','Default User','All Users')) { return $null }
        return $u
    }
    return $null
}

$Script:SC_SystemAccountNames = @(
    'SYSTEM','SERVICIO LOCAL','LOCAL SERVICE','SERVICIO DE RED','NETWORK SERVICE',
    'ANONYMOUS LOGON','DESCONOCIDO','UNKNOWN','-'
    # 'USUARIO', 'INVITADO' y 'GUEST' ya no se ocultan: son cuentas reales (una cuenta
    # local llamada "Usuario" es muy comun en Windows en espanol) y su actividad
    # puede ser relevante.
)
$Script:SC_SystemAccountPatterns = @(
    '^DWM-\d+$',                                     # Desktop Window Manager por sesion
    '^UMFD-\d+$',                                     # User Mode Font Driver por sesion
    '.*\$$',                                           # cuentas de equipo (NOMBRE-PC$)
    '^S-1-\d+(-\d+)*$',                                # SID crudo sin resolver
    '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',  # GUID
    '.*TESTACCOUNT.*'                                  # cuentas de prueba internas de Windows (SMB2GuestTestAccount, etc.)
)

function Test-SCIsRealUser {
    <#
    Filtra cuentas de sistema/servicio/equipo de la lista de usuarios
    SELECCIONABLES del asistente (paso 2). No afecta a Resolve-SCRowUser: un
    hallazgo real con TargetUser=SYSTEM sigue siendo un dato correcto y
    consultable si alguien lo busca explicitamente, esto solo evita que la
    lista de "elige un usuario" se llene de ruido no investigable para un
    usuario sin conocimientos tecnicos (confirmado en un caso real: 23
    cuentas detectadas, mas de la mitad eran SYSTEM/DWM/UMFD/SIDs/GUIDs).
    #>
    param([string]$UserName)
    if ([string]::IsNullOrWhiteSpace($UserName)) { return $false }
    $u = $UserName.Trim()
    if ($Script:SC_SystemAccountNames -contains $u.ToUpperInvariant()) { return $false }
    foreach ($pat in $Script:SC_SystemAccountPatterns) {
        if ($u -match $pat) { return $false }
    }
    return $true
}

function Resolve-SCRowUser {
    <#
    Devuelve [PSCustomObject]@{ Usuario = <string|""> ; Confianza = 'Confirmado'|'Inferido'|'NoDisponible' }
    a partir de una fila (DataRow/PSCustomObject) y la entrada de esquema de su fuente.
    #>
    param(
        [Parameter(Mandatory)] $Row,
        [Parameter(Mandatory)] [hashtable]$SourceEntry,
        [string]$ResolvedPathCol = $null   # para fuentes Dynamic, columna de ruta ya detectada en runtime
    )

    if ($SourceEntry.UserCols) {
        foreach ($col in $SourceEntry.UserCols) {
            $v = $Row.$col
            if (-not [string]::IsNullOrWhiteSpace($v) -and $v -ne 'desconocido') {
                return [PSCustomObject]@{ Usuario = $v.Trim(); Confianza = 'Confirmado' }
            }
        }
    }

    $pathCol = if ($SourceEntry.Dynamic) { $ResolvedPathCol } else { $SourceEntry.PathCol }
    if ($pathCol) {
        $pv = $Row.$pathCol
        $inferred = Get-SCUserFromPath -PathValue $pv
        if ($inferred) {
            return [PSCustomObject]@{ Usuario = $inferred; Confianza = 'Inferido' }
        }
    }

    return [PSCustomObject]@{ Usuario = ''; Confianza = 'NoDisponible' }
}

#endregion
#endregion

#region ===== src\Query\QueryEngine.ps1 =====
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
#endregion

#region ===== src\Report\ReportTemplates.ps1 =====
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
#endregion

#region ===== src\Report\ReportPericial.ps1 =====
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
#endregion

#region ===== src\Report\ReportLlano.ps1 =====
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
#endregion

#region ===== src\UI\XAML.ps1 =====
#region ============================================================
# MaPeriT.SC - VENTANA PRINCIPAL (shell fijo en XAML)
# El contenido de cada paso del asistente se construye por codigo
# (Wizard.ps1) y se inyecta en ContentHost - mismo patron mixto que
# usa MaPeriT.TN (shell XAML + contenido dinamico por codigo).
# ============================================================

function Get-SCMainWindowXAML {
    $c = $Script:Colors
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$($Script:SC_FullTitle)"
        Width="960" Height="680" MinWidth="860" MinHeight="560"
        WindowStartupLocation="CenterScreen"
        Background="$($c.BgPrimary)"
        FontFamily="Segoe UI">
  <Window.Resources>
    <Style x:Key="SCBtn" TargetType="Button">
      <Setter Property="Padding" Value="18,9"/>
      <Setter Property="Background" Value="$($c.BgCard)"/>
      <Setter Property="Foreground" Value="$($c.Text)"/>
      <Setter Property="BorderBrush" Value="$($c.Border)"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="$($c.BgPanel)"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SCBtnPrimary" TargetType="Button" BasedOn="{StaticResource SCBtn}">
      <Setter Property="Background" Value="$($c.Accent)"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="$($c.AccentHover)"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="$($c.Text)"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Margin" Value="0,4"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="BorderBrush" Value="$($c.Border)"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="Foreground" Value="$($c.Text)"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Cabecera -->
    <Border Grid.Row="0" Background="$($c.BgHeader)" Padding="28,18">
      <StackPanel>
        <TextBlock Text="MaPeriT.SC" Foreground="White" FontSize="22" FontWeight="Light"/>
        <TextBlock x:Name="StepIndicatorText" Text="Paso 1" Foreground="#93C5FD" FontSize="12" Margin="0,4,0,0"/>
      </StackPanel>
    </Border>

    <!-- Contenido del paso actual -->
    <Border Grid.Row="1" x:Name="ContentHost" Padding="32,24" Background="$($c.BgPrimary)"/>

    <!-- Pie: navegacion -->
    <Border Grid.Row="2" Background="$($c.BgCard)" BorderBrush="$($c.Border)" BorderThickness="0,1,0,0" Padding="28,16">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="StatusText" Text="" Foreground="$($c.TextMuted)" FontSize="12" VerticalAlignment="Center"/>
          <ProgressBar x:Name="WizardProgressBar" Width="220" Height="14" Margin="14,0,0,0" Visibility="Collapsed" Minimum="0" Maximum="100"/>
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal">
          <Button x:Name="BtnCancel" Content="Cancelar" Style="{StaticResource SCBtn}" Margin="0,0,8,0"/>
          <Button x:Name="BtnBack" Content="&lt; Atras" Style="{StaticResource SCBtn}" Margin="0,0,8,0"/>
          <Button x:Name="BtnNext" Content="Siguiente &gt;" Style="{StaticResource SCBtnPrimary}"/>
        </StackPanel>
      </Grid>
    </Border>
  </Grid>
</Window>
"@
}

#endregion
#endregion

#region ===== src\UI\Wizard.ps1 =====
#region ============================================================
# MaPeriT.SC - ASISTENTE POR PASOS
# Shell fijo en XAML.ps1, cada paso se construye por codigo y se
# inyecta en ContentHost. Estado del asistente en $Script:SCWizard.
# ============================================================

$Script:SCWizard = @{
    Controls  = @{}
    StepOrder = @('Project','Users','Categories','DateTime','Keyword','Summary','Results','Reports')
    StepIndex = 0
    State     = @{
        ProjectPath       = ""
        KnownUsers        = @()
        SelectedUsers     = @()
        SelectedCategories= @()
        DateFrom          = $null
        DateTo            = $null
        TimeFrom          = $null
        TimeTo            = $null
        Keyword           = ""
        ExcludeKeyword    = ""
        QueryResults      = @()
        QuerySummary      = $null
        ReportOutputDir   = ""
        ReportPaths       = @()
    }
}

$Script:SCStepTitles = [ordered]@{
    Project    = "Paso 1 de 8 · Proyecto"
    Users      = "Paso 2 de 8 · Ambito de usuario"
    Categories = "Paso 3 de 8 · Categorias de interes"
    DateTime   = "Paso 4 de 8 · Ventana temporal"
    Keyword    = "Paso 5 de 8 · Palabra clave (opcional)"
    Summary    = "Paso 6 de 8 · Resumen y confirmacion"
    Results    = "Paso 7 de 8 · Resultados"
    Reports    = "Paso 8 de 8 · Informes"
}

# ── Helpers de construccion de UI ─────────────────────────────────────

function Get-SCStyle { param([string]$Name) return $Script:SCWizard.Controls.Window.FindResource($Name) }

# ── Plantillas de busqueda (guardar/cargar criterios entre casos) ────────
# No incluyen Usuarios: la lista de usuarios se detecta por proyecto y no
# tiene sentido reutilizarla entre casos distintos.

function Get-SCSavedTemplates {
    if (-not (Test-Path $Script:SC_TemplatesDir)) { return @() }
    return @(Get-ChildItem $Script:SC_TemplatesDir -Filter *.json -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { $_.BaseName })
}

function Save-SCTemplate {
    param([string]$Name)
    $safe = ($Name -replace '[\\/:*?"<>|]', '_').Trim()
    if (-not $safe) { return $null }
    if (-not (Test-Path $Script:SC_TemplatesDir)) { New-Item -ItemType Directory -Path $Script:SC_TemplatesDir -Force | Out-Null }
    $data = [PSCustomObject]@{
        Categorias     = @($Script:SCWizard.State.SelectedCategories)
        DateFrom       = if ($Script:SCWizard.State.DateFrom) { $Script:SCWizard.State.DateFrom.ToString("o") } else { $null }
        DateTo         = if ($Script:SCWizard.State.DateTo)   { $Script:SCWizard.State.DateTo.ToString("o") }   else { $null }
        TimeFrom       = if ($Script:SCWizard.State.TimeFrom) { $Script:SCWizard.State.TimeFrom.ToString() }    else { $null }
        TimeTo         = if ($Script:SCWizard.State.TimeTo)   { $Script:SCWizard.State.TimeTo.ToString() }      else { $null }
        Keyword        = $Script:SCWizard.State.Keyword
        ExcludeKeyword = $Script:SCWizard.State.ExcludeKeyword
    }
    $path = Join-Path $Script:SC_TemplatesDir "$safe.json"
    $data | ConvertTo-Json | Set-Content -Path $path -Encoding UTF8
    return $path
}

function Import-SCTemplate {
    param([string]$Name)
    $path = Join-Path $Script:SC_TemplatesDir "$Name.json"
    if (-not (Test-Path $path)) { return $false }
    try { $data = Get-Content $path -Raw | ConvertFrom-Json } catch { return $false }
    $Script:SCWizard.State.SelectedCategories = @($data.Categorias)
    $Script:SCWizard.State.DateFrom       = if ($data.DateFrom) { [datetime]$data.DateFrom } else { $null }
    $Script:SCWizard.State.DateTo         = if ($data.DateTo)   { [datetime]$data.DateTo }   else { $null }
    $Script:SCWizard.State.TimeFrom       = if ($data.TimeFrom) { [TimeSpan]::Parse($data.TimeFrom) } else { $null }
    $Script:SCWizard.State.TimeTo         = if ($data.TimeTo)   { [TimeSpan]::Parse($data.TimeTo) }   else { $null }
    $Script:SCWizard.State.Keyword        = "$($data.Keyword)"
    $Script:SCWizard.State.ExcludeKeyword = "$($data.ExcludeKeyword)"
    return $true
}

function New-SCHeading {
    param([string]$Text)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 19
    $tb.FontWeight = 'SemiBold'
    $tb.Foreground = New-WpfBrush $Script:Colors.Text
    $tb.Margin = [System.Windows.Thickness]::new(0,0,0,6)
    return $tb
}

function New-SCParagraph {
    param([string]$Text)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 13
    $tb.TextWrapping = 'Wrap'
    $tb.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $tb.Margin = [System.Windows.Thickness]::new(0,0,0,4)
    return $tb
}

function New-SCLabel {
    param([string]$Text, [switch]$Bold)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 12.5
    if ($Bold) { $tb.FontWeight = 'SemiBold' }
    $tb.Foreground = New-WpfBrush $Script:Colors.Text
    $tb.Margin = [System.Windows.Thickness]::new(0,10,0,4)
    return $tb
}

function New-SCCheckList {
    <# Items: array de @{ Value=""; Label="" }. Devuelve StackPanel con CheckBox.Tag=Value #>
    param([array]$Items, [string[]]$CheckedValues = @())
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = [System.Windows.Thickness]::new(0,4,0,4)
    foreach ($it in $Items) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $it.Label
        $cb.Tag = $it.Value
        if ($CheckedValues -contains $it.Value) { $cb.IsChecked = $true }
        [void]$sp.Children.Add($cb)
    }
    return $sp
}

function Get-SCCheckedValues {
    param($Panel)
    $vals = [System.Collections.Generic.List[string]]::new()
    foreach ($child in $Panel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) { $vals.Add([string]$child.Tag) }
    }
    return @($vals)
}

function Set-SCValidationError {
    param([string]$Message)
    $st = $Script:SCWizard.Controls.StatusText
    $st.Text = $Message
    $st.Foreground = New-WpfBrush $Script:Colors.Danger
}

function Clear-SCValidationError {
    $st = $Script:SCWizard.Controls.StatusText
    $st.Text = ""
    $st.Foreground = New-WpfBrush $Script:Colors.TextMuted
}

function Set-SCBusy {
    param([string]$Message)
    $ctrl = $Script:SCWizard.Controls
    $ctrl.StatusText.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $ctrl.StatusText.Text = $Message
    $ctrl.WizardProgressBar.Visibility = 'Visible'
    $ctrl.WizardProgressBar.Value = 0
    $ctrl.BtnNext.IsEnabled = $false
    $ctrl.BtnBack.IsEnabled = $false
}

function Clear-SCBusy {
    $ctrl = $Script:SCWizard.Controls
    $ctrl.WizardProgressBar.Visibility = 'Collapsed'
    $ctrl.StatusText.Text = ""
    $ctrl.BtnNext.IsEnabled = $true
    $ctrl.BtnBack.IsEnabled = $true
}

function Set-SCProgressText {
    param([string]$Text, [int]$Current = -1, [int]$Total = -1)
    $ctrl = $Script:SCWizard.Controls
    $ctrl.StatusText.Text = $Text
    if ($Total -gt 0) {
        $ctrl.WizardProgressBar.Maximum = $Total
        $ctrl.WizardProgressBar.Value = $Current
    }
}

# ── Paso 1: Proyecto ──────────────────────────────────────────────────

function Show-SCStepProject {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Selecciona el proyecto"))
    [void]$panel.Children.Add((New-SCParagraph "Elige la carpeta de evidencias generada por MaPeriT.SW u OF sobre la que ya se haya ejecutado MaPeriT.AN. Debe contener la subcarpeta ANALISIS_AN."))

    $row = New-Object System.Windows.Controls.Grid
    $row.Margin = [System.Windows.Thickness]::new(0,16,0,0)
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $c2.Width = [System.Windows.GridLength]::Auto
    [void]$row.ColumnDefinitions.Add($c1)
    [void]$row.ColumnDefinitions.Add($c2)

    $box = New-Object System.Windows.Controls.TextBox
    $box.Text = $Script:SCWizard.State.ProjectPath
    $box.VerticalContentAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($box,0)
    [void]$row.Children.Add($box)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "Examinar..."
    $btn.Style = (Get-SCStyle "SCBtn")
    $btn.Margin = [System.Windows.Thickness]::new(8,0,0,0)
    [System.Windows.Controls.Grid]::SetColumn($btn,1)
    $btn.Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Selecciona la carpeta de evidencias (con ANALISIS_AN dentro)"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $Script:SCWizard.Controls.ProjectPathBox.Text = $dlg.SelectedPath
        }
    })
    [void]$row.Children.Add($btn)
    [void]$panel.Children.Add($row)

    $Script:SCWizard.Controls.ProjectPathBox = $box
    return $panel
}

# ── Paso 2: Usuarios ──────────────────────────────────────────────────

function Show-SCStepUsers {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Ambito de usuario"))
    [void]$panel.Children.Add((New-SCParagraph "Elige 'Todos los usuarios' o selecciona uno o varios usuarios concretos detectados en este proyecto (sesiones de Windows y navegadores)."))

    $items = [System.Collections.Generic.List[object]]::new()
    $items.Add(@{ Value = '__ALL__'; Label = 'Todos los usuarios' })
    foreach ($u in $Script:SCWizard.State.KnownUsers) { $items.Add(@{ Value = $u; Label = $u }) }
    if ($Script:SCWizard.State.KnownUsers.Count -eq 0) {
        [void]$panel.Children.Add((New-SCParagraph "No se ha detectado ningun usuario en sesiones ni navegadores de este proyecto. Puedes continuar con 'Todos los usuarios'; los hallazgos sin usuario asociado se marcaran como tal."))
    }

    $checked = if ($Script:SCWizard.State.SelectedUsers.Count -eq 0) { @('__ALL__') } else { $Script:SCWizard.State.SelectedUsers }
    $list = New-SCCheckList -Items $items -CheckedValues $checked
    [void]$panel.Children.Add($list)
    $Script:SCWizard.Controls.UsersPanel = $list
    return $panel
}

# ── Paso 3: Categorias ────────────────────────────────────────────────

function Show-SCStepCategories {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Categorias de interes"))
    [void]$panel.Children.Add((New-SCParagraph "Selecciona sobre que tipo de actividad quieres consultar. Puedes marcar varias."))

    $templates = Get-SCSavedTemplates
    if ($templates.Count -gt 0) {
        [void]$panel.Children.Add((New-SCLabel "Cargar una plantilla guardada (opcional):" -Bold))
        $tplRow = New-Object System.Windows.Controls.StackPanel
        $tplRow.Orientation = 'Horizontal'
        $tplRow.Margin = [System.Windows.Thickness]::new(0,4,0,16)
        $tplCombo = New-Object System.Windows.Controls.ComboBox
        $tplCombo.Width = 220
        foreach ($t in $templates) { [void]$tplCombo.Items.Add($t) }
        $tplCombo.SelectedIndex = 0
        [void]$tplRow.Children.Add($tplCombo)
        $Script:SCWizard.Controls.TemplateCombo = $tplCombo
        $tplBtn = New-Object System.Windows.Controls.Button
        $tplBtn.Content = "Cargar"
        $tplBtn.Style = (Get-SCStyle "SCBtn")
        $tplBtn.Margin = [System.Windows.Thickness]::new(8,0,0,0)
        $tplBtn.Add_Click({
            $name = $Script:SCWizard.Controls.TemplateCombo.SelectedItem
            if ($name -and (Import-SCTemplate -Name $name)) {
                Render-SCStep
            }
        })
        [void]$tplRow.Children.Add($tplBtn)
        [void]$panel.Children.Add($tplRow)
    }

    $items = foreach ($key in $Script:SC_Categories.Keys) { @{ Value = $key; Label = $Script:SC_Categories[$key].Label } }
    $list = New-SCCheckList -Items $items -CheckedValues $Script:SCWizard.State.SelectedCategories
    [void]$panel.Children.Add($list)
    $Script:SCWizard.Controls.CategoriesPanel = $list
    return $panel
}

# ── Paso 4: Ventana temporal ──────────────────────────────────────────

function Show-SCStepDateTime {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Ventana temporal"))
    [void]$panel.Children.Add((New-SCParagraph "Rango de fechas (opcional, deja en blanco para no limitar) y, si quieres, una franja horaria recurrente dentro de ese rango. Las horas se comparan tal como las guarda cada fuente: en UTC, salvo el registro de cambios de ficheros (USN), que va en la hora local del equipo analizado."))

    $dateRow = New-Object System.Windows.Controls.StackPanel
    $dateRow.Orientation = 'Horizontal'
    $dateRow.Margin = [System.Windows.Thickness]::new(0,12,0,0)

    $lblFrom = New-Object System.Windows.Controls.TextBlock
    $lblFrom.Text = "Desde:"; $lblFrom.VerticalAlignment = 'Center'; $lblFrom.Margin = [System.Windows.Thickness]::new(0,0,8,0)
    [void]$dateRow.Children.Add($lblFrom)
    $dpFrom = New-Object System.Windows.Controls.DatePicker
    $dpFrom.Width = 150
    if ($Script:SCWizard.State.DateFrom) { $dpFrom.SelectedDate = $Script:SCWizard.State.DateFrom }
    [void]$dateRow.Children.Add($dpFrom)

    $lblTo = New-Object System.Windows.Controls.TextBlock
    $lblTo.Text = "Hasta:"; $lblTo.VerticalAlignment = 'Center'; $lblTo.Margin = [System.Windows.Thickness]::new(20,0,8,0)
    [void]$dateRow.Children.Add($lblTo)
    $dpTo = New-Object System.Windows.Controls.DatePicker
    $dpTo.Width = 150
    if ($Script:SCWizard.State.DateTo) { $dpTo.SelectedDate = $Script:SCWizard.State.DateTo }
    [void]$dateRow.Children.Add($dpTo)

    [void]$panel.Children.Add($dateRow)

    $useTime = New-Object System.Windows.Controls.CheckBox
    $useTime.Content = "Limitar ademas a una franja horaria recurrente (por ejemplo, de 23:00 a 06:00 en cualquier dia del rango)"
    $useTime.Margin = [System.Windows.Thickness]::new(0,18,0,4)
    $useTime.IsChecked = [bool]($Script:SCWizard.State.TimeFrom)
    [void]$panel.Children.Add($useTime)

    $timeRow = New-Object System.Windows.Controls.StackPanel
    $timeRow.Orientation = 'Horizontal'
    $timeRow.Margin = [System.Windows.Thickness]::new(0,4,0,0)

    $lblTf = New-Object System.Windows.Controls.TextBlock
    $lblTf.Text = "Hora inicio (HH:mm):"; $lblTf.VerticalAlignment = 'Center'; $lblTf.Margin = [System.Windows.Thickness]::new(0,0,8,0)
    [void]$timeRow.Children.Add($lblTf)
    $tbFrom = New-Object System.Windows.Controls.TextBox
    $tbFrom.Width = 70
    $tbFrom.Text = if ($Script:SCWizard.State.TimeFrom) { $Script:SCWizard.State.TimeFrom.ToString("hh\:mm") } else { "23:00" }
    [void]$timeRow.Children.Add($tbFrom)

    $lblTt = New-Object System.Windows.Controls.TextBlock
    $lblTt.Text = "Hora fin (HH:mm):"; $lblTt.VerticalAlignment = 'Center'; $lblTt.Margin = [System.Windows.Thickness]::new(20,0,8,0)
    [void]$timeRow.Children.Add($lblTt)
    $tbTo = New-Object System.Windows.Controls.TextBox
    $tbTo.Width = 70
    $tbTo.Text = if ($Script:SCWizard.State.TimeTo) { $Script:SCWizard.State.TimeTo.ToString("hh\:mm") } else { "06:00" }
    [void]$timeRow.Children.Add($tbTo)

    [void]$panel.Children.Add($timeRow)

    $Script:SCWizard.Controls.DateFromPicker    = $dpFrom
    $Script:SCWizard.Controls.DateToPicker      = $dpTo
    $Script:SCWizard.Controls.UseTimeWindowCheck= $useTime
    $Script:SCWizard.Controls.TimeFromBox       = $tbFrom
    $Script:SCWizard.Controls.TimeToBox         = $tbTo
    return $panel
}

# ── Paso 5: Palabra clave ─────────────────────────────────────────────

function Show-SCStepKeyword {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Palabra clave (opcional)"))
    [void]$panel.Children.Add((New-SCParagraph "Si buscas algo concreto (nombre de un programa, una web, un fichero...) escribelo aqui. Se buscara dentro de la descripcion de cada hallazgo. Dejalo en blanco para no filtrar."))
    $box = New-Object System.Windows.Controls.TextBox
    $box.Margin = [System.Windows.Thickness]::new(0,12,0,0)
    $box.Text = $Script:SCWizard.State.Keyword
    [void]$panel.Children.Add($box)
    $Script:SCWizard.Controls.KeywordBox = $box

    [void]$panel.Children.Add((New-SCLabel "Excluir si contiene (opcional)" -Bold))
    [void]$panel.Children.Add((New-SCParagraph "Independiente de lo anterior: cualquier hallazgo cuya descripcion contenga este texto se descarta. Util para quitar ruido conocido (por ejemplo, 'OneDrive\logs' o '.tmp'). Dejalo en blanco para no excluir nada."))
    $exBox = New-Object System.Windows.Controls.TextBox
    $exBox.Margin = [System.Windows.Thickness]::new(0,4,0,0)
    $exBox.Text = $Script:SCWizard.State.ExcludeKeyword
    [void]$panel.Children.Add($exBox)
    $Script:SCWizard.Controls.ExcludeKeywordBox = $exBox

    return $panel
}

# ── Paso 6: Resumen y confirmacion ────────────────────────────────────

function Show-SCStepSummary {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Resumen de la consulta"))
    [void]$panel.Children.Add((New-SCParagraph "Revisa los criterios antes de ejecutar la consulta. Se indica que fuentes de datos se van a consultar y cuales no estan disponibles en este proyecto."))

    # Guardar plantilla arriba del todo: si no vas a revisar el resto del
    # resumen, este bloque debe verse sin necesidad de bajar (ContentHost no
    # tiene scroll, y este paso puede ser largo).
    [void]$panel.Children.Add((New-SCLabel "Guardar estos criterios como plantilla (opcional):" -Bold))
    [void]$panel.Children.Add((New-SCParagraph "Guarda categorias, fechas, franja horaria y palabras clave (no el usuario, que depende de cada proyecto) para poder reutilizarlos en otro caso desde el paso de Categorias."))
    $saveRow = New-Object System.Windows.Controls.Grid
    $saveRow.Margin = [System.Windows.Thickness]::new(0,4,0,18)
    $sc1 = New-Object System.Windows.Controls.ColumnDefinition; $sc1.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $sc2 = New-Object System.Windows.Controls.ColumnDefinition; $sc2.Width = [System.Windows.GridLength]::Auto
    [void]$saveRow.ColumnDefinitions.Add($sc1); [void]$saveRow.ColumnDefinitions.Add($sc2)
    $nameBox = New-Object System.Windows.Controls.TextBox
    $nameBox.VerticalContentAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($nameBox,0)
    [void]$saveRow.Children.Add($nameBox)
    $Script:SCWizard.Controls.TemplateNameBox = $nameBox
    $saveBtn = New-Object System.Windows.Controls.Button
    $saveBtn.Content = "Guardar plantilla"
    $saveBtn.Style = (Get-SCStyle "SCBtn")
    $saveBtn.Margin = [System.Windows.Thickness]::new(8,0,0,0)
    [System.Windows.Controls.Grid]::SetColumn($saveBtn,1)
    $saveBtn.Add_Click({
        $n = $Script:SCWizard.Controls.TemplateNameBox.Text.Trim()
        if (-not $n) { Set-SCValidationError "Escribe un nombre para la plantilla."; return }
        $p = Save-SCTemplate -Name $n
        if ($p) { Set-SCProgressText -Text "Plantilla guardada: $p" } else { Set-SCValidationError "No se pudo guardar la plantilla." }
    })
    [void]$saveRow.Children.Add($saveBtn)
    [void]$panel.Children.Add($saveRow)

    $usersTxt = if ($Script:SCWizard.State.SelectedUsers.Count -eq 0 -or $Script:SCWizard.State.SelectedUsers -contains '__ALL__') { "Todos los usuarios" } else { $Script:SCWizard.State.SelectedUsers -join ', ' }
    $catsTxt  = ($Script:SCWizard.State.SelectedCategories | ForEach-Object { $Script:SC_Categories[$_].Label }) -join '; '
    $fromTxt  = if ($Script:SCWizard.State.DateFrom) { $Script:SCWizard.State.DateFrom.ToString("dd/MM/yyyy") } else { "(sin limite)" }
    $toTxt    = if ($Script:SCWizard.State.DateTo)   { $Script:SCWizard.State.DateTo.ToString("dd/MM/yyyy") }   else { "(sin limite)" }
    $timeTxt  = if ($Script:SCWizard.State.TimeFrom) { "$($Script:SCWizard.State.TimeFrom.ToString('hh\:mm')) - $($Script:SCWizard.State.TimeTo.ToString('hh\:mm')) (todos los dias del rango)" } else { "(sin restriccion horaria)" }
    $kwTxt    = if ($Script:SCWizard.State.Keyword) { $Script:SCWizard.State.Keyword } else { "(ninguna)" }
    $exKwTxt  = if ($Script:SCWizard.State.ExcludeKeyword) { $Script:SCWizard.State.ExcludeKeyword } else { "(ninguna)" }

    [void]$panel.Children.Add((New-SCLabel "Usuario(s):" -Bold))
    [void]$panel.Children.Add((New-SCParagraph $usersTxt))
    [void]$panel.Children.Add((New-SCLabel "Categorias:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph $catsTxt))
    [void]$panel.Children.Add((New-SCLabel "Rango de fechas:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph "$fromTxt a $toTxt"))
    [void]$panel.Children.Add((New-SCLabel "Franja horaria:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph $timeTxt))
    [void]$panel.Children.Add((New-SCLabel "Palabra clave:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph $kwTxt))
    [void]$panel.Children.Add((New-SCLabel "Excluir si contiene:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph $exKwTxt))

    $sourceKeys = Get-SCSourcesForCategories -CategoryKeys $Script:SCWizard.State.SelectedCategories
    $available  = [System.Collections.Generic.List[string]]::new()
    $missing    = [System.Collections.Generic.List[string]]::new()
    foreach ($k in $sourceKeys) {
        $entry = Get-SCSourceEntry -Key $k
        $p = Join-Path $Script:SCSession.ANOutputPath $entry.RelPath
        if (Test-Path $p) { $available.Add($k) } else { $missing.Add($k) }
    }

    [void]$panel.Children.Add((New-SCLabel "Fuentes que se consultaran:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph ($(if ($available.Count -gt 0) { $available -join ', ' } else { '(ninguna disponible)' }))))
    if ($missing.Count -gt 0) {
        $warn = New-SCParagraph ("No disponibles en este proyecto (se omiten): " + ($missing -join ', '))
        $warn.Foreground = New-WpfBrush $Script:Colors.Warning
        [void]$panel.Children.Add($warn)
    }

    return $panel
}

# ── Paso 7: Resultados ────────────────────────────────────────────────

function Show-SCStepResults {
    # Cachear el panel entero (DataGrid + DataTable ya construidos) y
    # reutilizarlo tal cual al volver a este paso, en vez de reconstruirlo:
    # WPF permite reasignar el mismo elemento visual a un padre distinto sin
    # problema. Reconstruir la tabla de resultados de cero cada vez que se
    # vuelve atras desde "Informes" reexpone, en cada reconstruccion, el bug
    # de WPF (DataGridItemAttachedStorage, ver Main.ps1) ligado a timing del
    # GC - confirmado que cuantas mas veces se repite la construccion, mas
    # probable es que salte. La cache se invalida en Start-SCFullQuery cuando
    # se ejecuta una consulta nueva.
    if ($Script:SCWizard.Controls.ResultsPanelCache) {
        return $Script:SCWizard.Controls.ResultsPanelCache
    }

    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Resultados"))

    $n = $Script:SCWizard.State.QueryResults.Count
    $summary = $Script:SCWizard.State.QuerySummary
    $infoTxt = "$n hallazgo(s). Desmarca los que no quieras incluir en los informes finales."
    [void]$panel.Children.Add((New-SCParagraph $infoTxt))
    if ($summary -and $summary.TotalFilasSinUsuarioAsociado -gt 0) {
        [void]$panel.Children.Add((New-SCParagraph "Nota: $($summary.TotalFilasSinUsuarioAsociado) fila(s) evaluadas no tenian usuario asociado en su fuente de origen."))
    }

    $onlyConfirmedCheck = New-Object System.Windows.Controls.CheckBox
    $onlyConfirmedCheck.Content = "Mostrar solo Confianza = Confirmado (oculta los de usuario inferido, sin desmarcar su inclusion)"
    $onlyConfirmedCheck.Margin = [System.Windows.Thickness]::new(0,4,0,0)
    [void]$panel.Children.Add($onlyConfirmedCheck)
    $Script:SCWizard.Controls.OnlyConfirmedCheck = $onlyConfirmedCheck

    $grid = New-Object System.Windows.Controls.DataGrid
    $grid.Height = 340
    $grid.AutoGenerateColumns = $false
    $grid.CanUserAddRows = $false
    $grid.IsReadOnly = $false
    $grid.RowHeaderWidth = 0
    $grid.GridLinesVisibility = 'Horizontal'
    $grid.Margin = [System.Windows.Thickness]::new(0,10,0,0)
    # RowDetailsVisibilityMode a Collapsed (no se usa RowDetailsTemplate en
    # este grid): por defecto WPF usa VisibleWhenSelected, que activa el
    # seguimiento interno de DataGridItemAttachedStorage por cada fila. Ese
    # seguimiento tiene un bug conocido de WPF: TryGetValue puede lanzar
    # ArgumentNullException("key") al preparar/reciclar filas con volumenes
    # grandes. Como salta dentro del callback de render de Windows, no es una
    # excepcion manejable: mata el proceso con STATUS_FATAL_USER_CALLBACK_EXCEPTION.
    # Al no usar detalles de fila, se desactiva ese seguimiento por completo.
    $grid.RowDetailsVisibilityMode = [System.Windows.Controls.DataGridRowDetailsVisibilityMode]::Collapsed
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($grid, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($grid, 'Standard')

    # Anchos FIJOS en todas las columnas, nunca Auto: con miles de filas y
    # valores de alta cardinalidad (p.ej. una fecha distinta por fila), un
    # ancho Auto obliga a WPF a medir el contenido de cada fila para calcular
    # el ancho de columna, lo que fuerza preparar muchos mas contenedores de
    # fila de los que la virtualizacion normalmente realizaria - y ese camino
    # (DataGridRow.PrepareRow) es exactamente donde se dispara el bug conocido
    # de WPF que lanza ArgumentNullException("key") y mata el proceso entero.
    # Reproducido y confirmado: con valores de baja cardinalidad (pocos
    # valores distintos repetidos) el bug no aparecia; con 15000 fechas
    # distintas en una columna Auto, se disparaba siempre.
    $colWidths = @{ Fecha = 150; Fuente = 130; Usuario = 130; Confianza = 100; Descripcion = 260; Origen = 220 }
    $colChk = New-Object System.Windows.Controls.DataGridCheckBoxColumn
    $colChk.Header = "Incluir"; $colChk.Binding = New-Object System.Windows.Data.Binding("Incluir"); $colChk.Binding.Mode = 'TwoWay'
    [void]$grid.Columns.Add($colChk)
    foreach ($colName in @('Fecha','Fuente','Usuario','Confianza','Descripcion','Origen')) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header = $colName
        $col.Binding = New-Object System.Windows.Data.Binding($colName)
        $col.Width = $colWidths[$colName]
        [void]$grid.Columns.Add($col)
    }

    # Poblacion de la DataTable EN LINEA (no como llamada a funcion aparte):
    # reproducido y confirmado que llamar a esta misma logica a traves de una
    # funcion separada (con su propio scope/parametros) hacia mucho mas
    # probable el bug de WPF descrito en Main.ps1 sobre DataGridItemAttachedStorage
    # con volumenes grandes de filas - probablemente por la presion adicional
    # de recolector de basura que genera cada llamada a funcion. En linea,
    # con el manejador global de Main.ps1 como red de seguridad adicional.
    $tbl = [System.Data.DataTable]::new("SCResults")
    [void]$tbl.Columns.Add("Incluir", [bool])
    [void]$tbl.Columns.Add("Fecha", [string])
    [void]$tbl.Columns.Add("Fuente", [string])
    [void]$tbl.Columns.Add("Usuario", [string])
    [void]$tbl.Columns.Add("Confianza", [string])
    [void]$tbl.Columns.Add("Descripcion", [string])
    [void]$tbl.Columns.Add("Origen", [string])
    foreach ($r in $Script:SCWizard.State.QueryResults) {
        $row = $tbl.NewRow()
        $row["Incluir"]     = [bool]$r.Incluir
        $row["Fecha"]       = Format-SCFecha $r
        $row["Fuente"]      = $r.Fuente
        $row["Usuario"]     = if ($r.Usuario) { $r.Usuario } else { "(sin usuario asociado)" }
        $row["Confianza"]   = $r.Confianza
        $row["Descripcion"] = $r.Descripcion
        $row["Origen"]      = $r.Origen
        [void]$tbl.Rows.Add($row)
    }
    $grid.ItemsSource = $tbl.DefaultView

    # El filtro solo cambia que filas se VEN (DataView.RowFilter); la
    # DataTable subyacente y su columna "Incluir" no se tocan, asi que
    # Save-SCResultsSelection (que recorre $tbl.Rows por indice) sigue
    # funcionando igual este o no activo el filtro.
    $onlyConfirmedCheck.Add_Click({
        $t = $Script:SCWizard.Controls.ResultsTable
        if (-not $t) { return }
        $t.DefaultView.RowFilter = if ($Script:SCWizard.Controls.OnlyConfirmedCheck.IsChecked) { "Confianza = 'Confirmado'" } else { "" }
    })

    [void]$panel.Children.Add($grid)
    $Script:SCWizard.Controls.ResultsGrid = $grid
    $Script:SCWizard.Controls.ResultsTable = $tbl
    $Script:SCWizard.Controls.ResultsPanelCache = $panel
    return $panel
}

function Save-SCResultsSelection {
    $tbl = $Script:SCWizard.Controls.ResultsTable
    if (-not $tbl) { return }
    for ($i = 0; $i -lt $tbl.Rows.Count; $i++) {
        if ($i -lt $Script:SCWizard.State.QueryResults.Count) {
            $Script:SCWizard.State.QueryResults[$i].Incluir = [bool]$tbl.Rows[$i]["Incluir"]
        }
    }
}

# ── Paso 8: Informes ──────────────────────────────────────────────────

function Show-SCStepReports {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Generar informes"))
    [void]$panel.Children.Add((New-SCParagraph "Se generaran dos informes con los mismos hallazgos confirmados: uno pericial formal y otro en lenguaje llano. Elige la carpeta de destino."))

    if (-not $Script:SCWizard.State.ReportOutputDir) {
        $Script:SCWizard.State.ReportOutputDir = Join-Path $Script:SCSession.ProjectPath "CONSULTAS_SC\Consulta_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }

    $row = New-Object System.Windows.Controls.Grid
    $row.Margin = [System.Windows.Thickness]::new(0,14,0,0)
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = [System.Windows.GridLength]::Auto
    [void]$row.ColumnDefinitions.Add($c1); [void]$row.ColumnDefinitions.Add($c2)

    $box = New-Object System.Windows.Controls.TextBox
    $box.Text = $Script:SCWizard.State.ReportOutputDir
    $box.VerticalContentAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($box,0)
    [void]$row.Children.Add($box)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "Examinar..."
    $btn.Style = (Get-SCStyle "SCBtn")
    $btn.Margin = [System.Windows.Thickness]::new(8,0,0,0)
    [System.Windows.Controls.Grid]::SetColumn($btn,1)
    $btn.Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Carpeta donde guardar los informes"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $Script:SCWizard.Controls.ReportDirBox.Text = $dlg.SelectedPath
        }
    })
    [void]$row.Children.Add($btn)
    [void]$panel.Children.Add($row)
    $Script:SCWizard.Controls.ReportDirBox = $box

    $resultBox = New-Object System.Windows.Controls.StackPanel
    $resultBox.Margin = [System.Windows.Thickness]::new(0,20,0,0)
    $Script:SCWizard.Controls.ReportResultPanel = $resultBox
    [void]$panel.Children.Add($resultBox)

    if ($Script:SCWizard.State.ReportPaths.Count -gt 0) {
        Show-SCReportResultLinks
    }

    return $panel
}

function Show-SCReportResultLinks {
    $rp = $Script:SCWizard.Controls.ReportResultPanel
    $rp.Children.Clear()
    $ok = New-SCParagraph "Informes generados correctamente:"
    $ok.Foreground = New-WpfBrush $Script:Colors.Success
    [void]$rp.Children.Add($ok)
    foreach ($p in $Script:SCWizard.State.ReportPaths) { [void]$rp.Children.Add((New-SCParagraph $p)) }

    $btnRow = New-Object System.Windows.Controls.StackPanel
    $btnRow.Orientation = 'Horizontal'
    $btnRow.Margin = [System.Windows.Thickness]::new(0,10,0,0)

    $btnOpen = New-Object System.Windows.Controls.Button
    $btnOpen.Content = "Abrir carpeta de informes"
    $btnOpen.Style = (Get-SCStyle "SCBtnPrimary")
    $btnOpen.HorizontalAlignment = 'Left'
    $btnOpen.Add_Click({ Start-Process explorer.exe $Script:SCWizard.State.ReportOutputDir })
    [void]$btnRow.Children.Add($btnOpen)

    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = "Cerrar aplicacion"
    $btnClose.Style = (Get-SCStyle "SCBtn")
    $btnClose.Margin = [System.Windows.Thickness]::new(8,0,0,0)
    $btnClose.Add_Click({ $Script:SCWizard.Controls.Window.Close() })
    [void]$btnRow.Children.Add($btnClose)

    [void]$rp.Children.Add($btnRow)
}

# ── Motor de transiciones asincronas ──────────────────────────────────

function Start-SCUserPreScan {
    Set-SCBusy -Message "Detectando usuarios del proyecto..."
    $keys = @('EVTX_Logons','EVTX_FailedLogons','Browser_Historial')
    $keyByPath = @{}
    $paths = foreach ($k in $keys) {
        $e = Get-SCSourceEntry -Key $k
        $p = Join-Path $Script:SCSession.ANOutputPath $e.RelPath
        $keyByPath[$p] = $k
        $p
    }
    Invoke-AsyncSourceIndexing -FilePaths $paths -UIContext ([PSCustomObject]@{ KeyByPath = $keyByPath }) `
        -OnProgress {
            param($ui, $cur, $tot, $file)
            Set-SCProgressText -Text "Detectando usuarios... ($cur/$tot) $file" -Current $cur -Total $tot
        } `
        -OnComplete {
            param($ui, $tablesByPath, $errorsByPath)
            foreach ($p in $tablesByPath.Keys) {
                $k = $ui.KeyByPath[$p]
                if ($k) { $Script:SCSession.LoadedTables[$k] = $tablesByPath[$p] }
            }
            $users = [System.Collections.Generic.List[string]]::new()
            foreach ($k in @('EVTX_Logons','EVTX_FailedLogons')) {
                $t = $Script:SCSession.LoadedTables[$k]
                if ($t) {
                    foreach ($r in $t.Rows) {
                        foreach ($col in @('TargetUser','SubjectUser')) {
                            if ($t.Columns.Contains($col)) {
                                $v = $r[$col]
                                if (-not [string]::IsNullOrWhiteSpace($v) -and -not $users.Contains($v)) { $users.Add($v) }
                            }
                        }
                    }
                }
            }
            $bt = $Script:SCSession.LoadedTables['Browser_Historial']
            if ($bt -and $bt.Columns.Contains('Usuario')) {
                foreach ($r in $bt.Rows) {
                    $v = $r['Usuario']
                    if (-not [string]::IsNullOrWhiteSpace($v) -and $v -ne 'desconocido' -and -not $users.Contains($v)) { $users.Add($v) }
                }
            }
            $realUsers = @($users | Where-Object { Test-SCIsRealUser $_ })
            $Script:SCWizard.State.KnownUsers = @($realUsers | Sort-Object)
            Clear-SCBusy
            Move-SCWizardTo -StepKey 'Users'
        }
}

function Start-SCFullQuery {
    $sourceKeys = Get-SCSourcesForCategories -CategoryKeys $Script:SCWizard.State.SelectedCategories
    $pending = $sourceKeys | Where-Object { -not $Script:SCSession.LoadedTables.ContainsKey($_) }

    # $runQuery recibe TODO su estado por parametro ($ui), nunca por closure
    # sobre variables locales de esta funcion: cuando se invoca de forma
    # diferida (tras el DispatcherTimer asincrono), Start-SCFullQuery ya ha
    # retornado y su pila de llamada (con $sourceKeys) ha dejado de existir -
    # una closure sobre $sourceKeys se resuelve a $null en ese momento y la
    # consulta se ejecuta con 0 fuentes. Mismo motivo por el que
    # AsyncLoader.ps1 evita closures y pasa todo por $timer.Tag.
    $runQuery = {
        param($ui)
        $usersSel = if ($Script:SCWizard.State.SelectedUsers -contains '__ALL__' -or $Script:SCWizard.State.SelectedUsers.Count -eq 0) { @() } else { $Script:SCWizard.State.SelectedUsers }
        $q = Invoke-SCQuery -SourceKeys $ui.SourceKeys -Users $usersSel `
                -DateFrom $Script:SCWizard.State.DateFrom -DateTo $Script:SCWizard.State.DateTo `
                -TimeFrom $Script:SCWizard.State.TimeFrom -TimeTo $Script:SCWizard.State.TimeTo `
                -Keyword $Script:SCWizard.State.Keyword -ExcludeKeyword $Script:SCWizard.State.ExcludeKeyword
        $Script:SCWizard.State.QueryResults = $q.Resultados
        $Script:SCWizard.State.QuerySummary = $q.Resumen
        $Script:SCWizard.Controls.ResultsPanelCache = $null   # consulta nueva -> invalidar cache del paso Resultados
        Clear-SCBusy
        Move-SCWizardTo -StepKey 'Results'
    }

    if ($pending.Count -eq 0) {
        Set-SCBusy -Message "Ejecutando consulta..."
        & $runQuery ([PSCustomObject]@{ SourceKeys = $sourceKeys })
        return
    }

    Set-SCBusy -Message "Cargando fuentes seleccionadas..."
    $keyByPath = @{}
    $paths = foreach ($k in $pending) {
        $e = Get-SCSourceEntry -Key $k
        $p = Join-Path $Script:SCSession.ANOutputPath $e.RelPath
        $keyByPath[$p] = $k
        $p
    }
    Invoke-AsyncSourceIndexing -FilePaths $paths -UIContext ([PSCustomObject]@{ KeyByPath = $keyByPath; RunQuery = $runQuery; SourceKeys = $sourceKeys }) `
        -OnProgress {
            param($ui, $cur, $tot, $file)
            Set-SCProgressText -Text "Cargando fuentes... ($cur/$tot) $file" -Current $cur -Total $tot
        } `
        -OnComplete {
            param($ui, $tablesByPath, $errorsByPath)
            foreach ($p in $tablesByPath.Keys) {
                $k = $ui.KeyByPath[$p]
                if ($k) { $Script:SCSession.LoadedTables[$k] = $tablesByPath[$p] }
            }
            Set-SCProgressText -Text "Ejecutando consulta..."
            & $ui.RunQuery $ui
        }
}

function Invoke-SCGenerateReports {
    $dir = $Script:SCWizard.Controls.ReportDirBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($dir)) { Set-SCValidationError "Indica una carpeta de destino."; return }
    $Script:SCWizard.State.ReportOutputDir = $dir
    try {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    } catch {
        Set-SCValidationError "No se pudo crear la carpeta: $($_.Exception.Message)"
        return
    }

    Set-SCBusy -Message "Generando informes..."
    $findings = @($Script:SCWizard.State.QueryResults | Where-Object { $_.Incluir })
    $criteria = [PSCustomObject]@{
        Usuarios   = if ($Script:SCWizard.State.SelectedUsers -contains '__ALL__' -or $Script:SCWizard.State.SelectedUsers.Count -eq 0) { @('Todos los usuarios') } else { $Script:SCWizard.State.SelectedUsers }
        Categorias = @($Script:SCWizard.State.SelectedCategories | ForEach-Object { $Script:SC_Categories[$_].Label })
        DateFrom   = $Script:SCWizard.State.DateFrom
        DateTo     = $Script:SCWizard.State.DateTo
        TimeFrom   = $Script:SCWizard.State.TimeFrom
        TimeTo     = $Script:SCWizard.State.TimeTo
        Keyword    = $Script:SCWizard.State.Keyword
        ExcludeKeyword = $Script:SCWizard.State.ExcludeKeyword
        Resumen    = $Script:SCWizard.State.QuerySummary
    }

    $paths = [System.Collections.Generic.List[string]]::new()
    try {
        $p1 = New-SCReportPericial -OutputDir $dir -Findings $findings -Criteria $criteria
        $paths.Add($p1)
        $p2 = New-SCReportLlano -OutputDir $dir -Findings $findings -Criteria $criteria
        $paths.Add($p2)
        $p3 = Export-SCResultsCsv -OutputDir $dir -Findings $findings
        $paths.Add($p3)
        $Script:SCWizard.State.ReportPaths = @($paths)
        Clear-SCBusy
        Show-SCReportResultLinks
    } catch {
        Clear-SCBusy
        Set-SCValidationError "Error generando los informes: $($_.Exception.Message)"
    }
}

function Export-SCResultsCsv {
    <# Exporta la tabla de hallazgos incluidos a CSV, junto a los dos
       informes HTML, para poder trabajarla en Excel (ordenar, tablas
       dinamicas...) sin depender del HTML. #>
    param([string]$OutputDir, [array]$Findings)
    $csvPath = Join-Path $OutputDir "Resultados_SC.csv"
    $rows = foreach ($f in $Findings) {
        [PSCustomObject]@{
            Fecha       = Format-SCFecha $f
            Fuente      = $f.Fuente
            Usuario     = $f.Usuario
            Confianza   = $f.Confianza
            Descripcion = $f.Descripcion
            Origen      = $f.Origen
        }
    }
    $rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Force
    return $csvPath
}

# ── Render / navegacion ────────────────────────────────────────────────

function Render-SCStep {
    Clear-SCValidationError
    $key = $Script:SCWizard.StepOrder[$Script:SCWizard.StepIndex]
    $ctrl = $Script:SCWizard.Controls
    $ctrl.StepIndicatorText.Text = $Script:SCStepTitles[$key]

    $content = switch ($key) {
        'Project'    { Show-SCStepProject }
        'Users'      { Show-SCStepUsers }
        'Categories' { Show-SCStepCategories }
        'DateTime'   { Show-SCStepDateTime }
        'Keyword'    { Show-SCStepKeyword }
        'Summary'    { Show-SCStepSummary }
        'Results'    { Show-SCStepResults }
        'Reports'    { Show-SCStepReports }
    }
    $ctrl.ContentHost.Child = $content

    $ctrl.BtnBack.IsEnabled = ($Script:SCWizard.StepIndex -gt 0)
    $ctrl.BtnNext.Content = switch ($key) {
        'Summary' { "Ejecutar consulta >" }
        'Results' { "Continuar a informes >" }
        'Reports' { "Generar informes" }
        default   { "Siguiente >" }
    }
}

function Move-SCWizardTo {
    param([string]$StepKey)
    $idx = [array]::IndexOf($Script:SCWizard.StepOrder, $StepKey)
    if ($idx -ge 0) { $Script:SCWizard.StepIndex = $idx; Render-SCStep }
}

function Move-SCWizardNext {
    Clear-SCValidationError
    $key = $Script:SCWizard.StepOrder[$Script:SCWizard.StepIndex]
    switch ($key) {
        'Project' {
            $path = $Script:SCWizard.Controls.ProjectPathBox.Text.Trim()
            if (-not (Test-SCProject -Path $path)) {
                Set-SCValidationError "La carpeta indicada no contiene un analisis MaPeriT.AN valido (se busca la subcarpeta ANALISIS_AN)."
                return
            }
            $Script:SCSession.ProjectPath  = $path
            $Script:SCSession.ANOutputPath = Join-Path $path $Script:AN_OutputFolderName
            $meta = Get-SCProjectMetadata -Path $path
            $Script:SCSession.CaseNumber = $meta.CaseNumber
            $Script:SCSession.Examiner   = $meta.Examiner
            $Script:SCWizard.State.ProjectPath = $path
            Start-SCUserPreScan
        }
        'Users' {
            $sel = Get-SCCheckedValues -Panel $Script:SCWizard.Controls.UsersPanel
            if ($sel.Count -eq 0) { Set-SCValidationError "Selecciona 'Todos los usuarios' o al menos un usuario concreto."; return }
            $Script:SCWizard.State.SelectedUsers = $sel
            Move-SCWizardTo -StepKey 'Categories'
        }
        'Categories' {
            $sel = Get-SCCheckedValues -Panel $Script:SCWizard.Controls.CategoriesPanel
            if ($sel.Count -eq 0) { Set-SCValidationError "Selecciona al menos una categoria de interes."; return }
            $Script:SCWizard.State.SelectedCategories = $sel
            Move-SCWizardTo -StepKey 'DateTime'
        }
        'DateTime' {
            $c = $Script:SCWizard.Controls
            $from = $c.DateFromPicker.SelectedDate
            $to   = $c.DateToPicker.SelectedDate
            if ($from -and $to -and $from -gt $to) { Set-SCValidationError "La fecha 'desde' no puede ser posterior a 'hasta'."; return }
            $Script:SCWizard.State.DateFrom = $from
            $Script:SCWizard.State.DateTo   = if ($to) { ([datetime]$to).Date.AddDays(1).AddSeconds(-1) } else { $null }
            if ($c.UseTimeWindowCheck.IsChecked) {
                $tf = New-Object TimeSpan; $tt = New-Object TimeSpan
                $okF = [TimeSpan]::TryParse($c.TimeFromBox.Text, [ref]$tf)
                $okT = [TimeSpan]::TryParse($c.TimeToBox.Text, [ref]$tt)
                if (-not ($okF -and $okT)) { Set-SCValidationError "Formato de hora invalido. Usa HH:mm, por ejemplo 23:00."; return }
                $Script:SCWizard.State.TimeFrom = $tf
                $Script:SCWizard.State.TimeTo   = $tt
            } else {
                $Script:SCWizard.State.TimeFrom = $null
                $Script:SCWizard.State.TimeTo   = $null
            }
            Move-SCWizardTo -StepKey 'Keyword'
        }
        'Keyword' {
            $Script:SCWizard.State.Keyword        = $Script:SCWizard.Controls.KeywordBox.Text.Trim()
            $Script:SCWizard.State.ExcludeKeyword = $Script:SCWizard.Controls.ExcludeKeywordBox.Text.Trim()
            Move-SCWizardTo -StepKey 'Summary'
        }
        'Summary' { Start-SCFullQuery }
        'Results' {
            Save-SCResultsSelection
            Move-SCWizardTo -StepKey 'Reports'
        }
        'Reports' { Invoke-SCGenerateReports }
    }
}

function Move-SCWizardBack {
    if ($Script:SCWizard.StepIndex -le 0) { return }
    $Script:SCWizard.StepIndex--
    Render-SCStep
}

function Show-SCWizard {
    param([System.Windows.Window]$Window)

    $Script:SCWizard.Controls.Window             = $Window
    $Script:SCWizard.Controls.ContentHost        = $Window.FindName("ContentHost")
    $Script:SCWizard.Controls.StepIndicatorText  = $Window.FindName("StepIndicatorText")
    $Script:SCWizard.Controls.StatusText         = $Window.FindName("StatusText")
    $Script:SCWizard.Controls.WizardProgressBar  = $Window.FindName("WizardProgressBar")
    $Script:SCWizard.Controls.BtnBack            = $Window.FindName("BtnBack")
    $Script:SCWizard.Controls.BtnNext            = $Window.FindName("BtnNext")
    $Script:SCWizard.Controls.BtnCancel          = $Window.FindName("BtnCancel")

    $Script:SCWizard.Controls.BtnNext.Add_Click({ Move-SCWizardNext })
    $Script:SCWizard.Controls.BtnBack.Add_Click({ Move-SCWizardBack })
    # La ventana del propio boton (antes $Window, que solo existia por casualidad en
    # el ambito del script principal)
    $Script:SCWizard.Controls.BtnCancel.Add_Click({ [System.Windows.Window]::GetWindow($this).Close() })

    $Script:SCWizard.StepIndex = 0
    Render-SCStep
}

#endregion
#endregion

#region ===== src\Main.ps1 =====
#region ============================================================
# MaPeriT.SC - PUNTO DE ENTRADA
# ============================================================

$ErrorActionPreference = "Continue"

try {
    Initialize-SCApplication
} catch {
    Write-Host "Error inicializando MaPeriT.SC: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Red de seguridad global: cualquier excepcion no controlada que escape de un
# manejador de evento WPF (click, tick de timer, etc.) se propaga como
# STATUS_FATAL_USER_CALLBACK_EXCEPTION y Windows mata el proceso entero sin
# posibilidad de recuperacion - no se ve como un error normal de PowerShell,
# la aplicacion simplemente desaparece. Se ha confirmado un bug real de WPF
# (DataGridItemAttachedStorage.TryGetValue lanzando ArgumentNullException de
# forma esporadica al preparar filas de un DataGrid con volumenes grandes,
# aparentemente ligado a temporizacion del recolector de basura, no a ningun
# error de configuracion del grid) que puede disparar este camino. Este
# manejador evita que MaPeriT.SC se cierre de golpe ante cualquier excepcion
# de este tipo: la registra en consola y deja que la aplicacion siga viva.
[System.Windows.Threading.Dispatcher]::CurrentDispatcher.add_UnhandledException({
    param($sender, $e)
    Write-Host "[AVISO] Error interno no fatal capturado: $($e.Exception.Message)" -ForegroundColor Yellow
    $e.Handled = $true
})

if ($ProjectPath) { $Script:SCWizard.State.ProjectPath = $ProjectPath }

try {
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new((Get-SCMainWindowXAML)))
    $Window = [System.Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Host "Error construyendo la ventana de MaPeriT.SC: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Show-SCWizard -Window $Window
[void]$Window.ShowDialog()

#endregion
#endregion

