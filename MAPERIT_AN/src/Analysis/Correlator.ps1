#region ============================================================
# MaPeriT.AN - CORRELADOR MULTI-FUENTE
# Cruza MFT + EVTX + Navegadores + datos SW para una timeline
# de alta fidelidad y scoring de riesgo por entidad.
# ============================================================

function Invoke-Correlation {
    param(
        [string]$ANOutputPath,
        [string]$SWEvidencePath
    )

    Write-ANSection "CORRELACION MULTI-FUENTE"

    $mftPath   = Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Completo.csv"
    $evtxPath  = Join-Path $ANOutputPath "$($Script:AN_Dirs.EVTX)\EVTX_Timeline.csv"
    $browsPath = Join-Path $ANOutputPath "$($Script:AN_Dirs.Browsers)\Browser_Historial.csv"
    $swTimeline= Join-Path $SWEvidencePath "$($Script:SW_Dirs.Analysis)\Timeline.csv"

    $timeline  = [System.Collections.Generic.List[object]]::new()
    $riskScores= [System.Collections.Generic.Dictionary[string, int]]::new()

    # ── Incorporar EVTX events ────────────────────────────────────────
    if (Test-Path $evtxPath) {
        $evtxData = @(Import-Csv $evtxPath -ErrorAction SilentlyContinue)
        foreach ($e in $evtxData) {
            $timeline.Add([PSCustomObject]@{
                Timestamp   = $e.TimeCreated_UTC
                ZonaHoraria = "UTC"
                Fuente      = "EVTX"
                EventID     = $e.EventID
                Categoria   = $e.Categoria
                Entidad     = if ($e.TargetUser) { $e.TargetUser } elseif ($e.SubjectUser) { $e.SubjectUser } else { "" }
                Descripcion = $e.Description
                Detalle     = "$($e.ProcessName) $($e.CommandLine) $($e.ServiceName)".Trim()
                Riesgo      = Get-EventRisk $e.EventID
            })
            # Acumular risk scores por usuario
            $user = if ($e.TargetUser) { $e.TargetUser } else { $e.SubjectUser }
            if ($user -and $user -ne "-" -and $user -ne "") {
                $riskScores[$user] = ($riskScores[$user] -as [int]) + (Get-EventRisk $e.EventID)
            }
        }
        Write-ANLog -Phase "CORR" -Action "EVTX_INCORPORADO" -Target "$($evtxData.Count) eventos" -Result "OK"
    }

    # ── Incorporar MFT timestomped ─────────────────────────────────────
    $mftTsPath = Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Timestomping.csv"
    if (Test-Path $mftTsPath) {
        $tsData = @(Import-Csv $mftTsPath -ErrorAction SilentlyContinue)
        foreach ($t in $tsData) {
            $timeline.Add([PSCustomObject]@{
                Timestamp   = $t.FN_Modificado_UTC
                ZonaHoraria = "UTC"
                Fuente      = "MFT_TIMESTOMP"
                EventID     = ""
                Categoria   = "Timestomping"
                Entidad     = $t.NombreFichero
                Descripcion = "Posible timestomping detectado: $($t.RazonTimestomp)"
                Detalle     = $t.RutaCompleta
                Riesgo      = 75
            })
        }
        Write-ANLog -Phase "CORR" -Action "MFT_TIMESTOMP_INCORPORADO" -Target "$($tsData.Count) entradas" -Result "OK"
    }

    # ── Incorporar ficheros borrados relevantes ─────────────────────────
    $mftDelPath = Join-Path $ANOutputPath "$($Script:AN_Dirs.MFT)\MFT_Borrados.csv"
    if (Test-Path $mftDelPath) {
        $delData = Import-Csv $mftDelPath -ErrorAction SilentlyContinue
        $interesting = @($delData | Where-Object {
            $_.NombreFichero -match "\.(exe|dll|ps1|bat|cmd|vbs|zip|rar|pdf|doc|xls)$"
        })
        foreach ($d in $interesting) {
            $timeline.Add([PSCustomObject]@{
                Timestamp   = $d.FN_Modificado_UTC
                ZonaHoraria = "UTC"
                Fuente      = "MFT_BORRADO"
                EventID     = ""
                Categoria   = "Fichero Borrado"
                Entidad     = $d.NombreFichero
                Descripcion = "Fichero borrado encontrado en MFT"
                Detalle     = $d.RutaCompleta
                Riesgo      = 30
            })
        }
        Write-ANLog -Phase "CORR" -Action "MFT_BORRADOS_INCORPORADO" -Target "$($interesting.Count) ficheros relevantes" -Result "OK"
    }

    # ── Incorporar timeline de SW ──────────────────────────────────────
    # Columnas reales de Analysis\Timeline.csv de MaPeriT.SW: Timestamp, Origen,
    # Categoria, Evento, Detalle, Usuario, Severidad (antes se leian Fuente/Tipo/
    # Entidad/Descripcion, que no existen, y los eventos de SW entraban vacios).
    # OJO: las horas de SW son hora LOCAL del equipo adquirido; las de EVTX/MFT son
    # UTC. La columna ZonaHoraria lo indica en cada fila.
    if (Test-Path $swTimeline) {
        $swData = @(Import-Csv $swTimeline -ErrorAction SilentlyContinue)
        foreach ($s in $swData) {
            $timeline.Add([PSCustomObject]@{
                Timestamp   = $s.Timestamp
                ZonaHoraria = "Local (equipo adquirido)"
                Fuente      = "SW_$($s.Origen)"
                EventID     = ""
                Categoria   = $s.Categoria
                Entidad     = $s.Usuario
                Descripcion = $s.Evento
                Detalle     = $s.Detalle
                Riesgo      = 10
            })
        }
        Write-ANLog -Phase "CORR" -Action "SW_TIMELINE_INCORPORADA" -Target "$($swData.Count) eventos SW" -Result "OK"
    }

    # ── Ordenar timeline ───────────────────────────────────────────────
    $sortedTimeline = @($timeline | Sort-Object Timestamp)
    Export-ANData -Data $sortedTimeline -Path (Join-Path $ANOutputPath "Correlacion_Timeline.csv") -Description "Timeline correlacionada"

    # ── Risk scores ───────────────────────────────────────────────────
    $scores = @($riskScores.GetEnumerator() | Sort-Object Value -Descending |
              ForEach-Object {
                  [PSCustomObject]@{
                      Entidad    = $_.Key
                      RiskScore  = $_.Value
                      Nivel      = if ($_.Value -gt 200) {"CRITICO"} elseif ($_.Value -gt 100) {"ALTO"} elseif ($_.Value -gt 50) {"MEDIO"} else {"BAJO"}
                  }
              })
    Export-ANData -Data $scores -Path (Join-Path $ANOutputPath "Correlacion_RiskScores.csv") -Description "Risk scores por entidad"

    Write-ANLog -Phase "CORR" -Action "CORRELACION_COMPLETA" -Target "Timeline=$($sortedTimeline.Count) eventos" -Result "OK"

    return @{
        Timeline   = $sortedTimeline
        RiskScores = $scores
    }
}

function Get-EventRisk {
    param([int]$EventID)
    switch ($EventID) {
        1102 { 90 }   # Log borrado
        1104 { 90 }   # Log borrado
        4697 { 80 }   # Servicio instalado
        7045 { 80 }   # Servicio nuevo
        4698 { 70 }   # Tarea programada
        4732 { 60 }   # Añadido a Administrators
        4720 { 50 }   # Cuenta creada
        4625 { 20 }   # Logon fallido
        4688 { 10 }   # Proceso creado
        4624 { 5  }   # Logon
        default { 5 }
    }
}
