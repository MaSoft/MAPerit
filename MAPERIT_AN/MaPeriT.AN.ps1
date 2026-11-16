#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.NOTES
    MaPeriT.AN - Analizador Forense Offline v1.2.1
    Analisis profundo sobre evidencias recopiladas por MaPeriT.SW
    Compilado: 2026-11-16 12:00:00
    Build: 2026-11-16 12:00:00
#>
#region ===== src\Main-Params.ps1 =====
<#
.SYNOPSIS
    MaPeriT.AN - Analizador Forense Offline

.DESCRIPTION
    Analiza en profundidad las evidencias recopiladas por MaPeriT.SW.
    Parsea el $MFT binario, analiza EVTX sin limite de eventos,
    extrae historial de navegadores de SQLite, y correlaciona todo
    en un informe de analisis forense profundo.

.PARAMETER EvidencePath
    OBLIGATORIO. Ruta al directorio de salida de MaPeriT.SW.
    Debe contener HashManifest.csv y la estructura de carpetas de SW.

.PARAMETER OutputPath
    Directorio de salida del analisis AN. Por defecto: EvidencePath\ANALISIS_AN

.PARAMETER ExaminerName
    Nombre del perito. Si se omite se reutiliza el del informe SW.

.PARAMETER SkipMFT
    Omitir el parseo del $MFT (util para pruebas rapidas).

.PARAMETER SkipBrowsers
    Omitir el parseo SQLite de navegadores.

.PARAMETER SkipEVTX
    Omitir el analisis profundo de logs EVTX.

.PARAMETER MaxMFTRecords
    Limite de registros MFT a procesar. 0 = todos (por defecto).

.PARAMETER IOCHashListPath
    Ruta opcional a un fichero de texto con hashes SHA1/SHA256/MD5 conocidos
    (uno por linea; lineas vacias o que empiecen por # se ignoran), para
    correlacionar contra los ejecutables de Amcache. Si se omite, se busca
    automaticamente "tools\IOC_Hashes.txt" junto al script. Enteramente
    offline: el fichero lo aporta el perito: AN nunca se conecta a ningun
    feed de IOCs en linea.

.EXAMPLE
    .\MaPeriT.AN.ps1 -EvidencePath "D:\Forense\MaPeriT_2026-001"

.EXAMPLE
    .\MaPeriT.AN.ps1 -EvidencePath "E:\Caso\Evidencias" -SkipMFT -ExaminerName "Juan Perez Garcia"

.EXAMPLE
    .\MaPeriT.AN.ps1 -EvidencePath "D:\Forense\MaPeriT_2026-001" -IOCHashListPath "D:\IOCs\hashes_conocidos.txt"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$EvidencePath,

    [string]$OutputPath      = "",
    [string]$ExaminerName    = "",
    [switch]$SkipMFT,
    [switch]$SkipBrowsers,
    [switch]$SkipEVTX,
    [long]$MaxMFTRecords     = 0,
    [string]$IOCHashListPath = ""
)
#endregion ===== src\Main-Params.ps1 =====

#region ===== src\Config.ps1 =====
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
#endregion ===== src\Config.ps1 =====

#region ===== src\Core\Logging.ps1 =====
#region ============================================================
# MaPeriT.AN - LOGGING
# ============================================================

$Script:ANLogPath = $null

function Initialize-ANLogging {
    param([string]$LogsPath)
    if (-not (Test-Path $LogsPath)) { New-Item -ItemType Directory -Path $LogsPath -Force | Out-Null }
    $Script:ANLogPath = Join-Path $LogsPath "MaPeriT_AN_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $header = "Timestamp,Phase,Action,Target,Result,Detail"
    $header | Out-File -FilePath $Script:ANLogPath -Encoding UTF8
}

function Write-ANLog {
    param(
        [string]$Phase  = "AN",
        [string]$Action = "",
        [string]$Target = "",
        [string]$Result = "INFO",
        [string]$Detail = ""
    )
    $ts    = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $color = switch ($Result) { "OK"{"Green"} "WARNING"{"Yellow"} "ERROR"{"Red"} "SKIP"{"DarkGray"} default{"Cyan"} }
    $prefix= switch ($Result) { "OK"{"[+]"} "WARNING"{"[!]"} "ERROR"{"[-]"} "SKIP"{"[~]"} default{"[*]"} }

    Write-Host "  $prefix " -ForegroundColor $color -NoNewline
    Write-Host "$Action" -ForegroundColor White -NoNewline
    if ($Target) { Write-Host " -> " -ForegroundColor DarkGray -NoNewline; Write-Host "$Target" -ForegroundColor Gray } else { Write-Host "" }

    if ($Script:ANLogPath) {
        $line = "`"$ts`",`"$Phase`",`"$Action`",`"$($Target -replace '"','""')`",`"$Result`",`"$($Detail -replace '"','""')`""
        try { $line | Out-File -FilePath $Script:ANLogPath -Append -Encoding UTF8 } catch {}
    }

    if ($Result -eq "ERROR")   { $Script:ANSession.Errors++ }
    if ($Result -eq "WARNING") { $Script:ANSession.Warnings++ }
}

function Write-ANProgress {
    param([string]$Message, [long]$Current = 0, [long]$Total = 0)
    if ($Total -gt 0) {
        $pct = [math]::Round($Current / $Total * 100, 1)
        Write-Host "`r  [*] $Message $Current/$Total ($pct%)" -NoNewline -ForegroundColor Yellow
    } else {
        Write-Host "`r  [*] $Message" -NoNewline -ForegroundColor Yellow
    }
}

function Write-ANSection {
    param([string]$Name)
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║  $($Name.PadRight(56)) ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Export-ANData {
    param([object[]]$Data, [string]$Path, [string]$Description)
    if (-not $Data -or $Data.Count -eq 0) {
        Write-ANLog -Action "SIN_DATOS" -Target $Description -Result "WARNING"
        return
    }
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -Force
    Write-ANLog -Action "EXPORTADO" -Target (Split-Path $Path -Leaf) -Result "OK" -Detail "$($Data.Count) registros"
}
#endregion ===== src\Core\Logging.ps1 =====

#region ===== ..\Common\HtmlEncoding.ps1 =====
#region ============================================================
# Ecosistema MaPeriT - COMPATIBILIDAD DE HtmlEncode COMPARTIDA
#
# BUG CONFIRMADO EMPIRICAMENTE (12/07/2026, verificacion end-to-end real de
# MaPeriT.OF contra un disco objetivo sintetico): "Add-Type -AssemblyName
# System.Web -ErrorAction SilentlyContinue" puede fallar en silencio incluso
# bajo Windows PowerShell 5.1 (no es un problema exclusivo de PowerShell 7 /
# .NET Core, como se habia asumido hasta ahora). Cuando falla, TODAS las
# llamadas a [System.Web.HttpUtility]::HtmlEncode(...) en cualquier
# generador de informes (SW, OF, AN usan esta clase extensivamente) lanzan
# "No se encuentra el tipo [System.Web.HttpUtility]" y el informe pericial
# se genera roto - en el caso de OF, el bug era aun peor: nunca llegaba
# siquiera a INTENTAR cargar el ensamblado.
#
# Este fichero garantiza que el tipo System.Web.HttpUtility SIEMPRE quede
# disponible: intenta cargar el ensamblado real y, si el tipo sigue sin
# resolver por cualquier motivo, define un reemplazo minimo bajo el MISMO
# nombre completamente cualificado. Todas las llamadas existentes
# [System.Web.HttpUtility]::HtmlEncode(...) en cualquier fichero de informe
# siguen funcionando sin cambiar ni un solo punto de llamada.
# ============================================================

Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

if (-not ([System.Management.Automation.PSTypeName]'System.Web.HttpUtility').Type) {
    try {
        Add-Type -TypeDefinition @"
using System;
namespace System.Web {
    public static class HttpUtility {
        public static string HtmlEncode(string s) {
            if (string.IsNullOrEmpty(s)) return s;
            return s.Replace("&","&amp;").Replace("<","&lt;").Replace(">","&gt;").Replace("\"","&quot;").Replace("'","&#39;");
        }
    }
}
"@ -Language CSharp -ErrorAction Stop
    } catch {
        # Si ni siquiera esto carga (extremadamente improbable), los generadores
        # de informe seguiran fallando igual que antes de este fichero - no hay
        # nada mas que se pueda hacer sin depender de una libreria externa.
    }
}

#endregion
#endregion ===== ..\Common\HtmlEncoding.ps1 =====

#region ===== src\Core\Initialize.ps1 =====
#region ============================================================
# MaPeriT.AN - INICIALIZACION Y VALIDACION
# ============================================================

function Test-SWEvidencePath {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "El directorio de evidencias no existe: $Path"
    }

    # Verificar que parece un directorio de MaPeriT.SW
    $manifest = Get-ChildItem $Path -Filter "HashManifest.csv" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $manifest) {
        throw "No se encontro HashManifest.csv en '$Path'. Asegurese de que es un directorio valido de MaPeriT.SW."
    }

    $fsDir = Join-Path $Path $Script:SW_Dirs.Filesystem
    if (-not (Test-Path $fsDir)) {
        Write-ANLog -Action "AVISO_ESTRUCTURA" -Target "Carpeta 03_Filesystem no encontrada" -Result "WARNING"
    }

    return $true
}

function Get-SWSessionInfo {
    param([string]$EvidencePath)

    $info = @{
        CaseNumber   = "DESCONOCIDO"
        ExaminerName = "DESCONOCIDO"
        ToolHash     = "DESCONOCIDO"
        StartTime    = $null
        OSVersion    = "DESCONOCIDO"
        ComputerName = "DESCONOCIDO"
    }

    # Intentar leer el log forense de OF. MaPeriT.OF nombra su log
    # "ForensicLog.csv" y SI registra SESION_INICIADA/SCRIPT_HASH como filas
    # propias. MaPeriT.SW usa un formato de log distinto ("ActionLog.csv",
    # sin esas acciones concretas) - para evidencia de SW este bloque nunca
    # encuentra nada y se recurre a los fallbacks de mas abajo (OSInfo.json +
    # InformePericial.html), que funcionan igual con evidencia de ambas
    # herramientas.
    $logPath = Join-Path $EvidencePath "$($Script:SW_Dirs.Logs)\ForensicLog.csv"
    if (Test-Path $logPath) {
        try {
            $logLines = Import-Csv $logPath -ErrorAction SilentlyContinue | Select-Object -First 100
            $initLine = $logLines | Where-Object { $_.Action -eq "SESION_INICIADA" } | Select-Object -First 1
            if ($initLine) { $info.CaseNumber = $initLine.Target }
            $hashLine = $logLines | Where-Object { $_.Action -eq "SCRIPT_HASH" } | Select-Object -First 1
            if ($hashLine) { $info.ToolHash = $hashLine.Target }
        } catch {}
    }

    # Extraer caso desde nombre del directorio (con o sin timestamp) - funciona
    # con la convencion de nombres por defecto de ambas herramientas.
    # Solo si el log no lo aporto (antes el nombre de carpeta sustituia al del log, y
    # con OF, "MaPeriT_OF_<caso>_<fecha>", el caso quedaba como "OF_<caso>").
    $dirName = Split-Path $EvidencePath -Leaf
    if ($info.CaseNumber -eq "DESCONOCIDO" -and $dirName -match "^(?:MaPeriT|ForensicPE)[._](?:OF_)?(.+?)(?:_\d{8}_\d{6})?$") {
        $candidate = $Matches[1] -replace "_\d{8}_\d{6}$",""
        if ($candidate -and $candidate -ne "DESCONOCIDO") { $info.CaseNumber = $candidate }
    }

    # OSInfo.json con multiples fallbacks de nombre de campo (antes se leia
    # este mismo fichero dos veces seguidas: una comprobacion simple que el
    # segundo bloque, mas completo, siempre sobreescribia igualmente -
    # eliminada la primera lectura redundante).
    $osPath = Join-Path $EvidencePath "$($Script:SW_Dirs.SystemInfo)\OSInfo.json"
    if (Test-Path $osPath) {
        try {
            $os = Get-Content $osPath -Raw | ConvertFrom-Json
            $info.OSVersion = if ($os.Caption) {$os.Caption}
                              elseif ($os.OSName) {$os.OSName}
                              elseif ($os.Name) {($os.Name -split "\|")[0].Trim()}
                              else {"DESCONOCIDO"}
            $info.ComputerName = if ($os.CSName) {$os.CSName}
                                 elseif ($os.ComputerName) {$os.ComputerName}
                                 elseif ($os.NombreEquipo) {$os.NombreEquipo}
                                 elseif ($os.SystemName) {$os.SystemName}
                                 else {"DESCONOCIDO"}
        } catch {}
    }

    # Perito y hash de la herramienta desde el informe HTML, para cuando el
    # log-based lookup de arriba no aplico (evidencia de SW, o de OF si algun
    # dia cambia su formato de log).
    # BUG CONFIRMADO: se leian solo las primeras 50 lineas del HTML
    # (-TotalCount 50) buscando "Perito" con una regex - pero el <style>
    # embebido (Get-ReportCSS/Get-OFCss) por si solo ocupa cerca de 290
    # lineas en SW y 210 en OF antes de llegar al <body>, asi que la ventana
    # de 50 lineas nunca alcanzaba el texto real: esta extraccion NUNCA ha
    # funcionado, ni con informes de SW ni de OF. Se lee el fichero completo
    # (un unico informe HTML, tamano manejable) en vez de un numero de
    # lineas fijo. Se aprovecha para extraer tambien el hash SHA-256 de la
    # herramienta (visible en portada/metodologia/pie del mismo informe),
    # que antes solo se obtenia via el log de OF y quedaba "DESCONOCIDO"
    # siempre para evidencia de SW.
    $reportHtml = Join-Path $EvidencePath "$($Script:SW_Dirs.Report)\InformePericial.html"
    if (Test-Path $reportHtml) {
        try {
            $content = Get-Content $reportHtml -Raw -ErrorAction SilentlyContinue
            if ($content) {
                if ($info.ExaminerName -eq "DESCONOCIDO" -and $content -match "Perito.*?>\s*([^<]{3,60})\s*<") {
                    $info.ExaminerName = $Matches[1].Trim()
                }
                if ($info.ToolHash -eq "DESCONOCIDO" -and $content -match "SHA-256.{0,60}?([A-Fa-f0-9]{64})") {
                    $info.ToolHash = $Matches[1]
                }
            }
        } catch {}
    }

    return $info
}

function Initialize-ANSession {
    param(
        [string]$EvidencePath,
        [string]$OutputPath,
        [string]$ExaminerName
    )

    $Script:ANSession.StartTime    = Get-Date
    $Script:ANSession.EvidencePath = $EvidencePath
    $Script:ANSession.OutputPath   = $OutputPath
    $Script:ANSession.ExaminerName = $ExaminerName

    $swInfo = Get-SWSessionInfo -EvidencePath $EvidencePath
    $Script:ANSession.SWCaseNumber = $swInfo.CaseNumber
    $Script:ANSession.SWExaminer   = $swInfo.ExaminerName
    $Script:ANSession.SWToolHash   = $swInfo.ToolHash

    if ([string]::IsNullOrEmpty($Script:ANSession.ExaminerName)) {
        $Script:ANSession.ExaminerName = $swInfo.ExaminerName
    }

    return $swInfo
}

function Initialize-ANOutputStructure {
    param([string]$OutputPath)
    foreach ($dir in $Script:AN_Dirs.Values) {
        $full = Join-Path $OutputPath $dir
        if (-not (Test-Path $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
    }
}

function Show-ANBanner {
    param([hashtable]$SWInfo)
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                              ║" -ForegroundColor Cyan
    Write-Host "  ║   MaPeriT.AN  v$($Script:AN_VERSION)  —  Analizador Forense Offline        ║" -ForegroundColor Cyan
    Write-Host "  ║                                                              ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "  EVIDENCIAS DE: $($Script:ANSession.EvidencePath)" -ForegroundColor White
    Write-Host "  Caso SW:       $($Script:ANSession.SWCaseNumber)"   -ForegroundColor Gray
    Write-Host "  Equipo:        $($SWInfo.ComputerName)"             -ForegroundColor Gray
    Write-Host "  SO:            $($SWInfo.OSVersion)"                -ForegroundColor Gray
    Write-Host "  Perito AN:     $($Script:ANSession.ExaminerName)"   -ForegroundColor Gray
    Write-Host "  Salida AN:     $($Script:ANSession.OutputPath)"     -ForegroundColor Gray
    Write-Host "  ════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
}
#endregion ===== src\Core\Initialize.ps1 =====

#region ===== src\Core\MFTParser.ps1 =====
#region ============================================================
# MaPeriT.AN - PARSER MFT BINARIO (C# EMBEBIDO)
# Parsea el fichero $MFT extraido por MaPeriT.SW byte a byte.
# Lee atributos $STANDARD_INFORMATION y $FILE_NAME de cada File Record.
# ============================================================

$Script:MFTCSharp = @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Text;

namespace MaPeriT
{
    public class MFTRecord
    {
        public long   RecordNumber;
        public bool   InUse;
        public bool   IsDirectory;
        public bool   IsDeleted;
        public string FileName;
        public int    FilenameNamespace;   // 0=POSIX 1=Win32 2=DOS 3=Win32&DOS
        public long   ParentRecordNumber;
        public long   FileSize;
        // $STANDARD_INFORMATION timestamps (manipulables por antiforensica)
        public DateTime SI_Created;
        public DateTime SI_Modified;
        public DateTime SI_MFTModified;
        public DateTime SI_Accessed;
        // $FILE_NAME timestamps (mas dificiles de falsificar)
        public DateTime FN_Created;
        public DateTime FN_Modified;
        public DateTime FN_MFTModified;
        public DateTime FN_Accessed;
        // Analisis
        public bool   IsTimestomped;
        public string TimestompReason;
        // Ruta completa (resuelta en segunda pasada)
        public string FullPath;
    }

    public class MFTParser
    {
        private const int RECORD_SIZE    = 1024;
        private const uint ATTR_SI       = 0x10;
        private const uint ATTR_FN       = 0x30;
        private const uint ATTR_END      = 0xFFFFFFFF;

        // ── Primera pasada: construir diccionario num→(nombre,padre) ──────────
        public static Dictionary<long, Tuple<string,long>> BuildPathIndex(string mftPath, Action<long,long> progress = null)
        {
            var index = new Dictionary<long, Tuple<string,long>>(500000);
            using (var fs = new FileStream(mftPath, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20))
            {
                long total = fs.Length / RECORD_SIZE;
                byte[] buf = new byte[RECORD_SIZE];
                long i = 0;
                while (true)
                {
                    int read = ReadFull(fs, buf, RECORD_SIZE);
                    if (read < RECORD_SIZE) break;
                    if (progress != null && i % 50000 == 0) progress(i, total);

                    if (buf[0] != 0x46 || buf[1] != 0x49 || buf[2] != 0x4C || buf[3] != 0x45) { i++; continue; }

                    ApplyUSA(buf);
                    // NOTA: no se descartan los registros "not in use" (borrados). Un
                    // fichero (borrado o no) dentro de una CARPETA borrada solo puede
                    // resolver su ruta completa si la carpeta borrada tambien esta en
                    // este indice - es precisamente el escenario de mayor valor
                    // forense (carpeta borrada + fichero borrado dentro). Antes se
                    // excluian aqui y la ruta resultante quedaba truncada a "[?]\nombre".

                    string fname = null;
                    int fnNs = 99;
                    long parent = 5; // root
                    ushort attrOff = LE16(buf, 0x14);
                    int pos = attrOff;
                    while (pos + 8 < RECORD_SIZE)
                    {
                        uint t = LE32(buf, pos);
                        if (t == ATTR_END) break;
                        uint len = LE32(buf, pos + 4);
                        if (len == 0 || pos + len > RECORD_SIZE) break;
                        if (t == ATTR_FN && buf[pos+8] == 0)
                        {
                            uint vLen = LE32(buf, pos+0x10);
                            ushort vOff = LE16(buf, pos+0x14);
                            int d = pos + vOff;
                            if (vLen >= 0x42 && d + 0x42 < RECORD_SIZE)
                            {
                                int ns = buf[d + 0x41];
                                if (fname == null || ns == 1 || ns == 3)
                                {
                                    parent = LE64(buf, d) & 0x0000FFFFFFFFFFFFL;
                                    fnNs   = ns;
                                    byte fnLen = buf[d + 0x40];
                                    int strStart = d + 0x42;
                                    if (strStart + fnLen * 2 <= RECORD_SIZE)
                                        fname = Encoding.Unicode.GetString(buf, strStart, fnLen * 2);
                                }
                            }
                        }
                        pos += (int)len;
                    }
                    if (fname != null)
                        index[i] = Tuple.Create(fname, parent);
                    i++;
                }
            }
            return index;
        }

        // ── Resolver ruta completa desde el indice ────────────────────────────
        public static string ResolvePath(long recordNum, Dictionary<long,Tuple<string,long>> index, int maxDepth = 32)
        {
            var parts = new List<string>();
            long cur = recordNum;
            for (int d = 0; d < maxDepth; d++)
            {
                if (!index.ContainsKey(cur)) { parts.Add("[?]"); break; }
                var entry = index[cur];
                parts.Add(entry.Item1);
                if (entry.Item2 == 5 || entry.Item2 == cur) break; // raiz o ciclo
                cur = entry.Item2;
            }
            parts.Reverse();
            return string.Join("\\", parts);
        }

        // ── Segunda pasada: parseo completo ───────────────────────────────────
        public static IEnumerable<MFTRecord> ParseAll(
            string mftPath,
            Dictionary<long,Tuple<string,long>> pathIndex,
            long maxRecords,
            int timestompThresholdSec,
            Action<long,long> progress)
        {
            using (var fs = new FileStream(mftPath, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20))
            {
                long total = fs.Length / RECORD_SIZE;
                if (maxRecords > 0) total = Math.Min(total, maxRecords);
                byte[] buf = new byte[RECORD_SIZE];
                long i = 0;
                while (i < total)
                {
                    int read = ReadFull(fs, buf, RECORD_SIZE);
                    if (read < RECORD_SIZE) break;
                    if (progress != null && i % 25000 == 0) progress(i, total);

                    var r = ParseRecord(buf, i, timestompThresholdSec);
                    if (r != null)
                    {
                        r.FullPath = ResolvePath(i, pathIndex);
                        if (r.IsDeleted) r.FullPath = "[BORRADO] " + r.FullPath;
                        yield return r;
                    }
                    i++;
                }
            }
        }

        // ── Parsear un record de 1024 bytes ───────────────────────────────────
        private static MFTRecord ParseRecord(byte[] raw, long idx, int threshSec)
        {
            if (raw[0] != 0x46 || raw[1] != 0x49 || raw[2] != 0x4C || raw[3] != 0x45)
                return null;

            byte[] buf = (byte[])raw.Clone();
            ApplyUSA(buf);

            ushort flags = LE16(buf, 0x16);
            var r = new MFTRecord
            {
                RecordNumber = idx,
                InUse        = (flags & 1) != 0,
                IsDirectory  = (flags & 2) != 0,
                IsDeleted    = (flags & 1) == 0
            };

            bool hasSI = false, hasFN = false;
            ushort attrOff = LE16(buf, 0x14);
            int pos = attrOff;

            while (pos + 8 < RECORD_SIZE)
            {
                uint t   = LE32(buf, pos);
                if (t == ATTR_END) break;
                uint len = LE32(buf, pos + 4);
                if (len == 0 || pos + len > RECORD_SIZE) break;

                bool nonRes = buf[pos + 8] != 0;

                if (!nonRes)
                {
                    uint vLen = LE32(buf, pos + 0x10);
                    ushort vOff = LE16(buf, pos + 0x14);
                    int d = pos + vOff;

                    if (t == ATTR_SI && vLen >= 48 && d + 48 <= RECORD_SIZE)
                    {
                        r.SI_Created     = FT(buf, d + 0);
                        r.SI_Modified    = FT(buf, d + 8);
                        r.SI_MFTModified = FT(buf, d + 16);
                        r.SI_Accessed    = FT(buf, d + 24);
                        hasSI = true;
                    }
                    else if (t == ATTR_FN && vLen >= 0x42 && d + 0x42 <= RECORD_SIZE)
                    {
                        int ns = buf[d + 0x41];
                        if (!hasFN || ns == 1 || ns == 3)
                        {
                            r.ParentRecordNumber = LE64(buf, d) & 0x0000FFFFFFFFFFFFL;
                            r.FN_Created         = FT(buf, d + 0x08);
                            r.FN_Modified        = FT(buf, d + 0x10);
                            r.FN_MFTModified     = FT(buf, d + 0x18);
                            r.FN_Accessed        = FT(buf, d + 0x20);
                            r.FileSize           = LE64(buf, d + 0x30);
                            r.FilenameNamespace  = ns;
                            byte fnLen = buf[d + 0x40];
                            int strStart = d + 0x42;
                            if (fnLen > 0 && strStart + fnLen * 2 <= RECORD_SIZE)
                                r.FileName = Encoding.Unicode.GetString(buf, strStart, fnLen * 2);
                            hasFN = true;
                        }
                    }
                }
                pos += (int)len;
            }

            if (!hasFN) return null;

            // Timestomping detection — solo indicadores fiables (SI < FN)
            // Se elimina el check de precision sub-segundo: demasiados falsos positivos
            // en ficheros de sistema instalados con timestamps redondeados.
            if (hasSI && r.SI_Created != DateTime.MinValue && r.FN_Created != DateTime.MinValue)
            {
                var reasons = new List<string>();
                var ts = TimeSpan.FromSeconds(threshSec);

                // Indicador primario: SI anterior a FN (imposible sin manipulacion)
                if (r.SI_Created  < r.FN_Created  - ts) reasons.Add("SI_Created < FN_Created");
                if (r.SI_Modified < r.FN_Modified - ts) reasons.Add("SI_Modified < FN_Modified");

                // Indicador logico: fichero creado despues de modificado (imposible)
                if (r.SI_Created > r.SI_Modified + TimeSpan.FromSeconds(60) &&
                    r.SI_Modified > DateTime.MinValue)
                    reasons.Add("SI_Created > SI_Modified+60s (imposible)");

                // Sub-segundo SOLO si la diferencia SI<FN es ademas de mas de 1 hora
                // (descartamos ruido de instalacion de Windows)
                if (reasons.Count == 0)
                {
                    bool siNoSubSec = r.SI_Created.Ticks  % 10000000 == 0 &&
                                      r.SI_Modified.Ticks % 10000000 == 0 &&
                                      r.SI_MFTModified.Ticks % 10000000 == 0;
                    bool fnHasSubSec= r.FN_Created.Ticks  % 10000000 != 0 ||
                                      r.FN_Modified.Ticks % 10000000 != 0;
                    bool bigDiff    = Math.Abs((r.SI_Created - r.FN_Created).TotalHours) > 1.0 ||
                                      Math.Abs((r.SI_Modified - r.FN_Modified).TotalHours) > 1.0;
                    if (siNoSubSec && fnHasSubSec && bigDiff)
                        reasons.Add("Precision SI=0 + diferencia >1h con FN");
                }

                if (reasons.Count > 0)
                {
                    r.IsTimestomped   = true;
                    r.TimestompReason = string.Join("; ", reasons);
                }
            }
            return r;
        }

        // ── USA Fixup ─────────────────────────────────────────────────────────
        private static void ApplyUSA(byte[] buf)
        {
            ushort usaOff  = LE16(buf, 4);
            ushort usaSize = LE16(buf, 6);
            if (usaOff == 0 || usaSize < 2 || usaOff + usaSize * 2 > RECORD_SIZE) return;
            for (int i = 1; i < usaSize; i++)
            {
                int sectorEnd = i * 512 - 2;
                int usaEntry  = usaOff + i * 2;
                if (sectorEnd + 2 > RECORD_SIZE || usaEntry + 2 > RECORD_SIZE) break;
                buf[sectorEnd]     = buf[usaEntry];
                buf[sectorEnd + 1] = buf[usaEntry + 1];
            }
        }

        // ── Helpers ───────────────────────────────────────────────────────────
        private static ushort LE16(byte[] b, int o) => (ushort)(b[o] | b[o+1] << 8);
        private static uint   LE32(byte[] b, int o) => (uint)(b[o] | b[o+1]<<8 | b[o+2]<<16 | b[o+3]<<24);
        private static long   LE64(byte[] b, int o) => (long)((ulong)b[o] | (ulong)b[o+1]<<8 | (ulong)b[o+2]<<16 |
                                                               (ulong)b[o+3]<<24 | (ulong)b[o+4]<<32 | (ulong)b[o+5]<<40 |
                                                               (ulong)b[o+6]<<48 | (ulong)b[o+7]<<56);
        private static DateTime FT(byte[] b, int o)
        {
            long ft = LE64(b, o);
            if (ft <= 0) return DateTime.MinValue;
            try { return DateTime.FromFileTimeUtc(ft); } catch { return DateTime.MinValue; }
        }
        private static int ReadFull(Stream s, byte[] buf, int size)
        {
            int total = 0;
            while (total < size)
            {
                int r = s.Read(buf, total, size - total);
                if (r == 0) break;
                total += r;
            }
            return total;
        }
    }
}
'@

function Initialize-MFTParser {
    try {
        Add-Type -TypeDefinition $Script:MFTCSharp -Language CSharp -ErrorAction Stop
        Write-ANLog -Action "MFTPARSER_CARGADO" -Target "MaPeriT.MFTParser" -Result "OK"
        return $true
    } catch {
        if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*MaPeriT*") { return $true }
        Write-ANLog -Action "MFTPARSER_ERROR" -Target $_.Exception.Message -Result "ERROR"
        return $false
    }
}

function Invoke-MFTAnalysis {
    param(
        [string]$MFTPath,
        [string]$OutputPath,
        [long]$MaxRecords = 0
    )

    Write-ANSection "ANALISIS MFT - MASTER FILE TABLE"
    $mftOut = Join-Path $OutputPath $Script:AN_Dirs.MFT

    if (-not (Test-Path $MFTPath)) {
        Write-ANLog -Phase "MFT" -Action "MFT_NO_ENCONTRADO" -Target $MFTPath -Result "ERROR"
        return
    }

    $mftSize = [math]::Round((Get-Item $MFTPath).Length / 1MB, 1)
    $estRecords = [math]::Floor((Get-Item $MFTPath).Length / 1024)
    Write-ANLog -Phase "MFT" -Action "MFT_ENCONTRADO" -Target "$mftSize MB / ~$estRecords registros estimados" -Result "OK"

    # ── Fase 1: construir indice de rutas ──────────────────────────────
    Write-Host "  [*] Fase 1/2: construyendo indice de rutas..." -ForegroundColor Yellow
    $progressCb = [Action[long,long]]{ param($c,$t) Write-ANProgress "Indexando" $c $t }

    try {
        $pathIndex = [MaPeriT.MFTParser]::BuildPathIndex($MFTPath, $progressCb)
        Write-Host ""
        Write-ANLog -Phase "MFT" -Action "INDICE_CONSTRUIDO" -Target "$($pathIndex.Count) entradas" -Result "OK"
    } catch {
        Write-Host ""
        Write-ANLog -Phase "MFT" -Action "INDICE_ERROR" -Target $_.Exception.Message -Result "ERROR"
        return
    }

    # ── Fase 2: parseo completo ────────────────────────────────────────
    Write-Host "  [*] Fase 2/2: parseo completo de atributos y timestamps..." -ForegroundColor Yellow
    $progressCb2 = [Action[long,long]]{ param($c,$t) Write-ANProgress "Parseando" $c $t }

    $allRecords    = [System.Collections.Generic.List[object]]::new()
    $timestomped   = [System.Collections.Generic.List[object]]::new()
    $deleted       = [System.Collections.Generic.List[object]]::new()

    try {
        $records = [MaPeriT.MFTParser]::ParseAll($MFTPath, $pathIndex, $MaxRecords, $Script:TimestompThreshold, $progressCb2)
        foreach ($r in $records) {
            $obj = [PSCustomObject]@{
                RecordNum       = $r.RecordNumber
                Estado          = if ($r.IsDeleted) {"BORRADO"} elseif ($r.IsDirectory) {"DIRECTORIO"} else {"FICHERO"}
                NombreFichero   = $r.FileName
                RutaCompleta    = $r.FullPath
                TamanoBytes     = $r.FileSize
                Namespace       = $Script:MFT_Namespaces[$r.FilenameNamespace]
                SI_Creado_UTC   = if ($r.SI_Created -gt [datetime]::MinValue) {$r.SI_Created.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                SI_Modificado_UTC = if ($r.SI_Modified -gt [datetime]::MinValue) {$r.SI_Modified.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                SI_MFT_UTC      = if ($r.SI_MFTModified -gt [datetime]::MinValue) {$r.SI_MFTModified.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                SI_Acceso_UTC   = if ($r.SI_Accessed -gt [datetime]::MinValue) {$r.SI_Accessed.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                FN_Creado_UTC   = if ($r.FN_Created -gt [datetime]::MinValue) {$r.FN_Created.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                FN_Modificado_UTC = if ($r.FN_Modified -gt [datetime]::MinValue) {$r.FN_Modified.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                FN_MFT_UTC      = if ($r.FN_MFTModified -gt [datetime]::MinValue) {$r.FN_MFTModified.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                FN_Acceso_UTC   = if ($r.FN_Accessed -gt [datetime]::MinValue) {$r.FN_Accessed.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                Timestomping    = $r.IsTimestomped
                RazonTimestomp  = $r.TimestompReason
            }
            $allRecords.Add($obj)
            if ($r.IsTimestomped) { $timestomped.Add($obj) }
            if ($r.IsDeleted -and $r.FileName -notlike "`$*") { $deleted.Add($obj) }
        }
        Write-Host ""
    } catch {
        Write-Host ""
        Write-ANLog -Phase "MFT" -Action "PARSEO_ERROR" -Target $_.Exception.Message -Result "ERROR"
        return
    }

    # ── Exportar resultados ────────────────────────────────────────────
    Write-ANLog -Phase "MFT" -Action "PARSEO_COMPLETO" -Target "$($allRecords.Count) registros validos" -Result "OK"
    $Script:ANSession.MFTRecords    = $allRecords.Count
    $Script:ANSession.MFTTimestomped= $timestomped.Count
    $Script:ANSession.MFTDeleted    = $deleted.Count

    # MFT completo (puede ser grande — chunked por si acaso)
    $allPath = Join-Path $mftOut "MFT_Completo.csv"
    Export-ANData -Data $allRecords.ToArray() -Path $allPath -Description "MFT completo"

    $tsPath = Join-Path $mftOut "MFT_Timestomping.csv"
    Export-ANData -Data $timestomped.ToArray() -Path $tsPath -Description "Ficheros con posible timestomping"

    $delPath = Join-Path $mftOut "MFT_Borrados.csv"
    Export-ANData -Data $deleted.ToArray() -Path $delPath -Description "Ficheros borrados"

    Write-ANLog -Phase "MFT" -Action "RESUMEN" -Target "Total=$($allRecords.Count) Timestomped=$($timestomped.Count) Borrados=$($deleted.Count)" -Result "OK"
}
#endregion ===== src\Core\MFTParser.ps1 =====

#region ===== src\Core\EVTXAnalyzer.ps1 =====
#region ============================================================
# MaPeriT.AN - ANALIZADOR EVTX PROFUNDO
# Usa System.Diagnostics.Eventing.Reader sobre los .evtx copiados.
# Sin limite de eventos. Sin dependencias externas.
# ============================================================

function Invoke-EVTXAnalysis {
    param(
        [string]$EventLogsPath,
        [string]$OutputPath
    )

    Write-ANSection "ANALISIS EVTX - LOGS DE EVENTOS"
    $evtxOut = Join-Path $OutputPath $Script:AN_Dirs.EVTX

    $evtxFiles = @(Get-ChildItem $EventLogsPath -Filter "*.evtx" -Recurse -ErrorAction SilentlyContinue)
    if ($evtxFiles.Count -eq 0) {
        Write-ANLog -Phase "EVTX" -Action "NO_HAY_EVTX" -Target $EventLogsPath -Result "WARNING"
        return
    }

    Write-ANLog -Phase "EVTX" -Action "EVTX_ENCONTRADOS" -Target "$($evtxFiles.Count) ficheros .evtx" -Result "OK"

    # Organizar por fichero clave
    $keyFiles = @{
        Security  = $evtxFiles | Where-Object { $_.Name -eq "Security.evtx" } | Select-Object -First 1
        System    = $evtxFiles | Where-Object { $_.Name -eq "System.evtx" }   | Select-Object -First 1
        PowerShell= $evtxFiles | Where-Object { $_.Name -like "*PowerShell*Operational*" } | Select-Object -First 1
        PSCore    = $evtxFiles | Where-Object { $_.Name -eq "PowerShellCore%4Operational.evtx" } | Select-Object -First 1
        Sysmon    = $evtxFiles | Where-Object { $_.Name -like "*Sysmon*" }     | Select-Object -First 1
        WMI       = $evtxFiles | Where-Object { $_.Name -like "*WMI-Activity*Operational*" } | Select-Object -First 1
        TaskSched = $evtxFiles | Where-Object { $_.Name -like "*TaskScheduler*Operational*" } | Select-Object -First 1
        Defender  = $evtxFiles | Where-Object { $_.Name -like "*Windows Defender*Operational*" } | Select-Object -First 1
    }

    $allEvents = [System.Collections.Generic.List[object]]::new()

    # ── Procesar Security.evtx ─────────────────────────────────────────
    if ($keyFiles.Security) {
        Write-Host "  [*] Procesando Security.evtx..." -ForegroundColor Yellow
        $secEvents = Read-EVTXEvents -FilePath $keyFiles.Security.FullName -EventIDs ($Script:EventIDs.Logon + $Script:EventIDs.AccountMgmt + $Script:EventIDs.AuditLog + $Script:EventIDs.Services + $Script:EventIDs.Process)
        foreach ($e in $secEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "SECURITY_PROCESADO" -Target "$($secEvents.Count) eventos relevantes" -Result "OK"
    }

    # ── Procesar Security Archives ─────────────────────────────────────
    $archiveSec = @($evtxFiles | Where-Object { $_.Name -like "Archive-Security-*.evtx" })
    if ($archiveSec.Count -gt 0) {
        Write-Host "  [*] Procesando $($archiveSec.Count) archives de Security (XPath)..." -ForegroundColor Yellow
        # Solo eventos criticos en archives — IDs de alta prioridad unicamente
        $archiveIDs = @(1102, 1104, 4624, 4625, 4648, 4672, 4697, 4698, 4720, 4726, 4728, 4732, 4740, 7045)
        $archiveCount = 0; $archIdx = 0
        foreach ($arch in $archiveSec) {
            $archIdx++
            if ($archIdx % 25 -eq 0) { Write-Host "`r  [*] Archives: $archIdx/$($archiveSec.Count)..." -NoNewline -ForegroundColor Yellow }
            $archEvents = @(Read-EVTXEvents -FilePath $arch.FullName -EventIDs $archiveIDs)
            foreach ($e in $archEvents) { $allEvents.Add($e) }
            $archiveCount += $archEvents.Count
        }
        Write-Host ""
        Write-ANLog -Phase "EVTX" -Action "ARCHIVES_PROCESADOS" -Target "$archiveCount eventos de $($archiveSec.Count) archives" -Result "OK"
    }

    # ── Procesar System.evtx ───────────────────────────────────────────
    if ($keyFiles.System) {
        Write-Host "  [*] Procesando System.evtx..." -ForegroundColor Yellow
        $sysEvents = Read-EVTXEvents -FilePath $keyFiles.System.FullName -EventIDs ($Script:EventIDs.Services + $Script:EventIDs.System)
        foreach ($e in $sysEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "SYSTEM_PROCESADO" -Target "$($sysEvents.Count) eventos relevantes" -Result "OK"
    }

    # ── Procesar PowerShell ────────────────────────────────────────────
    foreach ($psFile in @($keyFiles.PowerShell, $keyFiles.PSCore) | Where-Object { $_ }) {
        Write-Host "  [*] Procesando $($psFile.Name)..." -ForegroundColor Yellow
        $psEvents = Read-EVTXEvents -FilePath $psFile.FullName -EventIDs $Script:EventIDs.PowerShell
        foreach ($e in $psEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "POWERSHELL_PROCESADO" -Target "$($psEvents.Count) eventos" -Result "OK"
    }

    # ── Procesar WMI ──────────────────────────────────────────────────
    if ($keyFiles.WMI) {
        $wmiEvents = Read-EVTXEvents -FilePath $keyFiles.WMI.FullName -EventIDs $Script:EventIDs.WMI
        foreach ($e in $wmiEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "WMI_PROCESADO" -Target "$($wmiEvents.Count) eventos" -Result "OK"
    }

    # ── Procesar Defender ─────────────────────────────────────────────
    if ($keyFiles.Defender) {
        $defEvents = Read-EVTXEvents -FilePath $keyFiles.Defender.FullName -EventIDs $Script:EventIDs.Defender
        foreach ($e in $defEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "DEFENDER_PROCESADO" -Target "$($defEvents.Count) eventos" -Result "OK"
    }

    # ── Procesar TaskScheduler ────────────────────────────────────────
    if ($keyFiles.TaskSched) {
        $tsEvents = Read-EVTXEvents -FilePath $keyFiles.TaskSched.FullName -EventIDs $Script:EventIDs.Scheduled
        foreach ($e in $tsEvents) { $allEvents.Add($e) }
        Write-ANLog -Phase "EVTX" -Action "TASKSCHEDULER_PROCESADO" -Target "$($tsEvents.Count) eventos" -Result "OK"
    }

    # ── Ordenar y exportar ────────────────────────────────────────────
    $sorted = @($allEvents | Sort-Object TimeCreated_UTC)
    $Script:ANSession.EVTXEvents = $sorted.Count

    Export-ANData -Data $sorted -Path (Join-Path $evtxOut "EVTX_Timeline.csv") -Description "Timeline EVTX consolidada"

    # Exportar subconjuntos de interes
    # @(): con un unico evento, Where-Object devuelve un objeto suelto cuyo .Count es
    # $null en PowerShell 5.1 y la alerta correspondiente no saltaba (un unico borrado
    # del log de auditoria pasaba sin alerta).
    $logons  = @($sorted | Where-Object { $_.EventID -in @(4624,4625,4634,4648) })
    $failed  = @($sorted | Where-Object { $_.EventID -eq 4625 })
    $newSvc  = @($sorted | Where-Object { $_.EventID -in @(7045,4697) })
    $psBlock = @($sorted | Where-Object { $_.EventID -eq 4104 })
    # Solo 1102 es "log de auditoria borrado". 1100 (servicio de registro de eventos
    # detenido) y 1104 (log de seguridad lleno) se conservan en la timeline con su
    # propia descripcion, pero no se presentan como borrado.
    $logCleared = @($sorted | Where-Object { $_.EventID -eq 1102 })
    $processes  = @($sorted | Where-Object { $_.EventID -eq 4688 })

    Export-ANData -Data $logons      -Path (Join-Path $evtxOut "EVTX_Logons.csv")         -Description "Logons"
    Export-ANData -Data $failed      -Path (Join-Path $evtxOut "EVTX_FailedLogons.csv")   -Description "Logons fallidos"
    Export-ANData -Data $newSvc      -Path (Join-Path $evtxOut "EVTX_NuevosServicios.csv")-Description "Nuevos servicios"
    Export-ANData -Data $psBlock     -Path (Join-Path $evtxOut "EVTX_PowerShell4104.csv") -Description "ScriptBlock PowerShell"
    Export-ANData -Data $logCleared  -Path (Join-Path $evtxOut "EVTX_LogBorrado.csv")     -Description "Log auditoria borrado"
    Export-ANData -Data $processes   -Path (Join-Path $evtxOut "EVTX_Procesos.csv")       -Description "Procesos creados (4688)"

    Write-ANLog -Phase "EVTX" -Action "ANALISIS_COMPLETO" -Target "Total $($sorted.Count) eventos relevantes extraidos" -Result "OK"

    # ── Alertas ───────────────────────────────────────────────────────
    if ($logCleared.Count -gt 0) {
        Write-ANLog -Phase "EVTX" -Action "ALERTA_LOG_BORRADO" -Target "$($logCleared.Count) eventos de borrado de log" -Result "WARNING"
    }
    if ($failed.Count -gt 5) {
        Write-ANLog -Phase "EVTX" -Action "ALERTA_LOGONS_FALLIDOS" -Target "$($failed.Count) logons fallidos detectados" -Result "WARNING"
    }
    if ($newSvc.Count -gt 0) {
        Write-ANLog -Phase "EVTX" -Action "ALERTA_NUEVOS_SERVICIOS" -Target "$($newSvc.Count) servicios nuevos instalados" -Result "WARNING"
    }
}

function Read-EVTXEvents {
    param(
        [string]$FilePath,
        [int[]]$EventIDs
    )

    $results = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path $FilePath)) { return $results }

    # BUG CONFIRMADO #1: el filtro XPath se limitaba SIEMPRE a los primeros 15
    # IDs de $EventIDs, descartando el resto sin ningun aviso ni bucle que los
    # procesara despues. La llamada real desde Invoke-EVTXAnalysis concatena
    # hasta 31 IDs para Security.evtx (Logon+AccountMgmt+AuditLog+Services+
    # Process); los que caian tras el 15 - incluyendo 1102 (log de auditoria
    # borrado) y 4688 (proceso creado), usados explicitamente mas abajo para
    # EVTX_LogBorrado.csv/EVTX_Procesos.csv y la alerta de log borrado - nunca
    # se consultaban contra Security.evtx, mientras el log seguia registrando
    # "SECURITY_PROCESADO OK", dando falsa sensacion de cobertura completa.
    # Ahora se trocea en lotes de <=15 y se ejecuta una consulta XPath por lote.
    $eventIdSet = [System.Collections.Generic.HashSet[int]]::new([int[]]$EventIDs)
    $batches = [System.Collections.Generic.List[object]]::new()
    for ($bi = 0; $bi -lt $EventIDs.Count; $bi += 15) {
        $end = [Math]::Min($bi + 14, $EventIDs.Count - 1)
        $batches.Add(@($EventIDs[$bi..$end]))
    }
    if ($batches.Count -eq 0) { $batches.Add(@()) }

    foreach ($batch in $batches) {
    try {
        $reader = $null
        try {
            if ($batch.Count -eq 0) { throw "sin IDs, forzar fallback sin XPath" }
            $xpathIds = ($batch | ForEach-Object { "EventID=$_" }) -join " or "
            $xpath    = "*[System[($xpathIds)]]"
            $query    = New-Object System.Diagnostics.Eventing.Reader.EventLogQuery(
                            $FilePath,
                            [System.Diagnostics.Eventing.Reader.PathType]::FilePath,
                            $xpath)
            $reader   = New-Object System.Diagnostics.Eventing.Reader.EventLogReader($query)
        } catch {
            # Fallback sin XPath (lee todo). BUG CONFIRMADO #2: el comentario
            # original decia "filtra en PS" pero esa comprobacion nunca
            # existia - se anadia CUALQUIER evento del log a los resultados,
            # ignorando por completo $EventIDs. Ahora si se filtra de verdad
            # mas abajo (comprobacion $eventIdSet.Contains($eid)).
            $reader = New-Object System.Diagnostics.Eventing.Reader.EventLogReader(
                          $FilePath,
                          [System.Diagnostics.Eventing.Reader.PathType]::FilePath)
        }

        while ($true) {
            try {
                $event = $reader.ReadEvent()
                if ($null -eq $event) { break }

                $eid = $event.Id
                if ($eventIdSet.Count -gt 0 -and -not $eventIdSet.Contains($eid)) { $event.Dispose(); continue }

                $props = @{}
                try {
                    $xml = [xml]$event.ToXml()
                    $eventData = $xml.Event.EventData.Data
                    if ($eventData) {
                        foreach ($d in $eventData) {
                            if ($d.Name) { $props[$d.Name] = $d.'#text' }
                        }
                    }
                } catch {}

                $obj = [PSCustomObject]@{
                    TimeCreated_UTC = $event.TimeCreated.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
                    EventID         = $eid
                    Categoria       = Get-EventCategory $eid
                    Log             = $event.LogName
                    ComputerName    = $event.MachineName
                    UserID          = if ($event.UserId) { $event.UserId.Value } else { "" }
                    TargetUser      = $props["TargetUserName"]
                    TargetDomain    = $props["TargetDomainName"]
                    SubjectUser     = $props["SubjectUserName"]
                    LogonType       = if ($props["LogonType"]) { "$($props['LogonType']) ($($Script:LogonTypes[[int]$props['LogonType']]))" } else { "" }
                    WorkstationName = $props["WorkstationName"]
                    IPAddress       = $props["IpAddress"]
                    ProcessName     = $props["NewProcessName"]
                    CommandLine     = $props["CommandLine"]
                    ServiceName     = if ($props["ServiceName"]) { $props["ServiceName"] } elseif ($props["param1"]) { $props["param1"] } else { "" }
                    ScriptBlock     = if ($props["ScriptBlockText"]) { $props["ScriptBlockText"].Substring(0, [math]::Min(500, $props["ScriptBlockText"].Length)) } else { "" }
                    Description     = Get-EventDescription $eid $props
                }

                $results.Add($obj)
                $event.Dispose()
            } catch { break }
        }
        $reader.Dispose()
    } catch {
        Write-ANLog -Phase "EVTX" -Action "ERROR_LEYENDO" -Target (Split-Path $FilePath -Leaf) -Result "WARNING" -Detail $_.Exception.Message
    }
    } # fin foreach ($batch in $batches)

    return $results
}

function Get-EventCategory {
    param([int]$ID)
    switch ($ID) {
        {$_ -in @(4624,4625,4634,4647,4648,4672,4778,4779)} { "Autenticacion" }
        {$_ -in @(4688,4689)}                                { "Proceso" }
        {$_ -in @(4697,7045)}                                { "Servicio Nuevo" }
        {$_ -in @(7034,7035,7036,7040)}                      { "Servicio" }
        {$_ -in @(4698,4702,4699,106,140,141,200,201)}       { "Tarea Programada" }
        {$_ -in @(4103,4104,4105,4106,400,403,600)}          { "PowerShell" }
        1102                                                 { "Log Borrado" }
        {$_ -in @(1100,1104)}                                { "Registro de Eventos" }
        {$_ -in @(6005,6006,6008,41)}                        { "Arranque/Apagado" }
        {$_ -in @(5860,5861,5857,5858,5859)}                 { "WMI" }
        {$_ -in @(1116,1117,1118,1119,5001,5004)}            { "Defender" }
        {$_ -in @(4720,4722,4724,4725,4726,4728,4732,4733,4735,4738,4740,4756)} { "Gestion Cuentas" }
        default                                               { "Otro" }
    }
}

function Get-EventDescription {
    param([int]$ID, [hashtable]$Props)
    switch ($ID) {
        4624 { "Logon exitoso: $($Props['TargetUserName'])@$($Props['TargetDomainName']) Tipo=$($Props['LogonType'])" }
        4625 { "Logon FALLIDO: $($Props['TargetUserName'])@$($Props['TargetDomainName']) Tipo=$($Props['LogonType'])" }
        4634 { "Logoff: $($Props['TargetUserName'])" }
        4648 { "Logon con credenciales explicitas: $($Props['TargetUserName'])" }
        4672 { "Privilegios especiales asignados: $($Props['SubjectUserName'])" }
        4688 { "Proceso creado: $($Props['NewProcessName'])" }
        4697 { "Servicio instalado: $($Props['ServiceName'])" }
        4698 { "Tarea programada creada: $($Props['TaskName'])" }
        4720 { "Cuenta creada: $($Props['TargetUserName'])" }
        4726 { "Cuenta eliminada: $($Props['TargetUserName'])" }
        4728 { "Usuario anadido a grupo global: $($Props['TargetUserName'])" }
        4732 { "Usuario anadido a grupo local (Administrators?): $($Props['TargetUserName'])" }
        4740 { "Cuenta bloqueada: $($Props['TargetUserName'])" }
        1100 { "Servicio de registro de eventos detenido (apagado del sistema o detencion del servicio)" }
        1102 { "Log de auditoria borrado por $($Props['SubjectUserName'])" }
        1104 { "Log de seguridad lleno: no se registran mas eventos" }
        7045 { "Nuevo servicio instalado: $($Props['param1']) Ruta: $($Props['param2'])" }
        4104 { "Script PowerShell ejecutado (ScriptBlock)" }
        6005 { "Inicio del sistema (Event Log Service iniciado)" }
        6006 { "Apagado del sistema" }
        6008 { "Apagado inesperado" }
        41   { "Kernel-Power: reinicio sin apagado correcto" }
        default { "" }
    }
}
#endregion ===== src\Core\EVTXAnalyzer.ps1 =====

#region ===== src\Core\BrowserSQLite.ps1 =====
#region ============================================================
# MaPeriT.AN - PARSER SQLite DE NAVEGADORES
# Lee los ficheros History/places.sqlite copiados por MaPeriT.SW.
# Intenta multiple metodos: Microsoft.Data.Sqlite, System.Data.SQLite,
# sqlite3.exe en PATH o en tools/. Sin internet.
# ============================================================

$Script:SQLiteAvailable = $false
$Script:SQLiteMethod    = "none"

function Initialize-SQLiteParser {
    # Metodo 1: Microsoft.Data.Sqlite (disponible en .NET 5+)
    try {
        Add-Type -AssemblyName "Microsoft.Data.Sqlite" -ErrorAction Stop
        $Script:SQLiteAvailable = $true
        $Script:SQLiteMethod    = "Microsoft.Data.Sqlite"
        Write-ANLog -Action "SQLITE_METODO" -Target "Microsoft.Data.Sqlite" -Result "OK"
        return $true
    } catch {}

    # Metodo 2: System.Data.SQLite
    $sqliteDllPaths = @(
        (Join-Path $env:ProgramFiles "System.Data.SQLite\System.Data.SQLite.dll"),
        (Join-Path $env:ProgramFiles "SQLite\System.Data.SQLite.dll"),
        "System.Data.SQLite.dll"
    )
    foreach ($dll in $sqliteDllPaths) {
        if (Test-Path $dll) {
            try {
                Add-Type -Path $dll -ErrorAction Stop
                $Script:SQLiteAvailable = $true
                $Script:SQLiteMethod    = "System.Data.SQLite"
                Write-ANLog -Action "SQLITE_METODO" -Target "System.Data.SQLite ($dll)" -Result "OK"
                return $true
            } catch {}
        }
    }

    # Metodo 3: sqlite3.exe en PATH o en carpeta tools de SW
    # Usar la ruta del script capturada al inicio (fiable en scripts compilados)
    $scriptDir = if ($Script:ANScriptRoot) { $Script:ANScriptRoot } else { $PSScriptRoot }
    $sqlite3Paths = @(
        "sqlite3.exe",
        (Join-Path $scriptDir "tools\sqlite3.exe"),
        (Join-Path $scriptDir "Bin\sqlite3.exe"),
        (Join-Path $scriptDir "sqlite3.exe"),
        (Join-Path $Script:ANSession.EvidencePath "tools\sqlite3.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Git\mingw64\bin\sqlite3.exe"),
        (Join-Path $env:ProgramFiles "Git\mingw64\bin\sqlite3.exe")
    )
    if ($env:ChocolateyInstall) {
        $sqlite3Paths += (Join-Path $env:ChocolateyInstall "bin\sqlite3.exe")
    }
    foreach ($s3 in $sqlite3Paths) {
        $resolved = Get-Command $s3 -ErrorAction SilentlyContinue
        if ($resolved -or (Test-Path $s3)) {
            $Script:SQLiteAvailable = $true
            $Script:SQLiteMethod    = "sqlite3.exe:$(if($resolved){$resolved.Source}else{$s3})"
            Write-ANLog -Action "SQLITE_METODO" -Target "sqlite3.exe" -Result "OK"
            return $true
        }
    }

    Write-ANLog -Action "SQLITE_NO_DISPONIBLE" -Target "Instale sqlite3.exe en PATH o en tools\" -Result "WARNING"
    return $false
}

function Invoke-SQLiteQuery {
    param([string]$DbPath, [string]$Query)

    if (-not (Test-Path $DbPath)) { return @() }

    # Trabajar sobre una copia temporal (los originales pueden estar en uso)
    $tmpDb = [System.IO.Path]::GetTempFileName() + ".db"
    Copy-Item $DbPath $tmpDb -Force -ErrorAction SilentlyContinue

    try {
        switch -Wildcard ($Script:SQLiteMethod) {
            "Microsoft.Data.Sqlite" {
                $connStr = "Data Source=$tmpDb;Mode=ReadOnly"
                $conn = New-Object Microsoft.Data.Sqlite.SqliteConnection($connStr)
                $conn.Open()
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = $Query
                $reader = $cmd.ExecuteReader()
                $results = @()
                while ($reader.Read()) {
                    $row = [ordered]@{}
                    for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                        $row[$reader.GetName($i)] = if ($reader.IsDBNull($i)) { "" } else { $reader.GetValue($i).ToString() }
                    }
                    $results += [PSCustomObject]$row
                }
                $reader.Close(); $conn.Close()
                return $results
            }
            "System.Data.SQLite" {
                $connStr = "Data Source=$tmpDb;Version=3;Read Only=True"
                $conn = New-Object System.Data.SQLite.SQLiteConnection($connStr)
                $conn.Open()
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = $Query
                $adapter = New-Object System.Data.SQLite.SQLiteDataAdapter($cmd)
                $dt = New-Object System.Data.DataTable
                [void]$adapter.Fill($dt)
                $conn.Close()
                return $dt.Rows | ForEach-Object {
                    $row = [ordered]@{}
                    foreach ($col in $dt.Columns) { $row[$col.ColumnName] = $_[$col.ColumnName].ToString() }
                    [PSCustomObject]$row
                }
            }
            "sqlite3.exe:*" {
                # BUG CONFIRMADO EN PRODUCCION: $Script:SQLiteMethod tiene forma
                # "sqlite3.exe:<ruta completa>", y la ruta completa (p.ej.
                # "I:\OneDrive\...\sqlite3.exe") tiene SU PROPIA letra de unidad
                # con dos puntos. Split(":") sin limite parte por TODOS los ":",
                # asi que [1] devolvia solo "I" en vez de la ruta - exactamente
                # el error visto en logs reales: "The term 'I' is not recognized".
                # Limitar a 2 partes (solo el primer ":") conserva la ruta intacta.
                $exe = ($Script:SQLiteMethod -split ':', 2)[1]
                $csv = & $exe $tmpDb ".mode csv" ".headers on" $Query 2>$null
                if ($csv) { return $csv | ConvertFrom-Csv }
                return @()
            }
        }
    } catch {
        Write-ANLog -Action "SQLITE_QUERY_ERROR" -Target $_.Exception.Message -Result "WARNING"
        return @()
    } finally {
        Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue
    }
}

# Convierte el timestamp de Chrome (microsegundos desde 1601-01-01 UTC) a texto UTC.
# AddTicks(us * 10) y no AddMicroseconds: este ultimo solo existe en .NET 7+ y en
# PowerShell 5.1 (.NET Framework) lanzaba excepcion -> TODAS las fechas de
# historial, descargas y busquedas salian vacias.
function ConvertFrom-ChromeTime {
    param([long]$ChromeTime)
    if ($ChromeTime -le 0) { return "" }
    try {
        $base = [datetime]::new(1601,1,1,0,0,0,[System.DateTimeKind]::Utc)
        return $base.AddTicks($ChromeTime * 10).ToString("yyyy-MM-dd HH:mm:ss")
    } catch { return "" }
}

# Firefox: microsegundos desde 1970-01-01 UTC
function ConvertFrom-FirefoxTime {
    param([long]$FirefoxTime)
    if ($FirefoxTime -le 0) { return "" }
    try {
        $base = [datetime]::new(1970,1,1,0,0,0,[System.DateTimeKind]::Utc)
        return $base.AddTicks($FirefoxTime * 10).ToString("yyyy-MM-dd HH:mm:ss")
    } catch { return "" }
}

function Invoke-BrowserAnalysis {
    param(
        [string]$BrowsersPath,
        [string]$OutputPath
    )

    Write-ANSection "ANALISIS NAVEGADORES - SQLite"
    $browsOut = Join-Path $OutputPath $Script:AN_Dirs.Browsers

    if (-not (Test-Path $BrowsersPath)) {
        Write-ANLog -Phase "BROWSER" -Action "CARPETA_NO_ENCONTRADA" -Target $BrowsersPath -Result "WARNING"
        return
    }

    $allHistory   = [System.Collections.Generic.List[object]]::new()
    $allDownloads = [System.Collections.Generic.List[object]]::new()
    $allSearches  = [System.Collections.Generic.List[object]]::new()

    # ── Chromium (Chrome, Edge, Brave) ────────────────────────────────
    foreach ($browser in @("Chrome","Edge","Brave")) {
        $browserDir = Join-Path $BrowsersPath $browser
        if (-not (Test-Path $browserDir)) { continue }

        Write-Host "  [*] Analizando $browser..." -ForegroundColor Yellow
        $histFiles = @(Get-ChildItem $browserDir -Recurse -Filter "History" -File -ErrorAction SilentlyContinue)

        foreach ($hf in $histFiles) {
            $userMatch = $hf.FullName -match "\\$browser\\([^\\]+)\\"
            $userName  = if ($userMatch) { $Matches[1] } else { "desconocido" }

            # URLs visitadas
            $urlQuery = "SELECT u.url, u.title, u.visit_count, u.last_visit_time, v.visit_time, v.from_visit, v.transition FROM urls u LEFT JOIN visits v ON u.id = v.url ORDER BY v.visit_time DESC LIMIT 50000"
            $rows = Invoke-SQLiteQuery -DbPath $hf.FullName -Query $urlQuery
            foreach ($row in $rows) {
                $allHistory.Add([PSCustomObject]@{
                    Navegador    = $browser
                    Usuario      = $userName
                    URL          = $row.url
                    Titulo       = $row.title
                    Visitas      = $row.visit_count
                    UltimaVisita = ConvertFrom-ChromeTime ([long]$row.last_visit_time)
                    FechaVisita  = ConvertFrom-ChromeTime ([long]$row.visit_time)
                })
            }

            # Descargas
            $dlQuery = "SELECT target_path, tab_url, start_time, end_time, total_bytes, danger_type, state FROM downloads ORDER BY start_time DESC LIMIT 5000"
            $dlRows = Invoke-SQLiteQuery -DbPath $hf.FullName -Query $dlQuery
            foreach ($row in $dlRows) {
                $allDownloads.Add([PSCustomObject]@{
                    Navegador    = $browser
                    Usuario      = $userName
                    RutaDestino  = $row.target_path
                    URLOrigen    = $row.tab_url
                    Inicio       = ConvertFrom-ChromeTime ([long]$row.start_time)
                    Fin          = ConvertFrom-ChromeTime ([long]$row.end_time)
                    TamanoBytes  = $row.total_bytes
                    TipoPeligro  = $row.danger_type
                    Estado       = $row.state
                })
            }

            # Busquedas (keywords extraidas de URLs)
            $searchQuery = "SELECT url, title, last_visit_time FROM urls WHERE url LIKE '%search%q=%' OR url LIKE '%?q=%' OR url LIKE '%&q=%' OR url LIKE '%query=%' OR url LIKE '%#q=%' ORDER BY last_visit_time DESC LIMIT 10000"
            $srRows = Invoke-SQLiteQuery -DbPath $hf.FullName -Query $searchQuery
            foreach ($row in $srRows) {
                $term = ""
                if ($row.url -match "[?&#]q=([^&]+)") { $term = [uri]::UnescapeDataString($Matches[1]) }
                elseif ($row.url -match "query=([^&]+)") { $term = [uri]::UnescapeDataString($Matches[1]) }
                if ($term) {
                    $allSearches.Add([PSCustomObject]@{
                        Navegador  = $browser
                        Usuario    = $userName
                        Busqueda   = $term
                        URL        = $row.url
                        Fecha      = ConvertFrom-ChromeTime ([long]$row.last_visit_time)
                    })
                }
            }
        }
        Write-ANLog -Phase "BROWSER" -Action "${browser}_ANALIZADO" -Target "$($histFiles.Count) perfiles" -Result "OK"
    }

    # ── Firefox ───────────────────────────────────────────────────────
    $ffDir = Join-Path $BrowsersPath "Firefox"
    if (Test-Path $ffDir) {
        Write-Host "  [*] Analizando Firefox..." -ForegroundColor Yellow
        $ffPlaces = @(Get-ChildItem $ffDir -Recurse -Filter "places.sqlite" -File -ErrorAction SilentlyContinue)
        foreach ($pf in $ffPlaces) {
            $userMatch = $pf.FullName -match "\\Firefox\\([^\\]+)\\"
            $userName  = if ($userMatch) { $Matches[1] } else { "desconocido" }

            # Firefox timestamps en microsegundos desde epoch Unix (diferente de Chrome)
            $ffQuery = "SELECT p.url, p.title, p.visit_count, p.last_visit_date, h.visit_date, h.visit_type FROM moz_places p LEFT JOIN moz_historyvisits h ON p.id = h.place_id ORDER BY h.visit_date DESC LIMIT 50000"
            $ffRows  = Invoke-SQLiteQuery -DbPath $pf.FullName -Query $ffQuery
            foreach ($row in $ffRows) {
                # Firefox usa microsegundos desde 1970-01-01 UTC
                $visitDate = if ($row.visit_date) { ConvertFrom-FirefoxTime ([long]$row.visit_date) } else { "" }
                $lastVisit = if ($row.last_visit_date) { ConvertFrom-FirefoxTime ([long]$row.last_visit_date) } else { "" }
                $allHistory.Add([PSCustomObject]@{
                    Navegador    = "Firefox"
                    Usuario      = $userName
                    URL          = $row.url
                    Titulo       = $row.title
                    Visitas      = $row.visit_count
                    UltimaVisita = $lastVisit
                    FechaVisita  = $visitDate
                })
            }
        }
        Write-ANLog -Phase "BROWSER" -Action "FIREFOX_ANALIZADO" -Target "$($ffPlaces.Count) perfiles" -Result "OK"
    }

    # ── Exportar ──────────────────────────────────────────────────────
    $Script:ANSession.BrowserURLs = $allHistory.Count

    Export-ANData -Data $allHistory.ToArray()   -Path (Join-Path $browsOut "Browser_Historial.csv")   -Description "Historial de navegacion"
    Export-ANData -Data $allDownloads.ToArray() -Path (Join-Path $browsOut "Browser_Descargas.csv")   -Description "Descargas"
    Export-ANData -Data $allSearches.ToArray()  -Path (Join-Path $browsOut "Browser_Busquedas.csv")   -Description "Terminos de busqueda"

    Write-ANLog -Phase "BROWSER" -Action "ANALISIS_COMPLETO" -Target "URLs=$($allHistory.Count) Descargas=$($allDownloads.Count) Busquedas=$($allSearches.Count)" -Result "OK"
}
#endregion ===== src\Core\BrowserSQLite.ps1 =====

#region ===== src\Analysis\TimestompDetector.ps1 =====
#region ============================================================
# MaPeriT.AN - DETECTOR DE TIMESTOMPING Y ANALISIS MFT
# ============================================================

function Invoke-TimestompAnalysis {
    param([string]$MFTOutputPath)

    $mftAll = Join-Path $MFTOutputPath "MFT_Completo.csv"
    $mftTs  = Join-Path $MFTOutputPath "MFT_Timestomping.csv"

    if (-not (Test-Path $mftTs)) { return $null }

    $tsData = @(Import-Csv $mftTs -ErrorAction SilentlyContinue)
    if (-not $tsData -or $tsData.Count -eq 0) { return $null }

    # Agrupar por tipo de razon
    $byReason = $tsData | Group-Object { $_.RazonTimestomp } |
                Sort-Object Count -Descending |
                ForEach-Object {
                    [PSCustomObject]@{
                        RazonTimestomp = $_.Name
                        Cantidad       = $_.Count
                        Ejemplos       = ($_.Group | Select-Object -First 3 | ForEach-Object { $_.RutaCompleta }) -join "; "
                    }
                }

    # Ficheros de sistema afectados (mas sospechosos)
    $sysAffected = $tsData | Where-Object { $_.RutaCompleta -match "Windows|System32|SysWOW64|Program Files" }

    return @{
        Total       = $tsData.Count
        ByReason    = $byReason
        SysAffected = $sysAffected
        Data        = $tsData
    }
}
#endregion ===== src\Analysis\TimestompDetector.ps1 =====

#region ===== src\Analysis\DeletedFiles.ps1 =====
#region ============================================================
# MaPeriT.AN - ANALISIS DE FICHEROS BORRADOS (MFT)
# ============================================================

function Invoke-DeletedFilesAnalysis {
    param([string]$MFTOutputPath)

    $mftDel = Join-Path $MFTOutputPath "MFT_Borrados.csv"
    if (-not (Test-Path $mftDel)) { return $null }

    $deleted = @(Import-Csv $mftDel -ErrorAction SilentlyContinue)
    if (-not $deleted) { return $null }

    # Agrupar por extension para el informe
    $byExt = $deleted | ForEach-Object {
        $ext = [System.IO.Path]::GetExtension($_.NombreFichero).ToLower()
        if (-not $ext) { $ext = "(sin extension)" }
        $ext
    } | Group-Object | Sort-Object Count -Descending | Select-Object -First 20 |
    ForEach-Object {
        [PSCustomObject]@{ Extension = $_.Name; Cantidad = $_.Count }
    }

    # Ficheros borrados potencialmente interesantes
    $interesting = $deleted | Where-Object {
        $_.NombreFichero -match "\.(doc|docx|pdf|xls|xlsx|ppt|pptx|zip|rar|7z|exe|dll|ps1|bat|cmd|vbs|js|py|txt|csv|db|sqlite|pfx|pem|key|cer)$"
    }

    return @{
        Total       = $deleted.Count
        ByExtension = $byExt
        Interesting = $interesting
        Data        = $deleted
    }
}
#endregion ===== src\Analysis\DeletedFiles.ps1 =====

#region ===== src\Analysis\Correlator.ps1 =====
#region ============================================================
# MaPeriT.AN - CORRELADOR MULTI-FUENTE
# Cruza MFT + EVTX + Navegadores + datos SW para una timeline
# de alta fidelidad y scoring de riesgo por entidad.
# ============================================================

function Invoke-Correlation {
    param(
        [string]$ANOutputPath,
        [string]$SWEvidencePath
    )

    Write-ANSection "CORRELACION MULTI-FUENTE"

    $mftPath   = Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Completo.csv"
    $evtxPath  = Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_Timeline.csv"
    $browsPath = Join-Path $ANOutputPath "$($Script:AN_Dirs.Browsers)\Browser_Historial.csv"
    $swTimeline= Join-Path $SWEvidencePath "$($Script:SW_Dirs.Analysis)\Timeline.csv"

    $timeline  = [System.Collections.Generic.List[object]]::new()
    $riskScores= [System.Collections.Generic.Dictionary[string, int]]::new()

    # ── Incorporar EVTX events ────────────────────────────────────────
    if (Test-Path $evtxPath) {
        $evtxData = @(Import-Csv $evtxPath -ErrorAction SilentlyContinue)
        foreach ($e in $evtxData) {
            $timeline.Add([PSCustomObject]@{
                Timestamp   = $e.TimeCreated_UTC
                ZonaHoraria = "UTC"
                Fuente      = "EVTX"
                EventID     = $e.EventID
                Categoria   = $e.Categoria
                Entidad     = if ($e.TargetUser) { $e.TargetUser } elseif ($e.SubjectUser) { $e.SubjectUser } else { "" }
                Descripcion = $e.Description
                Detalle     = "$($e.ProcessName) $($e.CommandLine) $($e.ServiceName)".Trim()
                Riesgo      = Get-EventRisk $e.EventID
            })
            # Acumular risk scores por usuario
            $user = if ($e.TargetUser) { $e.TargetUser } else { $e.SubjectUser }
            if ($user -and $user -ne "-" -and $user -ne "") {
                $riskScores[$user] = ($riskScores[$user] -as [int]) + (Get-EventRisk $e.EventID)
            }
        }
        Write-ANLog -Phase "CORR" -Action "EVTX_INCORPORADO" -Target "$($evtxData.Count) eventos" -Result "OK"
    }

    # ── Incorporar MFT timestomped ─────────────────────────────────────
    $mftTsPath = Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Timestomping.csv"
    if (Test-Path $mftTsPath) {
        $tsData = @(Import-Csv $mftTsPath -ErrorAction SilentlyContinue)
        foreach ($t in $tsData) {
            $timeline.Add([PSCustomObject]@{
                Timestamp   = $t.FN_Modificado_UTC
                ZonaHoraria = "UTC"
                Fuente      = "MFT_TIMESTOMP"
                EventID     = ""
                Categoria   = "Timestomping"
                Entidad     = $t.NombreFichero
                Descripcion = "Posible timestomping detectado: $($t.RazonTimestomp)"
                Detalle     = $t.RutaCompleta
                Riesgo      = 75
            })
        }
        Write-ANLog -Phase "CORR" -Action "MFT_TIMESTOMP_INCORPORADO" -Target "$($tsData.Count) entradas" -Result "OK"
    }

    # ── Incorporar ficheros borrados relevantes ─────────────────────────
    $mftDelPath = Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Borrados.csv"
    if (Test-Path $mftDelPath) {
        $delData = Import-Csv $mftDelPath -ErrorAction SilentlyContinue
        $interesting = @($delData | Where-Object {
            $_.NombreFichero -match "\.(exe|dll|ps1|bat|cmd|vbs|zip|rar|pdf|doc|xls)$"
        })
        foreach ($d in $interesting) {
            $timeline.Add([PSCustomObject]@{
                Timestamp   = $d.FN_Modificado_UTC
                ZonaHoraria = "UTC"
                Fuente      = "MFT_BORRADO"
                EventID     = ""
                Categoria   = "Fichero Borrado"
                Entidad     = $d.NombreFichero
                Descripcion = "Fichero borrado encontrado en MFT"
                Detalle     = $d.RutaCompleta
                Riesgo      = 30
            })
        }
        Write-ANLog -Phase "CORR" -Action "MFT_BORRADOS_INCORPORADO" -Target "$($interesting.Count) ficheros relevantes" -Result "OK"
    }

    # ── Incorporar timeline de SW ──────────────────────────────────────
    # Columnas reales de Analysis\Timeline.csv de MaPeriT.SW: Timestamp, Origen,
    # Categoria, Evento, Detalle, Usuario, Severidad (antes se leian Fuente/Tipo/
    # Entidad/Descripcion, que no existen, y los eventos de SW entraban vacios).
    # OJO: las horas de SW son hora LOCAL del equipo adquirido; las de EVTX/MFT son
    # UTC. La columna ZonaHoraria lo indica en cada fila.
    if (Test-Path $swTimeline) {
        $swData = @(Import-Csv $swTimeline -ErrorAction SilentlyContinue)
        foreach ($s in $swData) {
            $timeline.Add([PSCustomObject]@{
                Timestamp   = $s.Timestamp
                ZonaHoraria = "Local (equipo adquirido)"
                Fuente      = "SW_$($s.Origen)"
                EventID     = ""
                Categoria   = $s.Categoria
                Entidad     = $s.Usuario
                Descripcion = $s.Evento
                Detalle     = $s.Detalle
                Riesgo      = 10
            })
        }
        Write-ANLog -Phase "CORR" -Action "SW_TIMELINE_INCORPORADA" -Target "$($swData.Count) eventos SW" -Result "OK"
    }

    # ── Ordenar timeline ───────────────────────────────────────────────
    $sortedTimeline = @($timeline | Sort-Object Timestamp)
    Export-ANData -Data $sortedTimeline -Path (Join-Path $ANOutputPath "Correlacion_Timeline.csv") -Description "Timeline correlacionada"

    # ── Risk scores ───────────────────────────────────────────────────
    $scores = @($riskScores.GetEnumerator() | Sort-Object Value -Descending |
              ForEach-Object {
                  [PSCustomObject]@{
                      Entidad    = $_.Key
                      RiskScore  = $_.Value
                      Nivel      = if ($_.Value -gt 200) {"CRITICO"} elseif ($_.Value -gt 100) {"ALTO"} elseif ($_.Value -gt 50) {"MEDIO"} else {"BAJO"}
                  }
              })
    Export-ANData -Data $scores -Path (Join-Path $ANOutputPath "Correlacion_RiskScores.csv") -Description "Risk scores por entidad"

    Write-ANLog -Phase "CORR" -Action "CORRELACION_COMPLETA" -Target "Timeline=$($sortedTimeline.Count) eventos" -Result "OK"

    return @{
        Timeline   = $sortedTimeline
        RiskScores = $scores
    }
}

function Get-EventRisk {
    param([int]$EventID)
    switch ($EventID) {
        1102 { 90 }   # Log borrado
        1104 { 90 }   # Log borrado
        4697 { 80 }   # Servicio instalado
        7045 { 80 }   # Servicio nuevo
        4698 { 70 }   # Tarea programada
        4732 { 60 }   # Añadido a Administrators
        4720 { 50 }   # Cuenta creada
        4625 { 20 }   # Logon fallido
        4688 { 10 }   # Proceso creado
        4624 { 5  }   # Logon
        default { 5 }
    }
}
#endregion ===== src\Analysis\Correlator.ps1 =====

#region ===== src\Analysis\ShimcacheAmcache.ps1 =====
#region ============================================================
# MaPeriT.AN - ANALISIS SHIMCACHE Y AMCACHE
# ShimCache: registro de compatibilidad de aplicaciones.
# Amcache:   inventario de ejecutables y drivers instalados.
# Ambos revelan ejecucion de programas aunque no haya Event ID 4688.
# ============================================================

function Get-ANIOCHashSet {
    <#
        Carga una lista local de hashes conocidos (SHA1/SHA256/MD5, uno por linea;
        lineas vacias o que empiecen por # se ignoran) para correlacionar contra
        los hashes de Amcache. Coherente con la filosofia 100% offline del
        ecosistema (el aviso legal declara "No se realizan conexiones de red"):
        la lista la aporta el propio perito -- descargada aparte, de cualquier
        feed publico de IOCs que considere oportuno -- nunca se consulta nada en
        linea desde aqui.
    #>
    param([string]$Path)

    # Normalizado a MAYUSCULAS explicitamente (en vez de confiar en pasar
    # [System.StringComparer]::OrdinalIgnoreCase al constructor del HashSet):
    # verificado empiricamente que esa via NO aplicaba la comparacion insensible
    # a mayusculas/minusculas en este contexto - Contains() con una variante en
    # minusculas del mismo hash devolvia $false. Normalizar en el propio valor
    # es mas explicito y no depende de la resolucion de sobrecarga del
    # constructor.
    $set = [System.Collections.Generic.HashSet[string]]::new()
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) { return $set }

    try {
        $lines = Get-Content $Path -ErrorAction Stop
        foreach ($line in $lines) {
            $h = $line.Trim()
            if ([string]::IsNullOrEmpty($h) -or $h.StartsWith("#")) { continue }
            if ($h -match '^[A-Fa-f0-9]{32}$' -or $h -match '^[A-Fa-f0-9]{40}$' -or $h -match '^[A-Fa-f0-9]{64}$') {
                [void]$set.Add($h.ToUpper())
            }
        }
        Write-ANLog -Phase "IOC" -Action "IOC_HASHLIST_CARGADA" -Target "$($set.Count) hashes desde $Path" -Result "OK"
    } catch {
        Write-ANLog -Phase "IOC" -Action "IOC_HASHLIST_ERROR" -Target $Path -Result "WARNING" -Detail $_.Exception.Message
    }
    return $set
}

function Invoke-ShimcacheAnalysis {
    param(
        [string]$EvidencePath,
        [string]$OutputPath,
        [System.Collections.Generic.HashSet[string]]$IOCHashSet = $null
    )

    Write-ANSection "ANALISIS SHIMCACHE / AMCACHE"

    # ── ShimCache ───────────────────────────────────────────────────────
    # MaPeriT.SW deja ExtractedValues\ShimCache.csv (columna RutaEjecutable) y el
    # binario AppCompatCache.bin; MaPeriT.OF solo deja 04_Registry\AppCompatCache.bin.
    # Si no hay CSV se interpreta el binario (antes, con evidencias de OF, el
    # ShimCache no se analizaba).
    $regDir   = Join-Path $EvidencePath $Script:SW_Dirs.Registry
    $shimPath = Join-Path $regDir "ExtractedValues\ShimCache.csv"
    $shimData = @()
    if (Test-Path $shimPath) {
        $shimData = @(Import-Csv $shimPath -ErrorAction SilentlyContinue)
    } else {
        $binPath = @((Join-Path $regDir "ExtractedValues\AppCompatCache.bin"), (Join-Path $regDir "AppCompatCache.bin")) |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($binPath) {
            $shimData = @(ConvertFrom-ANShimCache -Data ([System.IO.File]::ReadAllBytes($binPath)))
            $shimPath = $binPath
        }
    }
    if ($shimPath -and (Test-Path $shimPath)) {
        if ($shimData.Count -gt 0) {
            Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_LEIDO" -Target "$($shimData.Count) entradas ($(Split-Path $shimPath -Leaf))" -Result "OK"

            # Filtrar ejecutables fuera de rutas estandar (mas sospechosos).
            # SW escribe la ruta en "RutaEjecutable"; se mantienen los nombres
            # alternativos por compatibilidad con CSV de versiones anteriores.
            $suspicious = @($shimData | Where-Object {
                $path = if ($_.RutaEjecutable) { $_.RutaEjecutable } elseif ($_.Ruta) { $_.Ruta } elseif ($_.Path) { $_.Path } elseif ($_.FileName) { $_.FileName } else { "" }
                # Prefijos de ruta NT ("\??\C:\..."), larga ("\\?\C:\...") y volumen del sistema ("SYSVOL\...")
                $norm = $path -replace '^\\\?\?\\', '' -replace '^\\\\\?\\', '' -replace '^SYSVOL\\', 'C:\'
                $norm -and
                $norm -notmatch "^[A-Za-z]:\\Windows\\" -and
                $norm -notmatch "^[A-Za-z]:\\Program Files" -and
                $norm -notmatch "^[A-Za-z]:\\ProgramData\\Microsoft"
            })

            Export-ANData -Data $shimData      -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\ShimCache_Completo.csv")     -Description "ShimCache completo"
            Export-ANData -Data $suspicious    -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\ShimCache_Sospechosos.csv")  -Description "ShimCache ejecutables fuera de rutas estandar"

            Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_SOSPECHOSOS" -Target "$($suspicious.Count) ejecutables fuera de rutas estandar" -Result $(if($suspicious.Count -gt 0){"WARNING"}else{"OK"})
        } else {
            Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_VACIO" -Target $shimPath -Result "WARNING"
        }
    } else {
        Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_NO_ENCONTRADO" -Target $shimPath -Result "WARNING"
    }

    # ── Amcache.hve (hive binario) ─────────────────────────────────────
    $amcachePath = Join-Path $EvidencePath "$($Script:SW_Dirs.Filesystem)\Amcache.hve"
    if (Test-Path $amcachePath) {
        Write-ANLog -Phase "SHIM" -Action "AMCACHE_ENCONTRADO" -Target $amcachePath -Result "OK"

        $amcacheData = @(Read-AmcacheHive -HivePath $amcachePath -OutputPath $OutputPath)
        if ($amcacheData.Count -gt 0) {
            Export-ANData -Data $amcacheData -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\Amcache_Ejecutables.csv") -Description "Amcache ejecutables"

            # Filtrar por hash SHA1 conocidos como maliciosos (listado basico de flags)
            # En produccion esto se conectaria con feeds de IOCs
            # FechaReferencia es texto crudo del registro (LinkDate/InstallDate, sin
            # formato garantizado) - un Sort-Object directo lo ordena como STRING,
            # no cronologicamente (p.ej. "9/1/2025" queda despues que "10/1/2025"),
            # por lo que "los 200 mas recientes" podia contener entradas antiguas y
            # omitir ejecuciones realmente recientes. Se ordena por fecha real
            # parseada (best-effort, sin descartar filas no parseables).
            $recentExes = @($amcacheData | Sort-Object -Descending -Property @{
                Expression = {
                    $dt = [datetime]::MinValue
                    if ($_.FechaReferencia) { [void][datetime]::TryParse($_.FechaReferencia, [ref]$dt) }
                    $dt
                }
            } | Select-Object -First 200)
            Export-ANData -Data $recentExes -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\Amcache_Recientes.csv") -Description "Amcache 200 mas recientes por fecha de referencia"

            # Correlacion con lista local de hashes IOC (opcional, ver -IOCHashListPath)
            if ($IOCHashSet -and $IOCHashSet.Count -gt 0) {
                $iocMatches = @($amcacheData | Where-Object { $_.SHA1 -and $IOCHashSet.Contains($_.SHA1.ToUpper()) })
                if ($iocMatches.Count -gt 0) {
                    Export-ANData -Data $iocMatches -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\Amcache_IOCMatches.csv") -Description "Amcache - coincidencias con lista de IOCs"
                    Write-ANLog -Phase "SHIM" -Action "ALERTA_IOC_AMCACHE" -Target "$($iocMatches.Count) ejecutables coinciden con la lista de hashes IOC" -Result "WARNING"
                } else {
                    Write-ANLog -Phase "SHIM" -Action "IOC_SIN_COINCIDENCIAS" -Target "$($IOCHashSet.Count) hashes IOC comprobados, sin coincidencias en Amcache" -Result "OK"
                }
            }

            Write-ANLog -Phase "SHIM" -Action "AMCACHE_PROCESADO" -Target "$($amcacheData.Count) ejecutables en Amcache" -Result "OK"
        }
    } else {
        Write-ANLog -Phase "SHIM" -Action "AMCACHE_NO_ENCONTRADO" -Target $amcachePath -Result "WARNING"
    }
}

function ConvertFrom-ANShimCache {
    <#
        Interpreta el binario AppCompatCache (formato de Windows 10/11) que deja
        MaPeriT.OF en 04_Registry\AppCompatCache.bin. Mismo formato y misma
        logica que Parse-ShimCache de MaPeriT.SW 1.7.5 (comprobado contra datos
        reales); la fecha se da en UTC porque AN no se ejecuta en el equipo
        adquirido. Otros formatos (Windows 7/8) quedan anotados en el log.
    #>
    param([byte[]]$Data)

    $entries = [System.Collections.Generic.List[object]]::new()
    if ($null -eq $Data -or $Data.Length -lt 52) { return $entries }

    try {
        $offset = [int][BitConverter]::ToUInt32($Data, 0)
        if (($offset -ne 0x30 -and $offset -ne 0x34) -or [BitConverter]::ToUInt32($Data, $offset) -ne 0x73743031) {
            Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_FORMATO_NO_SOPORTADO" -Target ("Cabecera 0x{0:X}: solo se interpreta el formato de Windows 10/11" -f $offset) -Result "WARNING"
            return $entries
        }
        $indice = 0
        while ($offset + 14 -le $Data.Length) {
            if ([BitConverter]::ToUInt32($Data, $offset) -ne 0x73743031) { break }   # "10ts"
            $entrySize  = [int][BitConverter]::ToUInt32($Data, $offset + 8)
            $pathLength = [int][BitConverter]::ToUInt16($Data, $offset + 12)
            $pathOffset = $offset + 14
            if ($entrySize -le 0 -or $pathOffset + $pathLength + 8 -gt $Data.Length) { break }

            $path    = [System.Text.Encoding]::Unicode.GetString($Data, $pathOffset, $pathLength)
            $lastMod = ""
            $ticks   = [BitConverter]::ToInt64($Data, $pathOffset + $pathLength)
            if ($ticks -gt 0) {
                try { $lastMod = [DateTime]::FromFileTimeUtc($ticks).ToString("yyyy-MM-dd HH:mm:ss") } catch { }
            }

            [void]$entries.Add([PSCustomObject]@{
                Indice                 = $indice
                RutaEjecutable         = $path.TrimEnd("`0")
                UltimaModificacion_UTC = $lastMod
            })
            $indice++
            $offset = $offset + 12 + $entrySize
        }
    } catch {
        Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_PARSE_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    return $entries
}

function Read-AmcacheHive {
    param([string]$HivePath, [string]$OutputPath)

    $results = [System.Collections.Generic.List[object]]::new()
    $tempKey = "MAPE_AMCACHE_$(Get-Random)"
    $mounted = $false

    # NUNCA se monta el Amcache.hve de la evidencia: "reg load" abre el fichero en
    # lectura-escritura, puede reescribirlo y crea .LOG1/.LOG2 junto a el, lo que
    # rompia el hash registrado en el manifiesto de la adquisicion. Se monta una
    # copia de trabajo en la carpeta de salida de AN que se borra al terminar.
    $workDir = Join-Path $OutputPath "_amcache_trabajo_$(Get-Random)"
    try {
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workHive = Join-Path $workDir "Amcache.hve"
        foreach ($ext in @("", ".LOG1", ".LOG2")) {
            if (Test-Path -LiteralPath "$HivePath$ext") {
                Copy-Item -LiteralPath "$HivePath$ext" -Destination "$workHive$ext" -Force -ErrorAction Stop
                (Get-Item -LiteralPath "$workHive$ext" -Force).Attributes = 'Normal'
            }
        }

        # Montar la copia en HKU temporal
        $loadResult = & reg.exe load "HKU\$tempKey" $workHive 2>&1
        if ($LASTEXITCODE -eq 0) { $mounted = $true }
        if ($LASTEXITCODE -ne 0) {
            Write-ANLog -Phase "SHIM" -Action "AMCACHE_MOUNT_ERROR" -Target ($loadResult -join " ") -Result "WARNING"
            return $results
        }

        # Leer InventoryApplicationFile (ejecutables)
        $appFilePath = "Registry::HKU\$tempKey\Root\InventoryApplicationFile"
        if (Test-Path $appFilePath) {
            Get-ChildItem $appFilePath -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                    $results.Add([PSCustomObject]@{
                        Nombre        = if ($props.Name) {$props.Name} elseif ($props.'(default)') {$props.'(default)'} else {""}
                        RutaFichero   = if ($props.LowerCaseLongPath) {$props.LowerCaseLongPath} elseif ($props.LongPathHash) {$props.LongPathHash} else {""}
                        SHA1          = if ($props.FileId) { ($props.FileId -replace "^0000","") } else {""}
                        Version       = $props.Version
                        Publisher     = $props.Publisher
                        # LinkDate es la fecha de COMPILACION del ejecutable (cabecera PE),
                        # no la de ejecucion: antes se publicaba como "FechaEjecucion".
                        FechaReferencia = if ($props.LinkDate) { $props.LinkDate } else { "" }
                        TipoFecha     = if ($props.LinkDate) { "Compilacion del ejecutable (LinkDate)" } else { "" }
                        ProgramID     = $props.ProgramId
                        Arquitectura  = $props.Architecture
                    })
                } catch {}
            }
        }

        # Leer InventoryApplication (aplicaciones instaladas)
        $appPath = "Registry::HKU\$tempKey\Root\InventoryApplication"
        if (Test-Path $appPath) {
            Get-ChildItem $appPath -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                    $results.Add([PSCustomObject]@{
                        Nombre        = $props.Name
                        RutaFichero   = $props.RootDirPath
                        SHA1          = ""
                        Version       = $props.Version
                        Publisher     = $props.Publisher
                        FechaReferencia = $props.InstallDate
                        TipoFecha     = if ($props.InstallDate) { "Instalacion (InstallDate)" } else { "" }
                        ProgramID     = $props.ProgramId
                        Arquitectura  = ""
                    })
                } catch {}
            }
        }

    } catch {
        Write-ANLog -Phase "SHIM" -Action "AMCACHE_READ_ERROR" -Target $_.Exception.Message -Result "WARNING"
    } finally {
        if ($mounted) {
            # Liberar los manejadores que Get-ItemProperty deja abiertos sobre el hive;
            # sin esto "reg unload" puede fallar con "acceso denegado".
            [System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers()
            $null = & reg.exe unload "HKU\$tempKey" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-ANLog -Phase "SHIM" -Action "AMCACHE_UNLOAD_ERROR" -Target "HKU\$tempKey" -Result "WARNING" -Detail "Desmontar a mano con: reg unload HKU\$tempKey"
            }
        }
        Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    return $results
}
#endregion ===== src\Analysis\ShimcacheAmcache.ps1 =====

#region ===== src\Analysis\USNJournal.ps1 =====
#region ============================================================
# MaPeriT.AN - ANALISIS USN JOURNAL
# El USN Journal registra TODAS las operaciones sobre ficheros NTFS:
# creacion, modificacion, renombrado, borrado, cambio de atributos.
# Es la fuente mas completa de actividad en el sistema de ficheros.
# ============================================================

function Invoke-USNJournalAnalysis {
    param(
        [string]$EvidencePath,
        [string]$OutputPath
    )

    Write-ANSection "ANALISIS USN JOURNAL"

    $usnPath = Join-Path $EvidencePath "$($Script:SW_Dirs.Filesystem)\UsnJournal.csv"
    if (-not (Test-Path $usnPath)) {
        Write-ANLog -Phase "USN" -Action "USN_NO_ENCONTRADO" -Target $usnPath -Result "WARNING"
        return
    }

    $usnSize = [math]::Round((Get-Item $usnPath).Length / 1MB, 1)
    Write-ANLog -Phase "USN" -Action "USN_ENCONTRADO" -Target "$usnSize MB" -Result "OK"

    # Leer en chunks para no colapsar memoria con ficheros grandes
    Write-Host "  [*] Leyendo USN Journal ($usnSize MB)..." -ForegroundColor Yellow
    # @(): con una sola entrada Import-Csv devuelve un objeto suelto sin .Count en PS 5.1
    $usnData = @(Import-Csv $usnPath -ErrorAction SilentlyContinue)
    if (-not $usnData -or $usnData.Count -eq 0) {
        Write-ANLog -Phase "USN" -Action "USN_VACIO" -Target $usnPath -Result "WARNING"
        return
    }

    Write-ANLog -Phase "USN" -Action "USN_LEIDO" -Target "$($usnData.Count) entradas" -Result "OK"

    # Detectar columnas disponibles (fsutil csv puede variar)
    $cols = $usnData[0].PSObject.Properties.Name
    $reasonCol  = $cols | Where-Object { $_ -match "Reason|reason" } | Select-Object -First 1
    $nameCol    = $cols | Where-Object { $_ -match "FileName|Name|filename" } | Select-Object -First 1
    $timeCol    = $cols | Where-Object { $_ -match "TimeStamp|Time|timestamp" } | Select-Object -First 1
    $fileIdCol  = $cols | Where-Object { $_ -match "FileId|fileId" } | Select-Object -First 1

    # Limite de filas exportadas por categoria (evita CSV/HTML inmanejables).
    # El recuento del resumen SIEMPRE se calcula sobre el total real (antes de
    # truncar), y se deja constancia explicita en el log cuando se trunca -
    # antes el resumen contaba solo las 5000 exportadas sin avisar de que
    # habia mas, lo que podia hacer perder actividad relevante sin que el
    # perito supiera que existia.
    $exportLimit = 5000

    # ── Operaciones de borrado ─────────────────────────────────────────
    $deletionsAll = @($usnData | Where-Object {
        $r = if ($reasonCol) { $_.$reasonCol } else { "" }
        $r -match "DELETE|CLOSE.*DELETE|0x.*80"
    })
    $deletions = $deletionsAll | Select-Object -First $exportLimit
    Export-ANData -Data $deletions -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\USN_Borrados.csv") -Description "Operaciones de borrado en USN"
    if ($deletionsAll.Count -gt $exportLimit) {
        Write-ANLog -Phase "USN" -Action "USN_BORRADOS_TRUNCADO" -Target "$($deletionsAll.Count) totales, solo se exportaron $exportLimit" -Result "WARNING"
    }

    # ── Operaciones de renombrado (ocultan actividad) ──────────────────
    $renamesAll = @($usnData | Where-Object {
        $r = if ($reasonCol) { $_.$reasonCol } else { "" }
        $r -match "RENAME"
    })
    $renames = $renamesAll | Select-Object -First $exportLimit
    Export-ANData -Data $renames -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\USN_Renombrados.csv") -Description "Operaciones de renombrado en USN"
    if ($renamesAll.Count -gt $exportLimit) {
        Write-ANLog -Phase "USN" -Action "USN_RENOMBRADOS_TRUNCADO" -Target "$($renamesAll.Count) totales, solo se exportaron $exportLimit" -Result "WARNING"
    }

    # ── Ejecutables creados/modificados ───────────────────────────────
    $execOpsAll = @($usnData | Where-Object {
        $n = if ($nameCol) { $_.$nameCol } else { "" }
        $n -match "\.(exe|dll|sys|bat|cmd|ps1|vbs|js|msi|scr|com|pif)$"
    })
    $execOps = $execOpsAll | Select-Object -First $exportLimit
    Export-ANData -Data $execOps -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\USN_Ejecutables.csv") -Description "Operaciones sobre ejecutables en USN"
    if ($execOpsAll.Count -gt $exportLimit) {
        Write-ANLog -Phase "USN" -Action "USN_EJECUTABLES_TRUNCADO" -Target "$($execOpsAll.Count) totales, solo se exportaron $exportLimit" -Result "WARNING"
    }

    # ── Actividad en directorios temporales / sospechosos ─────────────
    $suspiciousPathsAll = @($usnData | Where-Object {
        $n = if ($nameCol) { $_.$nameCol } else { "" }
        $n -match "Temp|tmp|\\Users\\.*\\Downloads|\\AppData\\Local\\Temp|recycle|Roaming\\Microsoft\\Windows\\Recent"
    })
    $suspiciousPaths = $suspiciousPathsAll | Select-Object -First $exportLimit
    Export-ANData -Data $suspiciousPaths -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\USN_RutasSospechosas.csv") -Description "Actividad en rutas sospechosas (Temp, Downloads, etc.)"
    if ($suspiciousPathsAll.Count -gt $exportLimit) {
        Write-ANLog -Phase "USN" -Action "USN_SOSPECHOSAS_TRUNCADO" -Target "$($suspiciousPathsAll.Count) totales, solo se exportaron $exportLimit" -Result "WARNING"
    }

    # ── Resumen estadistico (sobre el TOTAL real, no lo truncado) ─────
    $summary = [PSCustomObject]@{
        TotalEntradas       = $usnData.Count
        Borrados            = $deletionsAll.Count
        Renombrados         = $renamesAll.Count
        OperacionesEjecutables = $execOpsAll.Count
        RutasSospechosas    = $suspiciousPathsAll.Count
        PrimerEvento        = if ($timeCol) { ($usnData | Select-Object -First 1).$timeCol } else { "N/A" }
        UltimoEvento        = if ($timeCol) { ($usnData | Select-Object -Last 1).$timeCol } else { "N/A" }
    }
    Export-ANData -Data @($summary) -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\USN_Resumen.csv") -Description "Resumen USN Journal"

    Write-ANLog -Phase "USN" -Action "USN_COMPLETO" -Target "Total=$($usnData.Count) Borrados=$($deletionsAll.Count) Renombrados=$($renamesAll.Count) Ejecutables=$($execOpsAll.Count)" -Result "OK"

    if ($deletionsAll.Count -gt 500) {
        Write-ANLog -Phase "USN" -Action "ALERTA_MUCHOS_BORRADOS" -Target "$($deletionsAll.Count) operaciones de borrado detectadas" -Result "WARNING"
    }
}
#endregion ===== src\Analysis\USNJournal.ps1 =====

#region ===== src\Report\ReportTemplates.ps1 =====
#region ============================================================
# MaPeriT.AN - PLANTILLAS CSS/JS DEL INFORME
# Mismo diseño que MaPeriT.SW para coherencia visual.
# ============================================================

function Get-ANCss {
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
.cover{background:linear-gradient(135deg,#0f172a 0%,#1a3a5c 50%,#0f172a 100%);color:#fff;padding:72px 64px;min-height:560px;display:flex;flex-direction:column;justify-content:center}
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
.dtable tr.ts-row{background:#fff5f5}.dtable tr.ts-row:hover{background:#fee2e2}
.dtable tr.del-row{background:#fff8f1}.dtable tr.del-row:hover{background:#fed7aa}
.tnote{padding:7px 14px;background:#fffbeb;border-top:1px solid #fef3c7;font-size:11px;color:#92400e}
.badge{display:inline-flex;align-items:center;padding:2px 9px;border-radius:4px;font-size:11px;font-weight:600;white-space:nowrap}
.b-ok{background:#dcfce7;color:#15803d}.b-warn{background:#fef9c3;color:#a16207}.b-err{background:#fee2e2;color:#b91c1c}.b-ts{background:#fee2e2;color:#991b1b}.b-del{background:#ffedd5;color:#9a3412}
.alert{padding:10px 14px;border-radius:var(--r);margin:10px 0;font-size:13px}
.alert-warn{background:#fffbeb;border:1px solid #fef3c7;color:#92400e}.alert-info{background:#eff6ff;border:1px solid #dbeafe;color:#1d4ed8}.alert-ok{background:#f0fdf4;border:1px solid #dcfce7;color:#15803d}.alert-crit{background:#fef2f2;border:1px solid #fecaca;color:#991b1b}
details{margin:6px 0}
summary{display:flex;align-items:center;gap:8px;padding:10px 14px;background:#f8fafc;border:1px solid var(--c-border);border-radius:var(--r);cursor:pointer;font-weight:600;font-size:13px;list-style:none;user-select:none}
summary::before{content:'▶';font-size:10px;transition:transform .15s;flex-shrink:0}
details[open]>summary::before{transform:rotate(90deg)}details[open]>summary{border-radius:var(--r) var(--r) 0 0;border-bottom-color:transparent}
details[open]>.det-body{border:1px solid var(--c-border);border-top:none;border-radius:0 0 var(--r) var(--r);padding:14px;background:var(--c-surface)}
p{margin:8px 0}.report-footer{text-align:center;font-size:11px;color:var(--c-muted);border-top:1px solid var(--c-border);padding:20px 56px}
@media print{.sidebar{display:none}.main{margin-left:0}.content{padding:20px}.page-break{page-break-before:always}.dtable thead{background:#1e293b!important;-webkit-print-color-adjust:exact;print-color-adjust:exact}}
@page{size:A4;margin:1.5cm}
'@
}

function Get-ANJs {
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
#endregion ===== src\Report\ReportTemplates.ps1 =====

#region ===== src\Report\ReportGenerator.ps1 =====
#region ============================================================
# MaPeriT.AN - GENERADOR DEL INFORME AN HTML
# ============================================================

function New-ANReport {
    param(
        [string]$ANOutputPath,
        [string]$EvidencePath,
        [hashtable]$SWInfo,
        [hashtable]$CorrelationData
    )

    $reportFile = Join-Path $ANOutputPath "$($Script:AN_Dirs.Report)\InformeAN.html"
    $css = Get-ANCss; $js = Get-ANJs
    $dur = if ($Script:ANSession.EndTime) {
               ($Script:ANSession.EndTime - $Script:ANSession.StartTime).ToString('hh\:mm\:ss')
           } else { "En curso" }

    # Campos de sesion (numero de caso, equipo, perito, SO, ruta de evidencias)
    # interpolados en HTML: deben ir codificados. Add-ANSection (tablas CSV)
    # ya lo hacia de forma consistente; esta era la unica excepcion, mismo
    # patron de bug ya corregido en MaPeriT.SW.
    $caseNumberEnc = [System.Web.HttpUtility]::HtmlEncode($Script:ANSession.SWCaseNumber)
    $examinerEnc   = [System.Web.HttpUtility]::HtmlEncode($Script:ANSession.ExaminerName)
    $evidencePathEnc = [System.Web.HttpUtility]::HtmlEncode($Script:ANSession.EvidencePath)
    $computerNameEnc = [System.Web.HttpUtility]::HtmlEncode($SWInfo.ComputerName)
    $osVersionEnc    = [System.Web.HttpUtility]::HtmlEncode($SWInfo.OSVersion)

    Write-ANLog -Phase "INFORME" -Action "GENERANDO_INFORME_AN" -Target $reportFile -Result "OK"

    $html = [System.Text.StringBuilder]::new(300000)

    [void]$html.AppendLine(@"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>MaPeriT.AN - Informe de Analisis - Caso $caseNumberEnc</title>
<style>$css</style>
</head>
<body>
"@)

    # ── SIDEBAR ────────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<nav class="sidebar">
  <div class="sb-brand">
    <div class="sb-brand-name">MaPeriT.AN</div>
    <div class="sb-brand-sub">Analizador Forense Offline v$($Script:AN_VERSION)</div>
  </div>
  <div class="sb-case">
    <strong>Caso SW</strong>$caseNumberEnc
    <strong style="margin-top:6px">Equipo</strong>$computerNameEnc
    <strong style="margin-top:6px">Perito AN</strong>$examinerEnc
  </div>
  <nav>
    <div class="sb-label">Analisis</div>
    <a href="#sec1">1. Resumen Ejecutivo AN</a>
    <a href="#sec2">2. Analisis MFT</a>
    <a href="#sec3">3. Timestomping</a>
    <a href="#sec4">4. Ficheros Borrados</a>
    <a href="#sec5">5. Logs EVTX Profundos</a>
    <a href="#sec6">6. Navegadores (SQLite)</a>
    <a href="#sec6b">6b. ShimCache / Amcache</a>
    <a href="#sec6c">6c. USN Journal</a>
    <a href="#sec7">7. Timeline Correlacionada</a>
    <a href="#sec8">8. Risk Scores</a>
    <a href="#sec9">9. Conclusiones AN</a>
  </nav>
  <div class="sb-footer">
    Analisis: $(Get-Date -Format 'dd/MM/yyyy HH:mm')<br>
    Duracion: $dur<br>
    Errores: $($Script:ANSession.Errors) / Avisos: $($Script:ANSession.Warnings)
  </div>
</nav>
<div class="main">
"@)

    # ── PORTADA ────────────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div class="cover">
  <div class="cover-badge">Informe de Analisis Forense Profundo</div>
  <h1>MaPeriT.AN</h1>
  <h2>Analisis Offline de Evidencias &mdash; Caso $caseNumberEnc</h2>
  <div class="cover-grid">
    <div class="cover-item"><label>Caso SW</label><span>$caseNumberEnc</span></div>
    <div class="cover-item"><label>Equipo Analizado</label><span>$computerNameEnc</span></div>
    <div class="cover-item"><label>SO</label><span>$osVersionEnc</span></div>
    <div class="cover-item"><label>Perito AN</label><span>$examinerEnc</span></div>
    <div class="cover-item"><label>Registros MFT</label><span>$($Script:ANSession.MFTRecords)</span></div>
    <div class="cover-item"><label>Timestomping detectado</label><span>$($Script:ANSession.MFTTimestomped)</span></div>
    <div class="cover-item"><label>Eventos EVTX analizados</label><span>$($Script:ANSession.EVTXEvents)</span></div>
    <div class="cover-item"><label>URLs de navegacion</label><span>$($Script:ANSession.BrowserURLs)</span></div>
  </div>
</div>

<div class="content">
"@)

    # ── SEC 1: RESUMEN EJECUTIVO AN ────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec1">
<div class="section-hdr"><div class="sec-num">1</div><h2>Resumen Ejecutivo AN</h2></div>
<p>Este informe complementa el informe pericial de MaPeriT.SW con un analisis profundo offline.
Trabaja sobre las evidencias ya recopiladas en <strong>$evidencePathEnc</strong>
sin modificar ninguna de ellas: los resultados se escriben en la carpeta de salida del analisis y los
hives se consultan sobre copias de trabajo temporales. Todas las fechas se expresan en UTC salvo las
procedentes de la timeline de MaPeriT.SW (hora local del equipo adquirido, indicada en cada fila).</p>

<div class="stat-grid">
  <div class="stat-card ok"><div class="sv">$($Script:ANSession.MFTRecords)</div><div class="sl">Registros MFT validos</div></div>
  <div class="stat-card $(if($Script:ANSession.MFTTimestomped -gt 0){'ts'}else{'ok'})">
    <div class="sv">$($Script:ANSession.MFTTimestomped)</div><div class="sl">Sospecha de Timestomping</div>
  </div>
  <div class="stat-card del"><div class="sv">$($Script:ANSession.MFTDeleted)</div><div class="sl">Ficheros Borrados (MFT)</div></div>
  <div class="stat-card"><div class="sv">$($Script:ANSession.EVTXEvents)</div><div class="sl">Eventos EVTX relevantes</div></div>
  <div class="stat-card"><div class="sv">$($Script:ANSession.BrowserURLs)</div><div class="sl">URLs de navegacion</div></div>
  <div class="stat-card $(if($Script:ANSession.Errors -gt 0){'ts'}else{'ok'})">
    <div class="sv">$($Script:ANSession.Errors)</div><div class="sl">Errores de analisis</div>
  </div>
</div>
</div>
"@)

    # ── SEC 2: ANALISIS MFT ────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec2" class="page-break">
<div class="section-hdr"><div class="sec-num">2</div><h2>Analisis MFT — Master File Table</h2></div>
<p>El fichero <code>&#36;MFT</code> binario fue extraido en la adquisicion SW mediante acceso raw al dispositivo.
Se han parseado los atributos <code>&#36;STANDARD_INFORMATION</code> y <code>&#36;FILE_NAME</code> de cada File Record (1024 bytes).</p>

<div class="alert alert-info">
  <strong>&#36;STANDARD_INFORMATION (SI)</strong>: timestamps que el SO actualiza en operaciones normales y que <em>pueden ser manipulados</em> por herramientas antiforensicas.<br>
  <strong>&#36;FILE_NAME (FN)</strong>: timestamps mantenidos por NTFS, <em>mas dificiles de falsificar</em> sin acceso a bajo nivel.
  La discrepancia entre ambos es indicador de timestomping.
</div>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Completo.csv") -Title "2.1 Todos los registros MFT (muestra)" -MaxRows 500 -Collapsible -HighlightCol "Timestomping" -HighlightVal "True" -HighlightClass "ts-row"
    [void]$html.AppendLine("</div>")

    # ── SEC 3: TIMESTOMPING ────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec3" class="page-break">
<div class="section-hdr"><div class="sec-num">3</div><h2>Timestomping Detectado</h2></div>
<p>Indicadores fiables: timestamps <code>&#36;STANDARD_INFORMATION</code> anteriores a <code>&#36;FILE_NAME</code>
(imposible sin manipulacion directa). Se excluyen heuristicas de sub-segundo que generan falsos positivos
en ficheros del instalador de Windows.</p>
"@)
    if ($Script:ANSession.MFTTimestomped -gt 0) {
        [void]$html.AppendLine("<div class='alert alert-warn'>Se detectaron <strong>$($Script:ANSession.MFTTimestomped) ficheros</strong> con indicadores de timestomping.</div>")
        # Mostrar primero los que NO son de sistema (mas relevantes para la investigacion)
        [void]$html.AppendLine("<div class='sub-hdr'>3.1 Ficheros fuera de rutas de sistema (prioridad alta)</div>")
        $tsFile = Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Timestomping.csv"
        if (Test-Path $tsFile) {
            # @() para que los recuentos del titulo sean correctos tambien con una sola fila;
            # las rutas de ficheros borrados llevan el prefijo "[BORRADO] " (MFTParser).
            $tsAll     = @(Import-Csv $tsFile -ErrorAction SilentlyContinue)
            $sysRe     = '^(\[BORRADO\] )?(Windows\\|Program Files|ProgramData)'
            $tsNoSys   = @($tsAll | Where-Object { $_.RutaCompleta -notmatch $sysRe } | Select-Object -First 200)
            $tsSys     = @($tsAll | Where-Object { $_.RutaCompleta -match $sysRe }    | Select-Object -First 100)
            $tmpNoSys  = Join-Path $env:TEMP "ts_nosys_$(Get-Random).csv"
            $tmpSys    = Join-Path $env:TEMP "ts_sys_$(Get-Random).csv"
            $tsNoSys | Export-Csv $tmpNoSys -NoTypeInformation -Encoding UTF8 -Force
            $tsSys    | Export-Csv $tmpSys  -NoTypeInformation -Encoding UTF8 -Force
            Add-ANSection -Html $html -FilePath $tmpNoSys -Title "3.1 Timestomping fuera de rutas sistema ($($tsNoSys.Count) de $($tsAll.Count))" -MaxRows 200 -HighlightClass "ts-row"
            Add-ANSection -Html $html -FilePath $tmpSys   -Title "3.2 Timestomping en rutas sistema ($($tsSys.Count)) — menor prioridad" -MaxRows 50 -Collapsible
            Remove-Item $tmpNoSys,$tmpSys -Force -ErrorAction SilentlyContinue
        }
    } else {
        [void]$html.AppendLine("<div class='alert alert-ok'>No se detectaron indicadores fiables de timestomping.</div>")
    }
    [void]$html.AppendLine("</div>")

    # ── SEC 4: FICHEROS BORRADOS ───────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec4" class="page-break">
<div class="section-hdr"><div class="sec-num">4</div><h2>Ficheros Borrados (MFT)</h2></div>
<p>El MFT conserva los File Records de ficheros borrados hasta que la posicion es reutilizada.
Se han identificado <strong>$($Script:ANSession.MFTDeleted) ficheros borrados</strong> con nombre recuperable.</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Borrados.csv") -Title "4.1 Ficheros borrados (muestra)" -MaxRows 300 -Collapsible -HighlightClass "del-row"
    [void]$html.AppendLine("</div>")

    # ── SEC 5: EVTX ───────────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec5" class="page-break">
<div class="section-hdr"><div class="sec-num">5</div><h2>Logs EVTX — Analisis Profundo</h2></div>
<p>Procesados <strong>$($Script:ANSession.EVTXEvents) eventos</strong> relevantes de todos los ficheros .evtx copiados,
sin limite de eventos (a diferencia del analisis preliminar de SW).</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_LogBorrado.csv")      -Title "5.1 ALERTA: Log de Auditoria Borrado" -MaxRows 50
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_NuevosServicios.csv") -Title "5.2 ALERTA: Nuevos Servicios Instalados" -MaxRows 50
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_FailedLogons.csv")    -Title "5.3 Logons Fallidos" -MaxRows 100
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_Logons.csv")          -Title "5.4 Logons Exitosos" -MaxRows 100
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_PowerShell4104.csv")  -Title "5.5 Scripts PowerShell (ScriptBlock 4104)" -MaxRows 50
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_Procesos.csv")        -Title "5.6 Procesos Creados (4688)" -MaxRows 100 -Collapsible
    [void]$html.AppendLine("</div>")

    # ── SEC 6: NAVEGADORES ─────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec6" class="page-break">
<div class="section-hdr"><div class="sec-num">6</div><h2>Navegadores Web (SQLite)</h2></div>
<p>Historial completo extraido directamente de los ficheros SQLite copiados. <strong>$($Script:ANSession.BrowserURLs) URLs</strong> recuperadas.</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.Browsers)\Browser_Busquedas.csv")  -Title "6.1 Terminos de Busqueda" -MaxRows 200
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.Browsers)\Browser_Descargas.csv")  -Title "6.2 Descargas" -MaxRows 100
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.Browsers)\Browser_Historial.csv")  -Title "6.3 Historial de Navegacion" -MaxRows 500 -Collapsible
    [void]$html.AppendLine("</div>")

    # ── SEC 6b: SHIMCACHE / AMCACHE ───────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec6b" class="page-break">
<div class="section-hdr"><div class="sec-num">6b</div><h2>ShimCache / Amcache — Programas Registrados</h2></div>
<p>Estas fuentes registran la presencia de ejecutables en el equipo aunque no existan Event IDs 4688
(proceso creado) en los logs de auditoria. Son indicios, no prueba concluyente de ejecucion: en Windows 10/11
el ShimCache incluye programas solo examinados, su fecha es la ultima modificacion del fichero y la de Amcache
es la de compilacion (LinkDate) o instalacion (InstallDate), nunca la de ejecucion.</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\ShimCache_Sospechosos.csv") -Title "6b.1 ShimCache - Ejecutables fuera de rutas estandar" -MaxRows 200
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\Amcache_Recientes.csv")     -Title "6b.2 Amcache - Ejecutables mas recientes por fecha de referencia" -MaxRows 200
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\ShimCache_Completo.csv")   -Title "6b.3 ShimCache completo" -MaxRows 500 -Collapsible
    [void]$html.AppendLine("</div>")

    # ── SEC 6c: USN JOURNAL ────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec6c" class="page-break">
<div class="section-hdr"><div class="sec-num">6c</div><h2>USN Journal — Operaciones en Sistema de Ficheros</h2></div>
<p>El USN Journal registra cada operacion NTFS (creacion, modificacion, renombrado, borrado).
Es la fuente mas completa para reconstruir actividad en el disco.</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\USN_Resumen.csv")          -Title "6c.0 Resumen USN Journal" -MaxRows 10
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\USN_Borrados.csv")         -Title "6c.1 Operaciones de Borrado" -MaxRows 200
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\USN_Renombrados.csv")      -Title "6c.2 Operaciones de Renombrado" -MaxRows 200
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\USN_Ejecutables.csv")      -Title "6c.3 Operaciones sobre Ejecutables" -MaxRows 300
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\USN_RutasSospechosas.csv") -Title "6c.4 Actividad en Rutas Sospechosas (Temp, Downloads)" -MaxRows 200
    [void]$html.AppendLine("</div>")

    # ── SEC 7: TIMELINE CORRELACIONADA ─────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec7" class="page-break">
<div class="section-hdr"><div class="sec-num">7</div><h2>Timeline Correlacionada</h2></div>
<p>Cronologia unificada que integra eventos EVTX, timestamps MFT, ficheros borrados y timeline de MaPeriT.SW.</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "Correlacion_Timeline.csv") -Title "7.1 Timeline completa" -MaxRows 500 -Collapsible
    [void]$html.AppendLine("</div>")

    # ── SEC 8: RISK SCORES ─────────────────────────────────────────────
    [void]$html.AppendLine(@"
<div id="sec8" class="page-break">
<div class="section-hdr"><div class="sec-num">8</div><h2>Risk Scores por Entidad</h2></div>
<p>Puntuacion de riesgo acumulada por usuario/entidad segun eventos EVTX (log borrado=90pts, servicio nuevo=80pts, etc.).</p>
"@)
    Add-ANSection -Html $html -FilePath (Join-Path $ANOutputPath "Correlacion_RiskScores.csv") -Title "8.1 Puntuacion de riesgo" -MaxRows 50
    [void]$html.AppendLine("</div>")

    # ── SEC 9: CONCLUSIONES AN ─────────────────────────────────────────
    $dateStr = (Get-Date).ToString("dd 'de' MMMM 'de' yyyy")
    [void]$html.AppendLine(@"
<div id="sec9" class="page-break">
<div class="section-hdr"><div class="sec-num">9</div><h2>Conclusiones AN</h2></div>
<p>El analisis profundo offline sobre las evidencias del caso <strong>$caseNumberEnc</strong>
ha procesado <strong>$($Script:ANSession.MFTRecords) registros MFT</strong>,
<strong>$($Script:ANSession.EVTXEvents) eventos de log</strong> y
<strong>$($Script:ANSession.BrowserURLs) URLs de navegacion</strong>.</p>

$(if ($Script:ANSession.MFTTimestomped -gt 0) {
"<div class='alert alert-crit'>Se han detectado <strong>$($Script:ANSession.MFTTimestomped) ficheros con indicadores de timestomping</strong>. Esto puede indicar manipulacion deliberada de timestamps para ocultar actividad. Se recomienda investigacion adicional de los ficheros listados en la seccion 3.</div>"
})

<p>Este informe debe interpretarse conjuntamente con el Informe Pericial de MaPeriT.SW.
Ambos documentos forman la evidencia tecnica completa del caso.</p>

<div style="margin-top:60px;display:grid;grid-template-columns:1fr 1fr;gap:48px;padding-top:32px;border-top:2px solid #e2e8f0">
  <div style="text-align:center"><div style="border-top:1px solid #94a3b8;margin-top:70px;padding-top:8px;font-size:13px">En __________, a $dateStr<br><br>$examinerEnc<br><em>Perito Informatico</em></div></div>
  <div style="text-align:center"><div style="border-top:1px solid #94a3b8;margin-top:70px;padding-top:8px;font-size:13px">Recibido: _______________<br><br>&nbsp;<br><em>Firma y sello</em></div></div>
</div>
</div>

</div><!-- /content -->

<div class="report-footer">
  Informe generado por <strong>MaPeriT.AN v$($Script:AN_VERSION)</strong> &bull;
  Caso: $caseNumberEnc &bull;
  Perito: $examinerEnc &bull;
  Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
</div>

</div><!-- /main -->
<script>$js</script>
</body></html>
"@)

    $html.ToString() | Out-File -FilePath $reportFile -Encoding UTF8
    Write-ANLog -Phase "INFORME" -Action "INFORME_AN_GENERADO" -Target $reportFile -Result "OK"
    return $reportFile
}

function Add-ANSection {
    param(
        [System.Text.StringBuilder]$Html,
        [string]$FilePath,
        [string]$Title,
        [int]$MaxRows      = 100,
        [switch]$Collapsible,
        [string]$HighlightCol   = "",
        [string]$HighlightVal   = "",
        [string]$HighlightClass = ""
    )

    $safeId = "t_" + ($Title -replace '[^a-zA-Z0-9]','_')

    if ($Collapsible) {
        [void]$Html.AppendLine("<details><summary>$([System.Web.HttpUtility]::HtmlEncode($Title))</summary><div class='det-body'>")
    } else {
        [void]$Html.AppendLine("<div class='sub-hdr'>$([System.Web.HttpUtility]::HtmlEncode($Title))</div>")
    }

    if (-not (Test-Path $FilePath)) {
        [void]$Html.AppendLine("<p><em style='color:#94a3b8'>Sin datos disponibles.</em></p>")
        if ($Collapsible) { [void]$Html.AppendLine("</div></details>") }
        return
    }

    try {
        $data = @(Import-Csv $FilePath -ErrorAction Stop | Select-Object -First $MaxRows)
        $totalInFile = @(Import-Csv $FilePath -ErrorAction SilentlyContinue).Count

        if ($data.Count -eq 0) {
            [void]$Html.AppendLine("<p><em style='color:#94a3b8'>Sin registros.</em></p>")
        } else {
            $cols = $data[0].PSObject.Properties.Name
            $showSearch = $totalInFile -gt 15
            $searchId = $safeId + "_s"
            $tableId  = $safeId + "_tbl"
            $monoCols = @('Hash','SHA256','SHA-256','RutaCompleta','FullPath','URL','CommandLine','ScriptBlock','SI_Creado_UTC','SI_Modificado_UTC','FN_Creado_UTC','FN_Modificado_UTC')
            $wrapCols = @('Descripcion','Description','Detalle','RazonTimestomp','TimestompReason','ScriptBlock')

            [void]$Html.AppendLine("<div class='tcard'>")
            [void]$Html.AppendLine("<div class='ttoolbar'>")
            [void]$Html.AppendLine("  <span class='ttoolbar-label'>$($data.Count) / $totalInFile registros</span>")
            if ($showSearch) {
                [void]$Html.AppendLine("  <input class='tsearch' id='$searchId' type='text' placeholder='Filtrar...' oninput=""filterTable('$searchId','$tableId')"">")
            }
            [void]$Html.AppendLine("</div><div class='twrap'>")
            [void]$Html.AppendLine("<table class='dtable' id='$tableId'><thead><tr>")
            foreach ($col in $cols) { [void]$Html.AppendLine("<th>$([System.Web.HttpUtility]::HtmlEncode($col))</th>") }
            [void]$Html.AppendLine("</tr></thead><tbody>")

            foreach ($row in $data) {
                $rowClass = ""
                if ($HighlightCol -and $HighlightClass) {
                    if ($row.$HighlightCol -eq $HighlightVal) { $rowClass = " class='$HighlightClass'" }
                } elseif ($HighlightClass) { $rowClass = " class='$HighlightClass'" }

                [void]$Html.Append("<tr$rowClass>")
                foreach ($col in $cols) {
                    $raw = if ($null -eq $row.$col) { "" } else { $row.$col.ToString() }
                    $enc = [System.Web.HttpUtility]::HtmlEncode($raw)
                    $cls = ""
                    if ($monoCols -contains $col) { $cls = " class='mono'" }
                    elseif ($wrapCols -contains $col) { $cls = " class='w'" }
                    $titleAttr = if ($raw.Length -gt 60 -and $cls -notlike "*w*") { " title='$([System.Web.HttpUtility]::HtmlEncode($raw))'" } else { "" }
                    if ($enc.Length -gt 80 -and $cls -notlike "*w*") { $enc = $enc.Substring(0,77) + "&#8230;" }
                    [void]$Html.Append("<td$cls$titleAttr>$enc</td>")
                }
                [void]$Html.AppendLine("</tr>")
            }
            [void]$Html.AppendLine("</tbody></table></div>")
            if ($totalInFile -gt $MaxRows) {
                [void]$Html.AppendLine("<div class='tnote'>Mostrando $MaxRows de $totalInFile. Fichero completo: $(Split-Path $FilePath -Leaf)</div>")
            }
            [void]$Html.AppendLine("</div>")
        }
    } catch {
        [void]$Html.AppendLine("<div class='alert alert-warn'>Error al leer: $([System.Web.HttpUtility]::HtmlEncode($_.Exception.Message))</div>")
    }

    if ($Collapsible) { [void]$Html.AppendLine("</div></details>") }
}
#endregion ===== src\Report\ReportGenerator.ps1 =====

#region ===== src\Main.ps1 =====
#region ============================================================
# MaPeriT.AN - PUNTO DE ENTRADA
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

# La carga de System.Web.HttpUtility (usado por New-ANReport) ahora la
# garantiza ..\Common\HtmlEncoding.ps1, incluido antes en la compilacion -
# ver ese fichero para el bug confirmado que motivo el cambio (la carga
# podia fallar en silencio, dejando todo HtmlEncode roto).

# Capturar ruta del script ANTES de cualquier cambio de directorio
# (necesario para localizar tools\ en scripts compilados)
$Script:ANScriptRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($Script:ANScriptRoot)) {
    $Script:ANScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

# ── Validar y preparar rutas ───────────────────────────────────────────
try { [void](Test-SWEvidencePath -Path $EvidencePath) }
catch {
    Write-Host ""
    Write-Host "  [-] ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

if ([string]::IsNullOrEmpty($OutputPath)) {
    $OutputPath = Join-Path $EvidencePath "ANALISIS_AN"
}

# ── Inicializar ────────────────────────────────────────────────────────
Initialize-ANOutputStructure -OutputPath $OutputPath
Initialize-ANLogging -LogsPath (Join-Path $OutputPath $Script:AN_Dirs.Logs)

$swInfo = Initialize-ANSession -EvidencePath $EvidencePath -OutputPath $OutputPath -ExaminerName $ExaminerName
Show-ANBanner -SWInfo $swInfo

Write-ANLog -Action "AN_INICIADO" -Target $EvidencePath -Result "OK"

# ── Inicializar C# helpers ─────────────────────────────────────────────
$mftReady    = Initialize-MFTParser
$sqliteReady = Initialize-SQLiteParser

# ── MODULO 1: Analisis MFT ────────────────────────────────────────────
if (-not $SkipMFT) {
    $mftFile = Join-Path $EvidencePath "$($Script:SW_Dirs.Filesystem)\`$MFT"
    if ($mftReady -and (Test-Path $mftFile)) {
        Invoke-MFTAnalysis -MFTPath $mftFile -OutputPath $OutputPath -MaxRecords $MaxMFTRecords
    } elseif (-not (Test-Path $mftFile)) {
        Write-ANLog -Phase "MFT" -Action "MFT_NO_ENCONTRADO" -Target $mftFile -Result "WARNING"
        Write-Host "  [!] $MFT no encontrado en las evidencias. Saltando analisis MFT." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [~] Analisis MFT omitido (-SkipMFT)" -ForegroundColor DarkGray
    Write-ANLog -Action "MFT_SALTADO" -Result "SKIP"
}

# ── MODULO 2: Analisis EVTX ───────────────────────────────────────────
if (-not $SkipEVTX) {
    $evtxDir = Join-Path $EvidencePath $Script:SW_Dirs.EventLogs
    if (Test-Path $evtxDir) {
        Invoke-EVTXAnalysis -EventLogsPath $evtxDir -OutputPath $OutputPath
    } else {
        Write-ANLog -Phase "EVTX" -Action "DIR_NO_ENCONTRADO" -Target $evtxDir -Result "WARNING"
    }
} else {
    Write-ANLog -Action "EVTX_SALTADO" -Result "SKIP"
}

# ── MODULO 3: Analisis Navegadores ────────────────────────────────────
if (-not $SkipBrowsers) {
    if ($sqliteReady) {
        $browsDir = Join-Path $EvidencePath $Script:SW_Dirs.Browsers
        if (Test-Path $browsDir) {
            Invoke-BrowserAnalysis -BrowsersPath $browsDir -OutputPath $OutputPath
        } else {
            Write-ANLog -Phase "BROWSER" -Action "DIR_NO_ENCONTRADO" -Target $browsDir -Result "WARNING"
        }
    } else {
        Write-ANLog -Phase "BROWSER" -Action "SQLITE_NO_DISPONIBLE" -Target "Coloque sqlite3.exe en PATH o en tools\" -Result "WARNING"
    }
} else {
    Write-ANLog -Action "BROWSERS_SALTADO" -Result "SKIP"
}

# ── Cargar lista de hashes IOC (opcional, 100% offline) ───────────────
$iocHashPath = $IOCHashListPath
if ([string]::IsNullOrWhiteSpace($iocHashPath)) {
    $defaultIOCCandidates = @(
        (Join-Path $Script:ANScriptRoot "tools\IOC_Hashes.txt"),
        (Join-Path $Script:ANScriptRoot "IOC_Hashes.txt")
    )
    $iocHashPath = $defaultIOCCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
$iocHashSet = if ($iocHashPath) { Get-ANIOCHashSet -Path $iocHashPath } else { [System.Collections.Generic.HashSet[string]]::new() }

# ── MODULO 4: ShimCache / Amcache ────────────────────────────────────
Invoke-ShimcacheAnalysis -EvidencePath $EvidencePath -OutputPath $OutputPath -IOCHashSet $iocHashSet

# ── MODULO 5: USN Journal ─────────────────────────────────────────────
Invoke-USNJournalAnalysis -EvidencePath $EvidencePath -OutputPath $OutputPath

# ── MODULO 6: Correlacion ─────────────────────────────────────────────
Write-Host ""
$correlation = Invoke-Correlation -ANOutputPath $OutputPath -SWEvidencePath $EvidencePath

# ── Finalizar sesion ──────────────────────────────────────────────────
$Script:ANSession.EndTime = Get-Date
$duration = ($Script:ANSession.EndTime - $Script:ANSession.StartTime).ToString('hh\:mm\:ss')

# ── Generar informe ───────────────────────────────────────────────────
Write-ANSection "GENERANDO INFORME AN"
$reportPath = New-ANReport -ANOutputPath $OutputPath -EvidencePath $EvidencePath -SWInfo $swInfo -CorrelationData $correlation

# ── Resumen final ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "  =================================================================" -ForegroundColor Green
Write-Host "              ANALISIS FORENSE AN COMPLETADO                       " -ForegroundColor Green
Write-Host "  =================================================================" -ForegroundColor Green
Write-Host "  Duracion:         $duration"                                        -ForegroundColor White
Write-Host "  Registros MFT:    $($Script:ANSession.MFTRecords)"                  -ForegroundColor White
Write-Host "  Timestomping:     $($Script:ANSession.MFTTimestomped) sospechosos"  -ForegroundColor $(if($Script:ANSession.MFTTimestomped -gt 0){"Red"}else{"White"})
Write-Host "  Borrados MFT:     $($Script:ANSession.MFTDeleted)"                  -ForegroundColor Yellow
Write-Host "  Eventos EVTX:     $($Script:ANSession.EVTXEvents)"                  -ForegroundColor White
Write-Host "  URLs navegacion:  $($Script:ANSession.BrowserURLs)"                 -ForegroundColor White
Write-Host "  Errores:          $($Script:ANSession.Errors)"                       -ForegroundColor $(if($Script:ANSession.Errors -gt 0){"Red"}else{"White"})
Write-Host "  Salida AN:        $OutputPath"                                       -ForegroundColor Cyan
Write-Host "  Informe:          $reportPath"                                       -ForegroundColor Cyan
Write-Host "  =================================================================" -ForegroundColor Green
Write-Host ""

Write-ANLog -Action "AN_COMPLETADO" -Target $OutputPath -Result "OK" -Detail "Duracion=$duration MFT=$($Script:ANSession.MFTRecords) EVTX=$($Script:ANSession.EVTXEvents) URLs=$($Script:ANSession.BrowserURLs)"
#endregion ===== src\Main.ps1 =====


