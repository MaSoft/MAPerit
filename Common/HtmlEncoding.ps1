#region ============================================================
# Ecosistema MaPeriT - COMPATIBILIDAD DE HtmlEncode COMPARTIDA
#
# BUG CONFIRMADO EMPIRICAMENTE (12/07/2026, verificacion end-to-end real de
# MaPeriT.OF contra un disco objetivo sintetico): "Add-Type -AssemblyName
# System.Web -ErrorAction SilentlyContinue" puede fallar en silencio incluso
# bajo Windows PowerShell 5.1 (no es un problema exclusivo de PowerShell 7 /
# .NET Core, como se habia asumido hasta ahora). Cuando falla, TODAS las
# llamadas a [System.Web.HttpUtility]::HtmlEncode(...) en cualquier
# generador de informes (SW, OF, AN usan esta clase extensivamente) lanzan
# "No se encuentra el tipo [System.Web.HttpUtility]" y el informe pericial
# se genera roto - en el caso de OF, el bug era aun peor: nunca llegaba
# siquiera a INTENTAR cargar el ensamblado.
#
# Este fichero garantiza que el tipo System.Web.HttpUtility SIEMPRE quede
# disponible: intenta cargar el ensamblado real y, si el tipo sigue sin
# resolver por cualquier motivo, define un reemplazo minimo bajo el MISMO
# nombre completamente cualificado. Todas las llamadas existentes
# [System.Web.HttpUtility]::HtmlEncode(...) en cualquier fichero de informe
# siguen funcionando sin cambiar ni un solo punto de llamada.
# ============================================================

Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

if (-not ([System.Management.Automation.PSTypeName]'System.Web.HttpUtility').Type) {
    try {
        Add-Type -TypeDefinition @"
using System;
namespace System.Web {
    public static class HttpUtility {
        public static string HtmlEncode(string s) {
            if (string.IsNullOrEmpty(s)) return s;
            return s.Replace("&","&amp;").Replace("<","&lt;").Replace(">","&gt;").Replace("\"","&quot;").Replace("'","&#39;");
        }
    }
}
"@ -Language CSharp -ErrorAction Stop
    } catch {
        # Si ni siquiera esto carga (extremadamente improbable), los generadores
        # de informe seguiran fallando igual que antes de este fichero - no hay
        # nada mas que se pueda hacer sin depender de una libreria externa.
    }
}

#endregion
