#region ============================================================
# MaPeriT.SW - PUNTO DE ENTRADA (EJECUCION)
# Este fichero se ejecuta despues de cargar todos los modulos
# ============================================================

# --- Punto de entrada ---
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# La carga de System.Web.HttpUtility (usado por los generadores de informe)
# ahora la garantiza ..\Common\HtmlEncoding.ps1, incluido antes en la
# compilacion - ver ese fichero para el bug confirmado que motivo el cambio
# (la carga podia fallar en silencio, dejando todo HtmlEncode roto).

# --- Modo Dry-Run (preflight de solo lectura, sin CaseNumber/ExaminerName) ---
if ($DryRun) {
    Invoke-DryRunPreflight -ScriptPath $PSCommandPath
    exit 0
}

# --- Modo Self-Test (prueba de la cadena de integridad, sin CaseNumber/ExaminerName) ---
if ($SelfTest) {
    $selfTestOk = Invoke-SelfTest
    if ($selfTestOk) { exit 0 } else { exit 1 }
}

# --- Modo verificacion ---
if (-not [string]::IsNullOrEmpty($VerifyPath)) {
    Write-Host ""
    Write-Host "  MaPeriT.SW - MODO VERIFICACION DE INTEGRIDAD" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $VerifyPath)) {
        Write-Host "  [-] Directorio no encontrado: $VerifyPath" -ForegroundColor Red
        exit 1
    }

    $manifestPath = Get-ChildItem -Path $VerifyPath -Recurse -Filter "HashManifest.csv" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $manifestPath) {
        Write-Host "  [-] HashManifest.csv no encontrado en $VerifyPath" -ForegroundColor Red
        exit 1
    }

    Write-Host "  [*] Directorio:  $VerifyPath" -ForegroundColor White
    Write-Host "  [*] Manifiesto:  $($manifestPath.FullName)" -ForegroundColor White
    Write-Host ""

    # Verificacion delegada a Test-HashManifest (Core\Hashing.ps1) - unica
    # implementacion de esta logica en todo el proyecto, ver comentario en esa funcion.
    $verifyResult = Test-HashManifest -ManifestPath $manifestPath.FullName -EvidenceRootPath $VerifyPath -ShowProgress

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
if ([string]::IsNullOrEmpty($CaseNumber) -or [string]::IsNullOrEmpty($ExaminerName)) {
    Write-Host "  [-] ERROR: -CaseNumber y -ExaminerName son obligatorios para adquisicion." -ForegroundColor Red
    Write-Host "  Use -VerifyPath para verificar una adquisicion previa." -ForegroundColor Yellow
    exit 1
}

# Resolver OutputPath por defecto
if ([string]::IsNullOrEmpty($OutputPath)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputPath = Join-Path (Get-Location) "MaPeriT_${CaseNumber}_${timestamp}"
}

# Ruta de salida siempre absoluta y en forma larga. Con una ruta relativa
# (".\Caso1") o en formato corto 8.3 ("C:\Users\NOMBRE~1\...") los ficheros
# se enumeran con su ruta larga, que no comparte prefijo con OutputPath, y el
# manifiesto de hashes se generaba con TODAS las rutas relativas vacias:
# la verificacion posterior con -VerifyPath era imposible.
$OutputPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine((Get-Location -PSProvider FileSystem).ProviderPath, $OutputPath))
if (-not (Test-Path -LiteralPath $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
$OutputPath = (Get-Item -LiteralPath $OutputPath).FullName.TrimEnd('\')

# --- Verificacion de prerequisitos ---
$issues = Test-Prerequisites
if ($issues.Count -gt 0) {
    Write-Host ""
    Write-Host "  [!] ERRORES DE PREREQUISITOS:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "      - $issue" -ForegroundColor Red
    }
    Write-Host ""
    exit 1
}

# --- Aplicar opciones de configuracion en tiempo de ejecucion ---
if ($MaxEventsPerQuery -gt 0) {
    Write-Host "  [*] Limite de eventos por consulta sobrescrito a $MaxEventsPerQuery (por defecto $($Script:Defaults.MaxEventsPerQuery))" -ForegroundColor Yellow
    $Script:Defaults.MaxEventsPerQuery = $MaxEventsPerQuery
}

if ($ExcludePaths -and $ExcludePaths.Count -gt 0) {
    $Script:ExcludePathPatterns = $ExcludePaths
    Write-Host "  [*] Exclusion de rutas activa ($($ExcludePaths.Count) patron(es)):" -ForegroundColor Yellow
    $ExcludePaths | ForEach-Object { Write-Host "      - $_" -ForegroundColor Yellow }
} else {
    $Script:ExcludePathPatterns = @()
}

if ($ChainOfCustodyStrictMode) {
    $Script:ChainOfCustodyStrictMode = $true
    Write-Host "  [*] Modo estricto de cadena de custodia activo (-ChainOfCustodyStrictMode)" -ForegroundColor Yellow
} else {
    $Script:ChainOfCustodyStrictMode = $false
}

# --- Inicializar helpers C# ---
$csharpReady = Initialize-CSharpHelpers

# --- Crear estructura de directorios ---
Initialize-OutputStructure -OutputPath $OutputPath | Out-Null

# --- Inicializar logging ---
Initialize-Logging -LogsPath (Join-Path $OutputPath $Script:OutputDirs.Logs)

# --- Inicializar sesion ---
$session = Initialize-ForensicSession `
    -CaseNumber $CaseNumber `
    -ExaminerName $ExaminerName `
    -OutputPath $OutputPath `
    -ScriptPath $PSCommandPath `
    -EvidenceDescription $EvidenceDescription `
    -HMACKey $HMACKey

# --- Mostrar banner ---
Show-SessionBanner

# --- Crear VSS Snapshot ---
Write-Host ""
Write-Host "  === PREPARACION ===" -ForegroundColor Cyan

# -NetworkIsolationCheck: se documenta lo antes posible (dato altamente volatil, RFC 3227)
# y antes de crear el VSS para no retrasar la captura de este estado.
if ($NetworkIsolationCheck) {
    Write-Host "  [*] Comprobando estado de red del equipo (-NetworkIsolationCheck)..." -ForegroundColor Yellow
    $netIsolationState = Test-NetworkIsolationState
    if ($netIsolationState) {
        $netCheckPath = Join-Path $OutputPath "$($Script:OutputDirs.Volatile)\NetworkIsolationCheck.json"
        Export-CollectionToJSON -Data $netIsolationState -OutputPath $netCheckPath -Phase "FASE_1" -Description "Estado de aislamiento de red al inicio de la adquisicion"
    }
}

$vssReady = New-ForensicVSSSnapshot -Volume "C:\"
if (-not $vssReady) {
    Write-Host "  [!] No se pudo crear VSS Snapshot. Algunos ficheros bloqueados no podran copiarse." -ForegroundColor Yellow
}

# --- Ejecutar fases ---
$totalCollected = 0
$phaseResults = @{}

for ($phase = 1; $phase -le 10; $phase++) {
    Write-ProgressBanner -CurrentPhase $phase -TotalPhases 10 -PhaseName $Script:PhaseNames[$phase]

    if ($phase -in $PhasesToSkip) {
        Write-Host "`n  [~] Fase $phase ($($Script:PhaseNames[$phase])) OMITIDA por configuracion" -ForegroundColor Yellow
        $Script:SessionInfo.PhasesSkipped += $phase
        Write-ForensicLog -Phase "FASE_$phase" -Action "FASE_OMITIDA" -Target $Script:PhaseNames[$phase] -Result "SKIP"
        continue
    }

    try {
        $phaseCollected = 0

        $phaseRaw = switch ($phase) {
            1  { Invoke-Phase1-VolatileCollection -OutputPath $OutputPath }
            2  { Invoke-Phase2-SystemInfoCollection -OutputPath $OutputPath }
            3  { Invoke-Phase3-FilesystemCollection -OutputPath $OutputPath }
            4  { Invoke-Phase4-RegistryCollection -OutputPath $OutputPath }
            5  { Invoke-Phase5-EventLogCollection -OutputPath $OutputPath }
            6  { Invoke-Phase6-BrowserCollection -OutputPath $OutputPath }
            7  { Invoke-Phase7-CommunicationsCollection -OutputPath $OutputPath }
            8  { Invoke-Phase8-CloudStorageCollection -OutputPath $OutputPath }
            9  { Invoke-Phase9-USBCollection -OutputPath $OutputPath }
            10 { Invoke-Phase10-PersistenceCollection -OutputPath $OutputPath }
        }
        $phaseCollected = if ($phaseRaw -is [array]) { [int]($phaseRaw[-1]) } else { [int]$phaseRaw }

        $totalCollected += $phaseCollected
        $phaseResults[$phase] = $phaseCollected
        $Script:SessionInfo.PhasesCompleted += $phase

        if ($Script:CurrentPhaseStart) {
            $phaseDuration = ((Get-Date) - $Script:CurrentPhaseStart).TotalMinutes
            if ($phaseDuration -gt $Script:Defaults.PhaseTimeoutMinutes) {
                Write-ForensicLog -Phase "FASE_$phase" -Action "FASE_TIMEOUT_SUPERADO" -Target "Duracion: $([math]::Round($phaseDuration,1)) min (limite: $($Script:Defaults.PhaseTimeoutMinutes) min)" -Result "WARNING"
                $Script:SessionInfo.TotalWarnings++
            }
        }

    } catch {
        Write-Host "`n  [-] ERROR EN FASE ${phase}: $($_.Exception.Message)" -ForegroundColor Red
        Write-ForensicLog -Phase "FASE_$phase" -Action "FASE_ERROR_GENERAL" -Target $_.Exception.Message -Result "ERROR"
        $Script:SessionInfo.PhasesFailed += $phase
        $Script:SessionInfo.TotalErrors++
    }
}

# --- Analisis ---
Write-Host ""
Write-Host "  === ANALISIS ===" -ForegroundColor Cyan

Write-PhaseHeader -PhaseNumber 11 -PhaseName "Analisis y Deteccion"

try {
    $timelineCount = Build-ForensicTimeline -OutputPath $OutputPath
    Write-ForensicLog -Phase "ANALISIS" -Action "TIMELINE" -Target "$timelineCount eventos en timeline" -Result "OK"
} catch {
    Write-ForensicLog -Phase "ANALISIS" -Action "TIMELINE_ERROR" -Target $_.Exception.Message -Result "ERROR"
}

try {
    $iocCount = Export-ForensicIOCs -OutputPath $OutputPath
    Write-ForensicLog -Phase "ANALISIS" -Action "IOCS" -Target "$iocCount indicadores extraidos" -Result "OK"
} catch {
    Write-ForensicLog -Phase "ANALISIS" -Action "IOCS_ERROR" -Target $_.Exception.Message -Result "ERROR"
}

$anomalyCount = 0
try {
    $anomalyCount = Find-ForensicAnomalies -OutputPath $OutputPath
    Write-ForensicLog -Phase "ANALISIS" -Action "ANOMALIAS" -Target "$anomalyCount anomalias detectadas" -Result "OK"
} catch {
    Write-ForensicLog -Phase "ANALISIS" -Action "ANOMALIAS_ERROR" -Target $_.Exception.Message -Result "ERROR"
}

# --- Integridad ---
Write-Host ""
Write-Host "  === VERIFICACION DE INTEGRIDAD ===" -ForegroundColor Cyan

$manifestPath = Join-Path $OutputPath "$($Script:OutputDirs.Logs)\HashManifest.csv"
$hashedCount = New-HashManifest -EvidenceRootPath $OutputPath -ManifestPath $manifestPath

if (-not [string]::IsNullOrEmpty($HMACKey)) {
    $hmacPath = Join-Path $OutputPath "$($Script:OutputDirs.Logs)\ManifestHMAC.txt"
    New-EvidenceHMAC -ManifestPath $manifestPath -Key $HMACKey -OutputPath $hmacPath
}

# --- Finalizar sesion ---
Complete-ForensicSession

# --- Generar informes ---
Write-Host ""
Write-Host "  === GENERACION DE INFORMES ===" -ForegroundColor Cyan

try {
    New-ChainOfCustodyReport -OutputPath $OutputPath
    Write-Host "  [+] Cadena de Custodia generada" -ForegroundColor Green
} catch {
    Write-Host "  [-] Error al generar Cadena de Custodia: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    New-ForensicReport -OutputPath $OutputPath
    Write-Host "  [+] Informe Pericial generado" -ForegroundColor Green
} catch {
    Write-Host "  [-] Error al generar Informe: $($_.Exception.Message)" -ForegroundColor Red
}

# --- Limpieza ---
Write-Host ""
Write-Host "  === LIMPIEZA ===" -ForegroundColor Cyan
Remove-ForensicVSSSnapshot

if ($Script:HivesNoDesmontadas -and $Script:HivesNoDesmontadas.Count -gt 0) {
    Write-Host ""
    Write-Host "  [!!!] AVISO CRITICO: EL EQUIPO ANALIZADO HA QUEDADO MODIFICADO" -ForegroundColor Red
    Write-Host "  Las siguientes claves de registro NO se pudieron desmontar y siguen" -ForegroundColor Red
    Write-Host "  cargadas en HKEY_USERS del equipo objetivo. Desmontelas manualmente" -ForegroundColor Red
    Write-Host "  con 'reg unload <clave>' antes de devolver o reiniciar el equipo:" -ForegroundColor Red
    foreach ($k in $Script:HivesNoDesmontadas) {
        Write-Host "      - $k" -ForegroundColor Red
    }
    Write-Host ""
}

# --- Resumen final ---
Write-Host ""
Write-Host "  =================================================================" -ForegroundColor Green
Write-Host "              PERITACION FORENSE COMPLETADA                        " -ForegroundColor Green
Write-Host "  =================================================================" -ForegroundColor Green
Write-Host "  Artefactos:  $totalCollected (elementos recopilados en fases)" -ForegroundColor White
Write-Host "  Evidencias:  $($Script:SessionInfo.TotalEvidences) (piezas en cadena de custodia)" -ForegroundColor White
Write-Host "  Hashes:      $hashedCount" -ForegroundColor White
Write-Host "  Anomalias:   $anomalyCount" -ForegroundColor White
Write-Host "  Directorio:  $OutputPath" -ForegroundColor White
if ($Script:HivesNoDesmontadas -and $Script:HivesNoDesmontadas.Count -gt 0) {
    Write-Host "  AVISO:       $($Script:HivesNoDesmontadas.Count) hive(s) de registro sin desmontar - ver arriba" -ForegroundColor Red
}
if ($Script:ChainOfCustodyStrictMode) {
    if ($Script:StrictCustodyFailures -and $Script:StrictCustodyFailures.Count -gt 0) {
        Write-Host "  Custodia:    FALLIDA - $($Script:StrictCustodyFailures.Count) evidencia(s) con hash invalido (-ChainOfCustodyStrictMode)" -ForegroundColor Red
    } else {
        Write-Host "  Custodia:    OK - todos los hashes verificados (-ChainOfCustodyStrictMode)" -ForegroundColor Green
    }
}
Write-Host "  =================================================================" -ForegroundColor Green
Write-Host ""

$exitCode = 0

# -ChainOfCustodyStrictMode: senalizacion agresiva al finalizar (no aborta la adquisicion
# en curso). Si hubo evidencias con hash invalido, el chequeo final de integridad se
# marca explicitamente como FALLIDO, de forma muy visible, y el codigo de salida del
# proceso permite detectarlo desde scripts de automatizacion que envuelvan la herramienta.
if ($Script:ChainOfCustodyStrictMode -and $Script:StrictCustodyFailures -and $Script:StrictCustodyFailures.Count -gt 0) {
    Write-Host ""
    Write-Host "  #################################################################" -ForegroundColor Red
    Write-Host "  # CHEQUEO FINAL DE INTEGRIDAD: FALLIDO (-ChainOfCustodyStrictMode) #" -ForegroundColor Red
    Write-Host "  #################################################################" -ForegroundColor Red
    Write-Host "  Las siguientes evidencias quedaron con un hash SHA-256 no valido" -ForegroundColor Red
    Write-Host "  (revise Logs\ChainOfCustody.csv, entradas con prefijo INVALIDO:):" -ForegroundColor Red
    foreach ($f in $Script:StrictCustodyFailures) {
        Write-Host "      - $f" -ForegroundColor Red
    }
    Write-Host ""
    Write-ForensicLog -Phase "FIN" -Action "CHEQUEO_INTEGRIDAD_FINAL_FALLIDO" -Target "$($Script:StrictCustodyFailures.Count) evidencia(s) con hash invalido" -Result "ERROR"
    $exitCode = 2
} else {
    Write-ForensicLog -Phase "FIN" -Action "PERITACION_COMPLETADA" -Target $OutputPath -Result "OK"
}

exit $exitCode
