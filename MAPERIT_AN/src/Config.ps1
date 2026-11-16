#region ============================================================
# MaPeriT.AN - CONFIGURACION GLOBAL
# ============================================================

$Script:AN_NAME    = "MaPeriT.AN"
$Script:AN_VERSION = "1.2.1"
$Script:AN_FULL    = "MaPeriT.AN - Analizador Forense Offline Profundo"

# --- Estructura de carpetas esperada de MaPeriT.SW ---
$Script:SW_Dirs = @{
    Volatile    = "01_Volatile"
    SystemInfo  = "02_SystemInfo"
    Filesystem  = "03_Filesystem"
    Registry    = "04_Registry"
    EventLogs   = "05_EventLogs"
    Browsers    = "06_Browsers"
    Comms       = "07_Communications"
    Cloud       = "08_CloudStorage"
    USB         = "09_USB"
    Persistence = "10_Persistence"
    Analysis    = "Analysis"
    Logs        = "Logs"
    Report      = "Report"
}

# --- Estructura de salida de AN ---
$Script:AN_Dirs = @{
    MFT       = "MFT"
    EVTX      = "EVTX"
    Browsers  = "Browsers"
    Report    = "Report"
    Logs      = "Logs"
}

# --- Event IDs de interes agrupados por categoria ---
$Script:EventIDs = @{
    Logon = @(4624, 4625, 4634, 4647, 4648, 4672, 4778, 4779)
    AccountMgmt = @(4720, 4722, 4723, 4724, 4725, 4726, 4728, 4732, 4733, 4735, 4738, 4740, 4756)
    Process = @(4688, 4689)
    Services = @(7034, 7035, 7036, 7040, 7045)
    Scheduled = @(106, 140, 141, 200, 201, 4698, 4702, 4699)
    PowerShell = @(4103, 4104, 4105, 4106, 400, 403, 600)
    AuditLog = @(1100, 1102, 1104)
    System = @(6005, 6006, 6008, 41)
    WMI = @(5857, 5858, 5859, 5860, 5861)
    Network = @(5140, 5142, 5145)
    Defender = @(1116, 1117, 1118, 1119, 5001, 5004)
    RemoteAccess = @(20, 25, 131, 1149, 4624)
}

# --- Logon types ---
$Script:LogonTypes = @{
    2  = "Interactive"
    3  = "Network"
    4  = "Batch"
    5  = "Service"
    7  = "Unlock"
    8  = "NetworkCleartext"
    9  = "NewCredentials"
    10 = "RemoteInteractive (RDP)"
    11 = "CachedInteractive"
    12 = "CachedRemoteInteractive"
    13 = "CachedUnlock"
}

# --- Namespaces de atributo $FILE_NAME en NTFS ---
$Script:MFT_Namespaces = @{ 0 = "POSIX"; 1 = "Win32"; 2 = "DOS"; 3 = "Win32&DOS" }

# --- Umbral de timestomping (segundos de tolerancia) ---
$Script:TimestompThreshold = 2

# --- Ficheros SQLite de navegadores (dentro de la carpeta copiada) ---
$Script:BrowserSQLiteFiles = @{
    Chrome_History   = "History"
    Edge_History     = "History"
    Brave_History    = "History"
    Firefox_History  = "places.sqlite"
    Firefox_Forms    = "formhistory.sqlite"
}

# --- Sesion AN ---
$Script:ANSession = @{
    StartTime    = $null
    EndTime      = $null
    EvidencePath = ""
    OutputPath   = ""
    ExaminerName = ""
    SWCaseNumber = ""
    SWExaminer   = ""
    SWToolHash   = ""
    MFTRecords   = 0
    MFTTimestomped = 0
    MFTDeleted   = 0
    EVTXEvents   = 0
    BrowserURLs  = 0
    Errors       = 0
    Warnings     = 0
}
