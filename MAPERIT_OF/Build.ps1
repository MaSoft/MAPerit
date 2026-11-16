#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$scriptDir  = Split-Path $MyInvocation.MyCommand.Path -Parent
$outputFile = Join-Path $scriptDir "MaPeriT.OF.ps1"
$buildDate  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$sourceFiles = @(
    "src\Main-Params.ps1",
    "src\Config.ps1",
    "src\Core\Logging.ps1",
    "..\Common\PathHelpers.ps1",
    "..\Common\HtmlEncoding.ps1",
    "src\Core\Hashing.ps1",
    "src\Core\FileAcquisition.ps1",
    "src\Core\RegistryOffline.ps1",
    "src\Core\Initialize.ps1",
    "src\Phases\Phase2-SystemInfo.ps1",
    "src\Phases\Phase3-Filesystem.ps1",
    "src\Phases\Phase4-Registry.ps1",
    "src\Phases\Phase5-EventLogs.ps1",
    "src\Phases\Phase6-Browsers.ps1",
    "src\Phases\Phase7-Communications.ps1",
    "src\Phases\Phase8-CloudStorage.ps1",
    "src\Phases\Phase9-USB.ps1",
    "src\Phases\Phase10-Persistence.ps1",
    "src\Report\ChainOfCustody.ps1",
    "src\Report\ReportTemplates.ps1",
    "src\Report\ReportGenerator.ps1",
    "src\Main.ps1"
)

Write-Host ""
Write-Host "  MaPeriT.OF Build System" -ForegroundColor Cyan
Write-Host "  =======================" -ForegroundColor Cyan
Write-Host ""

# Version en un unico punto de verdad (Config.ps1): se dot-sourcea aqui
# solo para leer $Script:TOOL_VERSION, nunca se hardcodea en este fichero.
# Antes decia "v1.0.0" fijo en la cabecera, desincronizado de la version
# real desde que Config.ps1 subio a 1.1.0.
. (Join-Path $scriptDir "src\Config.ps1")
$toolVersion = $Script:TOOL_VERSION
if (-not $toolVersion) {
    Write-Host "  [-] No se pudo leer `$Script:TOOL_VERSION desde src\Config.ps1" -ForegroundColor Red
    exit 1
}

$output     = [System.Text.StringBuilder]::new(800000)
$totalLines = 0

[void]$output.AppendLine(@"
#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.NOTES
    MaPeriT.OF - Adquisicion Forense Offline v$toolVersion
    Recopila evidencias desde disco montado en otro equipo o entorno Live
    Compatible con MaPeriT.AN para analisis posterior
    Compilado: $buildDate
    NO EDITAR DIRECTAMENTE - Modifique los ficheros fuente en src\
#>
"@)

foreach ($rel in $sourceFiles) {
    $path = Join-Path $scriptDir $rel
    if (-not (Test-Path $path)) {
        # Sin una fuente el compilado quedaria incompleto (funciones ausentes que solo
        # fallarian en plena ejecucion): se aborta, igual que MaPeriT.SW.
        Write-Host "  [-] FALTA: $rel - compilacion abortada" -ForegroundColor Red
        exit 1
    }
    $lines = Get-Content $path -Encoding UTF8
    $totalLines += $lines.Count
    [void]$output.AppendLine("#region ===== $rel =====")
    [void]$output.AppendLine($lines -join "`n")
    [void]$output.AppendLine("#endregion ===== $rel =====")
    [void]$output.AppendLine("")
    Write-Host "  [+] $rel" -ForegroundColor Green -NoNewline
    Write-Host (" " * [Math]::Max(1, 58 - $rel.Length)) -NoNewline
    Write-Host "($($lines.Count) lineas)" -ForegroundColor DarkGray
}

$content = $output.ToString()
$content | Out-File -FilePath $outputFile -Encoding UTF8

$hash = (Get-FileHash $outputFile -Algorithm SHA256).Hash
$size = [math]::Round((Get-Item $outputFile).Length / 1KB, 1)

Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host "  Build completado:" -ForegroundColor Green
Write-Host "    Ficheros compilados: $($sourceFiles.Count)"
Write-Host "    Lineas totales:      $totalLines"
Write-Host "    Tamano:              $size KB"
Write-Host "    Salida:              $outputFile"
Write-Host "    SHA-256:             $hash"
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host ""

# ── Verificacion de sintaxis tras compilar ──────────────────────────────
# Ver comentario extenso en MAPERIT_SW\Build.ps1: un solo operador exclusivo
# de PowerShell 7+ (??/?./&&/||) o una perdida de BOM impide que el fichero
# compilado ENTERO cargue bajo PowerShell 5.1, sin dejar rastro hasta que
# alguien lo ejecuta de verdad.
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
