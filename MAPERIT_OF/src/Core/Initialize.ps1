#region ============================================================
# MaPeriT.OF - INICIALIZACION Y VALIDACION
# ============================================================

function Initialize-OFSession {
    param(
        [string]$TargetDisk,
        [string]$CaseNumber,
        [string]$ExaminerName,
        [string]$OutputPath,
        [string]$EvidenceDescription,
        [string]$TargetUser
    )

    # --- Normalizar letra de disco ---
    $disk = $TargetDisk.TrimEnd('\').TrimEnd('/')
    if ($disk -notmatch '^[A-Za-z]:$') {
        throw "Formato de disco no valido: '$TargetDisk'. Use formato D: E: F: etc."
    }
    $root = $disk + '\'

    # --- Verificar que el disco existe y tiene Windows ---
    if (-not (Test-Path $root)) {
        throw "El disco '$root' no es accesible. Verifique que esta montado correctamente."
    }
    $winPath = Join-Path $root "Windows\System32"
    if (-not (Test-Path $winPath)) {
        throw "No se encontro una instalacion de Windows en '$root'. Verifique la letra de disco."
    }

    # --- Normalizar OutputPath ---
    if ([string]::IsNullOrEmpty($OutputPath)) {
        $ts         = Get-Date -Format 'yyyyMMdd_HHmmss'
        $OutputPath = Join-Path (Split-Path $Script:OFSession.ScriptPath -Parent) "MaPeriT_OF_${CaseNumber}_${ts}"
    }

    # Ruta de salida absoluta y en forma larga: con una ruta relativa o en formato
    # corto 8.3 la columna RelativePath del manifiesto quedaba vacia y -VerifyPath
    # no podia localizar los ficheros si la carpeta se movia.
    $OutputPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine((Get-Location -PSProvider FileSystem).ProviderPath, $OutputPath))
    if (-not (Test-Path -LiteralPath $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    $OutputPath = (Get-Item -LiteralPath $OutputPath).FullName.TrimEnd('\')
    $Script:OFSession.OutputPath = $OutputPath

    # --- Crear estructura de directorios de salida (identica a SW) ---
    foreach ($dir in $Script:OutputDirs.Values) {
        $full = Join-Path $OutputPath $dir
        if (-not (Test-Path $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
    }

    # --- Crear directorio de logs e inicializar logging ---
    Initialize-OFLogging -LogsPath (Join-Path $OutputPath $Script:OutputDirs.Logs)

    # --- Detectar perfiles de usuario en el disco objetivo ---
    $usersRoot      = Join-Path $root $Script:TargetPaths.Users
    $detectedUsers  = @()
    if (Test-Path $usersRoot) {
        $detectedUsers = Get-ChildItem $usersRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $Script:ExcludedProfiles } |
            Select-Object -ExpandProperty Name
    }

    # Filtrar por TargetUser si se especifico.
    # BUG CONFIRMADO: si -TargetUser no coincidia con ningun perfil detectado
    # (p.ej. un simple error de escritura), la version anterior ampliaba el
    # alcance a TODOS los usuarios del disco de forma silenciosa (solo
    # Write-Warning, que no queda en ForensicLog.csv ni en el informe), y
    # ademas registraba igualmente "USUARIO_FILTRADO=OK" mas abajo como si el
    # filtro se hubiera aplicado. Si una orden judicial limita la adquisicion
    # a un custodio concreto, un typo del perito ampliaba el alcance sin fallar
    # y sin dejar rastro fiable de la desviacion en el propio log forense.
    # Postura fail-safe: restringir el alcance ante duda, nunca ampliarlo -
    # si el usuario indicado no existe, se detiene la ejecucion.
    if ($TargetUser -and ($TargetUser -notin $detectedUsers)) {
        Write-ForensicLog -Phase "OF" -Action "USUARIO_NO_ENCONTRADO" -Target $TargetUser -Result "ERROR" -Detail "Perfiles detectados: $($detectedUsers -join ', ')"
        throw "El usuario '$TargetUser' no se encontro en $usersRoot. Perfiles detectados: $($detectedUsers -join ', '). Adquisicion detenida para no exceder el alcance autorizado - revise el nombre e intente de nuevo."
    }
    $processedUsers = if ($TargetUser) { @($TargetUser) } else { $detectedUsers }

    # --- Hash del propio script ---
    $scriptHash = Get-ForensicHash -FilePath $Script:OFSession.ScriptPath

    # --- Rellenar sesion ---
    $Script:TargetRoot                = $root
    $Script:OFSession.TargetDisk      = $disk
    $Script:OFSession.TargetRoot      = $root
    $Script:OFSession.CaseNumber      = $CaseNumber
    $Script:OFSession.ExaminerName    = $ExaminerName
    $Script:OFSession.OutputPath      = $OutputPath
    $Script:OFSession.StartTime       = Get-Date
    $Script:OFSession.ScriptHash      = $scriptHash
    $Script:OFSession.DetectedUsers   = $detectedUsers
    $Script:OFSession.ProcessedUsers  = $processedUsers

    # --- Log de inicio (mismo formato que SW para que AN pueda leer el caso) ---
    Write-ForensicLog -Phase "OF" -Action "SESION_INICIADA" -Target $CaseNumber -Result "OK"
    Write-ForensicLog -Phase "OF" -Action "SCRIPT_HASH"    -Target $scriptHash  -Result "OK"
    Write-ForensicLog -Phase "OF" -Action "DISCO_OBJETIVO" -Target $root        -Result "OK"
    Write-ForensicLog -Phase "OF" -Action "PERITO"         -Target $ExaminerName -Result "OK"
    Write-ForensicLog -Phase "OF" -Action "USUARIOS_DETECTADOS" -Target ($detectedUsers -join ", ") -Result "OK"
    if ($TargetUser) {
        Write-ForensicLog -Phase "OF" -Action "USUARIO_FILTRADO" -Target $TargetUser -Result "OK"
    }
    if ($EvidenceDescription) {
        Write-ForensicLog -Phase "OF" -Action "DESCRIPCION" -Target $EvidenceDescription -Result "OK"
    }

    # --- Nota de adquisicion offline en 01_Volatile (AN espera esa carpeta) ---
    $volatilePath = Join-Path $OutputPath $Script:OutputDirs.Volatile
    $noteContent  = @"
ADQUISICION OFFLINE - MaPeriT.OF v$($Script:TOOL_VERSION)
===========================================================
Fecha            : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Caso             : $CaseNumber
Perito           : $ExaminerName
Disco objetivo   : $root
Descripcion      : $EvidenceDescription

NOTA: Esta adquisicion se realizo sobre un disco montado en otro equipo.
Los datos volatiles (RAM, procesos, red, portapapeles, cache DNS/ARP)
NO estan disponibles en adquisicion offline y han sido omitidos.
Los artefactos recopilados corresponden a las fases 2-10 (datos persistentes).
"@
    $noteContent | Out-File -FilePath (Join-Path $volatilePath "OFFLINE_ACQUISITION.txt") -Encoding UTF8 -Force

    return $OutputPath
}

function Show-OFBanner {
    Write-Host $Script:Banner -ForegroundColor Cyan
    Write-Host "  Disco objetivo  : $($Script:OFSession.TargetRoot)" -ForegroundColor White
    Write-Host "  Caso            : $($Script:OFSession.CaseNumber)"  -ForegroundColor White
    Write-Host "  Perito          : $($Script:OFSession.ExaminerName)" -ForegroundColor White
    Write-Host "  Salida          : $($Script:OFSession.OutputPath)"   -ForegroundColor White
    Write-Host "  Usuarios        : $($Script:OFSession.ProcessedUsers -join ', ')" -ForegroundColor White
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor DarkGray
    Write-Host "  AVISO: OF no escribe en el disco objetivo. Los hives se copian y se"  -ForegroundColor Yellow
    Write-Host "         carga una copia de trabajo; nunca se monta el original. Use un"  -ForegroundColor Yellow
    Write-Host "         bloqueador de escritura para garantizar la inalterabilidad."      -ForegroundColor Yellow
    Write-Host "  ================================================================" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-TargetUserPaths {
    # Devuelve array de hashtables {Name, Root} para cada usuario a procesar
    return $Script:OFSession.ProcessedUsers | ForEach-Object {
        @{
            Name = $_
            Root = Join-Path $Script:TargetRoot "$($Script:TargetPaths.Users)\$_"
        }
    }
}
