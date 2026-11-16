#region ============================================================
# MaPeriT.AN - INICIALIZACION Y VALIDACION
# ============================================================

function Test-SWEvidencePath {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "El directorio de evidencias no existe: $Path"
    }

    # Verificar que parece un directorio de MaPeriT.SW
    $manifest = Get-ChildItem $Path -Filter "HashManifest.csv" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $manifest) {
        throw "No se encontro HashManifest.csv en '$Path'. Asegurese de que es un directorio valido de MaPeriT.SW."
    }

    $fsDir = Join-Path $Path $Script:SW_Dirs.Filesystem
    if (-not (Test-Path $fsDir)) {
        Write-ANLog -Action "AVISO_ESTRUCTURA" -Target "Carpeta 03_Filesystem no encontrada" -Result "WARNING"
    }

    return $true
}

function Get-SWSessionInfo {
    param([string]$EvidencePath)

    $info = @{
        CaseNumber   = "DESCONOCIDO"
        ExaminerName = "DESCONOCIDO"
        ToolHash     = "DESCONOCIDO"
        StartTime    = $null
        OSVersion    = "DESCONOCIDO"
        ComputerName = "DESCONOCIDO"
    }

    # Intentar leer el log forense de OF. MaPeriT.OF nombra su log
    # "ForensicLog.csv" y SI registra SESION_INICIADA/SCRIPT_HASH como filas
    # propias. MaPeriT.SW usa un formato de log distinto ("ActionLog.csv",
    # sin esas acciones concretas) - para evidencia de SW este bloque nunca
    # encuentra nada y se recurre a los fallbacks de mas abajo (OSInfo.json +
    # InformePericial.html), que funcionan igual con evidencia de ambas
    # herramientas.
    $logPath = Join-Path $EvidencePath "$($Script:SW_Dirs.Logs)\ForensicLog.csv"
    if (Test-Path $logPath) {
        try {
            $logLines = Import-Csv $logPath -ErrorAction SilentlyContinue | Select-Object -First 100
            $initLine = $logLines | Where-Object { $_.Action -eq "SESION_INICIADA" } | Select-Object -First 1
            if ($initLine) { $info.CaseNumber = $initLine.Target }
            $hashLine = $logLines | Where-Object { $_.Action -eq "SCRIPT_HASH" } | Select-Object -First 1
            if ($hashLine) { $info.ToolHash = $hashLine.Target }
        } catch {}
    }

    # Extraer caso desde nombre del directorio (con o sin timestamp) - funciona
    # con la convencion de nombres por defecto de ambas herramientas.
    # Solo si el log no lo aporto (antes el nombre de carpeta sustituia al del log, y
    # con OF, "MaPeriT_OF_<caso>_<fecha>", el caso quedaba como "OF_<caso>").
    $dirName = Split-Path $EvidencePath -Leaf
    if ($info.CaseNumber -eq "DESCONOCIDO" -and $dirName -match "^(?:MaPeriT|ForensicPE)[._](?:OF_)?(.+?)(?:_\d{8}_\d{6})?$") {
        $candidate = $Matches[1] -replace "_\d{8}_\d{6}$",""
        if ($candidate -and $candidate -ne "DESCONOCIDO") { $info.CaseNumber = $candidate }
    }

    # OSInfo.json con multiples fallbacks de nombre de campo (antes se leia
    # este mismo fichero dos veces seguidas: una comprobacion simple que el
    # segundo bloque, mas completo, siempre sobreescribia igualmente -
    # eliminada la primera lectura redundante).
    $osPath = Join-Path $EvidencePath "$($Script:SW_Dirs.SystemInfo)\OSInfo.json"
    if (Test-Path $osPath) {
        try {
            $os = Get-Content $osPath -Raw | ConvertFrom-Json
            $info.OSVersion = if ($os.Caption) {$os.Caption}
                              elseif ($os.OSName) {$os.OSName}
                              elseif ($os.Name) {($os.Name -split "\|")[0].Trim()}
                              else {"DESCONOCIDO"}
            $info.ComputerName = if ($os.CSName) {$os.CSName}
                                 elseif ($os.ComputerName) {$os.ComputerName}
                                 elseif ($os.NombreEquipo) {$os.NombreEquipo}
                                 elseif ($os.SystemName) {$os.SystemName}
                                 else {"DESCONOCIDO"}
        } catch {}
    }

    # Perito y hash de la herramienta desde el informe HTML, para cuando el
    # log-based lookup de arriba no aplico (evidencia de SW, o de OF si algun
    # dia cambia su formato de log).
    # BUG CONFIRMADO: se leian solo las primeras 50 lineas del HTML
    # (-TotalCount 50) buscando "Perito" con una regex - pero el <style>
    # embebido (Get-ReportCSS/Get-OFCss) por si solo ocupa cerca de 290
    # lineas en SW y 210 en OF antes de llegar al <body>, asi que la ventana
    # de 50 lineas nunca alcanzaba el texto real: esta extraccion NUNCA ha
    # funcionado, ni con informes de SW ni de OF. Se lee el fichero completo
    # (un unico informe HTML, tamano manejable) en vez de un numero de
    # lineas fijo. Se aprovecha para extraer tambien el hash SHA-256 de la
    # herramienta (visible en portada/metodologia/pie del mismo informe),
    # que antes solo se obtenia via el log de OF y quedaba "DESCONOCIDO"
    # siempre para evidencia de SW.
    $reportHtml = Join-Path $EvidencePath "$($Script:SW_Dirs.Report)\InformePericial.html"
    if (Test-Path $reportHtml) {
        try {
            $content = Get-Content $reportHtml -Raw -ErrorAction SilentlyContinue
            if ($content) {
                if ($info.ExaminerName -eq "DESCONOCIDO" -and $content -match "Perito.*?>\s*([^<]{3,60})\s*<") {
                    $info.ExaminerName = $Matches[1].Trim()
                }
                if ($info.ToolHash -eq "DESCONOCIDO" -and $content -match "SHA-256.{0,60}?([A-Fa-f0-9]{64})") {
                    $info.ToolHash = $Matches[1]
                }
            }
        } catch {}
    }

    return $info
}

function Initialize-ANSession {
    param(
        [string]$EvidencePath,
        [string]$OutputPath,
        [string]$ExaminerName
    )

    $Script:ANSession.StartTime    = Get-Date
    $Script:ANSession.EvidencePath = $EvidencePath
    $Script:ANSession.OutputPath   = $OutputPath
    $Script:ANSession.ExaminerName = $ExaminerName

    $swInfo = Get-SWSessionInfo -EvidencePath $EvidencePath
    $Script:ANSession.SWCaseNumber = $swInfo.CaseNumber
    $Script:ANSession.SWExaminer   = $swInfo.ExaminerName
    $Script:ANSession.SWToolHash   = $swInfo.ToolHash

    if ([string]::IsNullOrEmpty($Script:ANSession.ExaminerName)) {
        $Script:ANSession.ExaminerName = $swInfo.ExaminerName
    }

    return $swInfo
}

function Initialize-ANOutputStructure {
    param([string]$OutputPath)
    foreach ($dir in $Script:AN_Dirs.Values) {
        $full = Join-Path $OutputPath $dir
        if (-not (Test-Path $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
    }
}

function Show-ANBanner {
    param([hashtable]$SWInfo)
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                              ║" -ForegroundColor Cyan
    Write-Host "  ║   MaPeriT.AN  v$($Script:AN_VERSION)  —  Analizador Forense Offline        ║" -ForegroundColor Cyan
    Write-Host "  ║                                                              ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "  EVIDENCIAS DE: $($Script:ANSession.EvidencePath)" -ForegroundColor White
    Write-Host "  Caso SW:       $($Script:ANSession.SWCaseNumber)"   -ForegroundColor Gray
    Write-Host "  Equipo:        $($SWInfo.ComputerName)"             -ForegroundColor Gray
    Write-Host "  SO:            $($SWInfo.OSVersion)"                -ForegroundColor Gray
    Write-Host "  Perito AN:     $($Script:ANSession.ExaminerName)"   -ForegroundColor Gray
    Write-Host "  Salida AN:     $($Script:ANSession.OutputPath)"     -ForegroundColor Gray
    Write-Host "  ════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
}
