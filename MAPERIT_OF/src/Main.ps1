#region ============================================================
# MaPeriT.OF - PUNTO DE ENTRADA PRINCIPAL
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

# Capturar ruta del script antes de cualquier cambio de contexto
$Script:OFSession.ScriptPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot (Split-Path $MyInvocation.MyCommand.Path -Leaf) } `
                                else { $MyInvocation.MyCommand.Path }
if (-not (Test-Path $Script:OFSession.ScriptPath -ErrorAction SilentlyContinue)) {
    $Script:OFSession.ScriptPath = $MyInvocation.MyCommand.Path
}

# Unico punto de verdad de la version: Config.ps1 define TOOL_VERSION una sola vez,
# el banner solo tiene un marcador {VERSION} que se sustituye aqui.
$Script:Banner = $Script:Banner -replace '\{VERSION\}', $Script:TOOL_VERSION

# --- Modo verificacion (no toca ningun disco objetivo) ---
if (-not [string]::IsNullOrEmpty($VerifyPath)) {
    Write-Host ""
    Write-Host "  MaPeriT.OF - MODO VERIFICACION DE INTEGRIDAD" -ForegroundColor Cyan
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $VerifyPath)) {
        Write-Host "  [-] Directorio no encontrado: $VerifyPath" -ForegroundColor Red
        exit 1
    }

    $manifestFile = Get-ChildItem -Path $VerifyPath -Filter "HashManifest.csv" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $manifestFile) {
        Write-Host "  [-] HashManifest.csv no encontrado en $VerifyPath" -ForegroundColor Red
        exit 1
    }

    Write-Host "  [*] Directorio:  $VerifyPath" -ForegroundColor White
    Write-Host "  [*] Manifiesto:  $($manifestFile.FullName)" -ForegroundColor White
    Write-Host ""

    $verifyResult = Test-HashManifest -ManifestPath $manifestFile.FullName -EvidenceRootPath $VerifyPath -ShowProgress

    Write-Host ""
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host "  RESULTADO DE VERIFICACION" -ForegroundColor Cyan
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host "  Total en manifiesto:  $($verifyResult.Total)" -ForegroundColor White
    Write-Host "  Verificados OK:       $($verifyResult.Verified)" -ForegroundColor Green
    if ($verifyResult.Missing -gt 0) {
        Write-Host "  Ficheros faltantes:   $($verifyResult.Missing)" -ForegroundColor Red
    }
    if ($verifyResult.Mismatches -gt 0) {
        Write-Host "  Hashes NO coinciden:  $($verifyResult.Mismatches)" -ForegroundColor Red
    }
    if ($verifyResult.Success) {
        Write-Host "  INTEGRIDAD VERIFICADA: Todas las evidencias intactas" -ForegroundColor Green
    } else {
        Write-Host "  INTEGRIDAD COMPROMETIDA: Se detectaron discrepancias" -ForegroundColor Red
    }
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host ""
    # Codigo de salida 0 = integridad verificada, 1 = discrepancias (antes era
    # siempre 0, y un script de automatizacion no podia detectar el fallo).
    if ($verifyResult.Success) { exit 0 } else { exit 1 }
}

# --- Validar parametros obligatorios para modo adquisicion ---
if ([string]::IsNullOrEmpty($TargetDisk) -or [string]::IsNullOrEmpty($CaseNumber) -or [string]::IsNullOrEmpty($ExaminerName)) {
    Write-Host "  [-] ERROR: -TargetDisk, -CaseNumber y -ExaminerName son obligatorios para adquisicion." -ForegroundColor Red
    Write-Host "  Use -VerifyPath para verificar una adquisicion previa." -ForegroundColor Yellow
    exit 1
}

# --- Exclusion de rutas (-ExcludePaths) ---
if ($ExcludePaths -and $ExcludePaths.Count -gt 0) {
    $Script:ExcludePathPatterns = $ExcludePaths
    Write-Host "  [*] Exclusion de rutas activa ($($ExcludePaths.Count) patron(es)):" -ForegroundColor Yellow
    $ExcludePaths | ForEach-Object { Write-Host "      - $_" -ForegroundColor Yellow }
} else {
    $Script:ExcludePathPatterns = @()
}

# Mostrar banner
Write-Host $Script:Banner -ForegroundColor Cyan

# --- Inicializacion ---
try {
    $resolvedOutput = Initialize-OFSession `
        -TargetDisk          $TargetDisk `
        -CaseNumber          $CaseNumber `
        -ExaminerName        $ExaminerName `
        -OutputPath          $OutputPath `
        -EvidenceDescription $EvidenceDescription `
        -TargetUser          $TargetUser
} catch {
    Write-Host ""
    Write-Host "  [-] ERROR CRITICO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Show-OFBanner

# --- Ejecutar fases ---
$phaseResults = @{}

$allPhases = @(
    @{ Num=2;  Fn={ Invoke-Phase2-SystemInfo    -OutputPath $resolvedOutput } },
    @{ Num=3;  Fn={ Invoke-Phase3-Filesystem    -OutputPath $resolvedOutput } },
    @{ Num=4;  Fn={ Invoke-Phase4-Registry      -OutputPath $resolvedOutput } },
    @{ Num=5;  Fn={ Invoke-Phase5-EventLogs     -OutputPath $resolvedOutput } },
    @{ Num=6;  Fn={ Invoke-Phase6-Browsers      -OutputPath $resolvedOutput } },
    @{ Num=7;  Fn={ Invoke-Phase7-Communications -OutputPath $resolvedOutput } },
    @{ Num=8;  Fn={ Invoke-Phase8-CloudStorage  -OutputPath $resolvedOutput } },
    @{ Num=9;  Fn={ Invoke-Phase9-USB           -OutputPath $resolvedOutput } },
    @{ Num=10; Fn={ Invoke-Phase10-Persistence  -OutputPath $resolvedOutput } }
)

foreach ($phase in $allPhases) {
    if ($phase.Num -in $PhasesToSkip) {
        Write-Host ""
        Write-Host "  [~] Fase $($phase.Num) omitida (-SkipPhases)" -ForegroundColor DarkGray
        Write-ForensicLog -Phase "FASE_$($phase.Num)" -Action "FASE_OMITIDA" -Target "SkipPhases" -Result "SKIP"
        $phaseResults[$phase.Num] = 0
        $Script:OFSession.PhasesSkipped += $phase.Num
        continue
    }
    try {
        $phaseResults[$phase.Num] = & $phase.Fn
    } catch {
        Write-ForensicLog -Phase "FASE_$($phase.Num)" -Action "FASE_EXCEPCION" -Target $_.Exception.Message -Result "ERROR"
        $phaseResults[$phase.Num] = 0
        $Script:OFSession.PhasesFailed += $phase.Num
    }
}

# --- Limpiar todos los hives cargados (seguridad ante excepciones) ---
Dismount-AllOfflineHives

# --- Generar manifiesto y firmar ---
$Script:OFSession.EndTime = Get-Date
Write-Host ""
Write-Host "  ═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  GENERANDO MANIFIESTO Y FIRMANDO EVIDENCIAS..." -ForegroundColor Cyan

$manifestPath = Export-HashManifest -OutputPath $resolvedOutput -HMACKey $HMACKey

# --- Generar informe HTML ---
Write-Host "  GENERANDO INFORME HTML..." -ForegroundColor Cyan
$reportPath = New-OFReport -OutputPath $resolvedOutput -EvidenceDescription $EvidenceDescription

# --- Resumen final ---
$duration    = ($Script:OFSession.EndTime - $Script:OFSession.StartTime).ToString('hh\:mm\:ss')
$totalSizeMB = [math]::Round($Script:OFSession.TotalSizeBytes / 1MB, 2)

Write-Host ""
Write-Host "  =================================================================" -ForegroundColor Green
Write-Host "              ADQUISICION OFFLINE COMPLETADA                        " -ForegroundColor Green
Write-Host "  =================================================================" -ForegroundColor Green
Write-Host "  Caso              : $CaseNumber"                                   -ForegroundColor White
Write-Host "  Disco analizado   : $($Script:OFSession.TargetRoot)"               -ForegroundColor White
Write-Host "  SO objetivo       : $($Script:OFSession.TargetOS)"                 -ForegroundColor White
Write-Host "  Equipo objetivo   : $($Script:OFSession.TargetComputer)"           -ForegroundColor White
Write-Host "  Duracion          : $duration"                                     -ForegroundColor White
Write-Host "  Ficheros copiados : $($Script:OFSession.TotalFiles)"               -ForegroundColor White
Write-Host "  Tamano total      : $totalSizeMB MB"                               -ForegroundColor White
Write-Host "  Errores           : $($Script:OFSession.Errors)"                  -ForegroundColor $(if($Script:OFSession.Errors -gt 0){"Red"}else{"White"})
Write-Host "  Advertencias      : $($Script:OFSession.Warnings)"                -ForegroundColor $(if($Script:OFSession.Warnings -gt 0){"Yellow"}else{"White"})
Write-Host "  Salida            : $resolvedOutput"                               -ForegroundColor Cyan
Write-Host "  Manifiesto        : $manifestPath"                                 -ForegroundColor Cyan
Write-Host "  Informe           : $reportPath"                                   -ForegroundColor Cyan
Write-Host "  =================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Para analisis profundo ejecute MaPeriT.AN:" -ForegroundColor Yellow
Write-Host "  .\MaPeriT.AN.ps1 -EvidencePath `"$resolvedOutput`"" -ForegroundColor Yellow
Write-Host ""

Write-ForensicLog -Action "OF_COMPLETADO" -Target $resolvedOutput -Result "OK" `
    -Detail "Duracion=$duration Ficheros=$($Script:OFSession.TotalFiles) Tamano=${totalSizeMB}MB Errores=$($Script:OFSession.Errors)"
