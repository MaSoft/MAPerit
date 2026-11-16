#region ============================================================
# MaPeriT.SC - NORMALIZACION E INFERENCIA DE USUARIO
# No existe un campo "Usuario" comun entre fuentes de AN (confirmado
# leyendo el codigo: EVTX tiene TargetUser/SubjectUser, navegadores
# tienen Usuario, MFT/ShimCache/Amcache/USN no tienen ningun campo de
# usuario). Esta capa homogeneiza eso para el motor de consulta,
# marcando siempre si el usuario es Confirmado (viene de un campo del
# log) o Inferido (deducido de una ruta \Users\<usuario>\), porque esa
# distincion es la que sostiene la credibilidad pericial del hallazgo.
# ============================================================

# Sin exigir un caracter concreto antes de "Users": las rutas reales de
# MFT_Completo.csv en produccion vienen SIN letra de unidad ("Users\nombre\...",
# no "C:\Users\nombre\..."), y las de ficheros borrados llevan el prefijo
# "[BORRADO] " (espacio antes de "Users", no barra invertida). Exigir "\Users\"
# literal (con barra invertida obligatoria delante) dejaba SIEMPRE sin
# resolver el usuario en MFT/Amcache/ShimCache/USN reales - confirmado en
# produccion contra un caso real donde MFT_Completo tenia 9698 coincidencias
# sin filtro de usuario y 0 con filtro, porque la inferencia nunca acertaba.
$Script:SC_UserPathRegex = '(?i)(?<![\w])Users\\([^\\]+)\\'

function Get-SCUserFromPath {
    param([string]$PathValue)
    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
    if ($PathValue -match $Script:SC_UserPathRegex) {
        $u = $Matches[1]
        # Descartar perfiles de sistema, no son "usuarios" investigables
        if ($u -in @('Public','Default','Default User','All Users')) { return $null }
        return $u
    }
    return $null
}

$Script:SC_SystemAccountNames = @(
    'SYSTEM','SERVICIO LOCAL','LOCAL SERVICE','SERVICIO DE RED','NETWORK SERVICE',
    'ANONYMOUS LOGON','DESCONOCIDO','UNKNOWN','-'
    # 'USUARIO', 'INVITADO' y 'GUEST' ya no se ocultan: son cuentas reales (una cuenta
    # local llamada "Usuario" es muy comun en Windows en espanol) y su actividad
    # puede ser relevante.
)
$Script:SC_SystemAccountPatterns = @(
    '^DWM-\d+$',                                     # Desktop Window Manager por sesion
    '^UMFD-\d+$',                                     # User Mode Font Driver por sesion
    '.*\$$',                                           # cuentas de equipo (NOMBRE-PC$)
    '^S-1-\d+(-\d+)*$',                                # SID crudo sin resolver
    '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',  # GUID
    '.*TESTACCOUNT.*'                                  # cuentas de prueba internas de Windows (SMB2GuestTestAccount, etc.)
)

function Test-SCIsRealUser {
    <#
    Filtra cuentas de sistema/servicio/equipo de la lista de usuarios
    SELECCIONABLES del asistente (paso 2). No afecta a Resolve-SCRowUser: un
    hallazgo real con TargetUser=SYSTEM sigue siendo un dato correcto y
    consultable si alguien lo busca explicitamente, esto solo evita que la
    lista de "elige un usuario" se llene de ruido no investigable para un
    usuario sin conocimientos tecnicos (confirmado en un caso real: 23
    cuentas detectadas, mas de la mitad eran SYSTEM/DWM/UMFD/SIDs/GUIDs).
    #>
    param([string]$UserName)
    if ([string]::IsNullOrWhiteSpace($UserName)) { return $false }
    $u = $UserName.Trim()
    if ($Script:SC_SystemAccountNames -contains $u.ToUpperInvariant()) { return $false }
    foreach ($pat in $Script:SC_SystemAccountPatterns) {
        if ($u -match $pat) { return $false }
    }
    return $true
}

function Resolve-SCRowUser {
    <#
    Devuelve [PSCustomObject]@{ Usuario = <string|""> ; Confianza = 'Confirmado'|'Inferido'|'NoDisponible' }
    a partir de una fila (DataRow/PSCustomObject) y la entrada de esquema de su fuente.
    #>
    param(
        [Parameter(Mandatory)] $Row,
        [Parameter(Mandatory)] [hashtable]$SourceEntry,
        [string]$ResolvedPathCol = $null   # para fuentes Dynamic, columna de ruta ya detectada en runtime
    )

    if ($SourceEntry.UserCols) {
        foreach ($col in $SourceEntry.UserCols) {
            $v = $Row.$col
            if (-not [string]::IsNullOrWhiteSpace($v) -and $v -ne 'desconocido') {
                return [PSCustomObject]@{ Usuario = $v.Trim(); Confianza = 'Confirmado' }
            }
        }
    }

    $pathCol = if ($SourceEntry.Dynamic) { $ResolvedPathCol } else { $SourceEntry.PathCol }
    if ($pathCol) {
        $pv = $Row.$pathCol
        $inferred = Get-SCUserFromPath -PathValue $pv
        if ($inferred) {
            return [PSCustomObject]@{ Usuario = $inferred; Confianza = 'Inferido' }
        }
    }

    return [PSCustomObject]@{ Usuario = ''; Confianza = 'NoDisponible' }
}

#endregion
