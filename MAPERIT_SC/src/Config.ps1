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
