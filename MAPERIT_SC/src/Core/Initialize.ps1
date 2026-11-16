#region ============================================================
# MaPeriT.SC - INICIALIZACION DE ASSEMBLIES WPF
# ============================================================

function Initialize-SCApplication {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore      -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase           -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms  -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Web            -ErrorAction SilentlyContinue

    # DPI awareness para pantallas HiDPI
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class SC_DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
'@ -ErrorAction SilentlyContinue
        [SC_DpiHelper]::SetProcessDPIAware() | Out-Null
    } catch {}
}

function New-WpfBrush {
    param([string]$HexColor)
    return [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString($HexColor)
    )
}

#endregion
