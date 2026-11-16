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
