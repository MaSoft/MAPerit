#Requires -Version 5.1
<#
.SYNOPSIS
    Compila MaPeriT.TN desde los ficheros fuente en src\
    Uso: .\Build.ps1
#>

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
$OutputFile = Join-Path $ScriptRoot "MaPeriT.TN.ps1"

Write-Host ""
Write-Host "  MaPeriT.TN - Sistema de Compilacion" -ForegroundColor Cyan
Write-Host "  =====================================" -ForegroundColor Cyan
Write-Host ""

$SourceOrder = @(
    "src\Main-Params.ps1",
    "src\Config.ps1",
    "src\Core\Initialize.ps1",
    "src\Core\Logging.ps1",
    "src\Core\ProjectLoader.ps1",
    "src\Core\AsyncLoader.ps1",
    "src\Core\Bookmarks.ps1",
    "src\Analysis\IOCHighlighter.ps1",
    "src\Analysis\IOCScanner.ps1",
    "src\Analysis\TimelineBuilder.ps1",
    "src\Viewers\TextViewer.ps1",
    "src\Viewers\JSONViewer.ps1",
    "src\Viewers\CSVViewer.ps1",
    "src\Viewers\MFTViewer.ps1",
    "src\Viewers\EVTXViewer.ps1",
    "src\UI\XAML.ps1",
    "src\UI\Dashboard.ps1",
    "src\UI\MainWindow.ps1",
    "src\Main.ps1"
)

# Version en un unico punto de verdad (Config.ps1): se dot-sourcea aqui
# solo para leer $Script:TN_Version, nunca se hardcodea en este fichero.
# Antes decia "v1.0.0" fijo en la cabecera, desincronizado de la version
# real desde que Config.ps1 subio a 1.1.0 (este era precisamente el defecto
# que el comentario de MAPERIT_SC\Build.ps1 ya señalaba como conocido).
. (Join-Path $ScriptRoot "src\Config.ps1")
$Version = $Script:TN_Version

$header = @"
#Requires -Version 5.1
<#
    MaPeriT.TN v$Version - Visor Forense del Ecosistema MaPeriT
    Compilado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    No editar directamente - modificar src\ y recompilar con Build.ps1
#>

"@

$content = $header
$missing = @()

foreach ($relPath in $SourceOrder) {
    $fullPath = Join-Path $ScriptRoot $relPath
    if (-not (Test-Path $fullPath)) {
        $missing += $relPath
        # Sin una fuente el compilado quedaria incompleto (funciones ausentes que solo
        # fallarian en plena ejecucion): se aborta, igual que MaPeriT.SW.
        Write-Host "  [-] FALTA: $relPath - compilacion abortada" -ForegroundColor Red
        exit 1
    }
    $fileContent = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    $content += "#region ===== $relPath =====`n"
    $content += $fileContent.TrimEnd()
    $content += "`n#endregion`n`n"
    Write-Host "  [+] $relPath" -ForegroundColor DarkGray
}

[System.IO.File]::WriteAllText($OutputFile, $content, [System.Text.Encoding]::UTF8)
$hash = (Get-FileHash $OutputFile -Algorithm SHA256).Hash
$size = [Math]::Round((Get-Item $OutputFile).Length / 1KB, 1)

Write-Host ""
if ($missing.Count -gt 0) {
    Write-Host "  [!] $($missing.Count) fichero(s) no encontrados" -ForegroundColor Yellow
}
Write-Host "  [+] MaPeriT.TN.ps1 compilado: $size KB" -ForegroundColor Green
Write-Host "  [*] SHA-256: $hash" -ForegroundColor DarkGray
Write-Host ""

# ── Verificacion de sintaxis tras compilar ──────────────────────────────
# Ver comentario extenso en MAPERIT_SW\Build.ps1: un solo operador exclusivo
# de PowerShell 7+ (??/?./&&/||) o una perdida de BOM impide que el fichero
# compilado ENTERO cargue bajo PowerShell 5.1 - el propio dot-source de
# Config.ps1 unas lineas mas arriba en este Build.ps1 sufrio exactamente
# este problema hasta que se le añadio BOM (12/07/2026).
Write-Host "  Verificando sintaxis del fichero compilado..." -ForegroundColor Cyan
$verifyTokens = $null
$verifyErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($OutputFile, [ref]$verifyTokens, [ref]$verifyErrors)
if ($verifyErrors.Count -gt 0) {
    Write-Host "  [-] ERRORES DE SINTAXIS EN EL FICHERO COMPILADO:" -ForegroundColor Red
    foreach ($e in $verifyErrors) {
        Write-Host "      Linea $($e.Extent.StartLineNumber): $($e.Message)" -ForegroundColor Red
    }
    Write-Host "  El build ha generado un fichero que NO ARRANCARIA." -ForegroundColor Red
    exit 1
}
try {
    $null = [scriptblock]::Create((Get-Content $OutputFile -Raw))
    Write-Host "  [+] Sintaxis verificada: parseo AST limpio + motor PowerShell OK" -ForegroundColor Green
} catch {
    Write-Host "  [-] EL MOTOR REAL DE POWERSHELL RECHAZA EL FICHERO COMPILADO:" -ForegroundColor Red
    Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""
