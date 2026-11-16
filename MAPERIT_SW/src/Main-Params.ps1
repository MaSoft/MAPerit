<#
.SYNOPSIS
    MaPeriT.SW - Herramienta de Peritacion Informatica Forense Profesional

.DESCRIPTION
    Realiza una adquisicion forense completa de un equipo Windows siguiendo
    los estandares RFC 3227 y NIST SP 800-86. Genera un informe HTML
    profesional en espanol apto para presentacion en juzgado.

.PARAMETER CaseNumber
    Numero de caso o expediente (obligatorio, excepto en modo -VerifyPath)

.PARAMETER ExaminerName
    Nombre del perito informatico (obligatorio, excepto en modo -VerifyPath)

.PARAMETER OutputPath
    Directorio de salida para las evidencias. Por defecto: .\MaPeriT_<CaseNumber>_<timestamp>

.PARAMETER EvidenceDescription
    Descripcion del encargo pericial

.PARAMETER SkipPhases
    Numeros de fase a omitir (1-10), como cadena separada por comas o espacios
    (p.ej. "3,7" o "3 7"). NO usar sintaxis de array @() aqui: al invocarse este
    script con -File (como hace MASys), PowerShell NO evalua @() como
    expresion -- lo recibe como texto literal y falla la conversion a numero.
    Si se invoca el script de forma interactiva con -Command o dot-sourcing, un
    array real tambien funciona (se convierte a texto y se vuelve a parsear).

.PARAMETER SkipRAM
    Omitir el volcado de memoria RAM

.PARAMETER CopyLargeFiles
    Copiar ficheros grandes (>500MB) como PST/OST

.PARAMETER HMACKey
    Clave para firmar el manifiesto de evidencias con HMAC-SHA256

.PARAMETER VerifyPath
    Modo verificacion: comprueba la integridad de una adquisicion previa contra su manifiesto.
    No requiere -CaseNumber ni -ExaminerName.

.PARAMETER DryRun
    Modo simulacion de preflight: comprueba prerrequisitos (privilegios, PowerShell, SO),
    localiza winpmem, enumera perfiles de usuario y verifica la presencia de las rutas de
    artefactos clave de cada fase, SIN VSS, SIN montar hives y SIN copiar ni un solo byte.
    Util para validar el entorno antes de una adquisicion real. No requiere -CaseNumber ni
    -ExaminerName. No es una simulacion fase a fase: es un chequeo de entorno de solo lectura.

.PARAMETER SelfTest
    Ejecuta una prueba de humo de la cadena de integridad (hash + copia + registro de
    custodia) contra un fichero temporal sintetico propio de la herramienta, para
    verificar que el mecanismo de hashing/copia/cadena de custodia funciona correctamente
    ANTES de iniciar una adquisicion real sobre el equipo objetivo. No toca el equipo
    objetivo. No requiere -CaseNumber ni -ExaminerName.

.PARAMETER ExcludePaths
    Array de fragmentos de ruta a excluir de la copia de evidencias (comparacion por
    subcadena, sin distinguir mayusculas/minusculas). Util para minimizacion de datos
    cuando la autorizacion/orden judicial delimita el alcance de la adquisicion
    (p.ej. -ExcludePaths @("\Fotos Familiares\","\Backups Personales\")).
    Se aplica en los dos puntos centrales de copia (Copy-ForensicFile y
    Copy-ForensicDirectory), que cubren la practica totalidad de las Fases 3, 4, 6, 7 y 8.
    Las rutas excluidas quedan registradas como SKIP en el log, nunca se omiten en
    silencio.

.PARAMETER NetworkIsolationCheck
    Comprueba y documenta en la Fase 1 si el equipo analizado tiene conexiones de red
    activas en el momento de la adquisicion (adaptadores activos, conexiones TCP
    establecidas). Es solo un chequeo de LECTURA e informativo para el acta pericial; no
    aisla ni desconecta nada.

.PARAMETER ChainOfCustodyStrictMode
    Si alguna evidencia queda con un hash SHA-256 invalido (ver INVALIDO: en
    ChainOfCustody.csv), el chequeo final de integridad se marca explicitamente como
    FALLIDO y se destaca en rojo como hallazgo critico en el informe pericial HTML.
    IMPORTANTE: este modo NO aborta la adquisicion en curso -- interrumpirla a mitad de
    proceso perderia de forma irrecuperable los datos volatiles de las fases pendientes,
    lo cual es peor que el problema de integridad que se quiere señalar. Es un modo de
    senalizacion agresiva al final, no de aborto.

.PARAMETER MaxEventsPerQuery
    Sobrescribe el limite por defecto de eventos por consulta a los logs de Windows
    (Config.ps1: $Script:Defaults.MaxEventsPerQuery = 50000) sin tener que editar el
    fuente. Util en servidores con actividad muy alta donde el limite por defecto se
    queda corto (ver WARNING "EVENTOS_POSIBLEMENTE_TRUNCADOS" en el log de ejecucion).

.EXAMPLE
    .\MaPeriT.SW.ps1 -CaseNumber "2026-001" -ExaminerName "Juan Perez" -OutputPath "E:\Evidencias"

.EXAMPLE
    .\MaPeriT.SW.ps1 -CaseNumber "CASO-123" -ExaminerName "Ana Garcia" -SkipPhases "8" -SkipRAM

.EXAMPLE
    .\MaPeriT.SW.ps1 -VerifyPath "E:\Evidencias\MaPeriT_CASO-001_20260602"

.EXAMPLE
    .\MaPeriT.SW.ps1 -DryRun

.EXAMPLE
    .\MaPeriT.SW.ps1 -SelfTest

.EXAMPLE
    .\MaPeriT.SW.ps1 -CaseNumber "CASO-123" -ExaminerName "Ana Garcia" -ChainOfCustodyStrictMode -NetworkIsolationCheck -MaxEventsPerQuery 200000
#>

param(
    [string]$CaseNumber,

    [string]$ExaminerName,

    [string]$OutputPath,

    [string]$EvidenceDescription = "",

    [string]$SkipPhases = "",

    [switch]$SkipRAM,

    [switch]$CopyLargeFiles,

    [string]$HMACKey = "",

    [string]$VerifyPath = "",

    [switch]$DryRun,

    [switch]$SelfTest,

    [string[]]$ExcludePaths = @(),

    [switch]$NetworkIsolationCheck,

    [switch]$ChainOfCustodyStrictMode,

    [int]$MaxEventsPerQuery = 0
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
