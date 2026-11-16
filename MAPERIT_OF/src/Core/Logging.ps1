#region ============================================================
# MaPeriT.OF - LOGGING
# Mismo formato de salida que SW para compatibilidad con AN
# ============================================================

$Script:LogPath = ""

function Initialize-OFLogging {
    param([string]$LogsPath)
    $Script:LogPath = Join-Path $LogsPath "ForensicLog.csv"
    "Timestamp,Phase,Action,Target,Result,Detail" | Out-File -FilePath $Script:LogPath -Encoding UTF8 -Force
}

function Write-ForensicLog {
    param(
        [string]$Phase   = "OF",
        [string]$Action  = "",
        [string]$Target  = "",
        [string]$Result  = "OK",
        [string]$Detail  = "",
        [long]$DurationMs = 0
    )
    $ts     = (Get-Date).ToString($Script:Defaults.DateFormat)
    $detail = if ($DurationMs -gt 0) { "${Detail}$(if($Detail){' '})Duracion=${DurationMs}ms" } else { $Detail }
    $line   = "$ts,$Phase,$Action,`"$($Target -replace '"','""')`",$Result,`"$($detail -replace '"','""')`""
    Add-Content -Path $Script:LogPath -Value $line -Encoding UTF8

    $color = switch ($Result) {
        "OK"      { "Green"  }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red"    }
        "SKIP"    { "DarkGray" }
        default   { "White"  }
    }
    $symbol = switch ($Result) {
        "OK"      { "[+]" }
        "WARNING" { "[!]" }
        "ERROR"   { "[-]" }
        "SKIP"    { "[~]" }
        default   { "[*]" }
    }
    Write-Host "  $symbol $Action" -ForegroundColor $color -NoNewline
    if ($Target) { Write-Host " -> $Target" -ForegroundColor DarkGray -NoNewline }
    Write-Host ""

    if ($Result -eq "ERROR")   { $Script:OFSession.Errors++ }
    if ($Result -eq "WARNING") { $Script:OFSession.Warnings++ }
}

function Write-PhaseHeader {
    param([int]$PhaseNumber, [string]$PhaseName)
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║  FASE $PhaseNumber — $($PhaseName.PadRight(54))║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-ForensicLog -Phase "FASE_$PhaseNumber" -Action "FASE_INICIO" -Target $PhaseName
}

function Write-PhaseComplete {
    param([int]$PhaseNumber, [string]$PhaseName, [int]$ItemsCollected)
    Write-Host ""
    Write-Host "  [OK] Fase $PhaseNumber completada — $ItemsCollected artefactos recopilados" -ForegroundColor Green
    Write-ForensicLog -Phase "FASE_$PhaseNumber" -Action "FASE_COMPLETA" -Target "$ItemsCollected artefactos" -Result "OK"
}

function Write-StepHeader {
    param([string]$Step)
    Write-Host "  --- $Step" -ForegroundColor DarkCyan
}

function Export-CollectionToCSV {
    param([object]$Data, [string]$OutputPath, [string]$Phase, [string]$Description)
    try {
        $dir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $Data | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Force
        $count = if ($Data -is [array]) { $Data.Count } else { 1 }
        Write-ForensicLog -Phase $Phase -Action "EXPORTADO_CSV" -Target (Split-Path $OutputPath -Leaf) -Result "OK" -Detail "$count registros"
    } catch {
        Write-ForensicLog -Phase $Phase -Action "ERROR_CSV" -Target $Description -Result "ERROR" -Detail $_.Exception.Message
    }
}

function Export-CollectionToJSON {
    param([object]$Data, [string]$OutputPath, [string]$Phase, [string]$Description)
    try {
        $dir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        # -InputObject (no tuberia): una coleccion de un elemento sigue siendo un array JSON
        ConvertTo-Json -InputObject $Data -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        Write-ForensicLog -Phase $Phase -Action "EXPORTADO_JSON" -Target (Split-Path $OutputPath -Leaf) -Result "OK" -Detail $Description
    } catch {
        Write-ForensicLog -Phase $Phase -Action "ERROR_JSON" -Target $Description -Result "ERROR" -Detail $_.Exception.Message
    }
}

function Export-CollectionToText {
    param([string]$Content, [string]$OutputPath, [string]$Phase, [string]$Description)
    try {
        $dir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $Content | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        Write-ForensicLog -Phase $Phase -Action "EXPORTADO_TXT" -Target (Split-Path $OutputPath -Leaf) -Result "OK" -Detail $Description
    } catch {
        Write-ForensicLog -Phase $Phase -Action "ERROR_TXT" -Target $Description -Result "ERROR" -Detail $_.Exception.Message
    }
}
