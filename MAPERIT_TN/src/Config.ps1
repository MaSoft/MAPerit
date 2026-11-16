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
