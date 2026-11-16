#region ============================================================
# Ecosistema MaPeriT - HELPERS DE RUTAS COMPARTIDOS
# Fichero comun a varias herramientas (ver cada Build.ps1 para la lista
# exacta de que herramientas lo incluyen). NO EDITAR una copia local
# dentro de MAPERIT_SW/MAPERIT_OF/etc. - este es el unico punto de verdad.
# ============================================================

function Get-RelativeEvidencePath {
    <#
        Calcula la ruta relativa de un fichero de evidencia respecto a la raiz
        de salida, anclada estrictamente al PREFIJO de la ruta y sin distinguir
        mayusculas/minusculas (frecuente que la capitalizacion real en disco
        difiera de la de $RootPath en Windows).

        Antes cada herramienta (MaPeriT.SW, MaPeriT.OF) tenia su propia copia
        de esta misma funcion, escrita por separado. La version original de
        SW usaba $FullPath.Replace($RootPath, ""), que:
          - no es un anclaje de prefijo: sustituye CUALQUIER aparicion de
            $RootPath en toda la ruta, no solo al principio - podia corromper
            la ruta relativa si el nombre de la carpeta raiz se repetia en una
            subruta anidada.
          - es sensible a mayusculas/minusculas: si la capitalizacion real en
            disco difiere de la de $RootPath, no encuentra coincidencia y
            devuelve la ruta completa sin recortar, rompiendo la verificacion
            de integridad posterior (Test-HashManifest / -VerifyPath).
        Corregido una vez aqui en 2026-07-12 en vez de mantener dos copias
        que podian divergir o repetir el mismo bug por separado.
    #>
    param(
        [string]$FullPath,
        [string]$RootPath
    )
    if ([string]::IsNullOrEmpty($FullPath) -or [string]::IsNullOrEmpty($RootPath)) { return "" }

    if ($FullPath.StartsWith($RootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $FullPath.Substring($RootPath.Length).TrimStart('\')
    }

    # Fallback defensivo (no deberia ocurrir en uso normal): devolver cadena
    # vacia en vez de una ruta relativa erronea generada con .Replace() (que
    # sustituye CUALQUIER aparicion de $RootPath en toda la ruta, no solo al
    # principio). Una ruta vacia hace fallar la verificacion posterior de
    # forma visible (FILE_MISSING); una ruta relativa "plausible pero
    # incorrecta" fallaria de forma silenciosa y mas dificil de diagnosticar.
    # Write-ForensicLog es una funcion propia de cada herramienta (no de este
    # fichero comun), asi que se comprueba que exista antes de usarla.
    if (Get-Command Write-ForensicLog -ErrorAction SilentlyContinue) {
        Write-ForensicLog -Phase "INTEGRIDAD" -Action "RUTA_RELATIVA_NO_ANCLADA" -Target "$FullPath (raiz esperada: $RootPath)" -Result "WARNING"
    }
    return ""
}

#endregion
