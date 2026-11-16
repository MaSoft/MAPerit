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
