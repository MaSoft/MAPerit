#Requires -Version 5.1
<#
.SYNOPSIS
    Compila MaPeriT.SC desde los ficheros fuente en src\
    Uso: .\Build.ps1
#>

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
$OutputFile = Join-Path $ScriptRoot "MaPeriT.SC.ps1"

Write-Host ""
Write-Host "  MaPeriT.SC - Sistema de Compilacion" -ForegroundColor Cyan
Write-Host "  =====================================" -ForegroundColor Cyan
Write-Host ""

# Version en un unico punto de verdad (Config.ps1): se dot-sourcea aqui
# solo para leer $Script:SC_Version, nunca se hardcodea en este fichero
# (a diferencia de MAPERIT_TN\Build.ps1, donde la cabecera y el runtime
# quedan desincronizados porque el header usa un literal aparte).
. (Join-Path $ScriptRoot "src\Config.ps1")
$Version = $Script:SC_Version

$SourceOrder = @(
    "src\Main-Params.ps1",
    "src\Config.ps1",
    "src\Core\Initialize.ps1",
    "src\Core\Logging.ps1",
    "src\Core\ProjectLoader.ps1",
    "src\Core\AsyncLoader.ps1",
    "src\Query\SourceSchema.ps1",
    "src\Query\UserInference.ps1",
    "src\Query\QueryEngine.ps1",
    "src\Report\ReportTemplates.ps1",
    "src\Report\ReportPericial.ps1",
    "src\Report\ReportLlano.ps1",
    "src\UI\XAML.ps1",
    "src\UI\Wizard.ps1",
    "src\Main.ps1"
)

$header = @"
#Requires -Version 5.1
<#
    MaPeriT.SC v$Version - Consulta Guiada de Evidencias del Ecosistema MaPeriT
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
Write-Host "  [+] MaPeriT.SC.ps1 v$Version compilado: $size KB" -ForegroundColor Green
Write-Host "  [*] SHA-256: $hash" -ForegroundColor DarkGray
Write-Host ""

# ── Verificacion de sintaxis tras compilar ──────────────────────────────
# Ver comentario extenso en MAPERIT_SW\Build.ps1: un solo operador exclusivo
# de PowerShell 7+ (??/?./&&/||) o una perdida de BOM impide que el fichero
# compilado ENTERO cargue bajo PowerShell 5.1, sin dejar rastro hasta que
# alguien lo ejecuta de verdad.
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
