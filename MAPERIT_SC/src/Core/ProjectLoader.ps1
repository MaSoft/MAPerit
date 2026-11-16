#region ============================================================
# MaPeriT.SC - VALIDACION Y METADATOS DEL PROYECTO
# SC solo lee resultados ya generados por MaPeriT.AN. No modifica nada
# dentro de la carpeta de evidencias ni de ANALISIS_AN.
# ============================================================

function Test-SCProject {
    <#
    Valida que $Path sea una carpeta de evidencias MaPeriT con analisis
    AN ya generado (requisito de entrada de SC).
    #>
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path $Path -PathType Container)) { return $false }

    $anPath = Join-Path $Path $Script:AN_OutputFolderName
    if (-not (Test-Path $anPath -PathType Container)) { return $false }

    # Con al menos una subcarpeta conocida o el timeline de correlacion basta
    # para considerar que AN se ejecuto correctamente sobre este proyecto.
    $hasKnownDir = @($Script:AN_Dirs.Values | Where-Object { Test-Path (Join-Path $anPath $_) }).Count -gt 0
    $hasTimeline = Test-Path (Join-Path $anPath "Correlacion_Timeline.csv")

    return ($hasKnownDir -or $hasTimeline)
}

function Get-SCProjectMetadata {
    param([string]$Path)

    $meta = [ordered]@{
        Path         = $Path
        Name         = Split-Path $Path -Leaf
        CaseNumber   = ""
        Examiner     = ""
        ComputerName = ""
        ANOutputPath = Join-Path $Path $Script:AN_OutputFolderName
    }

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
                if ($s.ComputerName) { $meta.ComputerName  = $s.ComputerName }
            } catch {}
            break
        }
    }

    if ([string]::IsNullOrEmpty($meta.CaseNumber)) {
        $dirName = Split-Path $Path -Leaf
        if ($dirName -match '^MaPeriT_(?:OF_)?(.+?)_\d{8}') { $meta.CaseNumber = $Matches[1] }
    }

    # Ni MaPeriT.SW ni MaPeriT.OF generan session.json: sin estos respaldos el
    # "Equipo" y el "Perito" (tambien en la firma del informe) salian SIEMPRE
    # vacios. Mismas fuentes que usa MaPeriT.AN (Get-SWSessionInfo).
    if ([string]::IsNullOrEmpty($meta.ComputerName)) {
        $osPath = Join-Path $Path "02_SystemInfo\OSInfo.json"
        if (Test-Path $osPath) {
            try {
                $os = Get-Content $osPath -Raw | ConvertFrom-Json
                $meta.ComputerName = if ($os.CSName) { $os.CSName } elseif ($os.ComputerName) { $os.ComputerName } elseif ($os.NombreEquipo) { $os.NombreEquipo } elseif ($os.SystemName) { $os.SystemName } else { "" }
            } catch {}
        }
    }
    if ([string]::IsNullOrEmpty($meta.Examiner)) {
        $reportHtml = Join-Path $Path "Report\InformePericial.html"
        if (Test-Path $reportHtml) {
            try {
                $content = Get-Content $reportHtml -Raw -ErrorAction SilentlyContinue
                # Portada de SW ("Perito") y de OF ("Perito Informatico")
                if ($content -match "<label>Perito(?: Informatico)?</label>\s*<span>([^<]{1,80})</span>") {
                    $meta.Examiner = [System.Web.HttpUtility]::HtmlDecode($Matches[1].Trim())
                }
            } catch {}
        }
    }

    return [PSCustomObject]$meta
}

#endregion
