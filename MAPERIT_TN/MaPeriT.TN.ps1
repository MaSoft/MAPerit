#Requires -Version 5.1
<#
    MaPeriT.TN v1.1.2 - Visor Forense del Ecosistema MaPeriT
    Compilado: 2026-11-16 12:00:00
    No editar directamente - modificar src\ y recompilar con Build.ps1
#>
#region ===== src\Main-Params.ps1 =====
#region ============================================================
# MaPeriT.TN - PARAMETROS DE ENTRADA
# ============================================================
[CmdletBinding()]
param(
    [string]$ProjectPath = "",   # Abrir proyecto MaPeriT.SW / MaPeriT.OF directamente
    [string]$OpenFile    = ""    # Abrir fichero individual directamente
)
#endregion
#endregion

#region ===== src\Config.ps1 =====
#region ============================================================
# MaPeriT.TN - CONFIGURACION Y CONSTANTES
# ============================================================

$Script:TN_Version   = "1.1.2"
$Script:TN_Title     = "MaPeriT.TN"
$Script:TN_FullTitle = "MaPeriT.TN v$($Script:TN_Version) — Visor Forense"

# ── Gestión de tema ───────────────────────────────────────────────────
$Script:TN_Theme        = "Dark"
$Script:TN_ThemeRestart = $false
$Script:TN_RestoreState = $null

# ── Paleta oscura (predeterminada) ────────────────────────────────────
$Script:ColorsDark = @{
    BgPrimary    = "#111827"
    BgPanel      = "#1F2937"
    BgCard       = "#273244"
    BgSurface    = "#2D3B55"
    BgHeader     = "#0F172A"
    Accent       = "#3B82F6"
    AccentDark   = "#1D4ED8"
    AccentHover  = "#60A5FA"
    Text         = "#F1F5F9"
    TextMuted    = "#94A3B8"
    TextDim      = "#475569"
    Border       = "#334155"
    BorderLight  = "#3D4F6B"
    Success      = "#22C55E"
    Warning      = "#F59E0B"
    Danger       = "#EF4444"
    Critical     = "#DC2626"
    Info         = "#38BDF8"
    RowCritical  = "#3B1010"
    RowDanger    = "#3B2210"
    RowWarning   = "#3B3210"
    RowTimestomp = "#2A1040"
    RowInfo      = "#0F2840"
    SelectionBg  = "#1D4ED8"
    SelectionFg  = "#FFFFFF"
}

# ── Paleta clara ──────────────────────────────────────────────────────
$Script:ColorsLight = @{
    BgPrimary    = "#F1F5F9"
    BgPanel      = "#E2E8F0"
    BgCard       = "#FFFFFF"
    BgSurface    = "#CBD5E1"
    BgHeader     = "#CBD5E1"
    Accent       = "#2563EB"
    AccentDark   = "#1D4ED8"
    AccentHover  = "#3B82F6"
    Text         = "#0F172A"
    TextMuted    = "#475569"
    TextDim      = "#64748B"
    Border       = "#94A3B8"
    BorderLight  = "#CBD5E1"
    Success      = "#15803D"
    Warning      = "#B45309"
    Danger       = "#DC2626"
    Critical     = "#B91C1C"
    Info         = "#0369A1"
    RowCritical  = "#FEE2E2"
    RowDanger    = "#FED7AA"
    RowWarning   = "#FEF9C3"
    RowTimestomp = "#EDE9FE"
    RowInfo      = "#DBEAFE"
    SelectionBg  = "#2563EB"
    SelectionFg  = "#FFFFFF"
}

$Script:Colors = $Script:ColorsDark

# ── Directorios conocidos de MaPeriT.SW / MaPeriT.OF ─────────────────
# BUG CRITICO CONFIRMADO (12/07/2026, detectado en verificacion end-to-end
# real: SW/OF -> AN -> TN contra una adquisicion real): estas claves NUNCA
# coincidian con los nombres de carpeta que SW y OF generan de verdad.
# $Script:OutputDirs en MAPERIT_SW\src\Config.ps1 y MAPERIT_OF\src\Config.ps1
# usa "01_Volatile", "02_SystemInfo", etc. (prefijo numerico), NUNCA
# "Phase1_Volatile" como se asumia aqui. Con las claves antiguas, el arbol
# de fases y el Dashboard de TN mostraban SIEMPRE 0 de 10 fases detectadas
# para cualquier proyecto real (los ficheros seguian siendo accesibles via
# la rama de "carpetas no reconocidas", pero sin los nombres/iconos propios
# de cada fase ni el conteo del Dashboard). "MemoryDump" tampoco es una
# carpeta de nivel superior real (esta anidada dentro de 01_Volatile), se
# elimina esa clave fantasma.
$Script:SW_PhaseNames = [ordered]@{
    "01_Volatile"           = "1 · Datos Volátiles"
    "02_SystemInfo"         = "2 · Info del Sistema"
    "03_Filesystem"         = "3 · Sistema de Ficheros"
    "04_Registry"           = "4 · Registro Windows"
    "05_EventLogs"          = "5 · Logs de Eventos"
    "06_Browsers"           = "6 · Navegadores Web"
    "07_Communications"     = "7 · Comunicaciones"
    "08_CloudStorage"       = "8 · Almacenamiento Nube"
    "09_USB"                = "9 · USB / Externos"
    "10_Persistence"        = "10 · Persistencia"
    "Analysis"              = "Análisis SW"
    "Logs"                  = "Logs SW"
    "ANALISIS_AN"           = "AN · Análisis Profundo"
}

# ── Iconos por extensión / nombre ────────────────────────────────────
$Script:FileIcons = @{
    ".csv"   = "▦"
    ".json"  = "{}"
    ".evtx"  = "E"
    ".log"   = "≡"
    ".txt"   = "≡"
    ".html"  = "W"
    ".htm"   = "W"
    ".xml"   = "<>"
    ".bin"   = "B"
    ".hve"   = "R"
    ".dat"   = "D"
    ".raw"   = "M"
    ".pf"    = "P"
    ".inf"   = "≡"
    "`$MFT"  = "▦"
    "default"= "·"
}

# ── Event IDs por severidad ───────────────────────────────────────────
$Script:EventSeverity = @{
    Critical = @(1100, 1102, 4698, 4697, 4720, 4726, 4728, 4732, 4740, 7045)
    High     = @(4624, 4625, 4648, 4688, 4672, 4776, 4771, 4768, 4769)
    Medium   = @(6005, 6006, 6008, 6013, 4608, 4609, 4616, 4657)
}

# ── Patrones IOC ──────────────────────────────────────────────────────
$Script:IOCPatterns = @{
    IPv4External   = '(?<!\d)(?!10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|127\.|0\.0\.0\.0)(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)(?!\d)'
    SHA256         = '\b[0-9a-fA-F]{64}\b'
    SuspiciousExe  = '(?i)\b(cmd|powershell|wscript|cscript|mshta|rundll32|regsvr32|schtasks|bitsadmin|certutil|msiexec|wmic|net\.exe|psexec)\b'
    SuspiciousPath = '(?i)(\\temp\\|\\appdata\\local\\temp\\|\\downloads\\|\\public\\|\\programdata\\(?!microsoft))'
    EncodedCmd     = '(?i)(encodedcommand|downloadstring|invoke-expression|iex\s*[\(\|]|frombase64)'
}

# ── Mapeo de extensión a tipo de visor ───────────────────────────────
$Script:ViewerMap = @{
    ".csv"  = "CSV"
    ".json" = "JSON"
    ".evtx" = "EVTX"
    ".log"  = "Text"
    ".txt"  = "Text"
    ".inf"  = "Text"
    ".xml"  = "Text"
    ".html" = "HTML"
    ".htm"  = "HTML"
    ".bin"  = "Hex"
    ".raw"  = "Hex"
    ".hve"  = "Hex"
    ".dat"  = "Hex"
    ".pf"   = "Hex"
}

# Ficheros sin extensión con visor específico
$Script:SpecialFiles = @{
    "`$MFT"      = "MFT"
    "`$LogFile"  = "Hex"
    "hosts"      = "Text"
    "SAM"        = "Hex"
    "SYSTEM"     = "Hex"
    "SOFTWARE"   = "Hex"
    "SECURITY"   = "Hex"
}

# ── Limite de filas para carga inicial (rendimiento) ─────────────────
$Script:MaxRowsDefault  = 50000
$Script:MaxEVTXEvents   = 10000

#endregion
#endregion

#region ===== src\Core\Initialize.ps1 =====
#region ============================================================
# MaPeriT.TN - INICIALIZACION DE ASSEMBLIES WPF
# ============================================================

function Initialize-TNApplication {
    Add-Type -AssemblyName PresentationFramework    -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore         -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase              -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms     -ErrorAction SilentlyContinue
    Add-Type -AssemblyName Microsoft.VisualBasic    -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Net.Http          -ErrorAction SilentlyContinue

    # DPI awareness para pantallas HiDPI
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class TN_DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
'@ -ErrorAction SilentlyContinue
        [TN_DpiHelper]::SetProcessDPIAware() | Out-Null
    } catch {}

    # Helper para dark title bar en Windows 10/11
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class TN_DwmHelper {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    public static void SetDarkMode(IntPtr hwnd, bool dark) {
        int val = dark ? 1 : 0;
        DwmSetWindowAttribute(hwnd, 20, ref val, sizeof(int));
        DwmSetWindowAttribute(hwnd, 19, ref val, sizeof(int));
    }
}
'@ -ErrorAction SilentlyContinue
    } catch {}
}

function Set-DarkTitleBar {
    # Barra de titulo oscura solo con el tema oscuro (antes se forzaba tambien
    # en el tema claro).
    param([System.Windows.Window]$Window)
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
        [TN_DwmHelper]::SetDarkMode($hwnd, ($Script:TN_Theme -ne 'Light'))
    } catch {}
}

function New-WpfBrush {
    param([string]$HexColor)
    return [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString($HexColor)
    )
}

function New-WpfColor {
    param([string]$HexColor)
    return [System.Windows.Media.ColorConverter]::ConvertFromString($HexColor)
}

#endregion
#endregion

#region ===== src\Core\Logging.ps1 =====
#region ============================================================
# MaPeriT.TN - LOGGING (consola)
# ============================================================

function Write-TNLog {
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
# MaPeriT.TN - CARGADOR DE PROYECTOS MAPERIT
# ============================================================

function Test-MaPeriTProject {
    param([string]$Path)
    if (-not (Test-Path $Path -PathType Container)) { return $false }
    $hasManifest = (Test-Path (Join-Path $Path "Logs\HashManifest.csv")) -or
                   (Test-Path (Join-Path $Path "HashManifest.csv"))
    $hasPhase    = ($Script:SW_PhaseNames.Keys | Where-Object { Test-Path (Join-Path $Path $_) }) -ne $null
    return ($hasManifest -or $hasPhase)
}

function Get-ProjectMetadata {
    param([string]$Path)

    $meta = [ordered]@{
        Path          = $Path
        Name          = Split-Path $Path -Leaf
        CaseNumber    = ""
        Examiner      = ""
        StartTime     = ""
        ComputerName  = ""
        HasAN         = $false
        AnomalyCount  = 0
        ArtifactCount = 0
        PhaseCount    = 0
        FileSizeTotal = 0
    }

    # Intentar leer session.json (formato ideal, pero NI MaPeriT.SW NI MaPeriT.OF
    # lo generan actualmente - se deja el intento por si una version futura lo
    # escribe; ver fallback de ComputerName mas abajo, que si funciona hoy).
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
                if ($s.StartTime)    { $meta.StartTime     = $s.StartTime }
                if ($s.ComputerName) { $meta.ComputerName  = $s.ComputerName }
            } catch {}
            break
        }
    }

    # Fallback: ComputerName desde OSInfo.json (SW usa NombreEquipo, OF anade
    # CSName). Sin este fallback, ComputerName queda vacio en TODOS los casos
    # reales -- session.json arriba nunca existe en la practica -- pese a que
    # el dato si esta disponible en el propio proyecto.
    if ([string]::IsNullOrEmpty($meta.ComputerName)) {
        $osInfoPath = Join-Path $Path "02_SystemInfo\OSInfo.json"
        if (Test-Path $osInfoPath) {
            try {
                $osInfo = Get-Content $osInfoPath -Raw | ConvertFrom-Json
                if ($osInfo.NombreEquipo)   { $meta.ComputerName = $osInfo.NombreEquipo }
                elseif ($osInfo.CSName)     { $meta.ComputerName = $osInfo.CSName }
            } catch {}
        }
    }

    # Parsear numero de caso del nombre del directorio si no se encontro en session
    if ([string]::IsNullOrEmpty($meta.CaseNumber)) {
        $dirName = Split-Path $Path -Leaf
        if ($dirName -match '^MaPeriT_(?:OF_)?(.+?)_\d{8}') { $meta.CaseNumber = $Matches[1] }
    }

    # Contar fases presentes
    $meta.PhaseCount = @($Script:SW_PhaseNames.Keys | Where-Object { Test-Path (Join-Path $Path $_) }).Count

    # Detectar modulo AN
    $meta.HasAN = Test-Path (Join-Path $Path "ANALISIS_AN")

    # Contar artefactos (CSV + JSON)
    try {
        $files = Get-ChildItem $Path -Recurse -Include "*.csv","*.json" -ErrorAction SilentlyContinue
        $meta.ArtifactCount = $files.Count
        $meta.FileSizeTotal = ($files | Measure-Object -Property Length -Sum).Sum
    } catch {}

    # Contar anomalias desde el CSV de SW (SW solo lo crea si hay alguna). Antes,
    # si no existia, se contaban las entradas de 10_Persistence\AutorunsConsolidated.csv
    # y el panel mostraba como "anomalias" todos los programas de inicio.
    $ap = Join-Path $Path "Analysis\Anomalies.csv"
    if (Test-Path $ap) {
        try { $meta.AnomalyCount = @(Import-Csv $ap -ErrorAction SilentlyContinue).Count } catch {}
    }

    return $meta
}

function Get-ProjectTree {
    param([string]$RootPath)

    $root = [PSCustomObject]@{
        NodeType = "Project"
        Name     = Split-Path $RootPath -Leaf
        Path     = $RootPath
        Children = [System.Collections.Generic.List[object]]::new()
        Icon     = "P"
    }

    # Fases en orden conocido primero
    foreach ($dirKey in $Script:SW_PhaseNames.Keys) {
        $fullPath = Join-Path $RootPath $dirKey
        if (-not (Test-Path $fullPath -PathType Container)) { continue }

        $phaseNode = [PSCustomObject]@{
            NodeType = "Phase"
            Name     = $Script:SW_PhaseNames[$dirKey]
            Path     = $fullPath
            Icon     = "F"
            Children = [System.Collections.Generic.List[object]]::new()
        }
        foreach ($child in (Get-ChildNodes -Path $fullPath -Depth 0)) {
            $phaseNode.Children.Add($child) | Out-Null
        }
        $root.Children.Add($phaseNode) | Out-Null
    }

    # Directorios no reconocidos
    $knownDirs = @($Script:SW_PhaseNames.Keys)
    Get-ChildItem $RootPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $knownDirs } |
        ForEach-Object {
            $node = [PSCustomObject]@{
                NodeType = "Folder"
                Name     = $_.Name
                Path     = $_.FullName
                Icon     = "F"
                Children = [System.Collections.Generic.List[object]]::new()
            }
            foreach ($child in (Get-ChildNodes -Path $_.FullName -Depth 0)) {
                $node.Children.Add($child) | Out-Null
            }
            $root.Children.Add($node) | Out-Null
        }

    # Ficheros en la raiz
    Get-ChildItem $RootPath -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '\.(csv|json|html|txt|log)$' } |
        Sort-Object Name |
        ForEach-Object {
            $root.Children.Add((New-FileNode $_)) | Out-Null
        }

    return $root
}

function Get-ChildNodes {
    param([string]$Path, [int]$Depth)
    if ($Depth -gt 5) { return }
    $nodes = [System.Collections.Generic.List[object]]::new()

    Get-ChildItem $Path -Directory -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
        $node = [PSCustomObject]@{
            NodeType = "Folder"
            Name     = $_.Name
            Path     = $_.FullName
            Icon     = "F"
            Children = [System.Collections.Generic.List[object]]::new()
        }
        foreach ($child in (Get-ChildNodes -Path $_.FullName -Depth ($Depth + 1))) {
            $node.Children.Add($child) | Out-Null
        }
        $nodes.Add($node) | Out-Null
    }

    Get-ChildItem $Path -File -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
        $nodes.Add((New-FileNode $_)) | Out-Null
    }

    return $nodes
}

function New-FileNode {
    param([System.IO.FileInfo]$FileInfo)
    $ext = $FileInfo.Extension.ToLower()
    $icon = if ($Script:FileIcons.ContainsKey($ext)) { $Script:FileIcons[$ext] }
            elseif ($Script:SpecialFiles.ContainsKey($FileInfo.Name)) { "▦" }
            else { $Script:FileIcons["default"] }
    return [PSCustomObject]@{
        NodeType = "File"
        Name     = $FileInfo.Name
        Path     = $FileInfo.FullName
        Ext      = $ext
        Size     = $FileInfo.Length
        Icon     = $icon
        Children = $null
    }
}

function Get-FileViewerType {
    param([string]$FilePath)
    $name = [System.IO.Path]::GetFileName($FilePath)
    $ext  = [System.IO.Path]::GetExtension($FilePath).ToLower()

    # Ficheros especiales (incluyendo $MFT con el $ literal)
    if ($Script:SpecialFiles.ContainsKey($name))   { return $Script:SpecialFiles[$name] }
    # CSVs del modulo AN que son MFT parseado
    if ($name -match '^MFT_')                      { return "MFT" }
    if ($Script:ViewerMap.ContainsKey($ext))       { return $Script:ViewerMap[$ext] }
    return "Text"
}

function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -gt 1GB) { return "{0:N1} GB" -f ($Bytes / 1GB) }
    if ($Bytes -gt 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    if ($Bytes -gt 1KB) { return "{0:N0} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

#endregion
#endregion

#region ===== src\Core\AsyncLoader.ps1 =====
#region ============================================================
# MaPeriT.TN - CARGA ASINCRONA (Runspace + DispatcherTimer)
# ============================================================
# Sin C#, sin closures. Estado en $timer.Tag. Handler: param($sender,$e).

function New-LoadingOverlay {
    param([string]$Message = "Cargando...", [int]$RowSpan = 3)
    $overlay = New-Object System.Windows.Controls.Border
    $overlay.Background = New-WpfBrush $Script:Colors.BgPrimary
    $overlay.Visibility = 'Visible'
    [System.Windows.Controls.Panel]::SetZIndex($overlay, 99)
    [System.Windows.Controls.Grid]::SetRowSpan($overlay, $RowSpan)

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.HorizontalAlignment = 'Center'
    $sp.VerticalAlignment   = 'Center'

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text          = $Message
    $lbl.FontSize      = 15
    $lbl.Foreground    = New-WpfBrush $Script:Colors.TextMuted
    $lbl.TextAlignment = 'Center'
    $sp.Children.Add($lbl) | Out-Null

    $sub = New-Object System.Windows.Controls.TextBlock
    $sub.Text          = "Cargando en segundo plano..."
    $sub.FontSize      = 11
    $sub.Foreground    = New-WpfBrush $Script:Colors.TextDim
    $sub.TextAlignment = 'Center'
    $sub.Margin        = [System.Windows.Thickness]::new(0,6,0,0)
    $sp.Children.Add($sub) | Out-Null

    $overlay.Child = $sp
    return $overlay
}

function Invoke-AsyncCSVLoad {
    <#
    Carga un CSV en un PS Runspace en segundo plano.
    UIContext : PSCustomObject { DG, Status, Overlay, MaxRows }
    OnComplete: scriptblock param($ui, $table, $totalRows)
    OnError   : scriptblock param($ui, $msg)
    #>
    param(
        [string]$FilePath,
        [int]$MaxRows              = $Script:MaxRowsDefault,
        [PSCustomObject]$UIContext,
        [scriptblock]$OnComplete,
        [scriptblock]$OnError
    )

    # Script que corre en el Runspace de fondo (PS completo, puede usar Import-Csv)
    $bgScript = {
        param($path, $max)
        try {
            $raw   = @(Import-Csv $path -Encoding UTF8 -ErrorAction Stop)
            $total = $raw.Count
            if ($total -gt $max) { $raw = $raw[0..($max - 1)] }

            $tbl = [System.Data.DataTable]::new("TNData")
            if ($raw.Count -gt 0) {
                foreach ($prop in $raw[0].PSObject.Properties.Name) {
                    [void]$tbl.Columns.Add($prop, [string])
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
            Write-Output -NoEnumerate ([PSCustomObject]@{ Table = $tbl; Total = $total; Err = "" })
        } catch {
            Write-Output -NoEnumerate ([PSCustomObject]@{ Table = $null; Total = 0; Err = $_.Exception.Message })
        }
    }

    # Crear Runspace STA con acceso completo a PS
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{ path = $FilePath; max = $MaxRows })
    $handle = $ps.BeginInvoke()

    # DispatcherTimer: todo el estado en Tag para evitar closures.
    # En el handler: param($sender,$e) donde $sender ES el DispatcherTimer.
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(150)
    $timer.Tag = [PSCustomObject]@{
        Ps         = $ps
        Handle     = $handle
        Rs         = $rs
        UI         = $UIContext
        OnComplete = $OnComplete
        OnError    = $OnError
    }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx   = $sender.Tag
        $state = $ctx.Ps.InvocationStateInfo.State
        if ($state -in 'Completed', 'Failed', 'Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                if ($obj -and ($obj.Table -is [System.Data.DataTable])) {
                    & $ctx.OnComplete $ctx.UI $obj.Table $obj.Total
                } else {
                    $msg = if ($obj -and $obj.Err) { $obj.Err } else { "No se pudieron cargar los datos" }
                    if ($ctx.OnError) { & $ctx.OnError $ctx.UI $msg }
                }
            } catch {
                if ($ctx.OnError) { & $ctx.OnError $ctx.UI $_.Exception.Message }
            } finally {
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
}

#endregion
#endregion

#region ===== src\Core\Bookmarks.ps1 =====
#region ============================================================
# MaPeriT.TN - SISTEMA DE MARCADORES Y ANOTACIONES
# ============================================================

$Script:Bookmarks     = [System.Collections.Generic.List[PSCustomObject]]::new()
$Script:BookmarksPath = ""

function Initialize-Bookmarks {
    param([string]$ProjectPath)
    $Script:BookmarksPath = Join-Path $ProjectPath "TN_Bookmarks.json"
    $Script:Bookmarks.Clear()
    if (Test-Path $Script:BookmarksPath) {
        try {
            $loaded = Get-Content $Script:BookmarksPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($b in $loaded) {
                $Script:Bookmarks.Add([PSCustomObject]@{
                    FilePath   = [string]$b.FilePath
                    LineNumber = if ($b.PSObject.Properties['LineNumber'] -and $b.LineNumber) { [int]$b.LineNumber } else { 0 }
                    ColumnName = if ($b.PSObject.Properties['ColumnName']) { [string]$b.ColumnName } else { "" }
                    CellValue  = if ($b.PSObject.Properties['CellValue'])  { [string]$b.CellValue  } else { "" }
                    Label      = [string]$b.Label
                    Severity   = [string]$b.Severity
                    Note       = [string]$b.Note
                    Timestamp  = [string]$b.Timestamp
                }) | Out-Null
            }
        } catch {}
    }
}

function Save-Bookmarks {
    if ([string]::IsNullOrEmpty($Script:BookmarksPath)) { return }
    try {
        $Script:Bookmarks | ConvertTo-Json -Depth 5 |
            Set-Content $Script:BookmarksPath -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Add-Bookmark {
    param(
        [string]$FilePath,
        [string]$Label      = "",
        [string]$Severity   = "Info",
        [string]$Note       = "",
        [int]   $LineNumber = 0,
        [string]$ColumnName = "",
        [string]$CellValue  = ""
    )
    $existing = $Script:Bookmarks | Where-Object {
        $_.FilePath -eq $FilePath -and [int]$_.LineNumber -eq $LineNumber -and $_.ColumnName -eq $ColumnName
    } | Select-Object -First 1
    if ($existing) {
        if ($Label)    { $existing.Label    = $Label    }
        if ($Severity) { $existing.Severity = $Severity }
        if ($Note)     { $existing.Note     = $Note     }
        $existing.Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    } else {
        $Script:Bookmarks.Add([PSCustomObject]@{
            FilePath   = $FilePath
            LineNumber = $LineNumber
            ColumnName = $ColumnName
            CellValue  = $CellValue
            Label      = if ($Label) { $Label } else { [System.IO.Path]::GetFileName($FilePath) }
            Severity   = $Severity
            Note       = $Note
            Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }) | Out-Null
    }
    Save-Bookmarks
}

function Remove-Bookmark {
    param([PSCustomObject]$Bookmark)
    if ($Bookmark -and $Script:Bookmarks.Remove($Bookmark)) { Save-Bookmarks }
}

function Get-IsBookmarked {
    param([string]$FilePath)
    return ($Script:Bookmarks | Where-Object { $_.FilePath -eq $FilePath }).Count -gt 0
}

function Get-BookmarksTable {
    $tbl = [System.Data.DataTable]::new("Bookmarks")
    foreach ($c in @('Severity','Label','FilePath','LineNumber','ColumnName','CellValue','Note','Timestamp')) {
        [void]$tbl.Columns.Add($c, [string])
    }
    foreach ($b in $Script:Bookmarks) {
        $row = $tbl.NewRow()
        $row['Severity']   = $b.Severity
        $row['Label']      = $b.Label
        $row['FilePath']   = $b.FilePath
        $row['LineNumber'] = if ($b.LineNumber -gt 0) { $b.LineNumber.ToString() } else { "" }
        $row['ColumnName'] = $b.ColumnName
        $row['CellValue']  = $b.CellValue
        $row['Note']       = $b.Note
        $row['Timestamp']  = $b.Timestamp
        [void]$tbl.Rows.Add($row)
    }
    Write-Output -NoEnumerate $tbl
}

function New-BookmarksPanelContent {
    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    foreach ($h in @([System.Windows.GridLength]::Auto,
                     [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star),
                     [System.Windows.GridLength]::Auto)) {
        $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = $h
        $outer.RowDefinitions.Add($rd)
    }

    # Toolbar
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(8,5,8,5)
    $tbDP = New-Object System.Windows.Controls.DockPanel
    $tbDP.LastChildFill = $false

    $titleLbl = New-Object System.Windows.Controls.TextBlock
    $titleLbl.Text       = "Marcadores del Proyecto"
    $titleLbl.FontSize   = 12
    $titleLbl.FontWeight = [System.Windows.FontWeights]::SemiBold
    $titleLbl.Foreground = New-WpfBrush $Script:Colors.Text
    $titleLbl.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($titleLbl, 'Left')
    $tbDP.Children.Add($titleLbl) | Out-Null

    $rightSP = New-Object System.Windows.Controls.StackPanel
    $rightSP.Orientation = 'Horizontal'
    [System.Windows.Controls.DockPanel]::SetDock($rightSP, 'Right')
    foreach ($btnTxt in @("Exportar HTML", "Eliminar sel.")) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content     = $btnTxt
        $btn.Height      = 24
        $btn.Padding     = [System.Windows.Thickness]::new(8,2,8,2)
        $btn.Margin      = [System.Windows.Thickness]::new(4,0,0,0)
        $btn.Background  = New-WpfBrush $Script:Colors.BgSurface
        $btn.Foreground  = New-WpfBrush $Script:Colors.Text
        $btn.BorderBrush = New-WpfBrush $Script:Colors.Border
        $btn.FontSize    = 11
        $btn.Cursor      = [System.Windows.Input.Cursors]::Hand
        $rightSP.Children.Add($btn) | Out-Null
    }
    $tbDP.Children.Add($rightSP) | Out-Null
    $toolbar.Child = $tbDP
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # DataGrid — usa DataTable para que WPF pueda reflejar las propiedades
    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly          = $true
    $dg.AutoGenerateColumns = $false
    $dg.SelectionMode       = 'Extended'
    $dg.SelectionUnit       = 'FullRow'
    $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    Apply-DataGridDarkTheme $dg
    foreach ($cd in @(
        @{ H="Severidad"; B="Severity";   W=80  },
        @{ H="Etiqueta";  B="Label";      W=150 },
        @{ H="Archivo";   B="FilePath";   W=200 },
        @{ H="Linea";     B="LineNumber"; W=55  },
        @{ H="Columna";   B="ColumnName"; W=90  },
        @{ H="Valor";     B="CellValue";  W=160 },
        @{ H="Nota";      B="Note";       W=200 },
        @{ H="Fecha";     B="Timestamp";  W=130 }
    )) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header  = $cd.H
        $col.Binding = New-Object System.Windows.Data.Binding($cd.B)
        $col.Width   = $cd.W
        $dg.Columns.Add($col) | Out-Null
    }
    $dg.Add_LoadingRow({
        param($s, $e)
        $item = $e.Row.Item -as [System.Data.DataRowView]
        if ($null -eq $item) { return }
        $bg = switch ($item['Severity']) {
            "Critical" { New-WpfBrush $Script:Colors.RowCritical }
            "High"     { New-WpfBrush $Script:Colors.RowDanger   }
            "Medium"   { New-WpfBrush $Script:Colors.RowWarning  }
            default    { $null }
        }
        if ($null -ne $bg) { $e.Row.Background = $bg }
    })

    $bmTable = Get-BookmarksTable
    $dg.Tag        = $bmTable
    $dg.ItemsSource = $bmTable.DefaultView
    [System.Windows.Controls.Grid]::SetRow($dg, 1)
    $outer.Children.Add($dg) | Out-Null

    $dg.Add_MouseDoubleClick({
        param($s, $e)
        $item = $s.SelectedItem -as [System.Data.DataRowView]
        if ($item) {
            $fp = $item['FilePath'] -as [string]
            if (-not [string]::IsNullOrEmpty($fp) -and (Test-Path $fp)) {
                Open-FileInTab -FilePath $fp
            }
        }
    })

    # Status
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Text       = "$($Script:Bookmarks.Count) marcadores  ·  Doble clic para abrir"
    $statusLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $statusLabel.FontSize   = 11
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    foreach ($btn in ($rightSP.Children | Where-Object { $_ -is [System.Windows.Controls.Button] })) {
        $btn.Tag = [PSCustomObject]@{ DG = $dg; Status = $statusLabel }
        $btn.Add_Click({
            param($sender, $e)
            $ctx = $sender.Tag
            switch -Wildcard ($sender.Content) {
                "Exportar*" { Export-BookmarksReport }
                "Eliminar*" {
                    $sel = @($ctx.DG.SelectedItems | ForEach-Object { $_ })
                    foreach ($drv in $sel) {
                        $rv = $drv -as [System.Data.DataRowView]
                        if ($rv) {
                            $fp  = $rv['FilePath'] -as [string]
                            $ln  = 0; [int]::TryParse($rv['LineNumber'], [ref]$ln) | Out-Null
                            $col = $rv['ColumnName'] -as [string]
                            $bm  = $Script:Bookmarks | Where-Object {
                                $_.FilePath -eq $fp -and [int]$_.LineNumber -eq $ln -and $_.ColumnName -eq $col
                            } | Select-Object -First 1
                            if ($bm) { Remove-Bookmark -Bookmark $bm }
                        }
                    }
                    $newTbl = Get-BookmarksTable
                    $ctx.DG.Tag        = $newTbl
                    $ctx.DG.ItemsSource = $newTbl.DefaultView
                    $ctx.Status.Text   = "$($Script:Bookmarks.Count) marcadores"
                }
            }
        })
    }
    return $outer
}

function Show-AddBookmarkDialog {
    param(
        [string]$FilePath,
        [int]   $LineNumber = 0,
        [string]$ColumnName = "",
        [string]$CellValue  = ""
    )

    $hasLineCtx = $LineNumber -gt 0

    $dlg = New-Object System.Windows.Window
    $dlg.Title                 = "Anadir Marcador"
    $dlg.Width                 = 440
    $dlg.Height = if ($hasLineCtx) {
        if (-not [string]::IsNullOrEmpty($CellValue)) { 455 } else { 405 }
    } else { 355 }
    $dlg.Background            = New-WpfBrush $Script:Colors.BgPanel
    $dlg.WindowStartupLocation = 'CenterScreen'
    $dlg.ResizeMode            = 'NoResize'

    $existing = $Script:Bookmarks | Where-Object {
        $_.FilePath -eq $FilePath -and [int]$_.LineNumber -eq $LineNumber -and $_.ColumnName -eq $ColumnName
    } | Select-Object -First 1

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = [System.Windows.Thickness]::new(20,14,20,14)

    $mkLbl = {
        param($t)
        $l = New-Object System.Windows.Controls.TextBlock
        $l.Text = $t; $l.Foreground = New-WpfBrush $Script:Colors.TextMuted
        $l.FontSize = 11; $l.Margin = [System.Windows.Thickness]::new(0,8,0,3)
        return $l
    }
    $mkBox = {
        param($val)
        $b = New-Object System.Windows.Controls.TextBox
        $b.Text = $val; $b.Background = New-WpfBrush $Script:Colors.BgSurface
        $b.Foreground = New-WpfBrush $Script:Colors.Text
        $b.CaretBrush = [System.Windows.Media.Brushes]::White
        $b.BorderBrush = New-WpfBrush $Script:Colors.Border
        $b.Padding = [System.Windows.Thickness]::new(6,4,6,4); $b.FontSize = 12
        return $b
    }

    $sp.Children.Add((& $mkLbl "Archivo:")) | Out-Null
    $pathLbl = New-Object System.Windows.Controls.TextBlock
    $pathLbl.Text = [System.IO.Path]::GetFileName($FilePath)
    $pathLbl.Foreground = New-WpfBrush $Script:Colors.Text
    $pathLbl.FontSize = 12; $pathLbl.TextWrapping = 'Wrap'
    $sp.Children.Add($pathLbl) | Out-Null

    if ($hasLineCtx) {
        $sp.Children.Add((& $mkLbl "Fila / Linea:")) | Out-Null
        $lineInfo = New-Object System.Windows.Controls.TextBlock
        $lineInfo.Text = if ($ColumnName) { "Linea $LineNumber  ·  Columna: $ColumnName" } else { "Linea $LineNumber" }
        $lineInfo.Foreground = New-WpfBrush $Script:Colors.Info
        $lineInfo.FontSize = 12
        $sp.Children.Add($lineInfo) | Out-Null

        if (-not [string]::IsNullOrEmpty($CellValue)) {
            $sp.Children.Add((& $mkLbl "Valor de celda:")) | Out-Null
            $cellLbl = New-Object System.Windows.Controls.TextBlock
            $cellLbl.Text        = if ($CellValue.Length -gt 80) { $CellValue.Substring(0,80) + "..." } else { $CellValue }
            $cellLbl.Foreground  = New-WpfBrush $Script:Colors.TextMuted
            $cellLbl.FontSize    = 11
            $cellLbl.TextWrapping= 'Wrap'
            $sp.Children.Add($cellLbl) | Out-Null
        }
    }

    $sp.Children.Add((& $mkLbl "Etiqueta:")) | Out-Null
    $defLabel = if ($existing) { $existing.Label } elseif ($hasLineCtx -and $ColumnName) {
        "$([System.IO.Path]::GetFileNameWithoutExtension($FilePath)) L$LineNumber $ColumnName"
    } else { [System.IO.Path]::GetFileName($FilePath) }
    $labelBox = & $mkBox $defLabel
    $sp.Children.Add($labelBox) | Out-Null

    $sp.Children.Add((& $mkLbl "Severidad:")) | Out-Null
    $sevCombo = New-Object System.Windows.Controls.ComboBox
    $sevCombo.Background = New-WpfBrush $Script:Colors.BgSurface
    $sevCombo.Foreground = New-WpfBrush $Script:Colors.Text
    $sevCombo.FontSize   = 12
    $sevCombo.Padding    = [System.Windows.Thickness]::new(6,4,6,4)

    # El popup del ComboBox siempre usa fondo blanco del sistema (no override fiable en WPF).
    # Solución: texto oscuro en items (legible sobre blanco) + trigger azul en hover.
    # La cabecera cerrada usa $sevCombo.Foreground (color del tema), no el ItemContainerStyle.
    $icStyle = New-Object System.Windows.Style([System.Windows.Controls.ComboBoxItem])
    foreach ($sd in @(
        @{ P=[System.Windows.Controls.Control]::BackgroundProperty; V=[System.Windows.Media.Brushes]::Transparent },
        @{ P=[System.Windows.Controls.Control]::ForegroundProperty; V=(New-WpfBrush "#111827")                    },
        @{ P=[System.Windows.Controls.Control]::PaddingProperty;    V=([System.Windows.Thickness]::new(8,4,8,4))  }
    )) {
        $setter = New-Object System.Windows.Setter; $setter.Property=$sd.P; $setter.Value=$sd.V
        $icStyle.Setters.Add($setter) | Out-Null
    }
    $hiTrigger = New-Object System.Windows.Trigger
    $hiTrigger.Property = [System.Windows.Controls.ListBoxItem]::IsHighlightedProperty
    $hiTrigger.Value    = $true
    foreach ($td in @(
        @{ P=[System.Windows.Controls.Control]::BackgroundProperty; V=(New-WpfBrush $Script:Colors.SelectionBg) },
        @{ P=[System.Windows.Controls.Control]::ForegroundProperty; V=[System.Windows.Media.Brushes]::White     }
    )) {
        $ts = New-Object System.Windows.Setter; $ts.Property=$td.P; $ts.Value=$td.V
        $hiTrigger.Setters.Add($ts) | Out-Null
    }
    $icStyle.Triggers.Add($hiTrigger) | Out-Null
    $sevCombo.ItemContainerStyle = $icStyle

    $sevOptions = [string[]]@("Info","Medium","High","Critical")
    $sevCombo.ItemsSource = $sevOptions
    $defSev = if ($existing) { $existing.Severity } else { "Info" }
    $sevCombo.SelectedIndex = [System.Array]::IndexOf($sevOptions, $defSev)
    if ($sevCombo.SelectedIndex -lt 0) { $sevCombo.SelectedIndex = 0 }
    $sp.Children.Add($sevCombo) | Out-Null

    $sp.Children.Add((& $mkLbl "Nota:")) | Out-Null
    $noteVal = if ($existing) { $existing.Note } else { "" }
    $noteBox = & $mkBox $noteVal
    $sp.Children.Add($noteBox) | Out-Null

    $btnRow = New-Object System.Windows.Controls.StackPanel
    $btnRow.Orientation         = 'Horizontal'
    $btnRow.HorizontalAlignment = 'Right'
    $btnRow.Margin              = [System.Windows.Thickness]::new(0,14,0,0)

    $btnOK = New-Object System.Windows.Controls.Button
    $btnOK.Content = "Guardar"; $btnOK.Width = 90; $btnOK.Height = 30
    $btnOK.Background = New-WpfBrush $Script:Colors.Accent
    $btnOK.Foreground = [System.Windows.Media.Brushes]::White
    $btnOK.FontSize   = 12; $btnOK.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnOK.Margin     = [System.Windows.Thickness]::new(0,0,8,0)
    $btnRow.Children.Add($btnOK) | Out-Null

    $btnCancel = New-Object System.Windows.Controls.Button
    $btnCancel.Content = "Cancelar"; $btnCancel.Width = 80; $btnCancel.Height = 30
    $btnCancel.Background = New-WpfBrush $Script:Colors.BgCard
    $btnCancel.Foreground = New-WpfBrush $Script:Colors.Text
    $btnCancel.FontSize   = 12; $btnCancel.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnRow.Children.Add($btnCancel) | Out-Null
    $sp.Children.Add($btnRow) | Out-Null
    $dlg.Content = $sp

    $btnOK.Tag = [PSCustomObject]@{
        Dlg        = $dlg
        LabelBox   = $labelBox
        SevCombo   = $sevCombo
        NoteBox    = $noteBox
        FilePath   = $FilePath
        LineNumber = $LineNumber
        ColumnName = $ColumnName
        CellValue  = $CellValue
    }
    $btnOK.Add_Click({
        param($sender, $e)
        $ctx = $sender.Tag
        try {
            $sev = if ($ctx.SevCombo.SelectedItem) { $ctx.SevCombo.SelectedItem.ToString() } else { "Info" }
            Add-Bookmark -FilePath   $ctx.FilePath `
                         -Label      $ctx.LabelBox.Text.Trim() `
                         -Severity   $sev `
                         -Note       $ctx.NoteBox.Text.Trim() `
                         -LineNumber $ctx.LineNumber `
                         -ColumnName $ctx.ColumnName `
                         -CellValue  $ctx.CellValue
            $ctx.Dlg.DialogResult = $true
            Set-Status "Marcador guardado: $($ctx.LabelBox.Text.Trim())" "$($Script:Bookmarks.Count) marcadores"
        } catch {
            [System.Windows.MessageBox]::Show("Error al guardar marcador:`n$_", "MaPeriT.TN", 'OK', 'Error')
        }
    })
    $btnCancel.Tag = $dlg
    $btnCancel.Add_Click({ param($s,$e); ($s.Tag).DialogResult = $false })
    [void]$dlg.ShowDialog()
}

function Export-BookmarksReport {
    if ($Script:Bookmarks.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No hay marcadores para exportar.", "MaPeriT.TN", 'OK', 'Information')
        return
    }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter   = "HTML (*.html)|*.html|CSV (*.csv)|*.csv"
    $dlg.FileName = "MaPeriT_Marcadores_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    if ($dlg.ShowDialog() -ne $true) { return }
    $out = $dlg.FileName
    if ($out -match '\.csv$') {
        $Script:Bookmarks | Export-Csv $out -NoTypeInformation -Encoding UTF8
    } else {
        $rows = ""
        foreach ($b in $Script:Bookmarks) {
            $bg  = switch ($b.Severity) { "Critical"{"#3B1010"} "High"{"#3B2210"} "Medium"{"#3B3210"} default{"#1F2937"} }
            $ln  = if ($b.LineNumber -gt 0) { $b.LineNumber.ToString() } else { "" }
            $rows += "<tr style='background:$bg'>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.Severity))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.Label))</td>"
            $rows += "<td style='font-family:monospace;font-size:11px'>$([System.Net.WebUtility]::HtmlEncode($b.FilePath))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($ln))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.ColumnName))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.CellValue))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.Note))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.Timestamp))</td></tr>`n"
        }
        $html = "<!DOCTYPE html><html lang='es'><head><meta charset='UTF-8'><title>MaPeriT.TN - Marcadores</title><style>body{background:#111827;color:#F1F5F9;font-family:'Segoe UI',sans-serif;padding:30px}h1{color:#3B82F6;font-weight:300}.sub{color:#64748B;font-size:13px;margin-bottom:24px}table{border-collapse:collapse;width:100%}th{background:#0F172A;color:#94A3B8;font-size:11px;text-transform:uppercase;padding:8px 12px;text-align:left;border-bottom:1px solid #334155}td{padding:7px 12px;font-size:12px;border-bottom:1px solid #1F2937;color:#CBD5E1}</style></head><body><h1>MaPeriT.TN - Informe de Marcadores</h1><p class='sub'>Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &nbsp;·&nbsp; $($Script:Bookmarks.Count) marcadores</p><table><thead><tr><th>Severidad</th><th>Etiqueta</th><th>Archivo</th><th>Linea</th><th>Columna</th><th>Valor</th><th>Nota</th><th>Fecha</th></tr></thead><tbody>$rows</tbody></table></body></html>"
        [System.IO.File]::WriteAllText($out, $html, [System.Text.Encoding]::UTF8)
        Start-Process $out
    }
    Set-Status "Informe exportado: $out"
}

#endregion
#endregion

#region ===== src\Analysis\IOCHighlighter.ps1 =====
#region ============================================================
# MaPeriT.TN - DETECCION DE IOCs Y SEVERIDAD DE FILAS
# ============================================================

function Get-CellSeverity {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "Normal" }

    if ($Value -match $Script:IOCPatterns.EncodedCmd)     { return "Critical" }
    if ($Value -match $Script:IOCPatterns.SuspiciousPath) { return "High" }
    if ($Value -match $Script:IOCPatterns.SuspiciousExe)  { return "High" }
    if ($Value -match $Script:IOCPatterns.IPv4External)   { return "Info" }
    if ($Value -match $Script:IOCPatterns.SHA256)         { return "Info" }
    return "Normal"
}

function Get-RowSeverity {
    param([System.Data.DataRow]$Row)

    $cols = $Row.Table.Columns | ForEach-Object { $_.ColumnName }

    # Columna Severity explicita
    foreach ($c in @('Severity','Severidad','Level','Nivel')) {
        if ($c -in $cols) {
            switch ($Row[$c].ToString().ToUpper()) {
                { $_ -in 'CRITICAL','CRITICA','CRITICO' } { return 'Critical' }
                { $_ -in 'HIGH','ALTA','ALTO' }           { return 'High' }
                { $_ -in 'MEDIUM','MEDIA','MEDIO' }       { return 'Medium' }
            }
        }
    }

    # EventID
    if ('EventID' -in $cols) {
        $eid = 0
        if ([int]::TryParse($Row['EventID'].ToString(), [ref]$eid)) {
            if ($eid -in $Script:EventSeverity.Critical) { return 'Critical' }
            if ($eid -in $Script:EventSeverity.High)     { return 'High' }
            if ($eid -in $Script:EventSeverity.Medium)   { return 'Medium' }
        }
    }

    # Analizar contenido de celdas
    $maxSev = "Normal"
    foreach ($col in $cols) {
        $sev = Get-CellSeverity $Row[$col].ToString()
        switch ($sev) {
            "Critical" { return "Critical" }
            "High"     { if ($maxSev -ne "Critical") { $maxSev = "High" } }
            "Medium"   { if ($maxSev -notin "Critical","High") { $maxSev = "Medium" } }
            "Info"     { if ($maxSev -eq "Normal") { $maxSev = "Info" } }
        }
    }
    return $maxSev
}

function Get-SeverityBrush {
    param([string]$Severity, [bool]$IsAlt = $false)
    $hexColor = switch ($Severity) {
        "Critical" { $Script:Colors.RowCritical  }
        "High"     { $Script:Colors.RowDanger    }
        "Medium"   { $Script:Colors.RowWarning   }
        "Info"     { $Script:Colors.RowInfo      }
        default    { if ($IsAlt) { $Script:Colors.BgCard } else { $Script:Colors.BgPanel } }
    }
    return New-WpfBrush $hexColor
}

function Get-TimestompBrush { return New-WpfBrush $Script:Colors.RowTimestomp }

#endregion
#endregion

#region ===== src\Analysis\IOCScanner.ps1 =====
#region ============================================================
# MaPeriT.TN - ESCANER IOC DE PROYECTO COMPLETO
# ============================================================

function New-IOCScanViewerContent {
    param([string]$ProjectPath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    foreach ($h in @([System.Windows.GridLength]::Auto,
                     [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star),
                     [System.Windows.GridLength]::Auto)) {
        $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = $h
        $outer.RowDefinitions.Add($rd)
    }

    # Toolbar
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(8,5,8,5)
    $tbDP = New-Object System.Windows.Controls.DockPanel
    $tbDP.LastChildFill = $false

    $titleLbl = New-Object System.Windows.Controls.TextBlock
    $titleLbl.Text       = "Escaner IOC — Proyecto completo  ·  CSV · JSON · TXT · LOG"
    $titleLbl.FontSize   = 12
    $titleLbl.FontWeight = [System.Windows.FontWeights]::SemiBold
    $titleLbl.Foreground = New-WpfBrush $Script:Colors.Text
    $titleLbl.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($titleLbl, 'Left')
    $tbDP.Children.Add($titleLbl) | Out-Null

    $rightSP = New-Object System.Windows.Controls.StackPanel
    $rightSP.Orientation = 'Horizontal'
    [System.Windows.Controls.DockPanel]::SetDock($rightSP, 'Right')

    $filterBox = New-Object System.Windows.Controls.TextBox
    $filterBox.Width = 180; $filterBox.Height = 24
    $filterBox.Background = New-WpfBrush $Script:Colors.BgSurface
    $filterBox.Foreground = New-WpfBrush $Script:Colors.Text
    $filterBox.CaretBrush = [System.Windows.Media.Brushes]::White
    $filterBox.BorderBrush = New-WpfBrush $Script:Colors.Border
    $filterBox.Padding = [System.Windows.Thickness]::new(6,2,6,2)
    $filterBox.FontSize = 11; $filterBox.ToolTip = "Filtrar por tipo, fichero o coincidencia"
    $rightSP.Children.Add($filterBox) | Out-Null

    foreach ($bt in @("Export CSV","Export HTML")) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $bt; $btn.Height = 24
        $btn.Padding = [System.Windows.Thickness]::new(8,2,8,2)
        $btn.Margin  = [System.Windows.Thickness]::new(4,0,0,0)
        $btn.Background = New-WpfBrush $Script:Colors.BgSurface
        $btn.Foreground = New-WpfBrush $Script:Colors.Text
        $btn.BorderBrush = New-WpfBrush $Script:Colors.Border
        $btn.FontSize = 11; $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $rightSP.Children.Add($btn) | Out-Null
    }
    $tbDP.Children.Add($rightSP) | Out-Null
    $toolbar.Child = $tbDP
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # DataGrid
    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly = $true; $dg.AutoGenerateColumns = $false
    $dg.SelectionMode = 'Extended'; $dg.SelectionUnit = 'FullRow'
    $dg.CanUserSortColumns = $true; $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($dg, [System.Windows.Controls.VirtualizationMode]::Recycling)
    Apply-DataGridDarkTheme $dg
    Add-DataGridRowContextMenu -DG $dg -FilePath $ProjectPath
    foreach ($cd in @(
        @{ H="Severidad"; B="Severity"; W=80  },
        @{ H="Tipo IOC";  B="IOCType";  W=130 },
        @{ H="Fichero";   B="Fichero";  W=200 },
        @{ H="Linea";     B="Linea";    W=55  },
        @{ H="Coincidencia"; B="Match"; W=260 },
        @{ H="Contexto";  B="Context";  W=380 }
    )) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header  = $cd.H
        $col.Binding = New-Object System.Windows.Data.Binding($cd.B)
        $col.Width   = $cd.W
        $dg.Columns.Add($col) | Out-Null
    }
    $dg.Add_LoadingRow({
        param($s, $e)
        $item = $e.Row.Item -as [System.Data.DataRowView]
        if ($null -eq $item) { return }
        $bg = switch ($item['Severity']) {
            "Critical" { New-WpfBrush $Script:Colors.RowCritical }
            "High"     { New-WpfBrush $Script:Colors.RowDanger   }
            "Info"     { New-WpfBrush $Script:Colors.RowInfo     }
            default    { $null }
        }
        if ($null -ne $bg) { $e.Row.Background = $bg }
    })
    [System.Windows.Controls.Grid]::SetRow($dg, 1)
    $outer.Children.Add($dg) | Out-Null

    # BUG CONFIRMADO: $dg es local a esta funcion (mismo bug de closure que en
    # MainWindow.ps1) - usar $s (sender) en vez de la variable local capturada.
    $dg.Add_MouseDoubleClick({
        param($s, $e)
        $item = $s.SelectedItem -as [System.Data.DataRowView]
        if ($item) {
            $ruta = $item['Ruta'] -as [string]
            if ($ruta -and (Test-Path $ruta)) { Open-FileInTab -FilePath $ruta }
        }
    })

    # Status
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Text       = "Escaneando proyecto..."
    $statusLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $statusLabel.FontSize   = 11
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    $overlay = New-LoadingOverlay -Message "Escaneando IOCs en el proyecto..." -RowSpan 3
    $outer.Children.Add($overlay) | Out-Null

    # Filter
    $filterBox.Tag = [PSCustomObject]@{ DG = $dg; Status = $statusLabel }
    $filterBox.Add_TextChanged({
        param($sender, $e)
        $ctx = $sender.Tag
        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl) { return }
        $txt = $sender.Text.Trim()
        if ([string]::IsNullOrEmpty($txt)) {
            $tbl.DefaultView.RowFilter = ""
        } else {
            $safeT = $txt -replace "'", "''"
            try {
                $tbl.DefaultView.RowFilter = "CONVERT([IOCType],'System.String') LIKE '%$safeT%' OR CONVERT([Match],'System.String') LIKE '%$safeT%' OR CONVERT([Fichero],'System.String') LIKE '%$safeT%' OR CONVERT([Severity],'System.String') LIKE '%$safeT%'"
            } catch { $tbl.DefaultView.RowFilter = "" }
        }
        $ctx.DG.ItemsSource = $tbl.DefaultView
        $ctx.Status.Text = "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) IOCs"
    })

    # Export buttons
    foreach ($btn in ($rightSP.Children | Where-Object { $_ -is [System.Windows.Controls.Button] })) {
        $btn.Tag = [PSCustomObject]@{ DG = $dg }
        $btn.Add_Click({
            param($sender, $e)
            $ctx = $sender.Tag
            $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
            if ($null -eq $tbl -or $tbl.Rows.Count -eq 0) { Set-Status "Sin IOCs para exportar"; return }
            if ($sender.Content -match 'CSV') {
                $dlg2 = New-Object Microsoft.Win32.SaveFileDialog
                $dlg2.Filter = "CSV (*.csv)|*.csv"
                $dlg2.FileName = "IOC_Scan_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                if ($dlg2.ShowDialog() -eq $true) {
                    $tbl.DefaultView.ToTable() | Export-Csv $dlg2.FileName -NoTypeInformation -Encoding UTF8
                    Set-Status "Exportado: $($dlg2.FileName)"
                }
            } else {
                Export-IOCScanHTML -Table $tbl
            }
        })
    }

    # Background IOC scan (Runspace)
    $bgScript = {
        param($projectPath, $patterns)
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        $patternMap = [ordered]@{
            'EncodedCmd'     = @{ Pattern=$patterns.EncodedCmd;     Severity='Critical'; Label='Comando codificado' }
            'SuspiciousPath' = @{ Pattern=$patterns.SuspiciousPath; Severity='High';     Label='Ruta anomala'       }
            'SuspiciousExe'  = @{ Pattern=$patterns.SuspiciousExe;  Severity='High';     Label='Ejecutable sospechoso' }
            'IPv4External'   = @{ Pattern=$patterns.IPv4External;   Severity='Info';     Label='IP Externa'         }
            'SHA256'         = @{ Pattern=$patterns.SHA256;          Severity='Info';     Label='Hash SHA256'        }
        }
        $files = @(Get-ChildItem $projectPath -Recurse -Include "*.csv","*.json","*.txt","*.log" -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -lt 30MB -and $_.Length -gt 0 })
        foreach ($file in $files) {
            try {
                $lines = [System.IO.File]::ReadAllLines($file.FullName, [System.Text.Encoding]::UTF8)
                $lineNum = 0
                foreach ($line in $lines) {
                    $lineNum++
                    if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
                    foreach ($key in $patternMap.Keys) {
                        $pm = $patternMap[$key]
                        $m = [regex]::Match($line, $pm.Pattern)
                        if ($m.Success) {
                            $ctx = $line.Trim()
                            if ($ctx.Length -gt 280) { $ctx = $ctx.Substring(0,280) + "..." }
                            $matchVal = $m.Value
                            if ($matchVal.Length -gt 140) { $matchVal = $matchVal.Substring(0,140) }
                            $results.Add([PSCustomObject]@{
                                Severity = $pm.Severity
                                IOCType  = $pm.Label
                                Fichero  = $file.Name
                                Linea    = $lineNum
                                Match    = $matchVal
                                Context  = $ctx
                                Ruta     = $file.FullName
                            }) | Out-Null
                            break  # one hit per line per pattern priority
                        }
                    }
                }
            } catch {}
        }
        $sorted = $results | Sort-Object @{E={ switch($_.Severity){"Critical"{0}"High"{1}default{2}} }}, Fichero, Linea
        Write-Output -NoEnumerate ([PSCustomObject]@{ Results=$sorted; Files=$files.Count; Err="" })
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{ projectPath=$ProjectPath; patterns=$Script:IOCPatterns })
    $handle = $ps.BeginInvoke()

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(400)
    $timer.Tag = [PSCustomObject]@{ Ps=$ps; Handle=$handle; Rs=$rs; DG=$dg; Status=$statusLabel; Overlay=$overlay }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag
        if ($ctx.Ps.InvocationStateInfo.State -in 'Completed','Failed','Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                $tbl = [System.Data.DataTable]::new("IOCScan")
                foreach ($c in @('Severity','IOCType','Fichero','Linea','Match','Context','Ruta')) {
                    [void]$tbl.Columns.Add($c, [string])
                }
                if ($obj -and $obj.Results) {
                    foreach ($r in $obj.Results) {
                        $row = $tbl.NewRow()
                        $row['Severity'] = $r.Severity; $row['IOCType'] = $r.IOCType
                        $row['Fichero']  = $r.Fichero;  $row['Linea']   = $r.Linea.ToString()
                        $row['Match']    = $r.Match;    $row['Context']  = $r.Context
                        $row['Ruta']     = $r.Ruta
                        [void]$tbl.Rows.Add($row)
                    }
                }
                $ctx.DG.Tag = $tbl
                $ctx.DG.ItemsSource = $tbl.DefaultView
                $ctx.Status.Text = "$($tbl.Rows.Count) IOCs detectados en $($obj.Files) ficheros"
            } catch {
                $ctx.Status.Text = "Error: $($_.Exception.Message)"
            } finally {
                $ctx.Overlay.Visibility = 'Collapsed'
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
    return $outer
}

function Export-IOCScanHTML {
    param([System.Data.DataTable]$Table)
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = "HTML (*.html)|*.html"
    $dlg.FileName = "IOC_Scan_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    if ($dlg.ShowDialog() -ne $true) { return }
    $rows = ""
    foreach ($row in $Table.DefaultView.ToTable().Rows) {
        $bg = switch ($row['Severity']) { "Critical"{"#3B1010"} "High"{"#3B2210"} default{"#0F2840"} }
        $rows += "<tr style='background:$bg'>"
        foreach ($c in @('Severity','IOCType','Fichero','Linea','Match','Context')) {
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($row[$c].ToString()))</td>"
        }
        $rows += "</tr>`n"
    }
    $html = "<!DOCTYPE html><html lang='es'><head><meta charset='UTF-8'><title>MaPeriT.TN - IOC Scan</title><style>body{background:#111827;color:#F1F5F9;font-family:'Segoe UI',sans-serif;padding:30px}h1{color:#3B82F6;font-weight:300}.sub{color:#64748B;font-size:13px;margin-bottom:24px}table{border-collapse:collapse;width:100%}th{background:#0F172A;color:#94A3B8;font-size:11px;text-transform:uppercase;padding:8px 12px;text-align:left;border-bottom:1px solid #334155}td{padding:7px 12px;font-size:12px;border-bottom:1px solid #1F2937;color:#CBD5E1;word-break:break-all}</style></head><body><h1>MaPeriT.TN - Informe de IOCs</h1><p class='sub'>Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &nbsp;·&nbsp; $($Table.Rows.Count) hallazgos</p><table><thead><tr><th>Severidad</th><th>Tipo</th><th>Fichero</th><th>Linea</th><th>Coincidencia</th><th>Contexto</th></tr></thead><tbody>$rows</tbody></table></body></html>"
    [System.IO.File]::WriteAllText($dlg.FileName, $html, [System.Text.Encoding]::UTF8)
    Start-Process $dlg.FileName
    Set-Status "Informe IOC exportado: $($dlg.FileName)"
}

#endregion
#endregion

#region ===== src\Analysis\TimelineBuilder.ps1 =====
#region ============================================================
# MaPeriT.TN - TIMELINE CONSOLIDADA (MFT + EVTX + CSV)
# ============================================================

function New-TimelineViewerContent {
    param([string]$ProjectPath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    foreach ($h in @([System.Windows.GridLength]::Auto,
                     [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star),
                     [System.Windows.GridLength]::Auto)) {
        $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = $h
        $outer.RowDefinitions.Add($rd)
    }

    # Toolbar
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(8,5,8,5)
    $tbDP = New-Object System.Windows.Controls.DockPanel
    $tbDP.LastChildFill = $false

    $titleLbl = New-Object System.Windows.Controls.TextBlock
    $titleLbl.Text       = "Timeline Consolidada — MFT + EVTX + Artefactos CSV"
    $titleLbl.FontSize   = 12
    $titleLbl.FontWeight = [System.Windows.FontWeights]::SemiBold
    $titleLbl.Foreground = New-WpfBrush $Script:Colors.Text
    $titleLbl.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($titleLbl, 'Left')
    $tbDP.Children.Add($titleLbl) | Out-Null

    $rightSP = New-Object System.Windows.Controls.StackPanel
    $rightSP.Orientation = 'Horizontal'
    [System.Windows.Controls.DockPanel]::SetDock($rightSP, 'Right')

    $filterBox = New-Object System.Windows.Controls.TextBox
    $filterBox.Width = 180; $filterBox.Height = 24
    $filterBox.Background = New-WpfBrush $Script:Colors.BgSurface
    $filterBox.Foreground = New-WpfBrush $Script:Colors.Text
    $filterBox.CaretBrush = [System.Windows.Media.Brushes]::White
    $filterBox.BorderBrush = New-WpfBrush $Script:Colors.Border
    $filterBox.Padding = [System.Windows.Thickness]::new(6,2,6,2)
    $filterBox.FontSize = 11; $filterBox.ToolTip = "Filtrar timeline"
    $rightSP.Children.Add($filterBox) | Out-Null

    $btnExport = New-Object System.Windows.Controls.Button
    $btnExport.Content = "Exportar CSV"; $btnExport.Height = 24
    $btnExport.Padding = [System.Windows.Thickness]::new(8,2,8,2)
    $btnExport.Margin  = [System.Windows.Thickness]::new(4,0,0,0)
    $btnExport.Background = New-WpfBrush $Script:Colors.BgSurface
    $btnExport.Foreground = New-WpfBrush $Script:Colors.Text
    $btnExport.BorderBrush = New-WpfBrush $Script:Colors.Border
    $btnExport.FontSize = 11; $btnExport.Cursor = [System.Windows.Input.Cursors]::Hand
    $rightSP.Children.Add($btnExport) | Out-Null

    $tbDP.Children.Add($rightSP) | Out-Null
    $toolbar.Child = $tbDP
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # DataGrid
    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly = $true; $dg.AutoGenerateColumns = $false
    $dg.SelectionMode = 'Extended'; $dg.SelectionUnit = 'FullRow'
    $dg.CanUserSortColumns = $true; $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($dg, [System.Windows.Controls.VirtualizationMode]::Recycling)
    Apply-DataGridDarkTheme $dg
    Add-DataGridRowContextMenu -DG $dg -FilePath $ProjectPath
    foreach ($cd in @(
        @{ H="Fecha/Hora";   B="Timestamp";   W=155 },
        @{ H="Zona horaria"; B="Zona";        W=110 },
        @{ H="Fuente";       B="Fuente";       W=60  },
        @{ H="Tipo";         B="Tipo";         W=150 },
        @{ H="Descripcion";  B="Descripcion";  W=420 },
        @{ H="Artefacto";    B="Artefacto";    W=180 },
        @{ H="EventID";      B="EventID";      W=65  }
    )) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header  = $cd.H
        $col.Binding = New-Object System.Windows.Data.Binding($cd.B)
        $col.Width   = $cd.W
        $dg.Columns.Add($col) | Out-Null
    }
    $dg.Add_LoadingRow({
        param($s, $e)
        $item = $e.Row.Item -as [System.Data.DataRowView]
        if ($null -eq $item) { return }
        $eid = 0
        if ([int]::TryParse($item['EventID'], [ref]$eid)) {
            if ($eid -in $Script:EventSeverity.Critical) { $e.Row.Background = New-WpfBrush $Script:Colors.RowCritical; return }
            if ($eid -in $Script:EventSeverity.High)     { $e.Row.Background = New-WpfBrush $Script:Colors.RowDanger;   return }
        }
        # Solo los registros MFT con indicio de timestomping (antes se coloreaba
        # cualquier fila del MFT como si lo fuera)
        if ($item['Fuente'] -eq 'MFT' -and $item['Tipo'] -eq 'Posible timestomping') { $e.Row.Background = New-WpfBrush $Script:Colors.RowTimestomp }
    })
    [System.Windows.Controls.Grid]::SetRow($dg, 1)
    $outer.Children.Add($dg) | Out-Null

    # Status
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Text       = "Construyendo timeline..."
    $statusLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $statusLabel.FontSize   = 11
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    $overlay = New-LoadingOverlay -Message "Construyendo timeline..." -RowSpan 3
    $outer.Children.Add($overlay) | Out-Null

    # Filter
    $filterBox.Tag = [PSCustomObject]@{ DG=$dg; Status=$statusLabel }
    $filterBox.Add_TextChanged({
        param($sender, $e)
        $ctx = $sender.Tag
        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl) { return }
        $txt = $sender.Text.Trim()
        if ([string]::IsNullOrEmpty($txt)) { $tbl.DefaultView.RowFilter = "" } else {
            $safeT = $txt -replace "'", "''"
            try { $tbl.DefaultView.RowFilter = "CONVERT([Fuente],'System.String') LIKE '%$safeT%' OR CONVERT([Descripcion],'System.String') LIKE '%$safeT%' OR CONVERT([Artefacto],'System.String') LIKE '%$safeT%' OR CONVERT([Tipo],'System.String') LIKE '%$safeT%'" }
            catch { $tbl.DefaultView.RowFilter = "" }
        }
        $ctx.DG.ItemsSource = $tbl.DefaultView
        $ctx.Status.Text = "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) eventos"
    })

    # Export
    $btnExport.Tag = [PSCustomObject]@{ DG=$dg }
    $btnExport.Add_Click({
        param($sender, $e)
        $tbl = ($sender.Tag).DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl -or $tbl.Rows.Count -eq 0) { return }
        $dlg2 = New-Object Microsoft.Win32.SaveFileDialog
        $dlg2.Filter = "CSV (*.csv)|*.csv"
        $dlg2.FileName = "Timeline_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        if ($dlg2.ShowDialog() -eq $true) {
            $tbl.DefaultView.ToTable() | Export-Csv $dlg2.FileName -NoTypeInformation -Encoding UTF8
            Set-Status "Timeline exportada: $($dlg2.FileName)"
        }
    })

    # Background build
    $bgScript = {
        param($projectPath, $maxEvtx, $criticalIds, $highIds)
        $events = [System.Collections.Generic.List[PSCustomObject]]::new()

        # EVTX
        foreach ($evtx in @(Get-ChildItem $projectPath -Recurse -Filter "*.evtx" -ErrorAction SilentlyContinue)) {
            try {
                foreach ($ev in @(Get-WinEvent -Path $evtx.FullName -MaxEvents $maxEvtx -ErrorAction Stop)) {
                    $msg = if ($ev.Message) { ($ev.Message -replace "[\r\n]+"," ").Substring(0,[Math]::Min(200,$ev.Message.Length)) } else { "" }
                    # En UTC, como el MFT y los CSV de AN (antes hora local del equipo
                    # en el que se ejecuta TN, mezclada sin aviso con fechas UTC)
                    $utc = $ev.TimeCreated.ToUniversalTime()
                    $events.Add([PSCustomObject]@{
                        SortKey    = $utc
                        Timestamp  = $utc.ToString("yyyy-MM-dd HH:mm:ss")
                        Zona       = "UTC"
                        Fuente     = "EVTX"
                        Tipo       = $ev.ProviderName
                        Descripcion= $msg
                        Artefacto  = $evtx.Name
                        EventID    = $ev.Id.ToString()
                    }) | Out-Null
                }
            } catch {}
        }

        # MFT CSVs de MaPeriT.AN (columnas SI_Modificado_UTC/SI_Creado_UTC/FN_Creado_UTC,
        # RutaCompleta/NombreFichero, Estado, Timestomping). Antes se buscaban nombres
        # en ingles que AN no genera y el MFT no entraba nunca en la timeline.
        # Primero los ficheros con indicios (timestomping, borrados) y despues el
        # completo; un mismo registro solo se incluye una vez.
        $mftSeen  = [System.Collections.Generic.HashSet[string]]::new()
        $mftFiles = @(Get-ChildItem $projectPath -Recurse -Filter "MFT_*.csv" -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 50MB } |
            Sort-Object { if ($_.Name -match 'Timestomping') { 0 } elseif ($_.Name -match 'Borrados') { 1 } else { 2 } })
        foreach ($mft in $mftFiles) {
            try {
                foreach ($row in @(Import-Csv $mft.FullName -ErrorAction Stop | Select-Object -First 3000)) {
                    # Prioridad explicita (no el orden de las columnas del CSV) y sin valores vacios
                    $tsCol = @('SI_Modificado_UTC','SI_Creado_UTC','FN_Creado_UTC','SI_Modified','SI_Created','FN_Created') |
                        Where-Object { $row.PSObject.Properties[$_] -and $row.$_ } | Select-Object -First 1
                    if (-not $tsCol) { continue }
                    $key = "$($row.RecordNum)|$($row.RutaCompleta)$($row.FullPath)"
                    if (-not $mftSeen.Add($key)) { continue }
                    $dt = [datetime]::MinValue
                    $ok = [datetime]::TryParseExact([string]$row.$tsCol, 'yyyy-MM-dd HH:mm:ss.fffffff', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$dt)
                    if (-not $ok) { $ok = [datetime]::TryParse([string]$row.$tsCol, [ref]$dt) }
                    if ($ok -and $dt.Year -gt 2000) {
                        $desc = if ($row.RutaCompleta) { $row.RutaCompleta } elseif ($row.NombreFichero) { $row.NombreFichero } elseif ($row.FullPath) { $row.FullPath } elseif ($row.FileName) { $row.FileName } else { "" }
                        $tipo = if ("$($row.Timestomping)" -eq 'True') { "Posible timestomping" } elseif ($row.Estado -eq 'BORRADO') { "Fichero borrado" } else { $tsCol }
                        $events.Add([PSCustomObject]@{
                            SortKey    = $dt
                            Timestamp  = $dt.ToString("yyyy-MM-dd HH:mm:ss")
                            Zona       = "UTC"
                            Fuente     = "MFT"
                            Tipo       = $tipo
                            Descripcion= $desc
                            Artefacto  = $mft.Name
                            EventID    = ""
                        }) | Out-Null
                    }
                }
            } catch {}
        }

        # Other CSVs with time columns
        foreach ($csv in @(Get-ChildItem $projectPath -Recurse -Filter "*.csv" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^MFT_' -and $_.Length -lt 15MB -and $_.Length -gt 0 })) {
            try {
                $rows = @(Import-Csv $csv.FullName -ErrorAction Stop | Select-Object -First 500)
                if ($rows.Count -eq 0) { continue }
                $tsCol = $rows[0].PSObject.Properties.Name | Where-Object { $_ -match '^(Time|Date|Fecha|Hora|Created|Modified|Timestamp|LastWrite|LastAccess)' } | Select-Object -First 1
                if (-not $tsCol) { continue }
                foreach ($row in $rows) {
                    $tsVal = $row.$tsCol
                    if ([string]::IsNullOrEmpty($tsVal)) { continue }
                    $dt = [datetime]::MinValue
                    if ([datetime]::TryParse($tsVal, [ref]$dt) -and $dt.Year -gt 2000 -and $dt.Year -lt 2100) {
                        $cols = $row.PSObject.Properties.Name | Where-Object { $_ -notmatch 'Time|Date|Hash|Id$' } | Select-Object -First 3
                        $desc = ($cols | ForEach-Object { "$_=$($row.$_)" }) -join " | "
                        if ($desc.Length -gt 200) { $desc = $desc.Substring(0,200) }
                        # Zona horaria: la que indique la propia fila (ZonaHoraria de la
                        # correlacion de AN) o el nombre de la columna (*_UTC); si no,
                        # es la hora del origen sin zona declarada (p.ej. hora local de SW).
                        $zona = if ($row.PSObject.Properties['ZonaHoraria'] -and $row.ZonaHoraria) { $row.ZonaHoraria } elseif ($tsCol -match 'UTC') { "UTC" } else { "Sin indicar (origen)" }
                        $events.Add([PSCustomObject]@{
                            SortKey    = $dt
                            Timestamp  = $dt.ToString("yyyy-MM-dd HH:mm:ss")
                            Zona       = $zona
                            Fuente     = "CSV"
                            Tipo       = [System.IO.Path]::GetFileNameWithoutExtension($csv.Name)
                            Descripcion= $desc
                            Artefacto  = $csv.Name
                            EventID    = ""
                        }) | Out-Null
                    }
                }
            } catch {}
        }

        $sorted = @($events | Sort-Object SortKey -Descending | Select-Object -First 50000)
        Write-Output -NoEnumerate ([PSCustomObject]@{ Events=$sorted; Total=$events.Count; Err="" })
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{
        projectPath = $ProjectPath
        maxEvtx     = $Script:MaxEVTXEvents
        criticalIds = $Script:EventSeverity.Critical
        highIds     = $Script:EventSeverity.High
    })
    $handle = $ps.BeginInvoke()

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Tag = [PSCustomObject]@{ Ps=$ps; Handle=$handle; Rs=$rs; DG=$dg; Status=$statusLabel; Overlay=$overlay }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag
        if ($ctx.Ps.InvocationStateInfo.State -in 'Completed','Failed','Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                $tbl = [System.Data.DataTable]::new("Timeline")
                foreach ($c in @('Timestamp','Zona','Fuente','Tipo','Descripcion','Artefacto','EventID')) { [void]$tbl.Columns.Add($c,[string]) }
                if ($obj -and $obj.Events) {
                    foreach ($ev in $obj.Events) {
                        $row = $tbl.NewRow()
                        $row['Timestamp']  = $ev.Timestamp; $row['Zona']      = $ev.Zona; $row['Fuente'] = $ev.Fuente
                        $row['Tipo']       = $ev.Tipo;      $row['Descripcion']= $ev.Descripcion
                        $row['Artefacto']  = $ev.Artefacto; $row['EventID']   = $ev.EventID
                        [void]$tbl.Rows.Add($row)
                    }
                }
                $ctx.DG.Tag = $tbl; $ctx.DG.ItemsSource = $tbl.DefaultView
                $ctx.Status.Text = "$($tbl.Rows.Count) eventos$(if($obj.Total -gt 50000){' (top 50.000)'})"
            } catch { $ctx.Status.Text = "Error: $($_.Exception.Message)" }
            finally {
                $ctx.Overlay.Visibility = 'Collapsed'
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
    return $outer
}

#endregion
#endregion

#region ===== src\Viewers\TextViewer.ps1 =====
#region ============================================================
# MaPeriT.TN - VISOR DE TEXTO / LOG
# ============================================================

function New-TextViewerContent {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    $r0 = New-Object System.Windows.Controls.RowDefinition
    $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = New-Object System.Windows.Controls.RowDefinition
    $r1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $outer.RowDefinitions.Add($r0)
    $outer.RowDefinitions.Add($r1)

    # ── Barra de herramientas ────────────────────────────────────────
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background     = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush    = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness= [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding        = [System.Windows.Thickness]::new(8,5,8,5)

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    # Info label
    $size = if (Test-Path $FilePath) { Format-FileSize (Get-Item $FilePath).Length } else { "" }
    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text       = "$([System.IO.Path]::GetFileName($FilePath))  ·  $size"
    $lbl.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $lbl.FontSize   = 11
    $lbl.VerticalAlignment = 'Center'
    $sp.Children.Add($lbl) | Out-Null

    # Separator
    $sepBorder = New-Object System.Windows.Controls.Border
    $sepBorder.Width            = 1
    $sepBorder.Background       = New-WpfBrush $Script:Colors.Border
    $sepBorder.Margin           = [System.Windows.Thickness]::new(10,2,10,2)
    $sp.Children.Add($sepBorder) | Out-Null

    # Search box
    $searchBox = New-Object System.Windows.Controls.TextBox
    $searchBox.Width      = 180
    $searchBox.Height     = 24
    $searchBox.Background = New-WpfBrush $Script:Colors.BgSurface
    $searchBox.Foreground = New-WpfBrush $Script:Colors.Text
    $searchBox.CaretBrush = [System.Windows.Media.Brushes]::White
    $searchBox.BorderBrush= New-WpfBrush $Script:Colors.Border
    $searchBox.Padding    = [System.Windows.Thickness]::new(6,2,6,2)
    $searchBox.FontSize   = 11
    $sp.Children.Add($searchBox) | Out-Null

    # Copy button
    $copyBtn = New-Object System.Windows.Controls.Button
    $copyBtn.Content          = "Copiar todo"
    $copyBtn.Height           = 24
    $copyBtn.Padding          = [System.Windows.Thickness]::new(8,2,8,2)
    $copyBtn.Margin           = [System.Windows.Thickness]::new(6,0,0,0)
    $copyBtn.Background       = New-WpfBrush $Script:Colors.BgSurface
    $copyBtn.Foreground       = New-WpfBrush $Script:Colors.Text
    $copyBtn.BorderBrush      = New-WpfBrush $Script:Colors.Border
    $copyBtn.FontSize         = 11
    $copyBtn.Cursor           = [System.Windows.Input.Cursors]::Hand
    $sp.Children.Add($copyBtn) | Out-Null

    $toolbar.Child = $sp
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # ── Contenido ────────────────────────────────────────────────────
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility   = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Auto'
    $scroll.Background = New-WpfBrush $Script:Colors.BgPrimary

    $contentGrid = New-Object System.Windows.Controls.Grid
    $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = [System.Windows.GridLength]::Auto
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $contentGrid.ColumnDefinitions.Add($c0)
    $contentGrid.ColumnDefinitions.Add($c1)

    $monoFont = New-Object System.Windows.Media.FontFamily("Cascadia Code, Consolas, Courier New")

    # Leer fichero
    $lines = @()
    try {
        if (Test-Path $FilePath) {
            $lines = [System.IO.File]::ReadAllLines($FilePath, [System.Text.Encoding]::UTF8)
        }
    } catch {
        try { $lines = Get-Content $FilePath -ErrorAction SilentlyContinue }
        catch { $lines = @("Error al leer el fichero: $_") }
    }

    # Panel de numeros de linea
    $lineNums = New-Object System.Windows.Controls.TextBlock
    $lineNums.FontFamily   = $monoFont
    $lineNums.FontSize     = 12
    $lineNums.Foreground   = New-WpfBrush $Script:Colors.TextDim
    $lineNums.Background   = New-WpfBrush $Script:Colors.BgHeader
    $lineNums.Padding      = [System.Windows.Thickness]::new(8,8,12,8)
    $lineNums.TextAlignment= 'Right'
    $lineNums.Text         = (1..$([Math]::Max(1,$lines.Count)) | ForEach-Object { $_ }) -join "`n"
    $lineNums.VerticalAlignment = 'Top'
    [System.Windows.Controls.Grid]::SetColumn($lineNums, 0)

    # Contenido de texto
    $textContent = New-Object System.Windows.Controls.TextBlock
    $textContent.FontFamily  = $monoFont
    $textContent.FontSize    = 12
    $textContent.Foreground  = New-WpfBrush $Script:Colors.Text
    $textContent.Padding     = [System.Windows.Thickness]::new(12,8,8,8)
    $textContent.TextWrapping= 'NoWrap'
    $textContent.Text        = $lines -join "`n"
    $textContent.VerticalAlignment = 'Top'
    [System.Windows.Controls.Grid]::SetColumn($textContent, 1)

    $contentGrid.Children.Add($lineNums) | Out-Null
    $contentGrid.Children.Add($textContent) | Out-Null
    $scroll.Content = $contentGrid
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $outer.Children.Add($scroll) | Out-Null

    # Eventos
    # BUG CONFIRMADO (mismo patron que JSONViewer.ps1): $allText es local,
    # el boton se pulsa tras retornar la funcion -> portapapeles vacio sin
    # ningun error visible. Se guarda en .Tag.
    $allText = $lines -join "`n"
    $copyBtn.Tag = $allText
    $copyBtn.Add_Click({ param($s, $e) [System.Windows.Clipboard]::SetText($s.Tag) })

    # Busqueda: scroll a primera ocurrencia + resalta en status
    $searchBox.Tag = [PSCustomObject]@{
        Scroll    = $scroll
        LineNums  = $lineNums
        Content   = $textContent
        Lines     = $lines
        LastMatch = -1
    }
    $searchBox.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -ne 'Return') { return }
        $ctx   = $sender.Tag
        $query = $sender.Text.Trim()
        if ([string]::IsNullOrEmpty($query)) { return }

        $startLine = if ($e.Key -eq 'Return' -and [System.Windows.Input.Keyboard]::Modifiers -band 'Shift') {
            [Math]::Max(0, $ctx.LastMatch - 1)
        } else { $ctx.LastMatch + 1 }

        $found = -1
        for ($i = $startLine; $i -lt $ctx.Lines.Count; $i++) {
            if ($ctx.Lines[$i] -match [regex]::Escape($query)) { $found = $i; break }
        }
        if ($found -eq -1 -and $startLine -gt 0) {
            for ($i = 0; $i -lt $startLine; $i++) {
                if ($ctx.Lines[$i] -match [regex]::Escape($query)) { $found = $i; break }
            }
        }
        if ($found -ge 0) {
            $ctx.LastMatch = $found
            $approxY = $found * 18.5
            $ctx.Scroll.ScrollToVerticalOffset($approxY)
            $sender.Background = New-WpfBrush "#1A3A1A"
        } else {
            $sender.Background = New-WpfBrush "#3A1A1A"
        }
    })
    $searchBox.Add_TextChanged({
        param($sender, $e)
        $ctx = $sender.Tag
        $ctx.LastMatch = -1
        $sender.Background = New-WpfBrush $Script:Colors.BgSurface
    })

    # ── Menú contextual en el área de texto ─────────────────────────
    $textCM = New-Object System.Windows.Controls.ContextMenu
    $textCM.Background      = New-WpfBrush $Script:Colors.BgCard
    $textCM.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $textCM.BorderThickness = [System.Windows.Thickness]::new(1)
    $textCM.Padding         = [System.Windows.Thickness]::new(2)
    foreach ($mDef in @(
        @{ H="Copiar todo";                    A="Copy"     },
        @{ H="-";                              A="-"        },
        @{ H="Anadir marcador del archivo..."; A="Bookmark" }
    )) {
        if ($mDef.A -eq "-") { $textCM.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null }
        else {
            $mItem = New-Object System.Windows.Controls.MenuItem
            $mItem.Header     = $mDef.H
            $mItem.Foreground = New-WpfBrush $Script:Colors.Text
            $mItem.Background = New-WpfBrush $Script:Colors.BgCard
            $mItem.FontSize   = 12
            $mItem.Tag = [PSCustomObject]@{ Action=$mDef.A; FilePath=$FilePath; AllText=$allText }
            $mItem.Add_Click({
                param($s, $e)
                $ctx = $s.Tag
                switch ($ctx.Action) {
                    "Copy"     { [System.Windows.Clipboard]::SetText($ctx.AllText) }
                    "Bookmark" { Show-AddBookmarkDialog -FilePath $ctx.FilePath }
                }
            })
            $textCM.Items.Add($mItem) | Out-Null
        }
    }
    $outer.ContextMenu = $textCM

    return $outer
}

#endregion
#endregion

#region ===== src\Viewers\JSONViewer.ps1 =====
#region ============================================================
# MaPeriT.TN - VISOR JSON
# ============================================================

function New-JSONViewerContent {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    $r0 = New-Object System.Windows.Controls.RowDefinition; $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $outer.RowDefinitions.Add($r0)
    $outer.RowDefinitions.Add($r1)

    # ── Toolbar ─────────────────────────────────────────────────────
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(8,5,8,5)

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    $size = if (Test-Path $FilePath) { Format-FileSize (Get-Item $FilePath).Length } else { "" }
    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text       = "$([System.IO.Path]::GetFileName($FilePath))  ·  $size"
    $lbl.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $lbl.FontSize   = 11
    $lbl.VerticalAlignment = 'Center'
    $sp.Children.Add($lbl) | Out-Null

    $copyBtn = New-Object System.Windows.Controls.Button
    $copyBtn.Content     = "Copiar"
    $copyBtn.Height      = 24
    $copyBtn.Padding     = [System.Windows.Thickness]::new(8,2,8,2)
    $copyBtn.Margin      = [System.Windows.Thickness]::new(10,0,0,0)
    $copyBtn.Background  = New-WpfBrush $Script:Colors.BgSurface
    $copyBtn.Foreground  = New-WpfBrush $Script:Colors.Text
    $copyBtn.BorderBrush = New-WpfBrush $Script:Colors.Border
    $copyBtn.FontSize    = 11
    $copyBtn.Cursor      = [System.Windows.Input.Cursors]::Hand
    $sp.Children.Add($copyBtn) | Out-Null

    $toolbar.Child = $sp
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # ── Contenido ────────────────────────────────────────────────────
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility   = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Auto'
    $scroll.Background = New-WpfBrush $Script:Colors.BgPrimary

    $textBlock = New-Object System.Windows.Controls.TextBlock
    $textBlock.FontFamily  = New-Object System.Windows.Media.FontFamily("Cascadia Code, Consolas, Courier New")
    $textBlock.FontSize    = 12
    $textBlock.Foreground  = New-WpfBrush $Script:Colors.Text
    $textBlock.Padding     = [System.Windows.Thickness]::new(16,12,16,12)
    $textBlock.TextWrapping= 'NoWrap'
    $textBlock.VerticalAlignment = 'Top'

    $rawText = ""
    try {
        if (Test-Path $FilePath) {
            $rawText = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
            # Pretty-print JSON
            try {
                $obj = $rawText | ConvertFrom-Json
                $rawText = $obj | ConvertTo-Json -Depth 20
            } catch {}
        }
    } catch { $rawText = "Error al leer: $_" }

    $textBlock.Text = $rawText
    $scroll.Content = $textBlock
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $outer.Children.Add($scroll) | Out-Null

    # BUG CONFIRMADO (verificado empiricamente): $rawText es local a esta
    # funcion; el boton se pulsa despues de que la funcion ya ha retornado,
    # asi que $rawText es $null en ese momento - SetText($null) no lanza
    # error pero deja el portapapeles vacio: el examinador cree que ha
    # copiado evidencia y en realidad no ha copiado nada. Se guarda en .Tag.
    $copyBtn.Tag = $rawText
    $copyBtn.Add_Click({ param($s, $e) [System.Windows.Clipboard]::SetText($s.Tag) })

    return $outer
}

#endregion
#endregion

#region ===== src\Viewers\CSVViewer.ps1 =====
#region ============================================================
# MaPeriT.TN - VISOR CSV
# ============================================================

# Helper compartido: convierte array de PSObjects a DataTable.
# Usa Write-Output -NoEnumerate para evitar que PS enumere el DataTable al retornarlo.
function ConvertTo-DataTable {
    param([object[]]$Data, [string]$TableName = "TNData")
    $tbl = [System.Data.DataTable]::new($TableName)
    if (-not $Data -or $Data.Count -eq 0) {
        Write-Output -NoEnumerate $tbl
        return
    }
    foreach ($prop in $Data[0].PSObject.Properties.Name) {
        [void]$tbl.Columns.Add($prop, [string])
    }
    foreach ($item in $Data) {
        $row = $tbl.NewRow()
        foreach ($c in $tbl.Columns) {
            $v = $item.($c.ColumnName)
            $row[$c.ColumnName] = if ($null -ne $v) { $v.ToString() } else { "" }
        }
        [void]$tbl.Rows.Add($row)
    }
    Write-Output -NoEnumerate $tbl
}

function Apply-DataGridDarkTheme {
    param([System.Windows.Controls.DataGrid]$DG)
    $DG.Background               = New-WpfBrush $Script:Colors.BgPanel
    $DG.RowBackground            = New-WpfBrush $Script:Colors.BgPanel
    $DG.AlternatingRowBackground = New-WpfBrush $Script:Colors.BgCard
    $DG.Foreground               = New-WpfBrush $Script:Colors.Text
    $DG.BorderBrush              = New-WpfBrush $Script:Colors.Border
    $DG.BorderThickness          = [System.Windows.Thickness]::new(0)
    $DG.GridLinesVisibility      = 'Horizontal'
    $DG.HorizontalGridLinesBrush = New-WpfBrush $Script:Colors.Border
    $DG.ColumnHeaderHeight       = 30
    $DG.RowHeight                = 26
    $DG.FontSize                 = 12

    $hStyle = New-Object System.Windows.Style([System.Windows.Controls.Primitives.DataGridColumnHeader])
    foreach ($s in @(
        @{ P=[System.Windows.Controls.Control]::BackgroundProperty;      V=(New-WpfBrush $Script:Colors.BgHeader)  },
        @{ P=[System.Windows.Controls.Control]::ForegroundProperty;      V=(New-WpfBrush $Script:Colors.TextMuted) },
        @{ P=[System.Windows.Controls.Control]::BorderBrushProperty;     V=(New-WpfBrush $Script:Colors.Border)    },
        @{ P=[System.Windows.Controls.Control]::BorderThicknessProperty; V=([System.Windows.Thickness]::new(0,0,1,1)) },
        @{ P=[System.Windows.Controls.Control]::PaddingProperty;         V=([System.Windows.Thickness]::new(8,0,8,0)) },
        @{ P=[System.Windows.Controls.Control]::FontWeightProperty;      V=([System.Windows.FontWeights]::SemiBold) },
        @{ P=[System.Windows.Controls.Control]::FontSizeProperty;        V=11.0 }
    )) {
        $setter = New-Object System.Windows.Setter
        $setter.Property = $s.P
        $setter.Value    = $s.V
        $hStyle.Setters.Add($setter) | Out-Null
    }
    $DG.ColumnHeaderStyle = $hStyle

    $rStyle = New-Object System.Windows.Style([System.Windows.Controls.DataGridRow])
    $rs2 = New-Object System.Windows.Setter
    $rs2.Property = [System.Windows.Controls.DataGridRow]::ForegroundProperty
    $rs2.Value    = New-WpfBrush $Script:Colors.Text
    $rStyle.Setters.Add($rs2) | Out-Null
    $DG.RowStyle = $rStyle

    $cStyle = New-Object System.Windows.Style([System.Windows.Controls.DataGridCell])
    foreach ($csDef in @(
        @{ P=[System.Windows.Controls.DataGridCell]::BorderThicknessProperty; V=[System.Windows.Thickness]::new(0)                },
        @{ P=[System.Windows.Controls.DataGridCell]::ForegroundProperty;      V=(New-WpfBrush $Script:Colors.Text)                }
    )) {
        $cs2 = New-Object System.Windows.Setter; $cs2.Property = $csDef.P; $cs2.Value = $csDef.V
        $cStyle.Setters.Add($cs2) | Out-Null
    }
    $selTrigger = New-Object System.Windows.Trigger
    $selTrigger.Property = [System.Windows.Controls.DataGridCell]::IsSelectedProperty
    $selTrigger.Value    = $true
    foreach ($tDef in @(
        @{ P=[System.Windows.Controls.DataGridCell]::BackgroundProperty; V=(New-WpfBrush $Script:Colors.SelectionBg) },
        @{ P=[System.Windows.Controls.DataGridCell]::ForegroundProperty; V=([System.Windows.Media.Brushes]::White)   }
    )) {
        $ts = New-Object System.Windows.Setter; $ts.Property = $tDef.P; $ts.Value = $tDef.V
        $selTrigger.Setters.Add($ts) | Out-Null
    }
    $cStyle.Triggers.Add($selTrigger) | Out-Null
    $DG.CellStyle = $cStyle
}

function New-CSVViewerContent {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    $r0 = New-Object System.Windows.Controls.RowDefinition; $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $r2 = New-Object System.Windows.Controls.RowDefinition; $r2.Height = [System.Windows.GridLength]::Auto
    $outer.RowDefinitions.Add($r0)
    $outer.RowDefinitions.Add($r1)
    $outer.RowDefinitions.Add($r2)

    # ── Toolbar ─────────────────────────────────────────────────────
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(8,5,8,5)

    $tbDP = New-Object System.Windows.Controls.DockPanel
    $tbDP.LastChildFill = $false

    $fileLabel = New-Object System.Windows.Controls.TextBlock
    $fileLabel.Text              = [System.IO.Path]::GetFileName($FilePath)
    $fileLabel.Foreground        = New-WpfBrush $Script:Colors.Text
    $fileLabel.FontWeight        = [System.Windows.FontWeights]::SemiBold
    $fileLabel.FontSize          = 12
    $fileLabel.VerticalAlignment = 'Center'
    $fileLabel.Margin            = [System.Windows.Thickness]::new(0,0,12,0)
    [System.Windows.Controls.DockPanel]::SetDock($fileLabel, 'Left')
    $tbDP.Children.Add($fileLabel) | Out-Null

    $rightSP = New-Object System.Windows.Controls.StackPanel
    $rightSP.Orientation = 'Horizontal'
    [System.Windows.Controls.DockPanel]::SetDock($rightSP, 'Right')

    $filterBox = New-Object System.Windows.Controls.TextBox
    $filterBox.Width       = 200
    $filterBox.Height      = 24
    $filterBox.Background  = New-WpfBrush $Script:Colors.BgSurface
    $filterBox.Foreground  = New-WpfBrush $Script:Colors.Text
    $filterBox.CaretBrush  = [System.Windows.Media.Brushes]::White
    $filterBox.BorderBrush = New-WpfBrush $Script:Colors.Border
    $filterBox.Padding     = [System.Windows.Thickness]::new(6,2,6,2)
    $filterBox.FontSize    = 11
    $filterBox.ToolTip     = "Filtrar filas (busca en todas las columnas)"
    $rightSP.Children.Add($filterBox) | Out-Null

    foreach ($btnInfo in @(
        @{ Text="Limpiar"    },
        @{ Text="Copiar sel."},
        @{ Text="Export CSV" }
    )) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content     = $btnInfo.Text
        $btn.Height      = 24
        $btn.Padding     = [System.Windows.Thickness]::new(8,2,8,2)
        $btn.Margin      = [System.Windows.Thickness]::new(4,0,0,0)
        $btn.Background  = New-WpfBrush $Script:Colors.BgSurface
        $btn.Foreground  = New-WpfBrush $Script:Colors.Text
        $btn.BorderBrush = New-WpfBrush $Script:Colors.Border
        $btn.FontSize    = 11
        $btn.Cursor      = [System.Windows.Input.Cursors]::Hand
        $rightSP.Children.Add($btn) | Out-Null
    }

    $tbDP.Children.Add($rightSP) | Out-Null
    $toolbar.Child = $tbDP
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # ── DataGrid ─────────────────────────────────────────────────────
    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly            = $true
    $dg.AutoGenerateColumns   = $true
    $dg.SelectionMode         = 'Extended'
    $dg.SelectionUnit         = 'FullRow'
    $dg.CanUserSortColumns    = $true
    $dg.CanUserResizeColumns  = $true
    $dg.CanUserReorderColumns = $true
    $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($dg, [System.Windows.Controls.VirtualizationMode]::Recycling)
    # Columnas con ancho FIJO tambien cuando se auto-generan (no Auto/SizeToHeader):
    # con datasets grandes y ancho Auto, WPF tiene que medir el contenido de
    # cada fila para calcular el ancho de columna, lo que fuerza preparar
    # muchos mas contenedores de fila de los que la virtualizacion realizaria
    # normalmente - ese camino (DataGridRow.PrepareRow) es donde se dispara un
    # bug conocido de WPF (DataGridItemAttachedStorage.TryGetValue) que puede
    # matar el proceso entero sin excepcion manejable (confirmado en
    # MaPeriT.SC con el mismo patron). CSVViewer es el visor mas usado del
    # ecosistema (cualquier CSV de SW/AN, muchas columnas, hasta 50000 filas).
    $dg.Add_AutoGeneratingColumn({
        param($s, $e)
        $e.Column.Width = New-Object System.Windows.Controls.DataGridLength(160)
    })
    Apply-DataGridDarkTheme $dg
    Add-DataGridRowContextMenu -DG $dg -FilePath $FilePath
    [System.Windows.Controls.Grid]::SetRow($dg, 1)
    $outer.Children.Add($dg) | Out-Null

    # ── Status bar ───────────────────────────────────────────────────
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $statusLabel.FontSize   = 11
    $statusLabel.Text       = "Cargando..."
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    # ── Overlay ───────────────────────────────────────────────────────
    $overlay = New-LoadingOverlay -Message "Cargando $([System.IO.Path]::GetFileName($FilePath))..." -RowSpan 3
    $outer.Children.Add($overlay) | Out-Null

    # ── Colorear filas por IOC/severidad ─────────────────────────────
    $dg.Add_LoadingRow({
        param($s, $e)
        $item = $e.Row.Item
        if ($item -isnot [System.Data.DataRowView]) { return }
        $sev = Get-RowSeverity $item.Row
        if ($sev -ne "Normal") { $e.Row.Background = Get-SeverityBrush $sev }
    })

    # ── Filtro: estado en filterBox.Tag (sin closures) ───────────────
    $filterBox.Tag = [PSCustomObject]@{ DG = $dg; Status = $statusLabel }
    $filterBox.Add_TextChanged({
        param($sender, $e)
        $ctx = $sender.Tag
        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl) { return }
        $txt = $sender.Text.Trim()
        if ([string]::IsNullOrEmpty($txt)) {
            $tbl.DefaultView.RowFilter = ""
        } else {
            $safeT = $txt -replace "'", "''"
            $exprs = $tbl.Columns | ForEach-Object {
                "CONVERT([{0}], 'System.String') LIKE '%{1}%'" -f $_.ColumnName, $safeT
            }
            try { $tbl.DefaultView.RowFilter = $exprs -join " OR " } catch { $tbl.DefaultView.RowFilter = "" }
        }
        $ctx.DG.ItemsSource = $tbl.DefaultView
        $ctx.Status.Text = if ([string]::IsNullOrEmpty($sender.Text.Trim())) {
            "$($tbl.Rows.Count) filas"
        } else {
            "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) filas  ·  '$($sender.Text.Trim())'"
        }
    })

    # ── Botones: estado en Tag del boton (sin closures) ──────────────
    foreach ($btn in ($rightSP.Children | Where-Object { $_ -is [System.Windows.Controls.Button] })) {
        $btn.Tag = [PSCustomObject]@{ DG = $dg; Status = $statusLabel; FilterBox = $filterBox; FilePath = $FilePath }
        $btn.Add_Click({
            param($sender, $e)
            $ctx = $sender.Tag
            switch -Wildcard ($sender.Content) {
                "Limpiar"   { $ctx.FilterBox.Text = "" }
                "Copiar*"   {
                    $sel = $ctx.DG.SelectedItems
                    if (-not $sel -or $sel.Count -eq 0) { return }
                    $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
                    $lines = New-Object "System.Collections.Generic.List[string]"
                    if ($tbl) { $lines.Add(($tbl.Columns | ForEach-Object { $_.ColumnName }) -join "`t") }
                    foreach ($item in $sel) {
                        $drv = $item -as [System.Data.DataRowView]
                        if ($drv) { $lines.Add(($drv.Row.ItemArray | ForEach-Object { $_.ToString() }) -join "`t") }
                    }
                    if ($lines.Count -gt 0) { [System.Windows.Clipboard]::SetText($lines -join "`n") }
                }
                "Export*"   {
                    $dlg = New-Object Microsoft.Win32.SaveFileDialog
                    $dlg.Filter   = "CSV (*.csv)|*.csv"
                    $dlg.FileName = "export_$([System.IO.Path]::GetFileNameWithoutExtension($ctx.FilePath))"
                    if ($dlg.ShowDialog() -eq $true) {
                        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
                        if ($tbl) { $tbl.DefaultView.ToTable() | Export-Csv $dlg.FileName -NoTypeInformation -Encoding UTF8 }
                    }
                }
            }
        })
    }

    # ── Ctrl+C para copiar seleccion ─────────────────────────────────
    $dg.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq 'C' -and ([System.Windows.Input.Keyboard]::Modifiers -band 'Control')) {
            $sel = $s.SelectedItems
            if (-not $sel -or $sel.Count -eq 0) { return }
            $tbl = $s.Tag -as [System.Data.DataTable]
            $lines = New-Object "System.Collections.Generic.List[string]"
            if ($tbl) { $lines.Add(($tbl.Columns | ForEach-Object { $_.ColumnName }) -join "`t") }
            foreach ($item in $sel) {
                $drv = $item -as [System.Data.DataRowView]
                if ($drv) { $lines.Add(($drv.Row.ItemArray | ForEach-Object { $_.ToString() }) -join "`t") }
            }
            if ($lines.Count -gt 0) { [System.Windows.Clipboard]::SetText($lines -join "`n") }
        }
    })

    # ── Carga async: Runspace en fondo, resultado al UI thread via DispatcherTimer ──
    $ui = [PSCustomObject]@{
        DG      = $dg
        Status  = $statusLabel
        Overlay = $overlay
        MaxRows = $Script:MaxRowsDefault
    }

    Invoke-AsyncCSVLoad -FilePath $FilePath -MaxRows $Script:MaxRowsDefault -UIContext $ui `
        -OnComplete {
            param($ui, $table, $totalRows)
            $ui.DG.Tag         = $table
            $ui.DG.ItemsSource = $table.DefaultView
            $info = if ($totalRows -gt $ui.MaxRows) {
                "Mostrando $($ui.MaxRows) de $totalRows filas  ·  Usa el filtro para buscar"
            } elseif ($totalRows -eq 0) { "CSV vacio" } else { "$totalRows filas" }
            $ui.Status.Text        = $info
            $ui.Overlay.Visibility = 'Collapsed'
        } `
        -OnError {
            param($ui, $msg)
            $ui.Status.Text        = "Error al cargar: $msg"
            $ui.Overlay.Visibility = 'Collapsed'
        }

    return $outer
}

#endregion
#endregion

#region ===== src\Viewers\MFTViewer.ps1 =====
#region ============================================================
# MaPeriT.TN - VISOR MFT (CSV parseado de AN o raw $MFT)
# ============================================================

function New-MFTViewerContent {
    param([string]$FilePath)

    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if ($ext -eq ".csv") {
        return New-MFTCSVViewer -FilePath $FilePath
    }
    return New-MFTRawInfo -FilePath $FilePath
}

function New-MFTCSVViewer {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    $r0 = New-Object System.Windows.Controls.RowDefinition; $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::Auto
    $r2 = New-Object System.Windows.Controls.RowDefinition; $r2.Height = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $r3 = New-Object System.Windows.Controls.RowDefinition; $r3.Height = [System.Windows.GridLength]::Auto
    $outer.RowDefinitions.Add($r0)
    $outer.RowDefinitions.Add($r1)
    $outer.RowDefinitions.Add($r2)
    $outer.RowDefinitions.Add($r3)

    # ── Banner informativo ───────────────────────────────────────────
    $isMFTTimestomp = $FilePath -match 'MFT_Timestomping'
    $isMFTDeleted   = $FilePath -match 'MFT_Borrados'

    # Colores del tema activo (antes fijos de tema oscuro tambien en el claro)
    $bannerColor = if ($isMFTTimestomp) { $Script:Colors.RowTimestomp } elseif ($isMFTDeleted) { $Script:Colors.RowInfo } else { $Script:Colors.BgCard }
    $bannerText  = if ($isMFTTimestomp) {
        "POSIBLE TIMESTOMPING — Fechas de `$STANDARD_INFORMATION (SI_*) incoherentes con las de `$FILE_NAME (FN_*); el motivo de cada fila esta en RazonTimestomp. Fechas en UTC."
    } elseif ($isMFTDeleted) {
        "FICHEROS BORRADOS — Registros MFT marcados como no en uso (Estado = BORRADO) cuyo registro NTFS aun no ha sido reutilizado. Fechas en UTC."
    } else {
        "MFT COMPLETO — Todos los registros del Master File Table. SI_* son de `$STANDARD_INFORMATION (modificables). FN_* son de `$FILE_NAME (mas fiables). Fechas en UTC."
    }

    $banner = New-Object System.Windows.Controls.Border
    $banner.Background      = New-WpfBrush $bannerColor
    $banner.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $banner.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $banner.Padding         = [System.Windows.Thickness]::new(12,8,12,8)
    $bannerLabel = New-Object System.Windows.Controls.TextBlock
    $bannerLabel.Text         = $bannerText
    $bannerLabel.Foreground   = New-WpfBrush $Script:Colors.TextMuted
    $bannerLabel.FontSize     = 11
    $bannerLabel.TextWrapping = 'Wrap'
    $banner.Child = $bannerLabel
    [System.Windows.Controls.Grid]::SetRow($banner, 0)
    $outer.Children.Add($banner) | Out-Null

    # ── Toolbar ─────────────────────────────────────────────────────
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(8,5,8,5)

    $tbDP = New-Object System.Windows.Controls.DockPanel
    $tbDP.LastChildFill = $false

    $rightSP = New-Object System.Windows.Controls.StackPanel
    $rightSP.Orientation = 'Horizontal'
    [System.Windows.Controls.DockPanel]::SetDock($rightSP, 'Right')

    $chkNonSystem = New-Object System.Windows.Controls.CheckBox
    $chkNonSystem.Content          = "Solo fuera de System32/WinSxS"
    $chkNonSystem.Foreground       = New-WpfBrush $Script:Colors.Text
    $chkNonSystem.FontSize         = 11
    $chkNonSystem.VerticalAlignment= 'Center'
    $chkNonSystem.Margin           = [System.Windows.Thickness]::new(0,0,10,0)
    $rightSP.Children.Add($chkNonSystem) | Out-Null

    $filterBox = New-Object System.Windows.Controls.TextBox
    $filterBox.Width       = 200
    $filterBox.Height      = 24
    $filterBox.Background  = New-WpfBrush $Script:Colors.BgSurface
    $filterBox.Foreground  = New-WpfBrush $Script:Colors.Text
    $filterBox.CaretBrush  = [System.Windows.Media.Brushes]::White
    $filterBox.BorderBrush = New-WpfBrush $Script:Colors.Border
    $filterBox.Padding     = [System.Windows.Thickness]::new(6,2,6,2)
    $filterBox.FontSize    = 11
    $filterBox.ToolTip     = "Filtrar por ruta/nombre"
    $rightSP.Children.Add($filterBox) | Out-Null

    $btnCopy = New-Object System.Windows.Controls.Button
    $btnCopy.Content     = "Copiar sel."
    $btnCopy.Height      = 24
    $btnCopy.Padding     = [System.Windows.Thickness]::new(8,2,8,2)
    $btnCopy.Margin      = [System.Windows.Thickness]::new(4,0,0,0)
    $btnCopy.Background  = New-WpfBrush $Script:Colors.BgSurface
    $btnCopy.Foreground  = New-WpfBrush $Script:Colors.Text
    $btnCopy.BorderBrush = New-WpfBrush $Script:Colors.Border
    $btnCopy.FontSize    = 11
    $btnCopy.Cursor      = [System.Windows.Input.Cursors]::Hand
    $rightSP.Children.Add($btnCopy) | Out-Null

    $tbDP.Children.Add($rightSP) | Out-Null
    $toolbar.Child = $tbDP
    [System.Windows.Controls.Grid]::SetRow($toolbar, 1)
    $outer.Children.Add($toolbar) | Out-Null

    # ── DataGrid ─────────────────────────────────────────────────────
    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly              = $true
    $dg.AutoGenerateColumns     = $true
    $dg.SelectionMode           = 'Extended'
    $dg.SelectionUnit           = 'FullRow'
    $dg.CanUserSortColumns      = $true
    $dg.CanUserResizeColumns    = $true
    $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($dg, [System.Windows.Controls.VirtualizationMode]::Recycling)
    # Ancho fijo tambien en columnas auto-generadas - ver comentario extenso
    # en CSVViewer.ps1 (mismo riesgo de crash de WPF con datasets MFT grandes).
    $dg.Add_AutoGeneratingColumn({
        param($s, $e)
        $e.Column.Width = New-Object System.Windows.Controls.DataGridLength(160)
    })
    Apply-DataGridDarkTheme $dg
    Add-DataGridRowContextMenu -DG $dg -FilePath $FilePath
    [System.Windows.Controls.Grid]::SetRow($dg, 2)
    $outer.Children.Add($dg) | Out-Null

    # ── Status bar ───────────────────────────────────────────────────
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $statusLabel.FontSize   = 11
    $statusLabel.Text       = "Cargando MFT..."
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 3)
    $outer.Children.Add($statusBar) | Out-Null

    # ── Overlay de carga ──────────────────────────────────────────────
    $overlay = New-LoadingOverlay -Message "Cargando MFT..." -RowSpan 4
    $outer.Children.Add($overlay) | Out-Null

    # ── Colorear filas: timestomping (morado) y borradas (azul) ──────
    $dg.Add_LoadingRow({
        param($s, $e)
        $item = $e.Row.Item -as [System.Data.DataRowView]
        if ($null -eq $item) { return }
        $row = $item.Row

        # Timestomping: columna Timestomping de MaPeriT.AN (antes se buscaban
        # SI_Created/FN_Created, que AN no genera, y nunca se coloreaba nada)
        if ($row.Table.Columns.Contains('Timestomping') -and $row['Timestomping'].ToString() -eq 'True') {
            $e.Row.Background = Get-TimestompBrush
            return
        }
        # Compatibilidad con CSV de otras herramientas: SI_Created < FN_Created (margen 60 s)
        $siCol = $row.Table.Columns | Where-Object { $_.ColumnName -eq 'SI_Created' } | Select-Object -First 1
        $fnCol = $row.Table.Columns | Where-Object { $_.ColumnName -eq 'FN_Created' } | Select-Object -First 1
        if ($siCol -and $fnCol) {
            try {
                $siC = [datetime]::Parse($row['SI_Created'].ToString())
                $fnC = [datetime]::Parse($row['FN_Created'].ToString())
                if ($siC -lt $fnC.AddSeconds(-60)) {
                    $e.Row.Background = Get-TimestompBrush
                    return
                }
            } catch {}
        }

        # Ficheros borrados: Estado = BORRADO (AN) o InUse = false/0 (otras herramientas)
        $isDeleted = ($row.Table.Columns.Contains('Estado') -and $row['Estado'].ToString() -eq 'BORRADO') -or
                     ($row.Table.Columns.Contains('InUse') -and $row['InUse'].ToString() -match '^(false|0)$')
        if ($isDeleted) {
            $e.Row.Background = New-WpfBrush $Script:Colors.RowInfo
            return
        }

        $sev = Get-RowSeverity $row
        if ($sev -ne "Normal") { $e.Row.Background = Get-SeverityBrush $sev }
    })

    # ── Filtro: logica inline en los handlers, estado en Tag ─────────
    # filterBox.Tag: { DG, Status, Chk }
    # chkNonSystem.Tag: filterBox
    # Los handlers leen todo desde $sender.Tag — sin closures.

    $filterBox.Tag = [PSCustomObject]@{ DG = $dg; Status = $statusLabel; Chk = $chkNonSystem }

    $filterBox.Add_TextChanged({
        param($sender, $e)
        $ctx = $sender.Tag
        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl) { return }

        $txt           = $sender.Text.Trim()
        $onlyNonSystem = $ctx.Chk.IsChecked -eq $true
        $conditions    = @()

        if (-not [string]::IsNullOrEmpty($txt)) {
            $safeT = $txt -replace "'", "''"
            $exprs = $tbl.Columns | ForEach-Object {
                "CONVERT([{0}], 'System.String') LIKE '%{1}%'" -f $_.ColumnName, $safeT
            }
            $conditions += "(" + ($exprs -join " OR ") + ")"
        }

        if ($onlyNonSystem) {
            # RutaCompleta es la columna de AN (antes solo FullPath/Path: el filtro no hacia nada)
            $pathColObj = $tbl.Columns | Where-Object { $_.ColumnName -match '^(RutaCompleta|FullPath|Path)$' } | Select-Object -First 1
            if ($null -ne $pathColObj) {
                $pc = $pathColObj.ColumnName
                $conditions += "NOT (CONVERT([{0}], 'System.String') LIKE '%Windows%System32%' OR CONVERT([{0}], 'System.String') LIKE '%Windows%WinSxS%')" -f $pc
            }
        }

        try { $tbl.DefaultView.RowFilter = $conditions -join " AND " } catch { $tbl.DefaultView.RowFilter = "" }
        $ctx.DG.ItemsSource = $tbl.DefaultView
        $ctx.Status.Text    = "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) registros"
    })

    # El checkbox necesita re-ejecutar el mismo filtro.
    # chkNonSystem.Tag = filterBox → handler lee filterBox.Tag para el estado.
    $chkNonSystem.Tag = $filterBox
    $chkNonSystem.Add_Checked({
        param($sender, $e)
        $fb  = $sender.Tag    # filterBox
        $ctx = $fb.Tag        # PSCustomObject { DG, Status, Chk }
        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl) { return }

        $txt    = $fb.Text.Trim()
        $conditions = @()
        if (-not [string]::IsNullOrEmpty($txt)) {
            $safeT = $txt -replace "'", "''"
            $exprs = $tbl.Columns | ForEach-Object {
                "CONVERT([{0}], 'System.String') LIKE '%{1}%'" -f $_.ColumnName, $safeT
            }
            $conditions += "(" + ($exprs -join " OR ") + ")"
        }
        $pathColObj = $tbl.Columns | Where-Object { $_.ColumnName -match '^(RutaCompleta|FullPath|Path)$' } | Select-Object -First 1
        if ($null -ne $pathColObj) {
            $pc = $pathColObj.ColumnName
            $conditions += "NOT (CONVERT([{0}], 'System.String') LIKE '%Windows%System32%' OR CONVERT([{0}], 'System.String') LIKE '%Windows%WinSxS%')" -f $pc
        }
        try { $tbl.DefaultView.RowFilter = $conditions -join " AND " } catch { $tbl.DefaultView.RowFilter = "" }
        $ctx.DG.ItemsSource = $tbl.DefaultView
        $ctx.Status.Text    = "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) registros"
    })

    $chkNonSystem.Add_Unchecked({
        param($sender, $e)
        $fb  = $sender.Tag
        $ctx = $fb.Tag
        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl) { return }

        $txt = $fb.Text.Trim()
        if ([string]::IsNullOrEmpty($txt)) {
            $tbl.DefaultView.RowFilter = ""
        } else {
            $safeT = $txt -replace "'", "''"
            $exprs = $tbl.Columns | ForEach-Object {
                "CONVERT([{0}], 'System.String') LIKE '%{1}%'" -f $_.ColumnName, $safeT
            }
            try { $tbl.DefaultView.RowFilter = $exprs -join " OR " } catch { $tbl.DefaultView.RowFilter = "" }
        }
        $ctx.DG.ItemsSource = $tbl.DefaultView
        $ctx.Status.Text    = "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) registros"
    })

    # ── Copiar: estado en Tag del boton ───────────────────────────────
    $btnCopy.Tag = $dg
    $btnCopy.Add_Click({
        param($sender, $e)
        $dg2      = $sender.Tag -as [System.Windows.Controls.DataGrid]
        $selected = $dg2.SelectedItems
        if (-not $selected -or $selected.Count -eq 0) { return }
        $tbl   = $dg2.Tag -as [System.Data.DataTable]
        $lines = New-Object "System.Collections.Generic.List[string]"
        if ($tbl) { $lines.Add(($tbl.Columns | ForEach-Object { $_.ColumnName }) -join "`t") }
        foreach ($item in $selected) {
            $drv = $item -as [System.Data.DataRowView]
            if ($drv) { $lines.Add(($drv.Row.ItemArray | ForEach-Object { $_.ToString() }) -join "`t") }
        }
        if ($lines.Count -gt 0) { [System.Windows.Clipboard]::SetText($lines -join "`n") }
    })

    # ── Carga async ───────────────────────────────────────────────────
    $ui = [PSCustomObject]@{
        DG      = $dg
        Status  = $statusLabel
        Overlay = $overlay
        MaxRows = $Script:MaxRowsDefault
    }

    Invoke-AsyncCSVLoad -FilePath $FilePath -MaxRows $Script:MaxRowsDefault -UIContext $ui `
        -OnComplete {
            param($ui, $table, $totalRows)
            $ui.DG.Tag         = $table
            $ui.DG.ItemsSource = $table.DefaultView
            $info = if ($totalRows -gt $ui.MaxRows) {
                "$($ui.MaxRows) de $totalRows registros (truncado)"
            } else { "$totalRows registros" }
            $ui.Status.Text        = $info
            $ui.Overlay.Visibility = 'Collapsed'
        } `
        -OnError {
            param($ui, $msg)
            $ui.Status.Text        = "Error: $msg"
            $ui.Overlay.Visibility = 'Collapsed'
        }

    return $outer
}

function New-MFTRawInfo {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.HorizontalAlignment = 'Center'
    $sp.VerticalAlignment   = 'Center'
    $sp.MaxWidth = 600

    $size = if (Test-Path $FilePath) { Format-FileSize (Get-Item $FilePath).Length } else { "?" }

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text          = "`$MFT  —  Fichero binario"
    $title.FontSize      = 20
    $title.FontWeight    = [System.Windows.FontWeights]::Light
    $title.Foreground    = New-WpfBrush $Script:Colors.Accent
    $title.TextAlignment = 'Center'
    $title.Margin        = [System.Windows.Thickness]::new(0,0,0,12)
    $sp.Children.Add($title) | Out-Null

    $info = New-Object System.Windows.Controls.TextBlock
    $info.Text           = "Tamano: $size`n`nEl `$MFT es el fichero binario del Master File Table de NTFS.`nPara un analisis completo ejecuta MaPeriT.AN sobre este directorio.`n`nMaPeriT.AN genera:`n  · MFT\MFT_Completo.csv`n  · MFT\MFT_Timestomping.csv`n  · MFT\MFT_Borrados.csv`n`nEstos CSVs tienen visor completo en MaPeriT.TN."
    $info.Foreground     = New-WpfBrush $Script:Colors.TextMuted
    $info.FontSize       = 13
    $info.TextWrapping   = 'Wrap'
    $info.TextAlignment  = 'Center'
    $info.LineHeight     = 22
    $sp.Children.Add($info) | Out-Null

    $outer.Children.Add($sp) | Out-Null
    return $outer
}

#endregion
#endregion

#region ===== src\Viewers\EVTXViewer.ps1 =====
#region ============================================================
# MaPeriT.TN - VISOR EVTX
# ============================================================

function New-EVTXViewerContent {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    $r0 = New-Object System.Windows.Controls.RowDefinition; $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $r2 = New-Object System.Windows.Controls.RowDefinition; $r2.Height = [System.Windows.GridLength]::Auto
    $outer.RowDefinitions.Add($r0)
    $outer.RowDefinitions.Add($r1)
    $outer.RowDefinitions.Add($r2)

    # ── Toolbar ─────────────────────────────────────────────────────
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(8,5,8,5)

    $tbDP = New-Object System.Windows.Controls.DockPanel
    $tbDP.LastChildFill = $false

    $fileLabel = New-Object System.Windows.Controls.TextBlock
    $fileLabel.Text              = [System.IO.Path]::GetFileName($FilePath)
    $fileLabel.Foreground        = New-WpfBrush $Script:Colors.Text
    $fileLabel.FontWeight        = [System.Windows.FontWeights]::SemiBold
    $fileLabel.FontSize          = 12
    $fileLabel.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($fileLabel, 'Left')
    $tbDP.Children.Add($fileLabel) | Out-Null

    $rightSP = New-Object System.Windows.Controls.StackPanel
    $rightSP.Orientation = 'Horizontal'
    [System.Windows.Controls.DockPanel]::SetDock($rightSP, 'Right')

    $filterBox = New-Object System.Windows.Controls.TextBox
    $filterBox.Width       = 180
    $filterBox.Height      = 24
    $filterBox.Background  = New-WpfBrush $Script:Colors.BgSurface
    $filterBox.Foreground  = New-WpfBrush $Script:Colors.Text
    $filterBox.CaretBrush  = [System.Windows.Media.Brushes]::White
    $filterBox.BorderBrush = New-WpfBrush $Script:Colors.Border
    $filterBox.Padding     = [System.Windows.Thickness]::new(6,2,6,2)
    $filterBox.FontSize    = 11
    $filterBox.ToolTip     = "Filtrar por EventID, proveedor o mensaje"
    $rightSP.Children.Add($filterBox) | Out-Null

    $btnCopy = New-Object System.Windows.Controls.Button
    $btnCopy.Content     = "Copiar sel."
    $btnCopy.Height      = 24
    $btnCopy.Padding     = [System.Windows.Thickness]::new(8,2,8,2)
    $btnCopy.Margin      = [System.Windows.Thickness]::new(4,0,0,0)
    $btnCopy.Background  = New-WpfBrush $Script:Colors.BgSurface
    $btnCopy.Foreground  = New-WpfBrush $Script:Colors.Text
    $btnCopy.BorderBrush = New-WpfBrush $Script:Colors.Border
    $btnCopy.FontSize    = 11
    $btnCopy.Cursor      = [System.Windows.Input.Cursors]::Hand
    $rightSP.Children.Add($btnCopy) | Out-Null

    $tbDP.Children.Add($rightSP) | Out-Null
    $toolbar.Child = $tbDP
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # ── DataGrid con columnas fijas ───────────────────────────────────
    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly              = $true
    $dg.AutoGenerateColumns     = $false
    $dg.SelectionMode           = 'Extended'
    $dg.SelectionUnit           = 'FullRow'
    $dg.CanUserSortColumns      = $true
    $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($dg, [System.Windows.Controls.VirtualizationMode]::Recycling)
    Apply-DataGridDarkTheme $dg
    Add-DataGridRowContextMenu -DG $dg -FilePath $FilePath

    foreach ($cd in @(
        @{ H="Fecha/Hora";  B="TimeCreated"; W=160 },
        @{ H="EventID";     B="Id";          W=70  },
        @{ H="Nivel";       B="Level";       W=70  },
        @{ H="Proveedor";   B="ProviderName";W=160 },
        @{ H="Mensaje";     B="Message";     W=500 },
        @{ H="Usuario";     B="UserId";      W=120 },
        @{ H="Equipo";      B="MachineName"; W=120 }
    )) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header  = $cd.H
        $col.Binding = New-Object System.Windows.Data.Binding($cd.B)
        $col.Width   = $cd.W
        $dg.Columns.Add($col) | Out-Null
    }

    [System.Windows.Controls.Grid]::SetRow($dg, 1)
    $outer.Children.Add($dg) | Out-Null

    # ── Status bar ───────────────────────────────────────────────────
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $statusLabel.FontSize   = 11
    $statusLabel.Text       = "Leyendo eventos..."
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    # ── Cargar eventos (sincrono: EVTX suelen ser manejables) ────────
    $rawEvents = @()
    $totalEvts = 0
    try {
        $rawEvents = @(Get-WinEvent -Path $FilePath -MaxEvents $Script:MaxEVTXEvents -ErrorAction Stop |
            Select-Object TimeCreated, Id, Level, ProviderName,
                @{ N='Message'; E={ ($_.Message -replace "`r`n"," " -replace "`n"," ").Substring(0, [Math]::Min(($_.Message -replace "`r`n"," " -replace "`n"," ").Length, 300)) } },
                @{ N='UserId';  E={ if ($_.UserId) { $_.UserId.Value } else { "" } } },
                MachineName)
        $totalEvts = $rawEvents.Count
    } catch {
        $statusLabel.Text = "Error al leer EVTX: $($_.Exception.Message)"
    }

    # Construir DataTable directamente (sin funciones que puedan enumerar)
    $tbl = [System.Data.DataTable]::new("EVTXData")
    if ($rawEvents.Count -gt 0) {
        foreach ($prop in $rawEvents[0].PSObject.Properties.Name) {
            [void]$tbl.Columns.Add($prop, [string])
        }
        foreach ($ev in $rawEvents) {
            $row = $tbl.NewRow()
            foreach ($c in $tbl.Columns) {
                $v = $ev.($c.ColumnName)
                $row[$c.ColumnName] = if ($null -ne $v) { $v.ToString() } else { "" }
            }
            [void]$tbl.Rows.Add($row)
        }
    }

    $dg.Tag         = $tbl
    $dg.ItemsSource = $tbl.DefaultView
    $statusLabel.Text = "$totalEvts eventos" + $(if ($totalEvts -ge $Script:MaxEVTXEvents) { " (limite $($Script:MaxEVTXEvents))" } else { "" })

    # ── Colorear filas por EventID ────────────────────────────────────
    $dg.Add_LoadingRow({
        param($s, $e)
        $item = $e.Row.Item -as [System.Data.DataRowView]
        if ($null -eq $item) { return }
        $eid = 0
        if ([int]::TryParse($item['Id'].ToString(), [ref]$eid)) {
            $bg = switch ($true) {
                ($eid -in $Script:EventSeverity.Critical) { New-WpfBrush $Script:Colors.RowCritical; break }
                ($eid -in $Script:EventSeverity.High)     { New-WpfBrush $Script:Colors.RowDanger;   break }
                ($eid -in $Script:EventSeverity.Medium)   { New-WpfBrush $Script:Colors.RowWarning;  break }
                default { $null }
            }
            if ($null -ne $bg) { $e.Row.Background = $bg }
        }
    })

    # ── Filtro: estado en filterBox.Tag (sin closures) ───────────────
    $filterBox.Tag = [PSCustomObject]@{ DG = $dg; Status = $statusLabel }
    $filterBox.Add_TextChanged({
        param($sender, $e)
        $ctx = $sender.Tag
        $tbl2 = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl2) { return }
        $txt = $sender.Text.Trim()
        if ([string]::IsNullOrEmpty($txt)) {
            $tbl2.DefaultView.RowFilter = ""
        } else {
            $safeT = $txt -replace "'", "''"
            try {
                $tbl2.DefaultView.RowFilter = "CONVERT([Id], 'System.String') LIKE '%$safeT%' OR CONVERT([Message], 'System.String') LIKE '%$safeT%' OR CONVERT([ProviderName], 'System.String') LIKE '%$safeT%'"
            } catch { $tbl2.DefaultView.RowFilter = "" }
        }
        $ctx.DG.ItemsSource = $tbl2.DefaultView
        $ctx.Status.Text    = "$($tbl2.DefaultView.Count) de $($tbl2.Rows.Count) eventos visibles"
    })

    # ── Copiar: estado en Tag del boton (sin closures) ───────────────
    $btnCopy.Tag = $dg
    $btnCopy.Add_Click({
        param($sender, $e)
        $dg2      = $sender.Tag -as [System.Windows.Controls.DataGrid]
        $selected = $dg2.SelectedItems
        if (-not $selected -or $selected.Count -eq 0) { return }
        $tbl3  = $dg2.Tag -as [System.Data.DataTable]
        $lines = New-Object "System.Collections.Generic.List[string]"
        if ($tbl3) { $lines.Add(($tbl3.Columns | ForEach-Object { $_.ColumnName }) -join "`t") }
        foreach ($item in $selected) {
            $drv = $item -as [System.Data.DataRowView]
            if ($drv) { $lines.Add(($drv.Row.ItemArray | ForEach-Object { $_.ToString() }) -join "`t") }
        }
        if ($lines.Count -gt 0) { [System.Windows.Clipboard]::SetText($lines -join "`n") }
    })

    return $outer
}

#endregion
#endregion

#region ===== src\UI\XAML.ps1 =====
#region ============================================================
# MaPeriT.TN - XAML DE LA VENTANA PRINCIPAL
# ============================================================

function Get-TNMainWindowXAML {
    return @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="MaPeriT.TN — Visor Forense"
    Height="820" Width="1320"
    MinHeight="600" MinWidth="900"
    Background="$($Script:Colors.BgPrimary)"
    WindowStartupLocation="CenterScreen"
    FontFamily="Segoe UI"
    FontSize="13"
    UseLayoutRounding="True"
    SnapsToDevicePixels="True">

    <Window.Resources>

        <!-- ── Boton base ─────────────────────────────────────────── -->
        <Style x:Key="TNBtn" TargetType="Button">
            <Setter Property="Foreground"        Value="$($Script:Colors.Text)"/>
            <Setter Property="Background"        Value="$($Script:Colors.BgCard)"/>
            <Setter Property="BorderBrush"       Value="$($Script:Colors.Border)"/>
            <Setter Property="BorderThickness"   Value="1"/>
            <Setter Property="Padding"           Value="12,5"/>
            <Setter Property="FontSize"          Value="12"/>
            <Setter Property="Cursor"            Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="$($Script:Colors.Accent)"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="$($Script:Colors.AccentDark)"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bd" Property="Opacity" Value="0.4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Boton primario (azul) -->
        <Style x:Key="TNBtnPrimary" TargetType="Button" BasedOn="{StaticResource TNBtn}">
            <Setter Property="Background"  Value="$($Script:Colors.Accent)"/>
            <Setter Property="BorderBrush" Value="$($Script:Colors.AccentDark)"/>
            <Setter Property="Foreground"  Value="White"/>
        </Style>

        <!-- Boton icono / sin borde -->
        <Style x:Key="TNBtnIcon" TargetType="Button">
            <Setter Property="Background"      Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground"      Value="$($Script:Colors.TextMuted)"/>
            <Setter Property="Padding"         Value="4"/>
            <Setter Property="Cursor"          Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}"
                                CornerRadius="3" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="$($Script:Colors.BgSurface)"/>
                                <Setter Property="Foreground" Value="$($Script:Colors.Text)"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ── TreeViewItem ────────────────────────────────────────── -->
        <Style TargetType="TreeViewItem">
            <Setter Property="Background"      Value="Transparent"/>
            <Setter Property="Foreground"      Value="$($Script:Colors.Text)"/>
            <Setter Property="FontSize"        Value="12"/>
            <Setter Property="Padding"         Value="3,2"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$($Script:Colors.BgSurface)"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="$($Script:Colors.SelectionBg)"/>
                    <Setter Property="Foreground" Value="$($Script:Colors.SelectionFg)"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="TreeView">
            <Setter Property="Background"      Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>

        <!-- ── TabItem ────────────────────────────────────────────── -->
        <Style TargetType="TabItem">
            <Setter Property="Background"      Value="$($Script:Colors.BgPanel)"/>
            <Setter Property="Foreground"      Value="$($Script:Colors.TextMuted)"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding"         Value="12,7"/>
            <Setter Property="Margin"          Value="0,0,1,0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border x:Name="tb"
                                Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}"
                                BorderThickness="0,0,0,2"
                                BorderBrush="Transparent">
                            <ContentPresenter ContentSource="Header"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="tb" Property="Background"  Value="$($Script:Colors.BgCard)"/>
                                <Setter TargetName="tb" Property="BorderBrush" Value="$($Script:Colors.Accent)"/>
                                <Setter Property="Foreground" Value="$($Script:Colors.Text)"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="tb" Property="Background" Value="$($Script:Colors.BgCard)"/>
                                <Setter Property="Foreground" Value="$($Script:Colors.Text)"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="TabControl">
            <Setter Property="Background"      Value="$($Script:Colors.BgPrimary)"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding"         Value="0"/>
        </Style>

        <!-- ── TextBox ────────────────────────────────────────────── -->
        <Style x:Key="TNTextBox" TargetType="TextBox">
            <Setter Property="Background"      Value="$($Script:Colors.BgPanel)"/>
            <Setter Property="Foreground"      Value="$($Script:Colors.Text)"/>
            <Setter Property="CaretBrush"      Value="$($Script:Colors.Text)"/>
            <Setter Property="BorderBrush"     Value="$($Script:Colors.Border)"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"         Value="7,4"/>
            <Setter Property="FontSize"        Value="12"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4">
                            <ScrollViewer x:Name="PART_ContentHost"
                                          Margin="{TemplateBinding Padding}"
                                          VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsFocused" Value="True">
                                <Setter Property="BorderBrush" Value="$($Script:Colors.Accent)"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ── MenuItem (sin columna de icono) ───────────────────── -->
        <Style TargetType="MenuItem">
            <Setter Property="Foreground"      Value="$($Script:Colors.Text)"/>
            <Setter Property="Background"      Value="$($Script:Colors.BgPanel)"/>
            <Setter Property="FontSize"        Value="13"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding"         Value="10,5"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="MenuItem">
                        <Grid SnapsToDevicePixels="True">
                            <Border x:Name="bd"
                                    Background="{TemplateBinding Background}"
                                    BorderBrush="{TemplateBinding BorderBrush}"
                                    BorderThickness="{TemplateBinding BorderThickness}"
                                    Padding="{TemplateBinding Padding}">
                                <ContentPresenter ContentSource="Header"
                                                  RecognizesAccessKey="True"
                                                  VerticalAlignment="Center"/>
                            </Border>
                            <Popup x:Name="PART_Popup"
                                   AllowsTransparency="True"
                                   Focusable="False"
                                   IsOpen="{Binding IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}}"
                                   Placement="Bottom">
                                <Border Background="$($Script:Colors.BgPanel)"
                                        BorderBrush="$($Script:Colors.Border)"
                                        BorderThickness="1"
                                        SnapsToDevicePixels="True">
                                    <ScrollViewer CanContentScroll="True" MaxHeight="500"
                                                  VerticalScrollBarVisibility="Auto">
                                        <StackPanel IsItemsHost="True"
                                                    KeyboardNavigation.DirectionalNavigation="Cycle"/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="$($Script:Colors.SelectionBg)"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Foreground" Value="$($Script:Colors.TextDim)"/>
                            </Trigger>
                            <Trigger Property="Role" Value="SubmenuHeader">
                                <Setter TargetName="PART_Popup" Property="Placement" Value="Right"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="Role" Value="TopLevelHeader"/>
                                    <Condition Property="IsSubmenuOpen" Value="True"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="bd" Property="Background" Value="$($Script:Colors.BgCard)"/>
                                <Setter Property="Foreground" Value="$($Script:Colors.Text)"/>
                            </MultiTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ContextMenu">
            <Setter Property="Background"      Value="$($Script:Colors.BgPanel)"/>
            <Setter Property="BorderBrush"     Value="$($Script:Colors.Border)"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"         Value="2"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ContextMenu">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}"
                                SnapsToDevicePixels="True">
                            <ScrollViewer CanContentScroll="True" MaxHeight="600"
                                          VerticalScrollBarVisibility="Auto">
                                <StackPanel IsItemsHost="True"
                                            KeyboardNavigation.DirectionalNavigation="Cycle"/>
                            </ScrollViewer>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Menu">
            <Setter Property="Background"      Value="Transparent"/>
            <Setter Property="Foreground"      Value="$($Script:Colors.Text)"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>

        <Style TargetType="Separator">
            <Setter Property="Background" Value="$($Script:Colors.Border)"/>
            <Setter Property="Margin"     Value="0,3"/>
            <Setter Property="Height"     Value="1"/>
        </Style>

        <!-- ── ScrollBar minimalista ──────────────────────────────── -->
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="$($Script:Colors.BgPanel)"/>
            <Setter Property="Width"      Value="8"/>
            <Style.Triggers>
                <Trigger Property="Orientation" Value="Horizontal">
                    <Setter Property="Height" Value="8"/>
                    <Setter Property="Width"  Value="Auto"/>
                </Trigger>
            </Style.Triggers>
        </Style>

    </Window.Resources>

    <DockPanel LastChildFill="True">

        <!-- ══════════════════════ MENU BAR ══════════════════════════ -->
        <Border DockPanel.Dock="Top" Background="$($Script:Colors.BgHeader)"
                BorderBrush="$($Script:Colors.Border)" BorderThickness="0,0,0,1">
            <DockPanel LastChildFill="False">
                <!-- Logo -->
                <StackPanel DockPanel.Dock="Left" Orientation="Horizontal"
                            VerticalAlignment="Center" Margin="14,0,20,0">
                    <TextBlock Text="MaPeriT" FontSize="15" FontWeight="Bold"
                               Foreground="$($Script:Colors.Accent)" VerticalAlignment="Center"/>
                    <TextBlock Text=".TN" FontSize="15" FontWeight="Light"
                               Foreground="$($Script:Colors.TextMuted)" VerticalAlignment="Center"/>
                </StackPanel>

                <!-- Menus -->
                <Menu DockPanel.Dock="Left" VerticalAlignment="Center" Height="34">
                    <MenuItem Header="_Archivo">
                        <MenuItem x:Name="MenuOpenProject" Header="Abrir Proyecto MaPeriT..."/>
                        <MenuItem x:Name="MenuOpenFile"    Header="Abrir Archivo..."/>
                        <Separator/>
                        <MenuItem x:Name="MenuCloseAll"    Header="Cerrar todas las pestanas"/>
                        <Separator/>
                        <MenuItem x:Name="MenuExit"        Header="Salir"/>
                    </MenuItem>
                    <MenuItem Header="_Vista">
                        <MenuItem x:Name="MenuToggleTree"  Header="Panel Explorador" IsCheckable="True" IsChecked="True"/>
                        <Separator/>
                        <MenuItem x:Name="MenuRefresh"     Header="Recargar proyecto"/>
                    </MenuItem>
                    <MenuItem Header="_Analisis">
                        <MenuItem x:Name="MenuIOCScan"   Header="Escanear IOCs en proyecto"/>
                        <MenuItem x:Name="MenuTimeline"  Header="Timeline consolidada"/>
                        <Separator/>
                        <MenuItem x:Name="MenuBookmarks" Header="Marcadores"/>
                        <Separator/>
                        <MenuItem x:Name="MenuGlobalSearchAll" Header="Busqueda global (todos los formatos)"/>
                    </MenuItem>
                    <MenuItem Header="A_yuda">
                        <MenuItem x:Name="MenuAbout" Header="Acerca de MaPeriT.TN"/>
                    </MenuItem>
                </Menu>
            </DockPanel>
        </Border>

        <!-- ══════════════════════ TOOLBAR ═══════════════════════════ -->
        <Border DockPanel.Dock="Top" Background="$($Script:Colors.BgPanel)"
                BorderBrush="$($Script:Colors.Border)" BorderThickness="0,0,0,1"
                Padding="10,6,10,6">
            <DockPanel LastChildFill="False">
                <!-- Izquierda: botones de accion -->
                <StackPanel DockPanel.Dock="Left" Orientation="Horizontal">
                    <Button x:Name="BtnOpenProject" Style="{StaticResource TNBtnPrimary}"
                            Height="28" Margin="0,0,6,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#128193;" Margin="0,0,6,0" VerticalAlignment="Center" FontSize="13"/>
                            <TextBlock Text="Abrir Proyecto" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="BtnOpenFile" Style="{StaticResource TNBtn}"
                            Height="28" Margin="0,0,16,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#128196;" Margin="0,0,6,0" VerticalAlignment="Center" FontSize="13"/>
                            <TextBlock Text="Abrir Archivo" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Button>

                    <!-- Nombre del proyecto activo -->
                    <TextBlock x:Name="TxtProjectLabel"
                               Text="Sin proyecto abierto"
                               Foreground="$($Script:Colors.TextDim)"
                               VerticalAlignment="Center"
                               FontSize="12"/>
                </StackPanel>

                <!-- Derecha: tema + busqueda global -->
                <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
                    <Button x:Name="BtnThemeToggle" Style="{StaticResource TNBtnIcon}"
                            Width="30" Height="28" Margin="0,0,8,0"
                            ToolTip="Cambiar tema claro / oscuro">
                        <TextBlock x:Name="TxtThemeIcon" FontSize="14"
                                   Text="&#9728;" VerticalAlignment="Center"
                                   HorizontalAlignment="Center"/>
                    </Button>
                    <TextBlock Text="Buscar:" Foreground="$($Script:Colors.TextMuted)" FontSize="11"
                               VerticalAlignment="Center" Margin="0,0,6,0"/>
                    <TextBox x:Name="TxtGlobalSearch" Style="{StaticResource TNTextBox}"
                             Width="210" Height="28"/>
                    <Button x:Name="BtnGlobalSearch" Style="{StaticResource TNBtn}"
                            Height="28" Width="30" Padding="0" Margin="4,0,0,0">
                        <TextBlock Text="&#128269;" FontSize="14"/>
                    </Button>
                </StackPanel>
            </DockPanel>
        </Border>

        <!-- ══════════════════════ STATUS BAR ════════════════════════ -->
        <Border DockPanel.Dock="Bottom" Background="$($Script:Colors.BgHeader)"
                BorderBrush="$($Script:Colors.Border)" BorderThickness="0,1,0,0"
                Padding="10,3">
            <DockPanel LastChildFill="False">
                <TextBlock x:Name="TxtStatusLeft"  DockPanel.Dock="Left"
                           Text="Listo" Foreground="$($Script:Colors.TextDim)" FontSize="11"
                           VerticalAlignment="Center"/>
                <TextBlock x:Name="TxtStatusRight" DockPanel.Dock="Right"
                           Text="" Foreground="$($Script:Colors.TextDim)" FontSize="11"
                           VerticalAlignment="Center"/>
            </DockPanel>
        </Border>

        <!-- ══════════════════════ MAIN CONTENT ══════════════════════ -->
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition x:Name="LeftCol" Width="270" MinWidth="140" MaxWidth="600"/>
                <ColumnDefinition Width="4"/>
                <ColumnDefinition Width="*" MinWidth="300"/>
            </Grid.ColumnDefinitions>

            <!-- ── PANEL IZQUIERDO: Explorador ─────────────────────── -->
            <Border x:Name="PanelLeft" Grid.Column="0" Background="$($Script:Colors.BgPanel)">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Cabecera panel -->
                    <Border Grid.Row="0" Background="$($Script:Colors.BgHeader)"
                            BorderBrush="$($Script:Colors.Border)" BorderThickness="0,0,0,1"
                            Padding="10,7">
                        <TextBlock Text="EXPLORADOR" Foreground="$($Script:Colors.TextDim)"
                                   FontSize="10" FontWeight="SemiBold"
                                   VerticalAlignment="Center"/>
                    </Border>

                    <!-- Filtro de arbol -->
                    <Border Grid.Row="1" Background="$($Script:Colors.BgPanel)" Padding="6,5">
                        <TextBox x:Name="TxtTreeFilter" Style="{StaticResource TNTextBox}"
                                 Height="26" FontSize="11"
                                 ToolTip="Filtrar archivos en el arbol"/>
                    </Border>

                    <!-- TreeView -->
                    <ScrollViewer Grid.Row="2"
                                  VerticalScrollBarVisibility="Auto"
                                  HorizontalScrollBarVisibility="Auto"
                                  Background="$($Script:Colors.BgPanel)">
                        <TreeView x:Name="ProjectTree"
                                  Background="Transparent"
                                  BorderThickness="0"
                                  Padding="4,4,4,20"/>
                    </ScrollViewer>
                </Grid>
            </Border>

            <!-- ── SEPARADOR ──────────────────────────────────────── -->
            <GridSplitter Grid.Column="1" Width="4"
                          HorizontalAlignment="Stretch"
                          Background="$($Script:Colors.BgCard)" Cursor="SizeWE"/>

            <!-- ── PANEL DERECHO: Contenido ───────────────────────── -->
            <Grid Grid.Column="2">

                <!-- TabControl para pestanas abiertas -->
                <TabControl x:Name="TabsMain"
                            Background="$($Script:Colors.BgPrimary)"
                            BorderThickness="0"
                            Padding="0"/>

                <!-- Estado vacio (se oculta cuando hay pestanas) -->
                <Grid x:Name="GridEmptyState" Background="$($Script:Colors.BgPrimary)"
                      Visibility="Visible">
                    <StackPanel HorizontalAlignment="Center"
                                VerticalAlignment="Center">
                        <TextBlock HorizontalAlignment="Center">
                            <Run Text="MaPeriT" FontSize="54" FontWeight="Thin"
                                 Foreground="$($Script:Colors.BgSurface)"/>
                            <Run Text=".TN" FontSize="54" FontWeight="Light"
                                 Foreground="$($Script:Colors.Accent)"/>
                        </TextBlock>
                        <TextBlock Text="Visor Forense del Ecosistema MaPeriT"
                                   FontSize="14" Foreground="$($Script:Colors.BorderLight)"
                                   TextAlignment="Center" Margin="0,4,0,40"/>

                        <StackPanel Orientation="Horizontal"
                                    HorizontalAlignment="Center">
                            <Button x:Name="BtnEmptyProject"
                                    Style="{StaticResource TNBtnPrimary}"
                                    Padding="18,10" Margin="0,0,12,0"
                                    FontSize="13">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#128193;" Margin="0,0,8,0" FontSize="15"/>
                                    <TextBlock Text="Abrir Proyecto MaPeriT"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnEmptyFile"
                                    Style="{StaticResource TNBtn}"
                                    Padding="18,10"
                                    FontSize="13">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#128196;" Margin="0,0,8,0" FontSize="15"/>
                                    <TextBlock Text="Abrir Archivo"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                    </StackPanel>
                </Grid>

            </Grid>
        </Grid>

    </DockPanel>
</Window>
"@
}

#endregion
#endregion

#region ===== src\UI\Dashboard.ps1 =====
#region ============================================================
# MaPeriT.TN - DASHBOARD DE PROYECTO
# ============================================================

function New-DashboardContent {
    param([hashtable]$Meta)

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility   = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'
    $scroll.Background = New-WpfBrush $Script:Colors.BgPrimary

    $root = New-Object System.Windows.Controls.StackPanel
    $root.Margin = [System.Windows.Thickness]::new(20,20,20,20)

    # ── Cabecera ─────────────────────────────────────────────────────
    $header = New-Object System.Windows.Controls.Border
    $header.Background      = New-WpfBrush $Script:Colors.BgCard
    $header.CornerRadius    = [System.Windows.CornerRadius]::new(6)
    $header.Padding         = [System.Windows.Thickness]::new(20,16,20,16)
    $header.Margin          = [System.Windows.Thickness]::new(0,0,0,16)

    $headerGrid = New-Object System.Windows.Controls.Grid
    $hc0 = New-Object System.Windows.Controls.ColumnDefinition
    $hc0.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $hc1 = New-Object System.Windows.Controls.ColumnDefinition
    $hc1.Width = [System.Windows.GridLength]::Auto
    $headerGrid.ColumnDefinitions.Add($hc0)
    $headerGrid.ColumnDefinitions.Add($hc1)

    $titleSP = New-Object System.Windows.Controls.StackPanel
    $caseLabel = New-Object System.Windows.Controls.TextBlock
    $caseLabel.Text       = if ($Meta.CaseNumber) { "Caso: $($Meta.CaseNumber)" } else { $Meta.Name }
    $caseLabel.FontSize   = 20
    $caseLabel.FontWeight = [System.Windows.FontWeights]::Light
    $caseLabel.Foreground = New-WpfBrush $Script:Colors.Text
    $titleSP.Children.Add($caseLabel) | Out-Null

    $infoLabel = New-Object System.Windows.Controls.TextBlock
    $infoLabel.FontSize   = 11
    $infoLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $infoLabel.Margin     = [System.Windows.Thickness]::new(0,4,0,0)
    $parts = @()
    if ($Meta.ComputerName) { $parts += "Equipo: $($Meta.ComputerName)" }
    if ($Meta.Examiner)     { $parts += "Perito: $($Meta.Examiner)" }
    if ($Meta.StartTime)    { $parts += "Adquisicion: $($Meta.StartTime)" }
    $infoLabel.Text = $parts -join "   ·   "
    $titleSP.Children.Add($infoLabel) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($titleSP, 0)
    $headerGrid.Children.Add($titleSP) | Out-Null

    if ($Meta.HasAN) {
        $anBadge = New-Object System.Windows.Controls.Border
        $anBadge.Background        = New-WpfBrush "#0F3460"
        $anBadge.CornerRadius      = [System.Windows.CornerRadius]::new(4)
        $anBadge.Padding           = [System.Windows.Thickness]::new(8,4,8,4)
        $anBadge.VerticalAlignment = 'Center'
        $anText = New-Object System.Windows.Controls.TextBlock
        $anText.Text       = "AN Disponible"
        $anText.Foreground = New-WpfBrush $Script:Colors.Accent
        $anText.FontSize   = 11
        $anText.FontWeight = [System.Windows.FontWeights]::SemiBold
        $anBadge.Child     = $anText
        [System.Windows.Controls.Grid]::SetColumn($anBadge, 1)
        $headerGrid.Children.Add($anBadge) | Out-Null
    }

    $header.Child = $headerGrid
    $root.Children.Add($header) | Out-Null

    # ── Tarjetas de estadisticas (WrapPanel en lugar de UniformGrid) ──
    $statsWrap = New-Object System.Windows.Controls.WrapPanel
    $statsWrap.Margin = [System.Windows.Thickness]::new(0,0,0,16)

    $anomalyColor = if ($Meta.AnomalyCount -gt 0) { $Script:Colors.Warning } else { $Script:Colors.Success }
    $statsData = @(
        @{ Label="Fases capturadas";   Value=$Meta.PhaseCount.ToString();                Color=$Script:Colors.Accent  },
        @{ Label="Artefactos CSV/JSON";Value=$Meta.ArtifactCount.ToString();             Color=$Script:Colors.Success },
        @{ Label="Anomalias SW";       Value=$Meta.AnomalyCount.ToString();              Color=$anomalyColor          },
        @{ Label="Tamano total";       Value=(Format-FileSize $Meta.FileSizeTotal);      Color=$Script:Colors.Info    }
    )

    foreach ($stat in $statsData) {
        $card = New-Object System.Windows.Controls.Border
        $card.Background      = New-WpfBrush $Script:Colors.BgCard
        $card.CornerRadius    = [System.Windows.CornerRadius]::new(6)
        $card.Padding         = [System.Windows.Thickness]::new(20,14,20,14)
        $card.Margin          = [System.Windows.Thickness]::new(0,0,10,10)
        $card.BorderBrush     = New-WpfBrush $Script:Colors.Border
        $card.BorderThickness = [System.Windows.Thickness]::new(1)
        $card.MinWidth        = 160

        $cardSP = New-Object System.Windows.Controls.StackPanel
        $valText = New-Object System.Windows.Controls.TextBlock
        $valText.Text       = $stat.Value
        $valText.FontSize   = 28
        $valText.FontWeight = [System.Windows.FontWeights]::Light
        $valText.Foreground = New-WpfBrush $stat.Color
        $cardSP.Children.Add($valText) | Out-Null

        $lblText = New-Object System.Windows.Controls.TextBlock
        $lblText.Text       = $stat.Label
        $lblText.FontSize   = 11
        $lblText.Foreground = New-WpfBrush $Script:Colors.TextMuted
        $lblText.Margin     = [System.Windows.Thickness]::new(0,2,0,0)
        $cardSP.Children.Add($lblText) | Out-Null

        $card.Child = $cardSP
        $statsWrap.Children.Add($card) | Out-Null
    }
    $root.Children.Add($statsWrap) | Out-Null

    # ── Fases presentes (WrapPanel) ───────────────────────────────────
    $sectionLabel = New-Object System.Windows.Controls.TextBlock
    $sectionLabel.Text       = "FASES DE ADQUISICION"
    $sectionLabel.FontSize   = 10
    $sectionLabel.FontWeight = [System.Windows.FontWeights]::SemiBold
    $sectionLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $sectionLabel.Margin     = [System.Windows.Thickness]::new(0,0,0,8)
    $root.Children.Add($sectionLabel) | Out-Null

    $phasesWrap = New-Object System.Windows.Controls.WrapPanel
    $phasesWrap.Margin = [System.Windows.Thickness]::new(0,0,0,20)

    foreach ($kv in $Script:SW_PhaseNames.GetEnumerator()) {
        $phaseDir = Join-Path $Meta.Path $kv.Key
        $exists   = Test-Path $phaseDir

        $pCard = New-Object System.Windows.Controls.Border
        $pBgColor = if ($exists) { $Script:Colors.BgCard } else { $Script:Colors.BgPanel }
        $pCard.Background      = New-WpfBrush $pBgColor
        $pCard.CornerRadius    = [System.Windows.CornerRadius]::new(4)
        $pCard.Padding         = [System.Windows.Thickness]::new(10,7,10,7)
        $pCard.Margin          = [System.Windows.Thickness]::new(0,0,6,6)
        $pCard.Opacity         = if ($exists) { 1.0 } else { 0.35 }
        $pCard.MinWidth        = 200

        $pSP = New-Object System.Windows.Controls.StackPanel
        $pSP.Orientation = 'Horizontal'

        # Indicador de estado (rectangulo coloreado en lugar de Ellipse para evitar namespace)
        $dot = New-Object System.Windows.Controls.Border
        $dot.Width         = 8
        $dot.Height        = 8
        $dotColor = if ($exists) { $Script:Colors.Success } else { $Script:Colors.TextDim }
        $dot.Background    = New-WpfBrush $dotColor
        $dot.CornerRadius  = [System.Windows.CornerRadius]::new(4)
        $dot.VerticalAlignment = 'Center'
        $dot.Margin        = [System.Windows.Thickness]::new(0,0,8,0)
        $pSP.Children.Add($dot) | Out-Null

        $pText = New-Object System.Windows.Controls.TextBlock
        $pText.Text       = $kv.Value
        $pText.FontSize   = 12
        $pFgColor = if ($exists) { $Script:Colors.Text } else { $Script:Colors.TextDim }
        $pText.Foreground = New-WpfBrush $pFgColor
        $pText.VerticalAlignment = 'Center'
        $pSP.Children.Add($pText) | Out-Null

        if ($exists) {
            $fCount = if ($Meta.PhaseCounts) { [int]($Meta.PhaseCounts[$kv.Key]) } else { 0 }
            $countText = New-Object System.Windows.Controls.TextBlock
            $countText.Text       = "  ($fCount)"
            $countText.FontSize   = 11
            $countText.Foreground = New-WpfBrush $Script:Colors.TextMuted
            $countText.VerticalAlignment = 'Center'
            $pSP.Children.Add($countText) | Out-Null
        }

        $pCard.Child = $pSP
        $phasesWrap.Children.Add($pCard) | Out-Null
    }
    $root.Children.Add($phasesWrap) | Out-Null

    # ── Ruta ──────────────────────────────────────────────────────────
    $pathLabel = New-Object System.Windows.Controls.TextBlock
    $pathLabel.Text         = "Ruta: $($Meta.Path)"
    $pathLabel.FontSize     = 11
    $pathLabel.Foreground   = New-WpfBrush $Script:Colors.TextDim
    $pathLabel.TextWrapping = 'Wrap'
    $root.Children.Add($pathLabel) | Out-Null

    $scroll.Content = $root
    return $scroll
}

#endregion
#endregion

#region ===== src\UI\MainWindow.ps1 =====
#region ============================================================
# MaPeriT.TN - LOGICA DE LA VENTANA PRINCIPAL
# ============================================================

$Script:OpenTabs    = @{}    # FilePath -> TabItem
$Script:CurrentProject = $null

# ── Helpers de UI ─────────────────────────────────────────────────────

function Set-Status {
    param([string]$Left = "", [string]$Right = "")
    $Script:TNControls.StatusLeft.Dispatcher.Invoke({
        if ($Left)  { $Script:TNControls.StatusLeft.Text  = $Left  }
        if ($Right) { $Script:TNControls.StatusRight.Text = $Right }
    })
}

function Show-EmptyState {
    param([bool]$Show)
    $Script:TNControls.GridEmptyState.Visibility = if ($Show) { 'Visible' } else { 'Collapsed' }
}

function New-TabHeader {
    param([string]$Title, [string]$Icon = "·")

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    $iconTB = New-Object System.Windows.Controls.TextBlock
    $iconTB.Text       = $Icon
    $iconTB.Foreground = New-WpfBrush $Script:Colors.Accent
    $iconTB.FontSize   = 11
    $iconTB.Margin     = [System.Windows.Thickness]::new(0,0,6,0)
    $iconTB.VerticalAlignment = 'Center'
    $sp.Children.Add($iconTB) | Out-Null

    $titleTB = New-Object System.Windows.Controls.TextBlock
    $titleTB.Text       = $Title
    $titleTB.Foreground = New-WpfBrush $Script:Colors.Text
    $titleTB.FontSize   = 12
    $titleTB.VerticalAlignment = 'Center'
    $sp.Children.Add($titleTB) | Out-Null

    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content    = "✕"
    $closeBtn.Width      = 18
    $closeBtn.Height     = 18
    $closeBtn.Margin     = [System.Windows.Thickness]::new(8,0,0,0)
    $closeBtn.Background = [System.Windows.Media.Brushes]::Transparent
    $closeBtn.Foreground = New-WpfBrush $Script:Colors.TextDim
    $closeBtn.BorderThickness = [System.Windows.Thickness]::new(0)
    $closeBtn.Padding    = [System.Windows.Thickness]::new(0)
    $closeBtn.FontSize   = 10
    $closeBtn.Cursor     = [System.Windows.Input.Cursors]::Hand
    $closeBtn.VerticalContentAlignment = 'Center'
    $closeBtn.HorizontalContentAlignment = 'Center'
    $closeBtn.ToolTip    = "Cerrar pestana"
    $sp.Children.Add($closeBtn) | Out-Null

    # Hover en close btn ($this = el propio boton en el handler)
    $closeBtn.Add_MouseEnter({ $this.Foreground = New-WpfBrush $Script:Colors.Danger })
    $closeBtn.Add_MouseLeave({ $this.Foreground = New-WpfBrush $Script:Colors.TextDim })

    # Menú contextual en la cabecera de la pestaña
    $cmTag = [PSCustomObject]@{ Key = "" }
    $tabCM = New-Object System.Windows.Controls.ContextMenu
    $tabCM.Background     = New-WpfBrush $Script:Colors.BgCard
    $tabCM.BorderBrush    = New-WpfBrush $Script:Colors.Border
    $tabCM.BorderThickness = [System.Windows.Thickness]::new(1)
    $tabCM.Padding        = [System.Windows.Thickness]::new(2)
    foreach ($mDef in @(
        @{ H="Cerrar";             A="Close"      },
        @{ H="Cerrar las demas";   A="CloseOther" },
        @{ H="Cerrar todas";       A="CloseAll"   },
        @{ H="-";                  A="-"          },
        @{ H="Copiar ruta";        A="CopyPath"   }
    )) {
        if ($mDef.A -eq "-") { $tabCM.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null }
        else {
            $mi = New-Object System.Windows.Controls.MenuItem
            $mi.Header     = $mDef.H
            $mi.Foreground = New-WpfBrush $Script:Colors.Text
            $mi.Background = New-WpfBrush $Script:Colors.BgCard
            $mi.FontSize   = 12
            $mi.Tag        = [PSCustomObject]@{ Action=$mDef.A; CMTag=$cmTag }
            $mi.Add_Click({
                param($s, $e)
                $ctx = $s.Tag
                $key = $ctx.CMTag.Key
                switch ($ctx.Action) {
                    "Close"      { if ($key) { Close-Tab $key } }
                    "CloseOther" {
                        $toClose = @($Script:OpenTabs.Keys | Where-Object { $_ -ne $key })
                        foreach ($k in $toClose) { Close-Tab $k }
                    }
                    "CloseAll"   { Close-AllTabs }
                    "CopyPath"   { if ($key) { [System.Windows.Clipboard]::SetText($key) } }
                }
            })
            $tabCM.Items.Add($mi) | Out-Null
        }
    }
    $sp.ContextMenu = $tabCM

    return @{ Panel=$sp; CloseBtn=$closeBtn; TitleBlock=$titleTB; CMTag=$cmTag }
}

# ── Menú contextual en filas de DataGrid ──────────────────────────────

function Add-DataGridRowContextMenu {
    param(
        [System.Windows.Controls.DataGrid]$DG,
        [string]$FilePath = ""
    )

    # Seleccionar la fila bajo el cursor en click derecho
    $DG.Add_PreviewMouseRightButtonDown({
        param($sender, $e)
        $elem = $e.OriginalSource -as [System.Windows.DependencyObject]
        while ($null -ne $elem) {
            if ($elem -is [System.Windows.Controls.DataGridRow]) {
                $sender.SelectedItem = $elem.Item
                break
            }
            try { $elem = [System.Windows.Media.VisualTreeHelper]::GetParent($elem) }
            catch { break }
        }
    })

    $cmTag = [PSCustomObject]@{ DG=$DG; FilePath=$FilePath }
    $rowCM = New-Object System.Windows.Controls.ContextMenu
    $rowCM.Background      = New-WpfBrush $Script:Colors.BgCard
    $rowCM.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $rowCM.BorderThickness = [System.Windows.Thickness]::new(1)
    $rowCM.Padding         = [System.Windows.Thickness]::new(2)
    $DG.ContextMenu   = $rowCM

    foreach ($mDef in @(
        @{ H="Copiar fila";               A="Copy"     },
        @{ H="-";                         A="-"        },
        @{ H="Anadir marcador en fila...";A="Bookmark" },
        @{ H="Escanear IOCs en fila";     A="IOC"      }
    )) {
        if ($mDef.A -eq "-") { $rowCM.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null }
        else {
            $mi = New-Object System.Windows.Controls.MenuItem
            $mi.Header     = $mDef.H
            $mi.Foreground = New-WpfBrush $Script:Colors.Text
            $mi.Background = New-WpfBrush $Script:Colors.BgCard
            $mi.FontSize   = 12
            $mi.Tag        = [PSCustomObject]@{ Action=$mDef.A; CMTag=$cmTag }
            $mi.Add_Click({
                param($s, $e)
                $ctx     = $s.Tag
                $dg      = $ctx.CMTag.DG
                $item    = $dg.SelectedItem
                if ($null -eq $item) { return }

                $tbl     = $dg.Tag -as [System.Data.DataTable]
                $rowView = $item -as [System.Data.DataRowView]
                $rowPath = $ctx.CMTag.FilePath
                $lineNum = 0
                $colName = ""
                $colVal  = ""

                if ($rowView -and $tbl) {
                    if ($tbl.Columns.Contains('Ruta')) {
                        $candidate = $rowView['Ruta'] -as [string]
                        if (-not [string]::IsNullOrEmpty($candidate)) { $rowPath = $candidate }
                    }
                    foreach ($lnCol in @('Linea','LineNumber','Line')) {
                        if ($tbl.Columns.Contains($lnCol)) {
                            $lv = 0
                            if ([int]::TryParse($rowView[$lnCol].ToString(), [ref]$lv) -and $lv -gt 0) {
                                $lineNum = $lv; break
                            }
                        }
                    }
                    foreach ($cc in @('Contenido','Message','Descripcion','Context','Match')) {
                        if ($tbl.Columns.Contains($cc)) {
                            $cv = $rowView[$cc] -as [string]
                            if (-not [string]::IsNullOrEmpty($cv)) {
                                $colName = $cc
                                $colVal  = if ($cv.Length -gt 120) { $cv.Substring(0,120) } else { $cv }
                                break
                            }
                        }
                    }
                }

                # Fallback: usar índice en DataTable como número de línea único por fila
                if ($lineNum -eq 0 -and $rowView -and $tbl) {
                    $lineNum = $tbl.Rows.IndexOf($rowView.Row) + 1
                }
                # Fallback: si no hay columna de contexto, usar la primera columna con valor
                if ([string]::IsNullOrEmpty($colName) -and $rowView -and $tbl) {
                    foreach ($col in $tbl.Columns) {
                        $cv = $rowView[$col.ColumnName] -as [string]
                        if (-not [string]::IsNullOrEmpty($cv)) {
                            $colName = $col.ColumnName
                            $colVal  = if ($cv.Length -gt 120) { $cv.Substring(0,120) } else { $cv }
                            break
                        }
                    }
                }

                switch ($ctx.Action) {
                    "Copy" {
                        if ($rowView) {
                            $vals = $rowView.Row.ItemArray | ForEach-Object { $_.ToString() }
                            [System.Windows.Clipboard]::SetText($vals -join "`t")
                        }
                    }
                    "Bookmark" {
                        Show-AddBookmarkDialog -FilePath   $rowPath `
                                               -LineNumber $lineNum `
                                               -ColumnName $colName `
                                               -CellValue  $colVal
                    }
                    "IOC" {
                        if (-not [string]::IsNullOrEmpty($rowPath) -and (Test-Path $rowPath)) {
                            Invoke-SingleFileIOCScan -FilePath $rowPath
                        }
                    }
                }
            })
            $rowCM.Items.Add($mi) | Out-Null
        }
    }
}

# ── Abrir archivo en pestana ───────────────────────────────────────────

function Open-FileInTab {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        Set-Status "Archivo no encontrado: $FilePath"
        return
    }

    # Si ya esta abierto, activar esa pestana
    if ($Script:OpenTabs.ContainsKey($FilePath)) {
        $Script:TNControls.TabsMain.SelectedItem = $Script:OpenTabs[$FilePath]
        return
    }

    $filename   = [System.IO.Path]::GetFileName($FilePath)
    $viewerType = Get-FileViewerType $FilePath
    $ext        = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $icon       = if ($Script:FileIcons.ContainsKey($ext)) { $Script:FileIcons[$ext] } else { $Script:FileIcons["default"] }

    Set-Status "Cargando $filename..."

    # Crear contenido del viewer
    $content = switch ($viewerType) {
        "CSV"   { New-CSVViewerContent  -FilePath $FilePath }
        "MFT"   { New-MFTViewerContent  -FilePath $FilePath }
        "EVTX"  { New-EVTXViewerContent -FilePath $FilePath }
        "JSON"  { New-JSONViewerContent -FilePath $FilePath }
        "Text"  { New-TextViewerContent -FilePath $FilePath }
        "HTML"  { New-HTMLViewerContent -FilePath $FilePath }
        "Hex"   { New-HexViewerContent  -FilePath $FilePath }
        default { New-TextViewerContent -FilePath $FilePath }
    }

    # Crear TabItem
    $tab = New-Object System.Windows.Controls.TabItem
    $headerParts = New-TabHeader -Title $filename -Icon $icon
    $tab.Header  = $headerParts.Panel
    $headerParts.CMTag.Key = $FilePath

    # Boton cerrar: guardar path en Tag del boton, leer con $this.Tag
    $headerParts.CloseBtn.Tag = $FilePath
    $headerParts.CloseBtn.Add_Click({
        Close-Tab ($this.Tag -as [string])
    })

    $tab.Content = $content
    $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
    $Script:TNControls.TabsMain.SelectedItem = $tab
    $Script:OpenTabs[$FilePath] = $tab

    Show-EmptyState $false
    Set-Status "$filename  ·  $viewerType" "$(($Script:OpenTabs.Keys).Count) pestanas abiertas"
}

function Close-Tab {
    param([string]$FilePath)
    if (-not $Script:OpenTabs.ContainsKey($FilePath)) { return }
    $tab = $Script:OpenTabs[$FilePath]
    $Script:TNControls.TabsMain.Items.Remove($tab)
    $Script:OpenTabs.Remove($FilePath)

    if ($Script:OpenTabs.Count -eq 0) {
        Show-EmptyState $true
        Set-Status "Listo" ""
    } else {
        Set-Status "$(($Script:OpenTabs.Keys).Count) pestanas abiertas" ""
    }
}

function Close-AllTabs {
    $paths = @($Script:OpenTabs.Keys)
    foreach ($p in $paths) { Close-Tab $p }
}

# ── Viewers simples (HTML y Hex) ───────────────────────────────────────

function New-HTMLViewerContent {
    param([string]$FilePath)
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.HorizontalAlignment = 'Center'
    $sp.VerticalAlignment   = 'Center'

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text       = "Informe HTML"
    $lbl.FontSize   = 18
    $lbl.Foreground = New-WpfBrush $Script:Colors.Accent
    $lbl.TextAlignment = 'Center'
    $lbl.Margin     = [System.Windows.Thickness]::new(0,0,0,12)
    $sp.Children.Add($lbl) | Out-Null

    $info = New-Object System.Windows.Controls.TextBlock
    $info.Text       = [System.IO.Path]::GetFileName($FilePath)
    $info.FontSize   = 12
    $info.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $info.TextAlignment = 'Center'
    $info.Margin     = [System.Windows.Thickness]::new(0,0,0,20)
    $sp.Children.Add($info) | Out-Null

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "Abrir en navegador"
    $btn.Padding = [System.Windows.Thickness]::new(16,8,16,8)
    $btn.Background  = New-WpfBrush $Script:Colors.Accent
    $btn.Foreground  = [System.Windows.Media.Brushes]::White
    $btn.BorderBrush = New-WpfBrush $Script:Colors.AccentDark
    $btn.FontSize    = 13
    $btn.Cursor      = [System.Windows.Input.Cursors]::Hand
    # BUG CONFIRMADO (verificado empiricamente): $capturedPath es local a esta
    # funcion; copiarla a otro nombre de variable NO la convierte en closure,
    # el scriptblock se invoca tras retornar la funcion y $capturedPath es
    # $null en ese momento -> Start-Process $null lanza una excepcion no
    # controlada (sin try/catch, sin manejador global) que puede tumbar toda
    # la aplicacion al abrir cualquier informe HTML. Se guarda en .Tag, que
    # SI viaja con el control con independencia del scope que lo creo.
    $btn.Tag = $FilePath
    $btn.Add_Click({
        param($s, $e)
        try { Start-Process $s.Tag } catch { Set-Status "No se pudo abrir en el navegador: $($_.Exception.Message)" "" }
    })
    $sp.Children.Add($btn) | Out-Null

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    $outer.Children.Add($sp) | Out-Null
    return $outer
}

function New-HexViewerContent {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    foreach ($h in @([System.Windows.GridLength]::Auto,
                     [System.Windows.GridLength]::Auto,
                     [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star),
                     [System.Windows.GridLength]::Auto)) {
        $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = $h
        $outer.RowDefinitions.Add($rd)
    }

    $size = if (Test-Path $FilePath) { Format-FileSize (Get-Item $FilePath).Length } else { "?" }
    $fileLen = if (Test-Path $FilePath) { (Get-Item $FilePath).Length } else { 0 }

    # Header
    $header = New-Object System.Windows.Controls.Border
    $header.Background      = New-WpfBrush $Script:Colors.BgCard
    $header.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $header.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $header.Padding         = [System.Windows.Thickness]::new(12,7,12,7)
    $hDP = New-Object System.Windows.Controls.DockPanel; $hDP.LastChildFill = $false
    $hTitle = New-Object System.Windows.Controls.TextBlock
    $hTitle.Text = "$([System.IO.Path]::GetFileName($FilePath))  ·  $size  ·  Hex Viewer"
    $hTitle.Foreground = New-WpfBrush $Script:Colors.Text; $hTitle.FontSize = 12
    $hTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
    $hTitle.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($hTitle, 'Left')
    $hDP.Children.Add($hTitle) | Out-Null
    $header.Child = $hDP
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    $outer.Children.Add($header) | Out-Null

    # Toolbar: offset + search
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgPanel
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(10,5,10,5)
    $tbSP = New-Object System.Windows.Controls.StackPanel; $tbSP.Orientation = 'Horizontal'

    foreach ($lbl in @("Ir a offset (hex):","  Buscar texto:")) {
        $l = New-Object System.Windows.Controls.TextBlock; $l.Text = $lbl
        $l.Foreground = New-WpfBrush $Script:Colors.TextMuted; $l.FontSize = 11
        $l.VerticalAlignment = 'Center'; $l.Margin = [System.Windows.Thickness]::new(0,0,6,0)
        $tbSP.Children.Add($l) | Out-Null
        $box = New-Object System.Windows.Controls.TextBox
        $box.Width = 110; $box.Height = 24
        $box.Background = New-WpfBrush $Script:Colors.BgSurface
        $box.Foreground = New-WpfBrush $Script:Colors.Text
        $box.CaretBrush = [System.Windows.Media.Brushes]::White
        $box.BorderBrush = New-WpfBrush $Script:Colors.Border
        $box.Padding = [System.Windows.Thickness]::new(6,2,6,2); $box.FontSize = 11
        $box.Margin = [System.Windows.Thickness]::new(0,0,12,0)
        $tbSP.Children.Add($box) | Out-Null
    }

    $btnCopy = New-Object System.Windows.Controls.Button
    $btnCopy.Content = "Copiar vista"; $btnCopy.Height = 24
    $btnCopy.Padding = [System.Windows.Thickness]::new(8,2,8,2)
    $btnCopy.Background = New-WpfBrush $Script:Colors.BgSurface
    $btnCopy.Foreground = New-WpfBrush $Script:Colors.Text
    $btnCopy.BorderBrush = New-WpfBrush $Script:Colors.Border
    $btnCopy.FontSize = 11; $btnCopy.Cursor = [System.Windows.Input.Cursors]::Hand
    $tbSP.Children.Add($btnCopy) | Out-Null

    $toolbar.Child = $tbSP
    [System.Windows.Controls.Grid]::SetRow($toolbar, 1)
    $outer.Children.Add($toolbar) | Out-Null

    # Hex content
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility   = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Auto'
    $scroll.Background = New-WpfBrush $Script:Colors.BgPrimary

    $monoFont = New-Object System.Windows.Media.FontFamily("Cascadia Code, Consolas, Courier New")
    $hexText = New-Object System.Windows.Controls.TextBlock
    $hexText.FontFamily = $monoFont; $hexText.FontSize = 11
    $hexText.Foreground = New-WpfBrush $Script:Colors.Text
    $hexText.Padding    = [System.Windows.Thickness]::new(14,10,14,10)
    $hexText.TextWrapping = 'NoWrap'; $hexText.VerticalAlignment = 'Top'

    $maxBytes = 65536  # 64 KB display limit
    $allHexLines = [System.Collections.Generic.List[string]]::new()
    try {
        $fs = [System.IO.File]::OpenRead($FilePath)
        $buf = [byte[]]::new([Math]::Min($maxBytes, $fs.Length))
        $read = $fs.Read($buf, 0, $buf.Length)
        $fs.Close()
        for ($i = 0; $i -lt $read; $i += 16) {
            $end   = [Math]::Min($i + 15, $read - 1)
            $chunk = $buf[$i..$end]
            $hex   = ($chunk | ForEach-Object { "{0:X2}" -f $_ }) -join " "
            $ascii = -join ($chunk | ForEach-Object { if ($_ -ge 32 -and $_ -le 126) { [char]$_ } else { "." } })
            $allHexLines.Add(("{0:X8}  {1,-47}  {2}" -f $i, $hex, $ascii))
        }
        $truncNote = if ($fileLen -gt $maxBytes) { "`n`n... ($size total — mostrando primeros 64 KB)" } else { "" }
        $hexText.Text = ($allHexLines -join "`n") + $truncNote
    } catch {
        $hexText.Text = "Error al leer el fichero: $_"
    }

    $scroll.Content = $hexText
    [System.Windows.Controls.Grid]::SetRow($scroll, 2)
    $outer.Children.Add($scroll) | Out-Null

    # Status
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLbl = New-Object System.Windows.Controls.TextBlock
    $statusLbl.Text = "Fichero binario  ·  $size  ·  $($allHexLines.Count) lineas"
    $statusLbl.Foreground = New-WpfBrush $Script:Colors.TextMuted; $statusLbl.FontSize = 11
    $statusBar.Child = $statusLbl
    [System.Windows.Controls.Grid]::SetRow($statusBar, 3)
    $outer.Children.Add($statusBar) | Out-Null

    # Toolbar interactions (offset + search + copy) — state in Tag
    $offsetBox = $tbSP.Children | Where-Object { $_ -is [System.Windows.Controls.TextBox] } | Select-Object -First 1
    $searchBox = $tbSP.Children | Where-Object { $_ -is [System.Windows.Controls.TextBox] } | Select-Object -Last 1

    $offsetBox.Tag = [PSCustomObject]@{ Scroll=$scroll; HexText=$hexText; Lines=$allHexLines; Status=$statusLbl }
    $offsetBox.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -ne 'Return') { return }
        $ctx = $sender.Tag
        $hexStr = $sender.Text.Trim() -replace "^0x",""
        $offset = 0
        if ([int64]::TryParse($hexStr, [System.Globalization.NumberStyles]::HexNumber, $null, [ref]$offset)) {
            $lineIdx = [int]($offset / 16)
            if ($lineIdx -ge 0 -and $lineIdx -lt $ctx.Lines.Count) {
                $approxY = $lineIdx * 17.0
                $ctx.Scroll.ScrollToVerticalOffset($approxY)
                $ctx.Status.Text = "Offset: 0x$('{0:X8}' -f $offset)  ·  Linea $($lineIdx+1)"
            }
        }
    })

    $searchBox.Tag = [PSCustomObject]@{ HexText=$hexText; Lines=$allHexLines; Status=$statusLbl; Scroll=$scroll }
    $searchBox.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -ne 'Return') { return }
        $ctx = $sender.Tag
        $q = $sender.Text.Trim()
        if ([string]::IsNullOrEmpty($q)) { return }
        $idx = -1
        for ($i = 0; $i -lt $ctx.Lines.Count; $i++) {
            if ($ctx.Lines[$i] -match [regex]::Escape($q)) { $idx = $i; break }
        }
        if ($idx -ge 0) {
            $ctx.Scroll.ScrollToVerticalOffset($idx * 17.0)
            $ctx.Status.Text = "Encontrado en linea $($idx+1)  ·  Offset 0x$('{0:X8}' -f ($idx*16))"
        } else {
            $ctx.Status.Text = "No encontrado: '$q'"
        }
    })

    $btnCopy.Tag = $hexText
    $btnCopy.Add_Click({
        param($sender, $e)
        $t = ($sender.Tag -as [System.Windows.Controls.TextBlock])
        if ($t) { [System.Windows.Clipboard]::SetText($t.Text) }
    })

    return $outer
}

# ── Cargar proyecto en el arbol ────────────────────────────────────────

function Load-ProjectTree {
    param([string]$ProjectPath)

    $ctrl = $Script:TNControls
    $ctrl.ProjectTree.Items.Clear()
    $ctrl.TxtProjectLabel.Text       = "Cargando proyecto..."
    $ctrl.TxtProjectLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    Set-Status "Cargando proyecto..." ""

    # Toda la E/S de disco en un runspace de fondo para no bloquear el hilo UI
    $bgScript = {
        param($projectPath, $swPhaseNames)

        $meta = [ordered]@{
            Path          = $projectPath
            Name          = (Split-Path $projectPath -Leaf)
            CaseNumber    = ""
            Examiner      = ""
            StartTime     = ""
            ComputerName  = ""
            HasAN         = $false
            AnomalyCount  = 0
            ArtifactCount = 0
            PhaseCount    = 0
            FileSizeTotal = 0
            PhaseCounts   = @{}
        }

        # Leer session.json (formato ideal, pero NI SW NI OF lo generan hoy -
        # se deja por si una version futura lo escribe; el fallback de abajo
        # con OSInfo.json es el que realmente funciona en la practica).
        foreach ($sf in @(
            (Join-Path $projectPath "Logs\session.json"),
            (Join-Path $projectPath "session.json")
        )) {
            if (Test-Path $sf) {
                try {
                    $s = Get-Content $sf -Raw | ConvertFrom-Json
                    if ($s.CaseNumber)   { $meta.CaseNumber   = $s.CaseNumber   }
                    if ($s.ExaminerName) { $meta.Examiner     = $s.ExaminerName }
                    if ($s.StartTime)    { $meta.StartTime    = $s.StartTime    }
                    if ($s.ComputerName) { $meta.ComputerName = $s.ComputerName }
                } catch {}
                break
            }
        }

        # Fallback: ComputerName desde OSInfo.json (SW: NombreEquipo, OF: CSName).
        # Sin esto, ComputerName queda vacio en TODOS los casos reales pese a que
        # el dato si esta disponible en el propio proyecto.
        if ([string]::IsNullOrEmpty($meta.ComputerName)) {
            $osInfoPath = Join-Path $projectPath "02_SystemInfo\OSInfo.json"
            if (Test-Path $osInfoPath) {
                try {
                    $osInfo = Get-Content $osInfoPath -Raw | ConvertFrom-Json
                    if ($osInfo.NombreEquipo)   { $meta.ComputerName = $osInfo.NombreEquipo }
                    elseif ($osInfo.CSName)     { $meta.ComputerName = $osInfo.CSName }
                } catch {}
            }
        }

        # Perito: de la portada del informe pericial de SW ("Perito") u OF ("Perito
        # Informatico"). Antes solo se buscaba en session.json, que no existe, y el
        # Dashboard nunca mostraba el perito.
        if ([string]::IsNullOrEmpty($meta.Examiner)) {
            $repPath = Join-Path $projectPath "Report\InformePericial.html"
            if (Test-Path $repPath) {
                try {
                    $rep = Get-Content $repPath -Raw -ErrorAction Stop
                    if ($rep -match "<label>Perito(?: Informatico)?</label>\s*<span>([^<]{1,80})</span>") {
                        $meta.Examiner = [System.Net.WebUtility]::HtmlDecode($Matches[1].Trim())
                    }
                } catch {}
            }
        }

        # Numero de caso del nombre del directorio (OF: "MaPeriT_OF_<caso>_<fecha>")
        if ([string]::IsNullOrEmpty($meta.CaseNumber)) {
            $dirName = Split-Path $projectPath -Leaf
            if ($dirName -match '^MaPeriT_(?:OF_)?(.+?)_\d{8}') { $meta.CaseNumber = $Matches[1] }
        }

        # Fases y modulo AN
        $meta.PhaseCount = @($swPhaseNames.Keys | Where-Object { Test-Path (Join-Path $projectPath $_) }).Count
        $meta.HasAN      = Test-Path (Join-Path $projectPath "ANALISIS_AN")

        # Conteo global de artefactos (operacion lenta — se ejecuta en background)
        try {
            $files = @(Get-ChildItem $projectPath -Recurse -Include "*.csv","*.json" -ErrorAction SilentlyContinue)
            $meta.ArtifactCount = $files.Count
            $meta.FileSizeTotal = ($files | Measure-Object -Property Length -Sum).Sum
        } catch {}

        # Anomalias: solo Analysis\Anomalies.csv de SW (ver Get-ProjectMetadata)
        $ap = Join-Path $projectPath "Analysis\Anomalies.csv"
        if (Test-Path $ap) {
            try { $meta.AnomalyCount = @(Import-Csv $ap -ErrorAction SilentlyContinue).Count } catch {}
        }

        # Conteo de ficheros por fase para el dashboard
        foreach ($dirKey in $swPhaseNames.Keys) {
            $phaseDir = Join-Path $projectPath $dirKey
            if (Test-Path $phaseDir) {
                try { $meta.PhaseCounts[$dirKey] = (Get-ChildItem $phaseDir -Recurse -File -ErrorAction SilentlyContinue).Count }
                catch { $meta.PhaseCounts[$dirKey] = 0 }
            }
        }

        # Arbol de navegacion: solo datos (PSObject), sin WPF
        function _TN_ChildNodes {
            param([string]$Path, [int]$Depth)
            if ($Depth -gt 5) { return }
            $nodes = [System.Collections.Generic.List[PSCustomObject]]::new()
            Get-ChildItem $Path -Directory -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
                $node = [PSCustomObject]@{
                    NodeType = "Folder"; Name = $_.Name; Path = $_.FullName
                    Children = [System.Collections.Generic.List[PSCustomObject]]::new()
                }
                foreach ($child in (_TN_ChildNodes $_.FullName ($Depth + 1))) {
                    $node.Children.Add($child) | Out-Null
                }
                $nodes.Add($node) | Out-Null
            }
            Get-ChildItem $Path -File -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
                $nodes.Add([PSCustomObject]@{
                    NodeType = "File"; Name = $_.Name; Path = $_.FullName
                    Ext      = $_.Extension.ToLower(); Size = $_.Length; Children = $null
                }) | Out-Null
            }
            return $nodes
        }

        $treeRoot = [PSCustomObject]@{
            NodeType = "Project"; Name = (Split-Path $projectPath -Leaf); Path = $projectPath
            Children = [System.Collections.Generic.List[PSCustomObject]]::new()
        }

        # Fases conocidas en orden
        foreach ($dirKey in $swPhaseNames.Keys) {
            $fullPath = Join-Path $projectPath $dirKey
            if (-not (Test-Path $fullPath -PathType Container)) { continue }
            $phaseNode = [PSCustomObject]@{
                NodeType = "Phase"; Name = $swPhaseNames[$dirKey]; Path = $fullPath
                Children = [System.Collections.Generic.List[PSCustomObject]]::new()
            }
            foreach ($child in (_TN_ChildNodes $fullPath 0)) {
                $phaseNode.Children.Add($child) | Out-Null
            }
            $treeRoot.Children.Add($phaseNode) | Out-Null
        }

        # Directorios no reconocidos
        $knownDirs = @($swPhaseNames.Keys)
        Get-ChildItem $projectPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $knownDirs } | ForEach-Object {
                $node = [PSCustomObject]@{
                    NodeType = "Folder"; Name = $_.Name; Path = $_.FullName
                    Children = [System.Collections.Generic.List[PSCustomObject]]::new()
                }
                foreach ($child in (_TN_ChildNodes $_.FullName 0)) {
                    $node.Children.Add($child) | Out-Null
                }
                $treeRoot.Children.Add($node) | Out-Null
            }

        # Ficheros en la raiz del proyecto
        Get-ChildItem $projectPath -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match '\.(csv|json|html|txt|log)$' } |
            Sort-Object Name | ForEach-Object {
                $treeRoot.Children.Add([PSCustomObject]@{
                    NodeType = "File"; Name = $_.Name; Path = $_.FullName
                    Ext      = $_.Extension.ToLower(); Size = $_.Length; Children = $null
                }) | Out-Null
            }

        Write-Output -NoEnumerate ([PSCustomObject]@{ Meta = $meta; Tree = $treeRoot; Err = "" })
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{
        projectPath  = $ProjectPath
        swPhaseNames = $Script:SW_PhaseNames
    })
    $handle = $ps.BeginInvoke()

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(300)
    $timer.Tag = [PSCustomObject]@{
        Ps          = $ps
        Handle      = $handle
        Rs          = $rs
        ProjectPath = $ProjectPath
    }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag
        if ($ctx.Ps.InvocationStateInfo.State -in 'Completed','Failed','Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                if ($null -eq $obj -or -not [string]::IsNullOrEmpty($obj.Err)) {
                    $errMsg = if ($obj -and $obj.Err) { $obj.Err } else { "Sin respuesta del proceso de carga" }
                    Set-Status "Error cargando proyecto: $errMsg" ""
                    $Script:TNControls.TxtProjectLabel.Text = "Error al cargar"
                    return
                }

                $meta = $obj.Meta
                $Script:CurrentProject = $meta

                $Script:TNControls.TxtProjectLabel.Text       = if ($meta.CaseNumber) { "Caso $($meta.CaseNumber)" } else { $meta.Name }
                $Script:TNControls.TxtProjectLabel.Foreground = New-WpfBrush $Script:Colors.Text

                Initialize-Bookmarks -ProjectPath $ctx.ProjectPath

                # Dashboard
                $dashKey = "__dashboard__$($ctx.ProjectPath)"
                if (-not $Script:OpenTabs.ContainsKey($dashKey)) {
                    $dashContent = New-DashboardContent -Meta $meta
                    $tab = New-Object System.Windows.Controls.TabItem
                    $headerParts = New-TabHeader -Title "Dashboard" -Icon "⊞"
                    $tab.Header  = $headerParts.Panel
                    $headerParts.CMTag.Key = $dashKey
                    $tab.Content = $dashContent
                    $Script:TNControls.TabsMain.Items.Insert(0, $tab)
                    $Script:TNControls.TabsMain.SelectedItem = $tab
                    $Script:OpenTabs[$dashKey] = $tab
                    $headerParts.CloseBtn.Tag = $dashKey
                    $headerParts.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
                    Show-EmptyState $false
                }

                # Construir arbol (solo operaciones WPF, datos ya calculados en background)
                Add-TreeNode -Node $obj.Tree -Control $Script:TNControls.ProjectTree | Out-Null

                Set-Status "Proyecto cargado: $($meta.Name)" "$($meta.PhaseCount) fases  ·  $($meta.ArtifactCount) artefactos"
            } catch {
                Set-Status "Error al procesar proyecto: $($_.Exception.Message)" ""
            } finally {
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
}

function Add-TreeNode {
    param($Node, $Control)

    $item = New-Object System.Windows.Controls.TreeViewItem

    # Header
    $headerSP = New-Object System.Windows.Controls.StackPanel
    $headerSP.Orientation = 'Horizontal'

    $iconTB = New-Object System.Windows.Controls.TextBlock
    $iconTB.Margin    = [System.Windows.Thickness]::new(0,0,5,0)
    $iconTB.FontSize  = 11
    $iconTB.VerticalAlignment = 'Center'

    $nameTB = New-Object System.Windows.Controls.TextBlock
    $nameTB.VerticalAlignment = 'Center'
    $nameTB.FontSize  = 12

    switch ($Node.NodeType) {
        "Project" {
            $iconTB.Text       = "P"
            $iconTB.Foreground = New-WpfBrush $Script:Colors.Accent
            $nameTB.Text       = $Node.Name
            $nameTB.FontWeight = [System.Windows.FontWeights]::SemiBold
            $nameTB.Foreground = New-WpfBrush $Script:Colors.Text
            $item.IsExpanded   = $true
        }
        "Phase" {
            $iconTB.Text       = "F"
            $iconTB.Foreground = New-WpfBrush $Script:Colors.Accent
            $nameTB.Text       = $Node.Name
            $nameTB.FontWeight = [System.Windows.FontWeights]::SemiBold
            $nameTB.Foreground = New-WpfBrush $Script:Colors.Text
            $item.IsExpanded   = $false
        }
        "Folder" {
            $iconTB.Text       = "+"
            $iconTB.Foreground = New-WpfBrush $Script:Colors.TextMuted
            $nameTB.Text       = $Node.Name
            $nameTB.Foreground = New-WpfBrush $Script:Colors.TextMuted
            $item.IsExpanded   = $false
        }
        "File" {
            $ext = $Node.Ext
            $iconTB.Text       = if ($Script:FileIcons.ContainsKey($ext)) { $Script:FileIcons[$ext] } else { $Script:FileIcons["default"] }
            $iconColor = switch ($ext) {
                ".csv"  { $Script:Colors.Success   }
                ".json" { $Script:Colors.Warning   }
                ".evtx" { $Script:Colors.Danger    }
                ".html" { $Script:Colors.Info      }
                default { $Script:Colors.TextMuted }
            }
            $iconTB.Foreground = New-WpfBrush $iconColor
            $nameTB.Text       = $Node.Name
            $nameTB.Foreground = New-WpfBrush $Script:Colors.Text
            $item.Cursor = [System.Windows.Input.Cursors]::Hand

            $item.Add_Selected({
                param($s, $e)
                $path = $s.Tag -as [string]
                if (-not [string]::IsNullOrEmpty($path)) {
                    $e.Handled = $true
                    Open-FileInTab -FilePath $path
                }
            })
            $item.Add_KeyDown({
                param($s, $e)
                if ($e.Key -eq 'Return') {
                    $path = $s.Tag -as [string]
                    if (-not [string]::IsNullOrEmpty($path)) {
                        $e.Handled = $true
                        Open-FileInTab -FilePath $path
                    }
                }
            })

            # Menú contextual
            $cm = New-Object System.Windows.Controls.ContextMenu
            $cm.Background      = New-WpfBrush $Script:Colors.BgCard
            $cm.BorderBrush     = New-WpfBrush $Script:Colors.Border
            $cm.BorderThickness = [System.Windows.Thickness]::new(1)
            $cm.Padding         = [System.Windows.Thickness]::new(2)
            foreach ($menuDef in @(
                @{ Header="Abrir en pestana";          Tag="Open"      },
                @{ Header="Anadir marcador...";        Tag="Bookmark"  },
                @{ Header="Escanear IOCs en fichero";  Tag="IOC"       },
                @{ Header="-"; Tag="-" },
                @{ Header="Copiar ruta";               Tag="CopyPath"  },
                @{ Header="Abrir ubicacion";           Tag="Explorer"  }
            )) {
                if ($menuDef.Tag -eq "-") {
                    $cm.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null
                } else {
                    $mi = New-Object System.Windows.Controls.MenuItem
                    $mi.Header     = $menuDef.Header
                    $mi.Foreground = New-WpfBrush $Script:Colors.Text
                    $mi.Background = New-WpfBrush $Script:Colors.BgCard
                    $mi.FontSize   = 12
                    $mi.Tag        = [PSCustomObject]@{ Action=$menuDef.Tag; ItemTag=$item }
                    $mi.Add_Click({
                        param($s, $e)
                        $ctx  = $s.Tag
                        $path = $ctx.ItemTag.Tag -as [string]
                        if ([string]::IsNullOrEmpty($path)) { return }
                        switch ($ctx.Action) {
                            "Open"     { Open-FileInTab -FilePath $path }
                            "Bookmark" { Show-AddBookmarkDialog -FilePath $path }
                            "IOC"      { Invoke-SingleFileIOCScan -FilePath $path }
                            "CopyPath" { [System.Windows.Clipboard]::SetText($path) }
                            "Explorer" { Start-Process "explorer.exe" "/select,`"$path`"" }
                        }
                    })
                    $cm.Items.Add($mi) | Out-Null
                }
            }
            $item.ContextMenu = $cm
        }
    }

    $headerSP.Children.Add($iconTB) | Out-Null
    $headerSP.Children.Add($nameTB) | Out-Null
    $item.Header = $headerSP
    $item.Tag    = $Node.Path

    # Tooltip con tamano para ficheros
    if ($Node.NodeType -eq "File" -and $Node.Size -gt 0) {
        $item.ToolTip = "$($Node.Name)`n$(Format-FileSize $Node.Size)`n$($Node.Path)"
    }

    # Agregar hijos
    if ($Node.Children -and $Node.Children.Count -gt 0) {
        foreach ($child in $Node.Children) {
            $childItem = Add-TreeNode -Node $child -Control $null
            $item.Items.Add($childItem) | Out-Null
        }
    }

    if ($null -ne $Control) { $Control.Items.Add($item) | Out-Null }
    return $item
}

# ── Filtro del arbol ───────────────────────────────────────────────────

function Apply-TreeFilter {
    param([string]$Filter, [System.Windows.Controls.ItemsControl]$Container)

    $anyVisible = $false
    foreach ($item in $Container.Items) {
        $tvi = $item -as [System.Windows.Controls.TreeViewItem]
        if ($null -eq $tvi) { continue }

        $node = $tvi.Tag -as [string]
        $headerText = ""
        try {
            $sp = $tvi.Header -as [System.Windows.Controls.StackPanel]
            if ($sp) {
                $headerText = ($sp.Children | Where-Object { $_ -is [System.Windows.Controls.TextBlock] } |
                    Select-Object -Last 1).Text
            }
        } catch {}

        $childVisible = Apply-TreeFilter -Filter $Filter -Container $tvi
        $selfMatch    = [string]::IsNullOrEmpty($Filter) -or ($headerText -match [regex]::Escape($Filter))

        $tvi.Visibility = if ($selfMatch -or $childVisible) { 'Visible' } else { 'Collapsed' }
        if ($tvi.Visibility -eq 'Visible') { $anyVisible = $true }
        if ($childVisible -and -not [string]::IsNullOrEmpty($Filter)) { $tvi.IsExpanded = $true }
    }
    return $anyVisible
}

# ── Busqueda global (multi-formato) ────────────────────────────────────

function Invoke-GlobalSearch {
    param([string]$Query)
    if ([string]::IsNullOrWhiteSpace($Query)) { return }
    if ($null -eq $Script:CurrentProject) { Set-Status "Abre un proyecto para usar la busqueda global"; return }

    Set-Status "Buscando '$Query' en todo el proyecto..."

    $searchKey = "__search__$Query"
    if ($Script:OpenTabs.ContainsKey($searchKey)) {
        $Script:TNControls.TabsMain.Items.Remove($Script:OpenTabs[$searchKey])
        $Script:OpenTabs.Remove($searchKey)
    }

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    foreach ($h in @([System.Windows.GridLength]::Auto,
                     [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star),
                     [System.Windows.GridLength]::Auto)) {
        $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = $h
        $outer.RowDefinitions.Add($rd)
    }

    $banner = New-Object System.Windows.Controls.Border
    $banner.Background      = New-WpfBrush $Script:Colors.BgCard
    $banner.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $banner.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $banner.Padding         = [System.Windows.Thickness]::new(10,7,10,7)
    $bannerLbl = New-Object System.Windows.Controls.TextBlock
    $bannerLbl.Text       = "Busqueda: '$Query'  ·  Buscando en CSV, JSON, TXT, LOG..."
    $bannerLbl.Foreground = New-WpfBrush $Script:Colors.Text
    $bannerLbl.FontSize   = 12
    $banner.Child = $bannerLbl
    [System.Windows.Controls.Grid]::SetRow($banner, 0)
    $outer.Children.Add($banner) | Out-Null

    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly = $true; $dg.AutoGenerateColumns = $false
    $dg.SelectionMode = 'Extended'; $dg.SelectionUnit = 'FullRow'
    $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($dg, [System.Windows.Controls.VirtualizationMode]::Recycling)
    Apply-DataGridDarkTheme $dg
    Add-DataGridRowContextMenu -DG $dg -FilePath ($Script:CurrentProject.Path)
    foreach ($cd in @(
        @{ H="Tipo";     B="Tipo";      W=55  },
        @{ H="Fichero";  B="Fichero";   W=200 },
        @{ H="Linea";    B="Linea";     W=55  },
        @{ H="Contenido";B="Contenido"; W=600 }
    )) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header = $cd.H; $col.Binding = New-Object System.Windows.Data.Binding($cd.B); $col.Width = $cd.W
        $dg.Columns.Add($col) | Out-Null
    }
    [System.Windows.Controls.Grid]::SetRow($dg, 1)
    $outer.Children.Add($dg) | Out-Null

    # BUG CONFIRMADO: $dg es local a esta funcion (closure rota, igual que el
    # resto de bugs de este fichero) - usar $s (el sender, que WPF entrega
    # vivo en cada invocacion con independencia del scope de creacion) en vez
    # de la variable local capturada.
    $dg.Add_MouseDoubleClick({
        param($s, $e)
        $item = $s.SelectedItem -as [System.Data.DataRowView]
        if ($item) {
            $ruta = $item['Ruta'] -as [string]
            if ($ruta -and (Test-Path $ruta)) { Open-FileInTab -FilePath $ruta }
        }
    })

    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLbl = New-Object System.Windows.Controls.TextBlock
    $statusLbl.Text = "Buscando..."; $statusLbl.Foreground = New-WpfBrush $Script:Colors.TextMuted; $statusLbl.FontSize = 11
    $statusBar.Child = $statusLbl
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    $overlay = New-LoadingOverlay -Message "Buscando '$Query'..." -RowSpan 3
    $outer.Children.Add($overlay) | Out-Null

    # Abrir pestaña de búsqueda antes del resultado (UX inmediato)
    $tab = New-Object System.Windows.Controls.TabItem
    $headerParts = New-TabHeader -Title "Busqueda: $Query" -Icon "S"
    $tab.Header = $headerParts.Panel; $tab.Content = $outer
    $headerParts.CMTag.Key = $searchKey
    $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
    $Script:TNControls.TabsMain.SelectedItem = $tab
    $Script:OpenTabs[$searchKey] = $tab
    $headerParts.CloseBtn.Tag = $searchKey
    $headerParts.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
    Show-EmptyState $false

    # Background search
    $bgScript = {
        param($rootPath, $query)
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        $extensions = @("*.csv","*.json","*.txt","*.log","*.inf","*.xml")
        $files = @(Get-ChildItem $rootPath -Recurse -Include $extensions -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -lt 20MB -and $_.Length -gt 0 })
        $pattern = [regex]::Escape($query)
        foreach ($file in $files) {
            try {
                $hits = Select-String -Path $file.FullName -Pattern $pattern -CaseSensitive:$false -ErrorAction SilentlyContinue
                foreach ($m in $hits) {
                    $line = $m.Line.Trim()
                    if ($line.Length -gt 300) { $line = $line.Substring(0,300) + "..." }
                    $results.Add([PSCustomObject]@{
                        Tipo      = $file.Extension.TrimStart('.').ToUpper()
                        Fichero   = $file.Name
                        Linea     = $m.LineNumber
                        Contenido = $line
                        Ruta      = $file.FullName
                    }) | Out-Null
                }
            } catch {}
        }
        Write-Output -NoEnumerate ([PSCustomObject]@{ Results=$results; FileCount=$files.Count; Err="" })
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{ rootPath=$Script:CurrentProject.Path; query=$Query })
    $handle = $ps.BeginInvoke()

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $timer.Tag = [PSCustomObject]@{
        Ps=$ps; Handle=$handle; Rs=$rs; DG=$dg; Status=$statusLbl
        Banner=$bannerLbl; Overlay=$overlay; Query=$Query
    }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag
        if ($ctx.Ps.InvocationStateInfo.State -in 'Completed','Failed','Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                $tbl = [System.Data.DataTable]::new("Search")
                foreach ($c in @('Tipo','Fichero','Linea','Contenido','Ruta')) { [void]$tbl.Columns.Add($c,[string]) }
                if ($obj -and $obj.Results) {
                    foreach ($r in $obj.Results) {
                        $row = $tbl.NewRow()
                        $row['Tipo']=$r.Tipo; $row['Fichero']=$r.Fichero; $row['Linea']=$r.Linea.ToString()
                        $row['Contenido']=$r.Contenido; $row['Ruta']=$r.Ruta
                        [void]$tbl.Rows.Add($row)
                    }
                }
                $ctx.DG.Tag = $tbl; $ctx.DG.ItemsSource = $tbl.DefaultView
                $ctx.Banner.Text  = "Busqueda: '$($ctx.Query)'  ·  $($tbl.Rows.Count) resultados en $($obj.FileCount) ficheros (CSV, JSON, TXT, LOG)"
                $ctx.Status.Text  = "$($tbl.Rows.Count) coincidencias  ·  Doble clic para abrir el fichero"
                Set-Status "$($tbl.Rows.Count) resultados para '$($ctx.Query)'" ""
            } catch { $ctx.Status.Text = "Error: $($_.Exception.Message)" }
            finally {
                $ctx.Overlay.Visibility = 'Collapsed'
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
}

# ── Escaneo IOC de fichero individual ──────────────────────────────────

function Invoke-SingleFileIOCScan {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) { return }
    Set-Status "Escaneando IOCs: $([System.IO.Path]::GetFileName($FilePath))..."

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $patternMap = [ordered]@{
        'EncodedCmd'     = @{ Pattern=$Script:IOCPatterns.EncodedCmd;     Severity='Critical'; Label='Comando codificado'     }
        'SuspiciousPath' = @{ Pattern=$Script:IOCPatterns.SuspiciousPath; Severity='High';     Label='Ruta anomala'           }
        'SuspiciousExe'  = @{ Pattern=$Script:IOCPatterns.SuspiciousExe;  Severity='High';     Label='Ejecutable sospechoso'  }
        'IPv4External'   = @{ Pattern=$Script:IOCPatterns.IPv4External;   Severity='Info';     Label='IP Externa'             }
        'SHA256'         = @{ Pattern=$Script:IOCPatterns.SHA256;          Severity='Info';     Label='Hash SHA256'            }
    }
    try {
        $lines = [System.IO.File]::ReadAllLines($FilePath, [System.Text.Encoding]::UTF8)
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            foreach ($key in $patternMap.Keys) {
                $pm = $patternMap[$key]
                $m = [regex]::Match($line, $pm.Pattern)
                if ($m.Success) {
                    $ctx = $line.Trim(); if ($ctx.Length -gt 250) { $ctx = $ctx.Substring(0,250) }
                    $results.Add([PSCustomObject]@{
                        Severity = $pm.Severity; IOCType = $pm.Label
                        Fichero  = [System.IO.Path]::GetFileName($FilePath)
                        Linea    = $lineNum; Match = $m.Value.Substring(0,[Math]::Min($m.Value.Length,120))
                        Context  = $ctx; Ruta = $FilePath
                    }) | Out-Null
                    break
                }
            }
        }
    } catch {}

    if ($results.Count -eq 0) { Set-Status "Sin IOCs detectados en $([System.IO.Path]::GetFileName($FilePath))"; return }

    $tbl = ConvertTo-DataTable @($results)
    $scanKey = "__iocsingle__$FilePath"
    if ($Script:OpenTabs.ContainsKey($scanKey)) {
        $Script:TNControls.TabsMain.Items.Remove($Script:OpenTabs[$scanKey])
        $Script:OpenTabs.Remove($scanKey)
    }
    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    foreach ($h in @([System.Windows.GridLength]::Auto, [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star))) {
        $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = $h; $outer.RowDefinitions.Add($rd)
    }
    $bann = New-Object System.Windows.Controls.Border
    $bann.Background = New-WpfBrush $Script:Colors.BgCard
    $bann.BorderBrush = New-WpfBrush $Script:Colors.Border; $bann.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $bann.Padding = [System.Windows.Thickness]::new(10,7,10,7)
    $bLbl = New-Object System.Windows.Controls.TextBlock
    $bLbl.Text = "IOC: $([System.IO.Path]::GetFileName($FilePath))  ·  $($results.Count) hallazgos"
    $bLbl.Foreground = New-WpfBrush $Script:Colors.Text; $bLbl.FontSize = 12
    $bann.Child = $bLbl; [System.Windows.Controls.Grid]::SetRow($bann, 0); $outer.Children.Add($bann) | Out-Null
    $dg2 = New-Object System.Windows.Controls.DataGrid
    $dg2.IsReadOnly = $true; $dg2.AutoGenerateColumns = $true
    $dg2.SelectionMode = 'Extended'; $dg2.SelectionUnit = 'FullRow'
    # Ancho fijo en columnas auto-generadas - ver comentario extenso en
    # CSVViewer.ps1 (riesgo de crash de WPF con DataGridItemAttachedStorage).
    $dg2.Add_AutoGeneratingColumn({
        param($s, $e)
        $e.Column.Width = New-Object System.Windows.Controls.DataGridLength(160)
    })
    Apply-DataGridDarkTheme $dg2
    Add-DataGridRowContextMenu -DG $dg2 -FilePath $FilePath
    $dg2.ItemsSource = $tbl.DefaultView; $dg2.Tag = $tbl
    [System.Windows.Controls.Grid]::SetRow($dg2, 1); $outer.Children.Add($dg2) | Out-Null
    $tab = New-Object System.Windows.Controls.TabItem
    $hp = New-TabHeader -Title "IOC: $([System.IO.Path]::GetFileName($FilePath))" -Icon "!"
    $tab.Header = $hp.Panel; $tab.Content = $outer
    $hp.CMTag.Key = $scanKey
    $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
    $Script:TNControls.TabsMain.SelectedItem = $tab
    $Script:OpenTabs[$scanKey] = $tab
    $hp.CloseBtn.Tag = $scanKey
    $hp.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
    Show-EmptyState $false
    Set-Status "$($results.Count) IOCs en $([System.IO.Path]::GetFileName($FilePath))" ""
}

# ── Cambio de tema ────────────────────────────────────────────────────

function Switch-Theme {
    $openFiles  = @($Script:OpenTabs.Keys | Where-Object { -not $_.StartsWith('__') })
    $projPath   = if ($Script:CurrentProject) { $Script:CurrentProject.Path } else { $null }

    $Script:TN_RestoreState = [PSCustomObject]@{
        OpenFiles   = $openFiles
        ProjectPath = $projPath
    }

    $Script:OpenTabs       = @{}
    $Script:CurrentProject = $null
    $Script:Bookmarks      = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($Script:TN_Theme -eq 'Dark') {
        $Script:TN_Theme = 'Light'
        $Script:Colors   = $Script:ColorsLight
    } else {
        $Script:TN_Theme = 'Dark'
        $Script:Colors   = $Script:ColorsDark
    }

    $Script:TN_ThemeRestart = $true
    $Script:TNControls.Window.Close()
}

# ── Inicializar ventana ────────────────────────────────────────────────

function Initialize-MainWindow {
    param([System.Windows.Window]$Window)

    # Recopilar controles nombrados
    $Script:TNControls = @{
        Window               = $Window
        BtnOpenProject       = $Window.FindName('BtnOpenProject')
        BtnOpenFile          = $Window.FindName('BtnOpenFile')
        BtnGlobalSearch      = $Window.FindName('BtnGlobalSearch')
        TxtGlobalSearch      = $Window.FindName('TxtGlobalSearch')
        TxtProjectLabel      = $Window.FindName('TxtProjectLabel')
        ProjectTree          = $Window.FindName('ProjectTree')
        TxtTreeFilter        = $Window.FindName('TxtTreeFilter')
        TabsMain             = $Window.FindName('TabsMain')
        GridEmptyState       = $Window.FindName('GridEmptyState')
        PanelLeft            = $Window.FindName('PanelLeft')
        StatusLeft           = $Window.FindName('TxtStatusLeft')
        StatusRight          = $Window.FindName('TxtStatusRight')
        MenuOpenProject      = $Window.FindName('MenuOpenProject')
        MenuOpenFile         = $Window.FindName('MenuOpenFile')
        MenuCloseAll         = $Window.FindName('MenuCloseAll')
        MenuToggleTree       = $Window.FindName('MenuToggleTree')
        MenuRefresh          = $Window.FindName('MenuRefresh')
        MenuExit             = $Window.FindName('MenuExit')
        MenuAbout            = $Window.FindName('MenuAbout')
        MenuIOCScan          = $Window.FindName('MenuIOCScan')
        MenuTimeline         = $Window.FindName('MenuTimeline')
        MenuBookmarks        = $Window.FindName('MenuBookmarks')
        MenuGlobalSearchAll  = $Window.FindName('MenuGlobalSearchAll')
        BtnEmptyProject      = $Window.FindName('BtnEmptyProject')
        BtnEmptyFile         = $Window.FindName('BtnEmptyFile')
        BtnThemeToggle       = $Window.FindName('BtnThemeToggle')
        TxtThemeIcon         = $Window.FindName('TxtThemeIcon')
    }

    $ctrl = $Script:TNControls

    # ── Override de colores de selección del TreeView ────────────────
    # {x:Static SystemColors.*BrushKey} en XamlReader resuelve a null; se hace en código.
    try {
        $hk  = [System.Windows.SystemColors]::HighlightBrushKey
        $htk = [System.Windows.SystemColors]::HighlightTextBrushKey
        $ik  = [System.Windows.SystemColors]::InactiveSelectionHighlightBrushKey
        $itk = [System.Windows.SystemColors]::InactiveSelectionHighlightTextBrushKey
        if ($hk)  { $ctrl.ProjectTree.Resources.Add($hk,  (New-WpfBrush $Script:Colors.SelectionBg)) }
        if ($htk) { $ctrl.ProjectTree.Resources.Add($htk, (New-WpfBrush $Script:Colors.SelectionFg)) }
        if ($ik)  { $ctrl.ProjectTree.Resources.Add($ik,  (New-WpfBrush $Script:Colors.BgSurface))   }
        if ($itk) { $ctrl.ProjectTree.Resources.Add($itk, (New-WpfBrush $Script:Colors.Text))         }
    } catch {}

    # ── Tema: icono inicial y click ──────────────────────────────────
    if ($ctrl.TxtThemeIcon) {
        $ctrl.TxtThemeIcon.Text = if ($Script:TN_Theme -eq 'Dark') { [char]0x2600 } else { [char]0x263D }
    }
    if ($ctrl.BtnThemeToggle) {
        $ctrl.BtnThemeToggle.Add_Click({ Switch-Theme })
    }

    # ── Eventos de botones y menus ──────────────────────────────────

    $openProjectAction = {
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Selecciona el directorio de salida de MaPeriT.SW o MaPeriT.OF"
        if ($dlg.ShowDialog() -eq 'OK') {
            $path = $dlg.SelectedPath
            if (Test-MaPeriTProject $path) {
                Load-ProjectTree -ProjectPath $path
            } else {
                [System.Windows.MessageBox]::Show(
                    "El directorio seleccionado no parece un proyecto de MaPeriT.SW ni de MaPeriT.OF`n`n$path",
                    "MaPeriT.TN", 'OK', 'Warning')
            }
        }
    }

    $openFileAction = {
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Filter = "Todos los soportados|*.csv;*.json;*.evtx;*.log;*.txt;*.html;*.xml;*.bin;*.dat;*.hve|CSV|*.csv|JSON|*.json|EVTX|*.evtx|Texto|*.log;*.txt;*.inf|Todos|*.*"
        $dlg.Title  = "Abrir archivo"
        if ($dlg.ShowDialog() -eq $true) {
            Open-FileInTab -FilePath $dlg.FileName
        }
    }

    $ctrl.BtnOpenProject.Add_Click($openProjectAction)
    $ctrl.BtnOpenFile.Add_Click($openFileAction)
    $ctrl.BtnEmptyProject.Add_Click($openProjectAction)
    $ctrl.BtnEmptyFile.Add_Click($openFileAction)
    $ctrl.MenuOpenProject.Add_Click($openProjectAction)
    $ctrl.MenuOpenFile.Add_Click($openFileAction)

    $ctrl.MenuCloseAll.Add_Click({ Close-AllTabs })

    # BUG CONFIRMADO (verificado empiricamente): $ctrl y $Window son variables
    # LOCALES de Initialize-MainWindow. Estos scriptblocks se invocan tras
    # ShowDialog(), cuando la funcion ya ha retornado y esas variables locales
    # ya no existen en la cadena de scopes - se resuelven a $null sin ningun
    # error visible (el "Salir" no cerraba, el toggle del arbol no hacia nada).
    # $Script:TNControls SI sobrevive porque es scope de script, no de funcion.
    $ctrl.MenuExit.Add_Click({ $Script:TNControls.Window.Close() })

    $ctrl.MenuToggleTree.Add_Click({
        $Script:TNControls.PanelLeft.Visibility = if ($Script:TNControls.MenuToggleTree.IsChecked) { 'Visible' } else { 'Collapsed' }
    })

    $ctrl.MenuRefresh.Add_Click({
        if ($Script:CurrentProject) { Load-ProjectTree -ProjectPath $Script:CurrentProject.Path }
    })

    $ctrl.MenuAbout.Add_Click({
        [System.Windows.MessageBox]::Show(
            "MaPeriT.TN v$($Script:TN_Version)`n`nVisor Forense del Ecosistema MaPeriT`nParte del proyecto MaPeriT de Peritacion Informatica Forense`n`nCompatible con proyectos MaPeriT.SW, MaPeriT.OF y MaPeriT.AN",
            "Acerca de MaPeriT.TN", 'OK', 'Information')
    })

    # ── Modulos de Analisis ──────────────────────────────────────────

    if ($ctrl.MenuIOCScan) {
        $ctrl.MenuIOCScan.Add_Click({
            if ($null -eq $Script:CurrentProject) { Set-Status "Abre un proyecto para escanear IOCs"; return }
            $key = "__iocscan__project"
            if ($Script:OpenTabs.ContainsKey($key)) {
                $Script:TNControls.TabsMain.SelectedItem = $Script:OpenTabs[$key]; return
            }
            $content = New-IOCScanViewerContent -ProjectPath $Script:CurrentProject.Path
            $tab = New-Object System.Windows.Controls.TabItem
            $hp = New-TabHeader -Title "IOC: Proyecto" -Icon "!"
            $tab.Header = $hp.Panel; $tab.Content = $content
            $hp.CMTag.Key = $key
            $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
            $Script:TNControls.TabsMain.SelectedItem = $tab
            $Script:OpenTabs[$key] = $tab
            $hp.CloseBtn.Tag = $key
            $hp.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
            Show-EmptyState $false
        })
    }

    if ($ctrl.MenuTimeline) {
        $ctrl.MenuTimeline.Add_Click({
            if ($null -eq $Script:CurrentProject) { Set-Status "Abre un proyecto para ver la timeline"; return }
            $key = "__timeline__project"
            if ($Script:OpenTabs.ContainsKey($key)) {
                $Script:TNControls.TabsMain.SelectedItem = $Script:OpenTabs[$key]; return
            }
            $content = New-TimelineViewerContent -ProjectPath $Script:CurrentProject.Path
            $tab = New-Object System.Windows.Controls.TabItem
            $hp = New-TabHeader -Title "Timeline" -Icon "T"
            $tab.Header = $hp.Panel; $tab.Content = $content
            $hp.CMTag.Key = $key
            $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
            $Script:TNControls.TabsMain.SelectedItem = $tab
            $Script:OpenTabs[$key] = $tab
            $hp.CloseBtn.Tag = $key
            $hp.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
            Show-EmptyState $false
        })
    }

    if ($ctrl.MenuBookmarks) {
        $ctrl.MenuBookmarks.Add_Click({
            try {
                $key = "__bookmarks__"
                if ($Script:OpenTabs.ContainsKey($key)) {
                    $Script:TNControls.TabsMain.Items.Remove($Script:OpenTabs[$key])
                    $Script:OpenTabs.Remove($key)
                }
                $content = New-BookmarksPanelContent
                $tab = New-Object System.Windows.Controls.TabItem
                $hp = New-TabHeader -Title "Marcadores" -Icon "B"
                $tab.Header = $hp.Panel; $tab.Content = $content
                $hp.CMTag.Key = $key
                $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
                $Script:TNControls.TabsMain.SelectedItem = $tab
                $Script:OpenTabs[$key] = $tab
                $hp.CloseBtn.Tag = $key
                $hp.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
                Show-EmptyState $false
                Set-Status "$($Script:Bookmarks.Count) marcadores" ""
            } catch {
                Set-Status "Error al abrir marcadores: $($_.Exception.Message)" ""
            }
        })
    }

    if ($ctrl.MenuGlobalSearchAll) {
        $ctrl.MenuGlobalSearchAll.Add_Click({
            if ($null -eq $Script:CurrentProject) { Set-Status "Abre un proyecto para buscar"; return }
            $query = [Microsoft.VisualBasic.Interaction]::InputBox("Texto a buscar:", "Busqueda global", "")
            if (-not [string]::IsNullOrWhiteSpace($query)) { Invoke-GlobalSearch -Query $query }
        })
    }

    # Busqueda global (mismo bug de closure: $ctrl local no sobrevive al retorno de la funcion)
    $ctrl.BtnGlobalSearch.Add_Click({
        Invoke-GlobalSearch -Query $Script:TNControls.TxtGlobalSearch.Text.Trim()
    })
    $ctrl.TxtGlobalSearch.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq 'Return') { Invoke-GlobalSearch -Query $s.Text.Trim() }
    })

    # Filtro del arbol (mismo bug de closure)
    $ctrl.TxtTreeFilter.Add_TextChanged({
        param($s, $e)
        Apply-TreeFilter -Filter $s.Text.Trim() -Container $Script:TNControls.ProjectTree
    })

    # Atajos de teclado globales (mismo bug de closure: $ctrl local no sobrevive)
    $Window.Add_KeyDown({
        param($s, $e)
        $mods = [System.Windows.Input.Keyboard]::Modifiers
        $tc = $Script:TNControls
        switch ($e.Key) {
            'W' {
                if ($mods -band 'Control') {
                    $selectedTab = $tc.TabsMain.SelectedItem -as [System.Windows.Controls.TabItem]
                    if ($selectedTab) {
                        $pathToClose = $Script:OpenTabs.Keys | Where-Object { $Script:OpenTabs[$_] -eq $selectedTab } | Select-Object -First 1
                        if ($pathToClose) { Close-Tab $pathToClose }
                    }
                    $e.Handled = $true
                }
            }
            'F' {
                if ($mods -band 'Control') {
                    $tc.TxtGlobalSearch.Focus()
                    $tc.TxtGlobalSearch.SelectAll()
                    $e.Handled = $true
                }
            }
            'T' {
                if ($mods -band 'Control') {
                    if ($Script:CurrentProject) {
                        $key = "__timeline__project"
                        if ($Script:OpenTabs.ContainsKey($key)) { $tc.TabsMain.SelectedItem = $Script:OpenTabs[$key] }
                        else { $tc.MenuTimeline.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent)) }
                    }
                    $e.Handled = $true
                }
            }
            'I' {
                if ($mods -band 'Control') {
                    if ($Script:CurrentProject) {
                        $key = "__iocscan__project"
                        if ($Script:OpenTabs.ContainsKey($key)) { $tc.TabsMain.SelectedItem = $Script:OpenTabs[$key] }
                        else { $tc.MenuIOCScan.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent)) }
                    }
                    $e.Handled = $true
                }
            }
        }
    })

    # Dark title bar + restauracion de estado tras cambio de tema
    $Window.Add_Loaded({
        Set-DarkTitleBar $Window

        if ($null -ne $Script:TN_RestoreState) {
            $state = $Script:TN_RestoreState
            $Script:TN_RestoreState = $null

            if (-not [string]::IsNullOrEmpty($state.ProjectPath) -and (Test-Path $state.ProjectPath)) {
                Load-ProjectTree -ProjectPath $state.ProjectPath
            }
            foreach ($fp in $state.OpenFiles) {
                if (Test-Path $fp) { Open-FileInTab -FilePath $fp }
            }
        }
    })

    Set-Status "Listo  ·  MaPeriT.TN v$($Script:TN_Version)" ""
}

#endregion
#endregion

#region ===== src\Main.ps1 =====
#region ============================================================
# MaPeriT.TN - PUNTO DE ENTRADA
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

# Inicializar assemblies WPF (una sola vez)
try {
    Initialize-TNApplication
} catch {
    Write-Host "  [ERROR] No se pudieron cargar los assemblies WPF: $_" -ForegroundColor Red
    Write-Host "  Requiere PowerShell 5.1+ en Windows." -ForegroundColor Yellow
    exit 1
}

# Red de seguridad global: cualquier excepcion no controlada que escape de un
# manejador de evento WPF (click, doble clic, etc.) se propaga en algunos
# casos como STATUS_FATAL_USER_CALLBACK_EXCEPTION y Windows mata el proceso
# entero sin posibilidad de recuperacion - la aplicacion desaparece sin
# ningun dialogo, perdiendo la sesion de trabajo del perito (pestañas
# abiertas, marcadores no guardados). No existia ningun manejador de este
# tipo en MaPeriT.TN (confirmado en auditoria). Se registra antes de mostrar
# cualquier ventana; el mismo Dispatcher persiste durante todo el bucle de
# reinicio por cambio de tema, asi que basta con registrarlo una vez aqui.
[System.Windows.Threading.Dispatcher]::CurrentDispatcher.add_UnhandledException({
    param($sender, $e)
    Write-Host "  [AVISO] Error interno no fatal capturado: $($e.Exception.Message)" -ForegroundColor Yellow
    $e.Handled = $true
})

do {
    $Script:TN_ThemeRestart = $false

    # Parsear XAML con el tema activo
    try {
        $reader = [System.Xml.XmlReader]::Create(
            [System.IO.StringReader]::new((Get-TNMainWindowXAML))
        )
        $Window = [System.Windows.Markup.XamlReader]::Load($reader)
    } catch {
        Write-Host "  [ERROR] Error al parsear XAML: $_" -ForegroundColor Red
        exit 1
    }

    # Inicializar logica de la ventana
    Initialize-MainWindow -Window $Window

    # Abrir proyecto o fichero pasado por parametro (solo en el primer arranque)
    if ($null -eq $Script:TN_RestoreState) {
        if (-not [string]::IsNullOrEmpty($ProjectPath) -and (Test-Path $ProjectPath)) {
            $Window.Add_ContentRendered({
                if (Test-MaPeriTProject $ProjectPath) {
                    Load-ProjectTree -ProjectPath $ProjectPath
                } else {
                    Open-FileInTab -FilePath $ProjectPath
                }
            })
        } elseif (-not [string]::IsNullOrEmpty($OpenFile) -and (Test-Path $OpenFile)) {
            $Window.Add_ContentRendered({
                Open-FileInTab -FilePath $OpenFile
            })
        }
    }

    # Mostrar ventana (bloqueante)
    [void]$Window.ShowDialog()

} while ($Script:TN_ThemeRestart)

#endregion
#endregion

