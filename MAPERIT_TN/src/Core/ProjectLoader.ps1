#region ============================================================
# MaPeriT.TN - CARGADOR DE PROYECTOS MAPERIT
# ============================================================

function Test-MaPeriTProject {
    param([string]$Path)
    if (-not (Test-Path $Path -PathType Container)) { return $false }
    $hasManifest = (Test-Path (Join-Path $Path "Logs\HashManifest.csv")) -or
                   (Test-Path (Join-Path $Path "HashManifest.csv"))
    $hasPhase    = ($Script:SW_PhaseNames.Keys | Where-Object { Test-Path (Join-Path $Path $_) }) -ne $null
    return ($hasManifest -or $hasPhase)
}

function Get-ProjectMetadata {
    param([string]$Path)

    $meta = [ordered]@{
        Path          = $Path
        Name          = Split-Path $Path -Leaf
        CaseNumber    = ""
        Examiner      = ""
        StartTime     = ""
        ComputerName  = ""
        HasAN         = $false
        AnomalyCount  = 0
        ArtifactCount = 0
        PhaseCount    = 0
        FileSizeTotal = 0
    }

    # Intentar leer session.json (formato ideal, pero NI MaPeriT.SW NI MaPeriT.OF
    # lo generan actualmente - se deja el intento por si una version futura lo
    # escribe; ver fallback de ComputerName mas abajo, que si funciona hoy).
    $sessionCandidates = @(
        (Join-Path $Path "Logs\session.json"),
        (Join-Path $Path "session.json")
    )
    foreach ($sf in $sessionCandidates) {
        if (Test-Path $sf) {
            try {
                $s = Get-Content $sf -Raw | ConvertFrom-Json
                if ($s.CaseNumber)   { $meta.CaseNumber   = $s.CaseNumber }
                if ($s.ExaminerName) { $meta.Examiner      = $s.ExaminerName }
                if ($s.StartTime)    { $meta.StartTime     = $s.StartTime }
                if ($s.ComputerName) { $meta.ComputerName  = $s.ComputerName }
            } catch {}
            break
        }
    }

    # Fallback: ComputerName desde OSInfo.json (SW usa NombreEquipo, OF anade
    # CSName). Sin este fallback, ComputerName queda vacio en TODOS los casos
    # reales -- session.json arriba nunca existe en la practica -- pese a que
    # el dato si esta disponible en el propio proyecto.
    if ([string]::IsNullOrEmpty($meta.ComputerName)) {
        $osInfoPath = Join-Path $Path "02_SystemInfo\OSInfo.json"
        if (Test-Path $osInfoPath) {
            try {
                $osInfo = Get-Content $osInfoPath -Raw | ConvertFrom-Json
                if ($osInfo.NombreEquipo)   { $meta.ComputerName = $osInfo.NombreEquipo }
                elseif ($osInfo.CSName)     { $meta.ComputerName = $osInfo.CSName }
            } catch {}
        }
    }

    # Parsear numero de caso del nombre del directorio si no se encontro en session
    if ([string]::IsNullOrEmpty($meta.CaseNumber)) {
        $dirName = Split-Path $Path -Leaf
        if ($dirName -match '^MaPeriT_(?:OF_)?(.+?)_\d{8}') { $meta.CaseNumber = $Matches[1] }
    }

    # Contar fases presentes
    $meta.PhaseCount = @($Script:SW_PhaseNames.Keys | Where-Object { Test-Path (Join-Path $Path $_) }).Count

    # Detectar modulo AN
    $meta.HasAN = Test-Path (Join-Path $Path "ANALISIS_AN")

    # Contar artefactos (CSV + JSON)
    try {
        $files = Get-ChildItem $Path -Recurse -Include "*.csv","*.json" -ErrorAction SilentlyContinue
        $meta.ArtifactCount = $files.Count
        $meta.FileSizeTotal = ($files | Measure-Object -Property Length -Sum).Sum
    } catch {}

    # Contar anomalias desde el CSV de SW (SW solo lo crea si hay alguna). Antes,
    # si no existia, se contaban las entradas de 10_Persistence\AutorunsConsolidated.csv
    # y el panel mostraba como "anomalias" todos los programas de inicio.
    $ap = Join-Path $Path "Analysis\Anomalies.csv"
    if (Test-Path $ap) {
        try { $meta.AnomalyCount = @(Import-Csv $ap -ErrorAction SilentlyContinue).Count } catch {}
    }

    return $meta
}

function Get-ProjectTree {
    param([string]$RootPath)

    $root = [PSCustomObject]@{
        NodeType = "Project"
        Name     = Split-Path $RootPath -Leaf
        Path     = $RootPath
        Children = [System.Collections.Generic.List[object]]::new()
        Icon     = "P"
    }

    # Fases en orden conocido primero
    foreach ($dirKey in $Script:SW_PhaseNames.Keys) {
        $fullPath = Join-Path $RootPath $dirKey
        if (-not (Test-Path $fullPath -PathType Container)) { continue }

        $phaseNode = [PSCustomObject]@{
            NodeType = "Phase"
            Name     = $Script:SW_PhaseNames[$dirKey]
            Path     = $fullPath
            Icon     = "F"
            Children = [System.Collections.Generic.List[object]]::new()
        }
        foreach ($child in (Get-ChildNodes -Path $fullPath -Depth 0)) {
            $phaseNode.Children.Add($child) | Out-Null
        }
        $root.Children.Add($phaseNode) | Out-Null
    }

    # Directorios no reconocidos
    $knownDirs = @($Script:SW_PhaseNames.Keys)
    Get-ChildItem $RootPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $knownDirs } |
        ForEach-Object {
            $node = [PSCustomObject]@{
                NodeType = "Folder"
                Name     = $_.Name
                Path     = $_.FullName
                Icon     = "F"
                Children = [System.Collections.Generic.List[object]]::new()
            }
            foreach ($child in (Get-ChildNodes -Path $_.FullName -Depth 0)) {
                $node.Children.Add($child) | Out-Null
            }
            $root.Children.Add($node) | Out-Null
        }

    # Ficheros en la raiz
    Get-ChildItem $RootPath -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '\.(csv|json|html|txt|log)$' } |
        Sort-Object Name |
        ForEach-Object {
            $root.Children.Add((New-FileNode $_)) | Out-Null
        }

    return $root
}

function Get-ChildNodes {
    param([string]$Path, [int]$Depth)
    if ($Depth -gt 5) { return }
    $nodes = [System.Collections.Generic.List[object]]::new()

    Get-ChildItem $Path -Directory -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
        $node = [PSCustomObject]@{
            NodeType = "Folder"
            Name     = $_.Name
            Path     = $_.FullName
            Icon     = "F"
            Children = [System.Collections.Generic.List[object]]::new()
        }
        foreach ($child in (Get-ChildNodes -Path $_.FullName -Depth ($Depth + 1))) {
            $node.Children.Add($child) | Out-Null
        }
        $nodes.Add($node) | Out-Null
    }

    Get-ChildItem $Path -File -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
        $nodes.Add((New-FileNode $_)) | Out-Null
    }

    return $nodes
}

function New-FileNode {
    param([System.IO.FileInfo]$FileInfo)
    $ext = $FileInfo.Extension.ToLower()
    $icon = if ($Script:FileIcons.ContainsKey($ext)) { $Script:FileIcons[$ext] }
            elseif ($Script:SpecialFiles.ContainsKey($FileInfo.Name)) { "▦" }
            else { $Script:FileIcons["default"] }
    return [PSCustomObject]@{
        NodeType = "File"
        Name     = $FileInfo.Name
        Path     = $FileInfo.FullName
        Ext      = $ext
        Size     = $FileInfo.Length
        Icon     = $icon
        Children = $null
    }
}

function Get-FileViewerType {
    param([string]$FilePath)
    $name = [System.IO.Path]::GetFileName($FilePath)
    $ext  = [System.IO.Path]::GetExtension($FilePath).ToLower()

    # Ficheros especiales (incluyendo $MFT con el $ literal)
    if ($Script:SpecialFiles.ContainsKey($name))   { return $Script:SpecialFiles[$name] }
    # CSVs del modulo AN que son MFT parseado
    if ($name -match '^MFT_')                      { return "MFT" }
    if ($Script:ViewerMap.ContainsKey($ext))       { return $Script:ViewerMap[$ext] }
    return "Text"
}

function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -gt 1GB) { return "{0:N1} GB" -f ($Bytes / 1GB) }
    if ($Bytes -gt 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    if ($Bytes -gt 1KB) { return "{0:N0} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

#endregion
