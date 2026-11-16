#region ============================================================
# MaPeriT.SW - LINEA TEMPORAL UNIFICADA
# Correlacion de eventos de todas las fuentes
# ============================================================

function Build-ForensicTimeline {
    param([string]$OutputPath)

    $analysisPath = Join-Path $OutputPath $Script:OutputDirs.Analysis
    $timeline = [System.Collections.ArrayList]::new()

    Write-StepHeader "Construyendo Linea Temporal Unificada"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # --- Eventos de logon/logoff ---
    try {
        $logonFile = Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis\SecurityLogon.csv"
        if (Test-Path $logonFile) {
            Import-Csv $logonFile -ErrorAction SilentlyContinue | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.Timestamp
                    Origen      = "EventLog-Security"
                    Categoria   = "Sesion"
                    Evento      = "Logon $($_.TipoLogonDesc)"
                    Detalle     = "Usuario: $($_.UsuarioDestino)\$($_.DominioDestino) desde $($_.IPOrigen)"
                    Usuario     = $_.UsuarioDestino
                    Severidad   = "Info"
                })
            }
        }
    } catch { }

    # --- Logons fallidos ---
    try {
        $failedFile = Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis\SecurityFailedLogon.csv"
        if (Test-Path $failedFile) {
            Import-Csv $failedFile -ErrorAction SilentlyContinue | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.Timestamp
                    Origen      = "EventLog-Security"
                    Categoria   = "Sesion"
                    Evento      = "Logon FALLIDO"
                    Detalle     = "Usuario: $($_.UsuarioDestino) desde $($_.IPOrigen) - $($_.RazonFallo)"
                    Usuario     = $_.UsuarioDestino
                    Severidad   = "Warning"
                })
            }
        }
    } catch { }

    # --- Arranques/Apagados ---
    try {
        $shutdownFile = Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis\SystemShutdowns.csv"
        if (Test-Path $shutdownFile) {
            Import-Csv $shutdownFile -ErrorAction SilentlyContinue | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.Timestamp
                    Origen      = "EventLog-System"
                    Categoria   = "Sistema"
                    Evento      = $_.Tipo
                    Detalle     = $_.Mensaje
                    Usuario     = "SYSTEM"
                    Severidad   = if($_.EventID -eq '6008'){"Warning"}else{"Info"}
                })
            }
        }
    } catch { }

    # --- Servicios instalados ---
    try {
        $svcFile = Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis\SystemServices.csv"
        if (Test-Path $svcFile) {
            Import-Csv $svcFile -ErrorAction SilentlyContinue | Where-Object { $_.EventID -eq '7045' } | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.Timestamp
                    Origen      = "EventLog-System"
                    Categoria   = "Servicio"
                    Evento      = "Nuevo servicio instalado"
                    Detalle     = $_.Mensaje
                    Usuario     = "SYSTEM"
                    Severidad   = "Warning"
                })
            }
        }
    } catch { }

    # --- PowerShell scripts ---
    try {
        $psFile = Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis\PowerShellScripts.csv"
        if (Test-Path $psFile) {
            Import-Csv $psFile -ErrorAction SilentlyContinue | ForEach-Object {
                $scriptPreview = if ($_.ScriptBlock.Length -gt 100) { $_.ScriptBlock.Substring(0, 100) + "..." } else { $_.ScriptBlock }
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.Timestamp
                    Origen      = "EventLog-PowerShell"
                    Categoria   = "Ejecucion"
                    Evento      = "Script PowerShell ejecutado"
                    Detalle     = "Path: $($_.ScriptPath) | $scriptPreview"
                    Usuario     = ""
                    Severidad   = "Info"
                })
            }
        }
    } catch { }

    # --- RDP ---
    try {
        $rdpFile = Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis\RDPSessions.csv"
        if (Test-Path $rdpFile) {
            Import-Csv $rdpFile -ErrorAction SilentlyContinue | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.Timestamp
                    Origen      = "EventLog-RDP"
                    Categoria   = "Sesion"
                    Evento      = $_.Accion
                    Detalle     = $_.Mensaje
                    Usuario     = ""
                    Severidad   = "Info"
                })
            }
        }
    } catch { }

    # --- Tareas programadas ---
    try {
        $taskFile = Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis\TaskScheduler.csv"
        if (Test-Path $taskFile) {
            Import-Csv $taskFile -ErrorAction SilentlyContinue | Where-Object { $_.EventID -in @('106','141') } | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.Timestamp
                    Origen      = "EventLog-TaskScheduler"
                    Categoria   = "Tarea"
                    Evento      = $_.Accion
                    Detalle     = $_.Mensaje
                    Usuario     = ""
                    Severidad   = if($_.EventID -eq '106'){"Warning"}else{"Info"}
                })
            }
        }
    } catch { }

    # --- USB ---
    try {
        $usbFile = Join-Path $OutputPath "$($Script:OutputDirs.USB)\USBTimeline.csv"
        if (Test-Path $usbFile) {
            Import-Csv $usbFile -ErrorAction SilentlyContinue | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.Timestamp
                    Origen      = "USB-$($_.Origen)"
                    Categoria   = "Dispositivo"
                    Evento      = "Actividad USB"
                    Detalle     = $_.Mensaje
                    Usuario     = ""
                    Severidad   = "Info"
                })
            }
        }
    } catch { }

    # --- BAM/DAM (ejecucion de programas) ---
    try {
        $bamFile = Join-Path $OutputPath "$($Script:OutputDirs.Registry)\ExtractedValues\BAM_DAM.csv"
        if (Test-Path $bamFile) {
            Import-Csv $bamFile -ErrorAction SilentlyContinue | Where-Object { $_.FechaEjecucion } | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.FechaEjecucion
                    Origen      = "Registry-$($_.Origen)"
                    Categoria   = "Ejecucion"
                    Evento      = "Programa ejecutado (BAM/DAM)"
                    Detalle     = $_.Ejecutable
                    Usuario     = $_.SID
                    Severidad   = "Info"
                })
            }
        }
    } catch { }

    # --- UserAssist ---
    try {
        $uaFile = Join-Path $OutputPath "$($Script:OutputDirs.Registry)\ExtractedValues\UserAssist.csv"
        if (Test-Path $uaFile) {
            Import-Csv $uaFile -ErrorAction SilentlyContinue | Where-Object { $_.UltimaEjecucion } | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.UltimaEjecucion
                    Origen      = "Registry-UserAssist"
                    Categoria   = "Ejecucion"
                    Evento      = "Programa ejecutado ($($_.Ejecuciones)x)"
                    Detalle     = $_.Programa
                    Usuario     = $_.Usuario
                    Severidad   = "Info"
                })
            }
        }
    } catch { }

    # --- Prefetch ---
    try {
        $pfFile = Join-Path $OutputPath "$($Script:OutputDirs.Filesystem)\PrefetchSummary.csv"
        if (Test-Path $pfFile) {
            Import-Csv $pfFile -ErrorAction SilentlyContinue | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.Modificado
                    Origen      = "Prefetch"
                    Categoria   = "Ejecucion"
                    Evento      = "Programa en Prefetch"
                    Detalle     = $_.Nombre
                    Usuario     = ""
                    Severidad   = "Info"
                })
            }
        }
    } catch { }

    # --- Papelera de reciclaje ---
    try {
        $rbFile = Join-Path $OutputPath "$($Script:OutputDirs.Filesystem)\RecycleBinSummary.csv"
        if (Test-Path $rbFile) {
            Import-Csv $rbFile -ErrorAction SilentlyContinue | Where-Object { $_.FechaEliminacion -ne "N/A" } | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.FechaEliminacion
                    Origen      = "RecycleBin"
                    Categoria   = "Fichero"
                    Evento      = "Fichero eliminado"
                    Detalle     = "$($_.NombreOriginal) ($($_.TamanoOriginal) bytes)"
                    Usuario     = $_.SID
                    Severidad   = "Info"
                })
            }
        }
    } catch { }

    # --- Defender ---
    try {
        $defFile = Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis\DefenderEvents.csv"
        if (Test-Path $defFile) {
            Import-Csv $defFile -ErrorAction SilentlyContinue | Where-Object { $_.Level -in @('Warning','Error','Critical') } | ForEach-Object {
                [void]$timeline.Add([PSCustomObject]@{
                    Timestamp   = $_.Timestamp
                    Origen      = "Defender"
                    Categoria   = "Seguridad"
                    Evento      = "Evento Defender ($($_.Level))"
                    Detalle     = $_.Mensaje
                    Usuario     = "SYSTEM"
                    Severidad   = "Warning"
                })
            }
        }
    } catch { }

    # --- Ordenar y exportar ---
    $sortedTimeline = @($timeline | Sort-Object { try { [DateTime]::Parse($_.Timestamp) } catch { [DateTime]::MinValue } })

    if ($sortedTimeline.Count -gt 0) {
        Export-CollectionToCSV -Data $sortedTimeline -OutputPath (Join-Path $analysisPath "Timeline.csv") -Phase "ANALISIS" -Description "Timeline unificada"

        $recentDays = 7
        $cutoff = (Get-Date).AddDays(-$recentDays).ToString($Script:Defaults.DateFormat)
        $recentTimeline = @($sortedTimeline | Where-Object {
            try { [DateTime]::Parse($_.Timestamp) -ge [DateTime]::Parse($cutoff) } catch { $false }
        })
        if ($recentTimeline.Count -gt 0) {
            Export-CollectionToCSV -Data $recentTimeline -OutputPath (Join-Path $analysisPath "Timeline_Last${recentDays}Days.csv") -Phase "ANALISIS" -Description "Timeline ultimos $recentDays dias"
        }
    }

    $sw.Stop()
    Write-ForensicLog -Phase "ANALISIS" -Action "TIMELINE_COMPLETADA" -Target "$($timeline.Count) eventos" -Result "OK" -DurationMs $sw.ElapsedMilliseconds

    return $timeline.Count
}
