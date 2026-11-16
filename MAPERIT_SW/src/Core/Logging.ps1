#region ============================================================
# MaPeriT.SW - MOTOR DE LOGGING
# ActionLog, CadenaCustodia, salida por consola
# ============================================================

function Initialize-Logging {
    param(
        [string]$LogsPath
    )
    $Script:ActionLogPath = Join-Path $LogsPath "ActionLog.csv"
    $Script:CustodyLogPath = Join-Path $LogsPath "ChainOfCustody.csv"
    $Script:EvidenceCounter = 0
    $Script:StrictCustodyFailures = @()

    "Timestamp,Phase,Action,Target,Result,Duration_ms,ErrorMessage" | Out-File -FilePath $Script:ActionLogPath -Encoding UTF8
    "Timestamp,EvidenceID,SourcePath,DestinationPath,SHA256Hash,AcquiredBy,Method,FileSize" | Out-File -FilePath $Script:CustodyLogPath -Encoding UTF8

    Write-ForensicLog -Phase "INIT" -Action "LOGGING_INICIADO" -Target $LogsPath -Result "OK"
}

function Write-ForensicLog {
    param(
        [string]$Phase,
        [string]$Action,
        [string]$Target,
        [string]$Result = "OK",
        [long]$DurationMs = 0,
        [string]$ErrorMessage = ""
    )
    $ts = Get-Date -Format $Script:Defaults.DateFormat
    $sanitizedTarget = $Target -replace '"', '""'
    $sanitizedError = $ErrorMessage -replace '"', '""'
    $line = "`"$ts`",`"$Phase`",`"$Action`",`"$sanitizedTarget`",`"$Result`",$DurationMs,`"$sanitizedError`""

    try {
        $line | Out-File -FilePath $Script:ActionLogPath -Append -Encoding UTF8
    } catch {
        # Si falla el log a fichero, al menos mostramos en consola
    }

    $color = switch ($Result) {
        "OK"      { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "SKIP"    { "DarkYellow" }
        default   { "White" }
    }

    $prefix = switch ($Result) {
        "OK"      { "[+]" }
        "WARNING" { "[!]" }
        "ERROR"   { "[-]" }
        "SKIP"    { "[~]" }
        default   { "[*]" }
    }

    Write-Host "  $prefix " -ForegroundColor $color -NoNewline
    Write-Host "$Action" -ForegroundColor White -NoNewline
    if ($Target) {
        Write-Host " -> " -ForegroundColor DarkGray -NoNewline
        Write-Host "$Target" -ForegroundColor Gray
    } else {
        Write-Host ""
    }
}

function Add-ChainOfCustodyEntry {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$Hash,
        [string]$Method,
        [long]$FileSize = 0
    )
    $Script:EvidenceCounter++
    $ts = Get-Date -Format $Script:Defaults.DateFormat
    $evidenceId = "EVD-{0:D5}" -f $Script:EvidenceCounter
    $examiner = $Script:SessionInfo.ExaminerName

    # --- Validacion de formato del hash antes de dejarlo constar en el acta de custodia ---
    # Get-ForensicHash nunca lanza excepcion: si el calculo falla devuelve cadenas de
    # diagnostico como "FILE_NOT_FOUND" o "HASH_ERROR: ...". Sin esta validacion, ese texto
    # quedaria escrito en la columna SHA256Hash del acta como si fuese un hash real,
    # comprometiendo la validez pericial de esa evidencia sin que nadie lo note.
    $isValidHash = $Hash -match '^[A-Fa-f0-9]{64}$'
    if (-not $isValidHash) {
        Write-ForensicLog -Phase "CUSTODY" -Action "HASH_INVALIDO_EN_CUSTODIA" -Target "$DestPath -> '$Hash'" -Result "ERROR" -ErrorMessage "El valor de hash no tiene formato SHA-256 valido (64 hex). La evidencia se registra igualmente marcada como INVALIDO, pero debe revisarse manualmente: puede que el fichero se haya eliminado o modificado tras la copia."
        if ($Script:SessionInfo) { $Script:SessionInfo.TotalErrors++ }
        # -ChainOfCustodyStrictMode: acumular para que el chequeo final de integridad se
        # marque explicitamente como FALLIDO y se destaque en el informe pericial. No aborta
        # la adquisicion en curso (ver documentacion del parametro).
        if ($Script:ChainOfCustodyStrictMode) {
            if (-not $Script:StrictCustodyFailures) { $Script:StrictCustodyFailures = @() }
            $Script:StrictCustodyFailures += "EVD-{0:D5} ({1})" -f $Script:EvidenceCounter, $DestPath
        }
    }
    $hashField = if ($isValidHash) { $Hash } else { "INVALIDO:$Hash" }

    $sanitizedSource = $SourcePath -replace '"', '""'
    $sanitizedDest = $DestPath -replace '"', '""'
    $line = "`"$ts`",`"$evidenceId`",`"$sanitizedSource`",`"$sanitizedDest`",`"$hashField`",`"$examiner`",`"$Method`",$FileSize"

    try {
        $line | Out-File -FilePath $Script:CustodyLogPath -Append -Encoding UTF8
    } catch {
        Write-ForensicLog -Phase "CUSTODY" -Action "ERROR_ESCRITURA_CUSTODIA" -Target $DestPath -Result "ERROR" -ErrorMessage $_.Exception.Message
    }
}

function Write-PhaseHeader {
    param(
        [int]$PhaseNumber,
        [string]$PhaseName
    )
    $Script:CurrentPhaseStart = Get-Date
    $header = @"

  ╔═════════════════════════════════════════════════════════════════╗
  ║  FASE $PhaseNumber - $($PhaseName.ToUpper().PadRight(52))║
  ╚═════════════════════════════════════════════════════════════════╝
"@
    Write-Host $header -ForegroundColor Cyan
    Write-ForensicLog -Phase "FASE_$PhaseNumber" -Action "INICIO_FASE" -Target $PhaseName -Result "OK"
}

function Write-PhaseComplete {
    param(
        [int]$PhaseNumber,
        [string]$PhaseName,
        [int]$ItemsCollected = 0
    )
    $duration = ((Get-Date) - $Script:CurrentPhaseStart).TotalSeconds
    Write-Host ""
    Write-Host "  [✓] Fase $PhaseNumber completada: $ItemsCollected elementos recopilados ($([math]::Round($duration,1))s)" -ForegroundColor Green
    Write-Host ""
    Write-ForensicLog -Phase "FASE_$PhaseNumber" -Action "FIN_FASE" -Target "$PhaseName - $ItemsCollected elementos" -Result "OK" -DurationMs ([long]($duration * 1000))
}

function Write-StepHeader {
    param(
        [string]$StepName
    )
    Write-Host ""
    Write-Host "  --- $StepName ---" -ForegroundColor DarkCyan
}

function Write-ProgressBanner {
    param(
        [int]$CurrentPhase,
        [int]$TotalPhases = 10,
        [string]$PhaseName
    )
    $pct = [math]::Round(($CurrentPhase / $TotalPhases) * 100)
    $filled = [math]::Round($pct / 5)
    $empty = 20 - $filled
    $bar = ("█" * $filled) + ("░" * $empty)
    Write-Host ""
    Write-Host "  Progreso: [$bar] $pct% - Fase $CurrentPhase/$TotalPhases" -ForegroundColor Yellow
}

function Export-CollectionToCSV {
    param(
        [array]$Data,
        [string]$OutputPath,
        [string]$Phase,
        [string]$Description
    )
    if ($null -eq $Data -or $Data.Count -eq 0) {
        Write-ForensicLog -Phase $Phase -Action "SIN_DATOS" -Target $Description -Result "WARNING"
        return
    }
    try {
        $Data | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        $hash = Get-ForensicHash -FilePath $OutputPath
        $size = (Get-Item $OutputPath).Length
        Add-ChainOfCustodyEntry -SourcePath "GENERATED" -DestPath $OutputPath -Hash $hash -Method "Export-CSV" -FileSize $size
        Write-ForensicLog -Phase $Phase -Action "EXPORTADO" -Target $OutputPath -Result "OK"
    } catch {
        Write-ForensicLog -Phase $Phase -Action "ERROR_EXPORT" -Target $OutputPath -Result "ERROR" -ErrorMessage $_.Exception.Message
    }
}

function Export-CollectionToJSON {
    param(
        [object]$Data,
        [string]$OutputPath,
        [string]$Phase,
        [string]$Description
    )
    if ($null -eq $Data) {
        Write-ForensicLog -Phase $Phase -Action "SIN_DATOS" -Target $Description -Result "WARNING"
        return
    }
    try {
        # -InputObject (no tuberia): con tuberia, una coleccion de UN elemento se
        # escribia como objeto suelto en vez de array, y quien leia el JSON
        # (p.ej. el informe con Anomalies.json) contaba 0 elementos.
        ConvertTo-Json -InputObject $Data -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
        $hash = Get-ForensicHash -FilePath $OutputPath
        $size = (Get-Item $OutputPath).Length
        Add-ChainOfCustodyEntry -SourcePath "GENERATED" -DestPath $OutputPath -Hash $hash -Method "Export-JSON" -FileSize $size
        Write-ForensicLog -Phase $Phase -Action "EXPORTADO" -Target $OutputPath -Result "OK"
    } catch {
        Write-ForensicLog -Phase $Phase -Action "ERROR_EXPORT" -Target $OutputPath -Result "ERROR" -ErrorMessage $_.Exception.Message
    }
}

function Export-CollectionToText {
    param(
        [string]$Content,
        [string]$OutputPath,
        [string]$Phase,
        [string]$Description
    )
    try {
        $Content | Out-File -FilePath $OutputPath -Encoding UTF8
        $hash = Get-ForensicHash -FilePath $OutputPath
        $size = (Get-Item $OutputPath).Length
        Add-ChainOfCustodyEntry -SourcePath "GENERATED" -DestPath $OutputPath -Hash $hash -Method "Export-TXT" -FileSize $size
        Write-ForensicLog -Phase $Phase -Action "EXPORTADO" -Target $OutputPath -Result "OK"
    } catch {
        Write-ForensicLog -Phase $Phase -Action "ERROR_EXPORT" -Target $OutputPath -Result "ERROR" -ErrorMessage $_.Exception.Message
    }
}
