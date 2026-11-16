#region ============================================================
# MaPeriT.SC - PUNTO DE ENTRADA
# ============================================================

$ErrorActionPreference = "Continue"

try {
    Initialize-SCApplication
} catch {
    Write-Host "Error inicializando MaPeriT.SC: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Red de seguridad global: cualquier excepcion no controlada que escape de un
# manejador de evento WPF (click, tick de timer, etc.) se propaga como
# STATUS_FATAL_USER_CALLBACK_EXCEPTION y Windows mata el proceso entero sin
# posibilidad de recuperacion - no se ve como un error normal de PowerShell,
# la aplicacion simplemente desaparece. Se ha confirmado un bug real de WPF
# (DataGridItemAttachedStorage.TryGetValue lanzando ArgumentNullException de
# forma esporadica al preparar filas de un DataGrid con volumenes grandes,
# aparentemente ligado a temporizacion del recolector de basura, no a ningun
# error de configuracion del grid) que puede disparar este camino. Este
# manejador evita que MaPeriT.SC se cierre de golpe ante cualquier excepcion
# de este tipo: la registra en consola y deja que la aplicacion siga viva.
[System.Windows.Threading.Dispatcher]::CurrentDispatcher.add_UnhandledException({
    param($sender, $e)
    Write-Host "[AVISO] Error interno no fatal capturado: $($e.Exception.Message)" -ForegroundColor Yellow
    $e.Handled = $true
})

if ($ProjectPath) { $Script:SCWizard.State.ProjectPath = $ProjectPath }

try {
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new((Get-SCMainWindowXAML)))
    $Window = [System.Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Host "Error construyendo la ventana de MaPeriT.SC: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Show-SCWizard -Window $Window
[void]$Window.ShowDialog()

#endregion
