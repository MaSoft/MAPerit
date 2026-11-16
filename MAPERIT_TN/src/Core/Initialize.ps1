#region ============================================================
# MaPeriT.TN - INICIALIZACION DE ASSEMBLIES WPF
# ============================================================

function Initialize-TNApplication {
    Add-Type -AssemblyName PresentationFramework    -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore         -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase              -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms     -ErrorAction SilentlyContinue
    Add-Type -AssemblyName Microsoft.VisualBasic    -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Net.Http          -ErrorAction SilentlyContinue

    # DPI awareness para pantallas HiDPI
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class TN_DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
'@ -ErrorAction SilentlyContinue
        [TN_DpiHelper]::SetProcessDPIAware() | Out-Null
    } catch {}

    # Helper para dark title bar en Windows 10/11
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class TN_DwmHelper {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    public static void SetDarkMode(IntPtr hwnd, bool dark) {
        int val = dark ? 1 : 0;
        DwmSetWindowAttribute(hwnd, 20, ref val, sizeof(int));
        DwmSetWindowAttribute(hwnd, 19, ref val, sizeof(int));
    }
}
'@ -ErrorAction SilentlyContinue
    } catch {}
}

function Set-DarkTitleBar {
    # Barra de titulo oscura solo con el tema oscuro (antes se forzaba tambien
    # en el tema claro).
    param([System.Windows.Window]$Window)
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
        [TN_DwmHelper]::SetDarkMode($hwnd, ($Script:TN_Theme -ne 'Light'))
    } catch {}
}

function New-WpfBrush {
    param([string]$HexColor)
    return [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString($HexColor)
    )
}

function New-WpfColor {
    param([string]$HexColor)
    return [System.Windows.Media.ColorConverter]::ConvertFromString($HexColor)
}

#endregion
