<#
.SYNOPSIS
    MaPeriT.OF - Adquisicion Forense Offline

.DESCRIPTION
    Recopila evidencias forenses desde un disco duro conectado a otro equipo
    o desde un entorno Windows Live CD. El disco objetivo NO necesita estar
    arrancado. Genera la misma estructura de salida que MaPeriT.SW para
    procesado posterior con MaPeriT.AN.

    Cumple RFC 3227 (IETF) y NIST SP 800-86.
    Todas las operaciones son de SOLO LECTURA sobre el disco objetivo.

.PARAMETER TargetDisk
    OBLIGATORIO. Letra de unidad del disco objetivo montado.
    Ejemplos: D:  E:  F:  G:

.PARAMETER CaseNumber
    OBLIGATORIO. Numero de caso o expediente.

.PARAMETER ExaminerName
    OBLIGATORIO. Nombre del perito informatico.

.PARAMETER OutputPath
    Directorio de salida. Por defecto: .\MaPeriT_OF_<caso>_<timestamp>

.PARAMETER EvidenceDescription
    Descripcion del encargo pericial.

.PARAMETER SkipPhases
    Fases a omitir (rango valido: 2-10), como cadena separada por comas o
    espacios (p.ej. "8,9" o "8 9"). NO usar sintaxis de array @() aqui: al
    invocarse este script con -File (como hace MASys), PowerShell NO
    evalua @() como expresion -- lo recibe como texto literal y falla la
    conversion a numero. Ejemplo: -SkipPhases "8,9"

.PARAMETER CopyLargeFiles
    Copiar ficheros grandes (>500 MB) como PST/OST.

.PARAMETER HMACKey
    Clave secreta para firma HMAC-SHA256 del manifiesto de evidencias.
    Permite verificacion criptografica de integridad en sede judicial.

.PARAMETER TargetUser
    Nombre de perfil de usuario especifico a analizar (carpeta en Users\).
    Si se omite, se procesan todos los perfiles detectados.

.PARAMETER ExcludePaths
    Array de fragmentos de ruta a excluir de la copia de evidencias (comparacion por
    subcadena, sin distinguir mayusculas/minusculas). Util para minimizacion de datos
    cuando la autorizacion/orden judicial delimita el alcance de la adquisicion
    (p.ej. -ExcludePaths @("\Fotos Familiares\","\Backups Personales\")). Las rutas
    excluidas quedan registradas como SKIP en el log, nunca se omiten en silencio.

.PARAMETER VerifyPath
    Modo verificacion: comprueba la integridad de una adquisicion OF previa contra su
    HashManifest.csv, reconstruyendo la ubicacion de cada fichero de forma portable
    aunque la carpeta de evidencias se haya movido o copiado a otra unidad para su
    presentacion en sede judicial. No requiere -TargetDisk/-CaseNumber/-ExaminerName.

.EXAMPLE
    .\MaPeriT.OF.ps1 -TargetDisk "D:" -CaseNumber "JUD-2026-112" -ExaminerName "Juan Perez Garcia"

.EXAMPLE
    .\MaPeriT.OF.ps1 -TargetDisk "E:" -CaseNumber "CASO-001" -ExaminerName "Ana Garcia" `
        -OutputPath "F:\Peritajes\CASO-001" -TargetUser "jsmith" -HMACKey "clave-judicial-2026"

.EXAMPLE
    .\MaPeriT.OF.ps1 -TargetDisk "F:" -CaseNumber "INC-789" -ExaminerName "Carlos Martinez" `
        -SkipPhases "8,9" -CopyLargeFiles

.EXAMPLE
    .\MaPeriT.OF.ps1 -VerifyPath "F:\Peritajes\MaPeriT_OF_CASO-001_20260712"
#>

param(
    # TargetDisk/CaseNumber/ExaminerName NO se declaran [Parameter(Mandatory=$true)]:
    # eso obligaria a PowerShell a pedirlos de forma interactiva incluso cuando el
    # unico proposito de la invocacion es -VerifyPath (que no toca ningun disco
    # objetivo). Se validan manualmente en Main.ps1 solo cuando no se use -VerifyPath.
    [string]$TargetDisk          = "",
    [string]$CaseNumber          = "",
    [string]$ExaminerName        = "",
    [string]$OutputPath          = "",
    [string]$EvidenceDescription = "",
    [string]$SkipPhases          = "",
    [switch]$CopyLargeFiles,
    [string]$HMACKey             = "",
    [string]$TargetUser          = "",
    [string[]]$ExcludePaths      = @(),
    [string]$VerifyPath          = ""
)

# $SkipPhases llega como texto (ver .PARAMETER SkipPhases) -- se admite
# separado por comas Y/O espacios porque un array real pasado en modo
# interactivo (-Command) se convierte a texto separado por espacios via
# ToString(), y ambos formatos deben funcionar igual.
[int[]]$PhasesToSkip = @()
if ($SkipPhases) {
    $PhasesToSkip = @(
        $SkipPhases -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    )
}
