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
