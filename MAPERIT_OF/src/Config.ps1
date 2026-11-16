#region ============================================================
# MaPeriT.OF - CONFIGURACION GLOBAL
# ============================================================

$Script:TOOL_NAME    = "MaPeriT.OF"
$Script:TOOL_VERSION = "1.1.2"
$Script:TOOL_FULL    = "MaPeriT.OF - Adquisicion Forense Offline Profesional"

# --- Nombres de fases (Phase 1 no aplica en offline) ---
$Script:PhaseNames = @{
    2  = "Informacion del Sistema"
    3  = "Artefactos del Sistema de Ficheros"
    4  = "Registro de Windows"
    5  = "Logs de Eventos"
    6  = "Navegadores Web"
    7  = "Comunicaciones"
    8  = "Almacenamiento en la Nube"
    9  = "Dispositivos USB/Externos"
    10 = "Mecanismos de Persistencia"
}

# --- Estructura de directorios de salida (IDENTICA a SW para compatibilidad con AN) ---
$Script:OutputDirs = @{
    Volatile       = "01_Volatile"
    SystemInfo     = "02_SystemInfo"
    Filesystem     = "03_Filesystem"
    Registry       = "04_Registry"
    EventLogs      = "05_EventLogs"
    Browsers       = "06_Browsers"
    Communications = "07_Communications"
    CloudStorage   = "08_CloudStorage"
    USB            = "09_USB"
    Persistence    = "10_Persistence"
    Analysis       = "Analysis"
    Report         = "Report"
    Logs           = "Logs"
}

# --- Rutas relativas al disco objetivo (se combinan con $Script:TargetRoot en runtime) ---
$Script:TargetPaths = @{
    Windows       = "Windows"
    System32      = "Windows\System32"
    Config        = "Windows\System32\config"
    EventLogs     = "Windows\System32\winevt\Logs"
    Tasks         = "Windows\System32\Tasks"
    Prefetch      = "Windows\Prefetch"
    Users         = "Users"
}

# --- Hives del registro en el disco objetivo ---
$Script:HiveFiles = @{
    SYSTEM   = "Windows\System32\config\SYSTEM"
    SOFTWARE = "Windows\System32\config\SOFTWARE"
    SAM      = "Windows\System32\config\SAM"
    SECURITY = "Windows\System32\config\SECURITY"
    NTUSER   = "NTUSER.DAT"
    UsrClass = "AppData\Local\Microsoft\Windows\UsrClass.dat"
}

# --- Rutas de perfiles de navegadores (relativas al perfil de usuario) ---
$Script:BrowserPaths = @{
    Chrome  = "AppData\Local\Google\Chrome\User Data"
    Edge    = "AppData\Local\Microsoft\Edge\User Data"
    Brave   = "AppData\Local\BraveSoftware\Brave-Browser\User Data"
    Firefox = "AppData\Roaming\Mozilla\Firefox\Profiles"
    IE      = "AppData\Local\Microsoft\Windows\WebCache"
}

# --- Ficheros de navegadores Chromium ---
$Script:ChromiumFiles = @(
    "History", "Downloads", "Cookies", "Login Data", "Preferences",
    "Bookmarks", "Web Data", "Top Sites", "Shortcuts", "Favicons",
    "Network\Cookies"   # ubicacion de las cookies desde Chrome/Edge 96
)

# --- Ficheros de Firefox ---
$Script:FirefoxFiles = @(
    "places.sqlite", "cookies.sqlite", "formhistory.sqlite",
    "logins.json", "key4.db", "cert9.db", "extensions.json",
    "webappsstore.sqlite", "favicons.sqlite", "permissions.sqlite"
)

# --- Rutas de comunicaciones (relativas al perfil de usuario) ---
$Script:CommunicationPaths = @{
    OutlookOST    = "AppData\Local\Microsoft\Outlook"
    OutlookPST    = "Documents\Outlook Files"
    TeamsNew      = "AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache"
    TeamsClassic  = "AppData\Roaming\Microsoft\Teams"
    Skype         = "AppData\Roaming\Microsoft\Skype for Desktop"
    Discord       = "AppData\Roaming\discord"
}

# --- Rutas de almacenamiento en la nube (relativas al perfil de usuario) ---
$Script:CloudPaths = @{
    OneDriveLogs     = "AppData\Local\Microsoft\OneDrive\logs"
    OneDriveSettings = "AppData\Local\Microsoft\OneDrive\settings"
    GoogleDrive      = "AppData\Local\Google\DriveFS"
    Dropbox          = "AppData\Local\Dropbox"
    DropboxInfo      = "AppData\Roaming\Dropbox"
}

# --- Perfiles de usuario del sistema a excluir ---
# "Administrator" ya NO se excluye (v1.1.2): es una cuenta real e investigable
# (el administrador integrado) y antes su perfil se omitia en silencio.
$Script:ExcludedProfiles = @(
    "Public", "Default", "Default User", "All Users",
    "defaultuser0", "TEMP"
)

# --- Defaults ---
$Script:Defaults = @{
    LargeFileThresholdMB = 500
    PhaseTimeoutMinutes  = 15
    HashAlgorithm        = "SHA256"
    CSVDelimiter         = ","
    DateFormat           = "yyyy-MM-dd HH:mm:ss.fff"
    DateFormatShort      = "yyyy-MM-dd HH:mm:ss"
    TimeZoneFormat       = "yyyy-MM-dd HH:mm:ss zzz"
    MaxEvtxFiles         = 200
}

# --- Sesion OF (rellenada en Initialize) ---
$Script:OFSession = @{
    StartTime         = $null
    EndTime           = $null
    TargetDisk        = ""
    TargetRoot        = ""
    CaseNumber        = ""
    ExaminerName      = ""
    OutputPath        = ""
    ScriptPath        = ""
    ScriptHash        = ""
    TargetOS          = "DESCONOCIDO"
    TargetComputer    = "DESCONOCIDO"
    DetectedUsers     = @()
    ProcessedUsers    = @()
    TotalFiles        = 0
    TotalSizeBytes    = 0
    Errors            = 0
    Warnings          = 0
    PhasesSkipped     = @()
    PhasesFailed      = @()
}

# --- Variable global: ruta raiz del disco objetivo (se define en Initialize) ---
$Script:TargetRoot = ""

# --- Variables para hives cargados (se limpian al finalizar) ---
$Script:LoadedHives = [System.Collections.Generic.Dictionary[string,string]]::new()
# Carpeta temporal con la copia de trabajo de cada hive cargado (clave de registro -> carpeta)
$Script:HiveWorkCopies = [System.Collections.Generic.Dictionary[string,string]]::new()

# --- Banner ---
$Script:Banner = @"

  ╔═══════════════════════════════════════════════════════════════════╗
  ║                                                                   ║
  ║      ███╗   ███╗ █████╗ ██████╗ ███████╗██████╗ ██╗████████╗     ║
  ║      ████╗ ████║██╔══██╗██╔══██╗██╔════╝██╔══██╗██║╚══██╔══╝     ║
  ║      ██╔████╔██║███████║██████╔╝█████╗  ██████╔╝██║   ██║        ║
  ║      ██║╚██╔╝██║██╔══██║██╔═══╝ ██╔══╝  ██╔══██╗██║   ██║        ║
  ║      ██║ ╚═╝ ██║██║  ██║██║     ███████╗██║  ██║██║   ██║        ║
  ║      ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝   ╚═╝  .OF  ║
  ║                                                                   ║
  ║          Adquisicion Forense Offline Profesional                  ║
  ║                       v{VERSION}                                      ║
  ║                                                                   ║
  ╚═══════════════════════════════════════════════════════════════════╝

"@
