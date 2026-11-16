#region ============================================================
# MaPeriT.SW - CONFIGURACIÓN GLOBAL
# Constantes, textos en español, tablas de referencia
# ============================================================

$Script:TOOL_NAME    = "MaPeriT.SW"
$Script:TOOL_VERSION = "1.7.5"
$Script:TOOL_FULL    = "MaPeriT.SW - Herramienta de Peritacion Informatica Forense Profesional"
$Script:TOOL_AUTHOR  = "MaPeriT.SW Project"
$Script:MIN_PS_VER   = [version]"5.1"

# --- Nombres de fases ---
$Script:PhaseNames = @{
    1  = "Datos Volatiles"
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

# --- Estructura de directorios de salida ---
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

# --- Event IDs de seguridad relevantes ---
$Script:SecurityEventIDs = @{
    LogonSuccess        = @(4624)
    LogonFailed         = @(4625)
    Logoff              = @(4634, 4647)
    ExplicitCredentials = @(4648)
    SpecialPrivileges   = @(4672)
    PrivilegeUse        = @(4673)
    AccountCreated      = @(4720)
    AccountEnabled      = @(4722)
    PasswordChange      = @(4723, 4724)
    AccountDisabled     = @(4725)
    AccountDeleted      = @(4726)
    AccountChanged      = @(4738)
    AccountLocked       = @(4740)
    AuditPolicyChange   = @(4719)
    ObjectAccess        = @(4663)
}

$Script:SystemEventIDs = @{
    ServiceCrash       = @(7034)
    ServiceControl     = @(7035, 7036)
    ServiceStartChange = @(7040)
    ServiceInstalled   = @(7045)
    ShutdownInitiated  = @(1074)
    EventLogStarted    = @(6005)
    EventLogStopped    = @(6006)
    UnexpectedShutdown = @(6008)
    SystemBoot         = @(6009)
}

$Script:AppEventIDs = @{
    AppCrash  = @(1000)
    WER       = @(1001)
    AppHang   = @(1002)
}

$Script:PowerShellEventIDs = @{
    ScriptBlock = @(4104)
    ModuleLog   = @(4103)
}

$Script:TaskSchedulerEventIDs = @{
    TaskRegistered = @(106)
    TaskUpdated    = @(140)
    TaskDeleted    = @(141)
    TaskStarted    = @(200)
    TaskCompleted  = @(201)
}

$Script:RDPEventIDs = @{
    SessionLogon      = @(21)
    ShellStart        = @(22)
    SessionLogoff     = @(23)
    SessionDisconnect = @(24)
    SessionReconnect  = @(25)
}

# --- Tipos de Logon (Event 4624) ---
$Script:LogonTypes = @{
    2  = "Interactivo (local)"
    3  = "Red"
    4  = "Batch"
    5  = "Servicio"
    7  = "Desbloqueo"
    8  = "Red (texto claro)"
    9  = "Credenciales nuevas"
    10 = "Escritorio Remoto (RDP)"
    11 = "Cached interactivo"
    12 = "Cached remoto"
    13 = "Cached desbloqueo"
}

# --- Rutas de registro clave ---
$Script:RegistryPaths = @{
    USBSTOR          = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
    USB              = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB"
    MountedDevices   = "HKLM:\SYSTEM\MountedDevices"
    NetworkList      = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles"
    NetworkSigs      = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures"
    NetworkInterfaces= "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    RunHKLM          = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    RunOnceHKLM      = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    RunHKCU          = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    RunOnceHKCU      = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    PoliciesRun      = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"
    Winlogon         = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    UninstallHKLM    = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    UninstallWow64   = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    UninstallHKCU    = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    AppCompatCache   = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache"
    BAM              = "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
    DAM              = "HKLM:\SYSTEM\CurrentControlSet\Services\dam\State\UserSettings"
    ShutdownTime     = "HKLM:\SYSTEM\CurrentControlSet\Control\Windows"
    TimeZone         = "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation"
    RDPClientDefault = "HKCU:\Software\Microsoft\Terminal Server Client\Default"
    RDPClientServers = "HKCU:\Software\Microsoft\Terminal Server Client\Servers"
    LastLoggedOn     = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
    UserAssist       = "Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
    RecentDocs       = "Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs"
    RunMRU           = "Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
    TypedPaths       = "Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"
    TypedURLs        = "Software\Microsoft\Internet Explorer\TypedURLs"
    MountPoints2     = "Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2"
    ComDlg32MRU      = "Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU"
    Shellbags        = "Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU"
}

# --- Rutas de perfiles de navegadores ---
$Script:BrowserPaths = @{
    Chrome  = "AppData\Local\Google\Chrome\User Data"
    Edge    = "AppData\Local\Microsoft\Edge\User Data"
    Brave   = "AppData\Local\BraveSoftware\Brave-Browser\User Data"
    Firefox = "AppData\Roaming\Mozilla\Firefox\Profiles"
    IE      = "AppData\Local\Microsoft\Windows\WebCache"
}

# --- Ficheros de navegadores Chromium a recopilar ---
$Script:ChromiumFiles = @(
    "History", "Downloads", "Cookies", "Login Data", "Preferences",
    "Bookmarks", "Web Data", "Top Sites", "Shortcuts", "Favicons",
    "Network Action Predictor",
    "Network\Cookies"   # ubicacion de las cookies desde Chrome/Edge 96
)

# --- Ficheros de Firefox a recopilar ---
$Script:FirefoxFiles = @(
    "places.sqlite", "cookies.sqlite", "formhistory.sqlite",
    "logins.json", "key4.db", "cert9.db", "extensions.json",
    "webappsstore.sqlite", "favicons.sqlite", "permissions.sqlite"
)

# --- Rutas de comunicaciones ---
$Script:CommunicationPaths = @{
    OutlookOST     = "AppData\Local\Microsoft\Outlook"
    OutlookPST     = "Documents\Outlook Files"
    TeamsNew        = "AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache"
    TeamsClassic    = "AppData\Roaming\Microsoft\Teams"
    Skype           = "AppData\Roaming\Microsoft\Skype for Desktop"
    Discord         = "AppData\Roaming\discord"
}

# --- Rutas de almacenamiento en la nube ---
$Script:CloudPaths = @{
    OneDriveLogs    = "AppData\Local\Microsoft\OneDrive\logs"
    OneDriveSettings= "AppData\Local\Microsoft\OneDrive\settings"
    GoogleDrive     = "AppData\Local\Google\DriveFS"
    Dropbox         = "AppData\Local\Dropbox"
    DropboxInfo     = "AppData\Roaming\Dropbox"
}

# --- Severidad de anomalias ---
$Script:AnomalySeverity = @{
    Critical = "CRITICA"
    High     = "ALTA"
    Medium   = "MEDIA"
    Low      = "BAJA"
    Info     = "INFORMATIVA"
}

# --- Textos del informe en espanol ---
$Script:ReportStrings = @{
    Title              = "INFORME PERICIAL INFORMATICO FORENSE"
    Subtitle           = "Analisis Forense Digital"
    Confidential       = "CONFIDENCIAL - DOCUMENTO PERICIAL"
    TOC                = "INDICE"
    ExecutiveSummary   = "RESUMEN EJECUTIVO"
    Methodology        = "METODOLOGIA"
    MethodologyText    = "El presente analisis forense se ha realizado siguiendo las directrices establecidas en la RFC 3227 (Guidelines for Evidence Collection and Archiving) del IETF y la guia NIST SP 800-86 (Guide to Integrating Forensic Techniques into Incident Response). La adquisicion de evidencias se ha efectuado respetando el orden de volatilidad establecido en la RFC 3227, priorizando la captura de datos volatiles antes de proceder con los datos persistentes. Todas las evidencias han sido verificadas mediante hash SHA-256 para garantizar su integridad."
    ChainOfCustody     = "CADENA DE CUSTODIA"
    SystemID           = "IDENTIFICACION DEL SISTEMA"
    CollectedEvidence  = "EVIDENCIAS RECOPILADAS"
    Findings           = "HALLAZGOS"
    Timeline           = "LINEA TEMPORAL"
    Anomalies          = "ANOMALIAS DETECTADAS"
    Conclusions        = "CONCLUSIONES"
    Appendices         = "ANEXOS"
    AppendixHashes     = "Anexo A: Manifiesto de Hashes"
    AppendixProcesses  = "Anexo B: Lista Completa de Procesos"
    AppendixServices   = "Anexo C: Lista Completa de Servicios"
    AppendixEvents     = "Anexo D: Analisis de Eventos"
    AppendixLog        = "Anexo E: Log de Ejecucion de la Herramienta"
    CaseNumber         = "Numero de Caso"
    ExaminerName       = "Perito Informatico"
    ExamDate           = "Fecha del Analisis"
    SystemName         = "Nombre del Equipo"
    ToolUsed           = "Herramienta Utilizada"
    ToolHash           = "Hash de la Herramienta (SHA-256)"
    EvidenceID         = "ID Evidencia"
    SourcePath         = "Ruta Origen"
    DestPath           = "Ruta Destino"
    SHA256             = "Hash SHA-256"
    AcquisitionMethod  = "Metodo de Adquisicion"
    Timestamp          = "Marca de Tiempo"
    Phase              = "Fase"
    Action             = "Accion"
    Result             = "Resultado"
    NoDataAvailable    = "No se encontraron datos en esta categoria."
    CollectionFailed   = "La recopilacion de este artefacto fallo. Consulte el log de ejecucion para mas detalles."
    TotalFiles         = "Total de ficheros recopilados"
    TotalSize          = "Tamano total de evidencias"
    ExecutionTime      = "Tiempo total de ejecucion"
    UserActivity       = "Actividad de Usuarios"
    NetworkActivity    = "Actividad de Red"
    InstalledSoftware  = "Software Instalado"
    USBDevices         = "Dispositivos USB"
    WebBrowsing        = "Navegacion Web"
    Communications     = "Comunicaciones"
    CloudStorage       = "Almacenamiento en la Nube"
    PersistenceMechanisms = "Mecanismos de Persistencia"
    Severity           = "Severidad"
    Description        = "Descripcion"
    Evidence           = "Evidencia"
    Recommendation     = "Recomendacion"
}

# --- Banner de inicio ---
$Script:Banner = @"

  ╔═══════════════════════════════════════════════════════════════════╗
  ║                                                                   ║
  ║      ███╗   ███╗ █████╗ ██████╗ ███████╗██████╗ ██╗████████╗     ║
  ║      ████╗ ████║██╔══██╗██╔══██╗██╔════╝██╔══██╗██║╚══██╔══╝     ║
  ║      ██╔████╔██║███████║██████╔╝█████╗  ██████╔╝██║   ██║        ║
  ║      ██║╚██╔╝██║██╔══██║██╔═══╝ ██╔══╝  ██╔══██╗██║   ██║        ║
  ║      ██║ ╚═╝ ██║██║  ██║██║     ███████╗██║  ██║██║   ██║        ║
  ║      ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝   ╚═╝  .SW  ║
  ║                                                                   ║
  ║        Herramienta de Peritacion Informatica Forense              ║
  ║                    Profesional v{VERSION}                         ║
  ║                                                                   ║
  ╚═══════════════════════════════════════════════════════════════════╝

"@

# --- Aviso legal ---
$Script:LegalDisclaimer = @"
═══════════════════════════════════════════════════════════════════════
                          AVISO LEGAL
═══════════════════════════════════════════════════════════════════════

  MaPeriT.SW realiza una adquisicion forense de evidencias
  digitales. Su uso debe estar autorizado por el propietario del
  equipo o por orden judicial.

  - Todas las operaciones son de SOLO LECTURA sobre el sistema.
  - La unica escritura se realiza en el directorio de salida.
  - Se crea un Volume Shadow Copy temporal que se elimina al finalizar.
  - No se realizan conexiones de red por parte de la herramienta.
  - Todas las evidencias se verifican mediante hash SHA-256.

  El uso no autorizado de esta herramienta puede constituir un
  delito conforme a la legislacion vigente.

═══════════════════════════════════════════════════════════════════════
"@

# --- Parametros por defecto ---
$Script:Defaults = @{
    LargeFileThresholdMB = 500
    PhaseTimeoutMinutes  = 10
    ADSScanTimeoutSec    = 120
    SignatureScanTimeout = 300
    MaxEventsPerQuery    = 50000
    HashAlgorithm        = "SHA256"
    CSVDelimiter         = ","
    DateFormat           = "yyyy-MM-dd HH:mm:ss.fff"
    DateFormatShort      = "yyyy-MM-dd HH:mm:ss"
    TimeZoneFormat       = "yyyy-MM-dd HH:mm:ss zzz"
}
