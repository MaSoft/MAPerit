<#
.SYNOPSIS
    Compila todos los modulos de MaPeriT.SW (src y ..\Common) en un unico fichero desplegable.
#>

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$outputFile = Join-Path $scriptDir "MaPeriT.SW.ps1"

# Orden de compilacion: Params primero, luego modulos, Main al final
$sourceFiles = @(
    "src\Main-Params.ps1",
    "src\Config.ps1",
    "src\Core\Logging.ps1",
    "..\Common\PathHelpers.ps1",
    "..\Common\HtmlEncoding.ps1",
    "src\Core\Hashing.ps1",
    "src\Core\CSharpHelpers.ps1",
    "src\Core\FileAcquisition.ps1",
    "src\Core\Initialize.ps1",
    "src\Phases\Phase1-Volatile.ps1",
    "src\Phases\Phase2-SystemInfo.ps1",
    "src\Phases\Phase3-Filesystem.ps1",
    "src\Phases\Phase4-Registry.ps1",
    "src\Phases\Phase5-EventLogs.ps1",
    "src\Phases\Phase6-Browsers.ps1",
    "src\Phases\Phase7-Communications.ps1",
    "src\Phases\Phase8-CloudStorage.ps1",
    "src\Phases\Phase9-USB.ps1",
    "src\Phases\Phase10-Persistence.ps1",
    "src\Analysis\Timeline.ps1",
    "src\Analysis\IOCExtractor.ps1",
    "src\Analysis\Anomalies.ps1",
    "src\Report\ChainOfCustody.ps1",
    "src\Report\ReportTemplates.ps1",
    "src\Report\ReportGenerator.ps1",
    "src\Main.ps1"
)

Write-Host ""
Write-Host "  MaPeriT.SW Build System" -ForegroundColor Cyan
Write-Host "  =======================" -ForegroundColor Cyan
Write-Host ""

# La version es un unico punto de verdad: src\Config.ps1 ($Script:TOOL_VERSION).
# Antes quedaba TAMBIEN hardcodeada aqui ("v1.7.0" fijo en la cabecera del fichero
# compilado), pudiendo desincronizarse silenciosamente si solo se actualizaba Config.ps1.
. (Join-Path $scriptDir "src\Config.ps1")
$toolVersion = $Script:TOOL_VERSION
if (-not $toolVersion) {
    Write-Host "  [-] No se pudo leer `$Script:TOOL_VERSION desde src\Config.ps1" -ForegroundColor Red
    exit 1
}

$output = [System.Text.StringBuilder]::new()

# Cabecera (antes del param block)
$buildDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
[void]$output.AppendLine("#Requires -RunAsAdministrator")
[void]$output.AppendLine("#Requires -Version 5.1")
[void]$output.AppendLine(@"
<#
.NOTES
    MaPeriT.SW - Herramienta de Peritacion Informatica Forense Profesional v$toolVersion
    Analisis forense digital completo para sistemas Windows
    Cumple RFC 3227 (IETF) y NIST SP 800-86
    Compilado: $buildDate
    NO EDITAR DIRECTAMENTE - Modifique los ficheros fuente en src\
#>
"@)

$totalLines = 0
$fileCount = 0

foreach ($file in $sourceFiles) {
    $filePath = Join-Path $scriptDir $file
    $fileName = Split-Path $file -Leaf

    if (-not (Test-Path $filePath)) {
        Write-Host "  [-] FALTA: $file" -ForegroundColor Red
        exit 1
    }

    $content = Get-Content $filePath -Raw -Encoding UTF8
    $lineCount = ($content -split "`n").Count

    [void]$output.AppendLine("")
    [void]$output.AppendLine("#region ===== $fileName =====")
    [void]$output.AppendLine($content)
    [void]$output.AppendLine("#endregion ===== $fileName =====")

    $totalLines += $lineCount
    $fileCount++
    Write-Host "  [+] $($file.PadRight(55)) ($lineCount lineas)" -ForegroundColor Green
}

$output.ToString() | Out-File -FilePath $outputFile -Encoding UTF8

$finalSize = [math]::Round((Get-Item $outputFile).Length / 1KB, 1)
$finalLines = (Get-Content $outputFile).Count

Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Cyan
Write-Host "  Build completado:" -ForegroundColor Green
Write-Host "    Ficheros compilados: $fileCount" -ForegroundColor White
Write-Host "    Lineas totales:      $finalLines" -ForegroundColor White
Write-Host "    Tamano:              $finalSize KB" -ForegroundColor White
Write-Host "    Salida:              $outputFile" -ForegroundColor White

$hash = (Get-FileHash $outputFile -Algorithm SHA256).Hash
Write-Host "    SHA-256:             $hash" -ForegroundColor Yellow
Write-Host "  =======================================================" -ForegroundColor Cyan
Write-Host ""

# ── Verificacion de sintaxis tras compilar ──────────────────────────────
# Un solo error de sintaxis en cualquier fichero fuente (p.ej. un operador
# exclusivo de PowerShell 7+ como ??/?./&&/||, o una perdida de BOM que
# corrompe un caracter especial - ambos casos ya se dieron en la auditoria
# de 2026-07-12) puede impedir que el script compilado ENTERO cargue bajo
# PowerShell 5.1, sin dejar ningun rastro hasta que alguien lo ejecuta de
# verdad. Se verifica aqui, en cada build, con el parser AST + Create()
# real contra el motor de PowerShell instalado.
Write-Host "  Verificando sintaxis del fichero compilado..." -ForegroundColor Cyan
$verifyTokens = $null
$verifyErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($outputFile, [ref]$verifyTokens, [ref]$verifyErrors)
if ($verifyErrors.Count -gt 0) {
    Write-Host "  [-] ERRORES DE SINTAXIS EN EL FICHERO COMPILADO:" -ForegroundColor Red
    foreach ($e in $verifyErrors) {
        Write-Host "      Linea $($e.Extent.StartLineNumber): $($e.Message)" -ForegroundColor Red
    }
    Write-Host "  El build ha generado un fichero que NO ARRANCARIA." -ForegroundColor Red
    exit 1
}
try {
    $null = [scriptblock]::Create((Get-Content $outputFile -Raw))
    Write-Host "  [+] Sintaxis verificada: parseo AST limpio + motor PowerShell OK" -ForegroundColor Green
} catch {
    Write-Host "  [-] EL MOTOR REAL DE POWERSHELL RECHAZA EL FICHERO COMPILADO:" -ForegroundColor Red
    Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""
