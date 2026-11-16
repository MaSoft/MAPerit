#region ============================================================
# MaPeriT.TN - PUNTO DE ENTRADA
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

# Inicializar assemblies WPF (una sola vez)
try {
    Initialize-TNApplication
} catch {
    Write-Host "  [ERROR] No se pudieron cargar los assemblies WPF: $_" -ForegroundColor Red
    Write-Host "  Requiere PowerShell 5.1+ en Windows." -ForegroundColor Yellow
    exit 1
}

# Red de seguridad global: cualquier excepcion no controlada que escape de un
# manejador de evento WPF (click, doble clic, etc.) se propaga en algunos
# casos como STATUS_FATAL_USER_CALLBACK_EXCEPTION y Windows mata el proceso
# entero sin posibilidad de recuperacion - la aplicacion desaparece sin
# ningun dialogo, perdiendo la sesion de trabajo del perito (pestañas
# abiertas, marcadores no guardados). No existia ningun manejador de este
# tipo en MaPeriT.TN (confirmado en auditoria). Se registra antes de mostrar
# cualquier ventana; el mismo Dispatcher persiste durante todo el bucle de
# reinicio por cambio de tema, asi que basta con registrarlo una vez aqui.
[System.Windows.Threading.Dispatcher]::CurrentDispatcher.add_UnhandledException({
    param($sender, $e)
    Write-Host "  [AVISO] Error interno no fatal capturado: $($e.Exception.Message)" -ForegroundColor Yellow
    $e.Handled = $true
})

do {
    $Script:TN_ThemeRestart = $false

    # Parsear XAML con el tema activo
    try {
        $reader = [System.Xml.XmlReader]::Create(
            [System.IO.StringReader]::new((Get-TNMainWindowXAML))
        )
        $Window = [System.Windows.Markup.XamlReader]::Load($reader)
    } catch {
        Write-Host "  [ERROR] Error al parsear XAML: $_" -ForegroundColor Red
        exit 1
    }

    # Inicializar logica de la ventana
    Initialize-MainWindow -Window $Window

    # Abrir proyecto o fichero pasado por parametro (solo en el primer arranque)
    if ($null -eq $Script:TN_RestoreState) {
        if (-not [string]::IsNullOrEmpty($ProjectPath) -and (Test-Path $ProjectPath)) {
            $Window.Add_ContentRendered({
                if (Test-MaPeriTProject $ProjectPath) {
                    Load-ProjectTree -ProjectPath $ProjectPath
                } else {
                    Open-FileInTab -FilePath $ProjectPath
                }
            })
        } elseif (-not [string]::IsNullOrEmpty($OpenFile) -and (Test-Path $OpenFile)) {
            $Window.Add_ContentRendered({
                Open-FileInTab -FilePath $OpenFile
            })
        }
    }

    # Mostrar ventana (bloqueante)
    [void]$Window.ShowDialog()

} while ($Script:TN_ThemeRestart)

#endregion
