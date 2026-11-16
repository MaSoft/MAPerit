#region ============================================================
# MaPeriT.SW - DETECCION DE ANOMALIAS
# Motor de analisis automatizado
# ============================================================

function Find-ForensicAnomalies {
    param([string]$OutputPath)

    $analysisPath = Join-Path $OutputPath $Script:OutputDirs.Analysis
    $anomalies = [System.Collections.ArrayList]::new()
    $anomalyId = 0

    Write-StepHeader "Ejecutando Deteccion de Anomalias"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # --- A1: Procesos desde ubicaciones sospechosas ---
    try {
        $suspFile = Join-Path $OutputPath "$($Script:OutputDirs.Persistence)\SuspiciousProcesses.csv"
        if (Test-Path $suspFile) {
            $suspProcs = Import-Csv $suspFile -ErrorAction SilentlyContinue
            foreach ($proc in $suspProcs) {
                $anomalyId++
                [void]$anomalies.Add([PSCustomObject]@{
                    ID          = "ANO-{0:D4}" -f $anomalyId
                    Severidad   = $Script:AnomalySeverity.Medium
                    Categoria   = "Proceso sospechoso"
                    Titulo      = "Proceso ejecutandose desde ubicacion inusual"
                    Descripcion = "El proceso '$($proc.Nombre)' (PID: $($proc.PID)) se esta ejecutando desde '$($proc.Ejecutable)', que es una ubicacion atipica para ejecutables legitimos."
                    Evidencia   = $suspFile
                    Recomendacion = "Verificar la legitimidad del ejecutable. Comprobar su hash contra bases de datos de malware."
                })
            }
        }
    } catch { }

    # --- A2: Servicios sin firma digital ---
    try {
        $unsignedFile = Join-Path $OutputPath "$($Script:OutputDirs.Persistence)\UnsignedServices.csv"
        if (Test-Path $unsignedFile) {
            $unsignedSvcs = Import-Csv $unsignedFile -ErrorAction SilentlyContinue
            foreach ($svc in $unsignedSvcs) {
                $anomalyId++
                [void]$anomalies.Add([PSCustomObject]@{
                    ID          = "ANO-{0:D4}" -f $anomalyId
                    Severidad   = $Script:AnomalySeverity.High
                    Categoria   = "Servicio sin firma"
                    Titulo      = "Servicio con ejecutable sin firma valida: $($svc.Servicio)"
                    Descripcion = "El servicio '$($svc.NombreMostrado)' ejecuta '$($svc.Ejecutable)' con estado de firma '$($svc.EstadoFirma)'. Los servicios legitimos de Windows deben tener firma digital valida."
                    Evidencia   = $unsignedFile
                    Recomendacion = "Investigar el origen del ejecutable. Un servicio sin firma puede indicar manipulacion o software no autorizado."
                })
            }
        }
    } catch { }

    # --- A3: Persistencia WMI ---
    try {
        $wmiFile = Join-Path $OutputPath "$($Script:OutputDirs.Persistence)\WMIPersistence.csv"
        if (Test-Path $wmiFile) {
            $wmiItems = @(Import-Csv $wmiFile -ErrorAction SilentlyContinue)
            if ($wmiItems.Count -gt 0) {
                $anomalyId++
                [void]$anomalies.Add([PSCustomObject]@{
                    ID          = "ANO-{0:D4}" -f $anomalyId
                    Severidad   = $Script:AnomalySeverity.Critical
                    Categoria   = "Persistencia WMI"
                    Titulo      = "Suscripciones WMI de persistencia detectadas"
                    Descripcion = "Se detectaron $($wmiItems.Count) elementos de persistencia WMI (EventFilters, EventConsumers, Bindings). Las suscripciones WMI son un mecanismo avanzado de persistencia frecuentemente utilizado por malware y APTs."
                    Evidencia   = $wmiFile
                    Recomendacion = "Analizar detalladamente cada suscripcion WMI. Verificar si corresponden a software legitimo o a persistencia maliciosa."
                })
            }
        }
    } catch { }

    # --- A4: Fuerza bruta (logons fallidos excesivos) ---
    try {
        $failedFile = Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis\SecurityFailedLogon.csv"
        if (Test-Path $failedFile) {
            $failedLogons = Import-Csv $failedFile -ErrorAction SilentlyContinue
            $grouped = $failedLogons | Group-Object UsuarioDestino | Where-Object { $_.Count -gt 10 }
            foreach ($group in $grouped) {
                $anomalyId++
                [void]$anomalies.Add([PSCustomObject]@{
                    ID          = "ANO-{0:D4}" -f $anomalyId
                    Severidad   = if($group.Count -gt 50){$Script:AnomalySeverity.Critical}else{$Script:AnomalySeverity.High}
                    Categoria   = "Fuerza bruta"
                    Titulo      = "Multiples intentos de sesion fallidos para '$($group.Name)'"
                    Descripcion = "Se detectaron $($group.Count) intentos de inicio de sesion fallidos para el usuario '$($group.Name)'. Esto puede indicar un ataque de fuerza bruta o intentos de acceso no autorizado."
                    Evidencia   = $failedFile
                    Recomendacion = "Verificar las IPs de origen. Comprobar si los intentos coinciden con horarios laborales normales. Revisar si la cuenta fue finalmente comprometida."
                })
            }

            $groupedByIP = $failedLogons | Where-Object { $_.IPOrigen -and $_.IPOrigen -ne '-' } | Group-Object IPOrigen | Where-Object { $_.Count -gt 20 }
            foreach ($group in $groupedByIP) {
                $anomalyId++
                [void]$anomalies.Add([PSCustomObject]@{
                    ID          = "ANO-{0:D4}" -f $anomalyId
                    Severidad   = $Script:AnomalySeverity.High
                    Categoria   = "Fuerza bruta por IP"
                    Titulo      = "Multiples intentos fallidos desde IP $($group.Name)"
                    Descripcion = "$($group.Count) intentos de sesion fallidos originados desde la direccion IP '$($group.Name)'."
                    Evidencia   = $failedFile
                    Recomendacion = "Identificar la IP de origen. Verificar si es interna o externa. Considerar bloqueo si es maliciosa."
                })
            }
        }
    } catch { }

    # --- A5: Servicios instalados recientemente ---
    try {
        $recentSvcFile = Join-Path $OutputPath "$($Script:OutputDirs.Persistence)\RecentServiceInstalls.csv"
        if (Test-Path $recentSvcFile) {
            $recentSvcs = Import-Csv $recentSvcFile -ErrorAction SilentlyContinue
            foreach ($svc in $recentSvcs) {
                $riesgo = "Baja"
                if ($svc.ImagePath -match 'Users|Temp|AppData|cmd\.exe|powershell|mshta|wscript|cscript|rundll32') {
                    $riesgo = "Alta"
                }
                if ($riesgo -eq "Alta") {
                    $anomalyId++
                    [void]$anomalies.Add([PSCustomObject]@{
                        ID          = "ANO-{0:D4}" -f $anomalyId
                        Severidad   = $Script:AnomalySeverity.High
                        Categoria   = "Servicio sospechoso"
                        Titulo      = "Servicio instalado con ruta sospechosa: $($svc.NombreServicio)"
                        Descripcion = "El servicio '$($svc.NombreServicio)' fue instalado el $($svc.Timestamp) con ImagePath='$($svc.ImagePath)'. La ruta contiene indicadores de posible actividad maliciosa."
                        Evidencia   = $recentSvcFile
                        Recomendacion = "Investigar quien y por que instalo este servicio. Analizar el ejecutable."
                    })
                }
            }
        }
    } catch { }

    # --- A6: Alternate Data Streams ---
    try {
        $adsFile = Join-Path $OutputPath "$($Script:OutputDirs.Persistence)\AlternateDataStreams.csv"
        if (Test-Path $adsFile) {
            $ads = @(Import-Csv $adsFile -ErrorAction SilentlyContinue)
            if ($ads.Count -gt 0) {
                $anomalyId++
                [void]$anomalies.Add([PSCustomObject]@{
                    ID          = "ANO-{0:D4}" -f $anomalyId
                    Severidad   = $Script:AnomalySeverity.Medium
                    Categoria   = "Alternate Data Streams"
                    Titulo      = "Alternate Data Streams sospechosos detectados"
                    Descripcion = "Se encontraron $($ads.Count) Alternate Data Streams no estandar en ficheros del sistema. Los ADS pueden ser utilizados para ocultar datos o codigo malicioso."
                    Evidencia   = $adsFile
                    Recomendacion = "Examinar el contenido de cada ADS. Los ADS de Zone.Identifier son normales y han sido excluidos."
                })
            }
        }
    } catch { }

    # --- A7: Apagados inesperados ---
    try {
        $shutdownFile = Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis\SystemShutdowns.csv"
        if (Test-Path $shutdownFile) {
            $unexpected = @(Import-Csv $shutdownFile -ErrorAction SilentlyContinue | Where-Object { $_.EventID -eq '6008' })
            if ($unexpected.Count -gt 0) {
                $anomalyId++
                [void]$anomalies.Add([PSCustomObject]@{
                    ID          = "ANO-{0:D4}" -f $anomalyId
                    Severidad   = $Script:AnomalySeverity.Medium
                    Categoria   = "Apagado inesperado"
                    Titulo      = "$($unexpected.Count) apagados inesperados del sistema"
                    Descripcion = "El sistema registro $($unexpected.Count) eventos de apagado inesperado (Event ID 6008). Esto puede indicar cortes de energia, fallos del sistema, o desconexiones forzadas para evitar registro de actividad."
                    Evidencia   = $shutdownFile
                    Recomendacion = "Correlacionar las fechas de apagados inesperados con otros eventos del sistema."
                })
            }
        }
    } catch { }

    # --- A8: Amenazas detectadas por Defender ---
    try {
        $avFile = Join-Path $OutputPath "$($Script:OutputDirs.SystemInfo)\AntivirusStatus.json"
        if (Test-Path $avFile) {
            $avData = Get-Content $avFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
            # Una sola amenaza se serializa como objeto suelto, no como array: sin @()
            # su .Count es $null en PowerShell 5.1 y la anomalia CRITICA se perdia.
            $amenazas = @($avData.AmenazasDetectadas | Where-Object { $_ })
            if ($amenazas.Count -gt 0) {
                $anomalyId++
                [void]$anomalies.Add([PSCustomObject]@{
                    ID          = "ANO-{0:D4}" -f $anomalyId
                    Severidad   = $Script:AnomalySeverity.Critical
                    Categoria   = "Malware detectado"
                    Titulo      = "Windows Defender detecto $($amenazas.Count) amenazas"
                    Descripcion = "Windows Defender tiene registro de $($amenazas.Count) detecciones de amenazas en este sistema. Esto confirma la presencia de software malicioso o potencialmente no deseado."
                    Evidencia   = $avFile
                    Recomendacion = "Analizar cada amenaza detectada, verificar si fue eliminada o puesta en cuarentena. Determinar vector de entrada."
                })
            }
        }
    } catch { }

    # --- A9: Autoruns sospechosos ---
    try {
        $autoFile = Join-Path $OutputPath "$($Script:OutputDirs.Persistence)\AutorunsConsolidated.csv"
        if (Test-Path $autoFile) {
            $highRiskAutoruns = Import-Csv $autoFile -ErrorAction SilentlyContinue | Where-Object { $_.Riesgo -eq 'Alta' }
            foreach ($ar in $highRiskAutoruns) {
                $anomalyId++
                [void]$anomalies.Add([PSCustomObject]@{
                    ID          = "ANO-{0:D4}" -f $anomalyId
                    Severidad   = $Script:AnomalySeverity.High
                    Categoria   = "Autorun sospechoso"
                    Titulo      = "Autorun de alto riesgo: $($ar.Nombre)"
                    Descripcion = "Se detecto un autorun de alto riesgo: Tipo='$($ar.Tipo)', Nombre='$($ar.Nombre)', Valor='$($ar.Valor)'. Las entradas en ubicaciones de usuario o con rutas a interpretes de comandos son indicadores de posible compromiso."
                    Evidencia   = $autoFile
                    Recomendacion = "Verificar la legitimidad de este autorun. Comprobar si coincide con software conocido."
                })
            }
        }
    } catch { }

    # --- A10: Certificados raiz sospechosos ---
    try {
        $certFile = Join-Path $OutputPath "$($Script:OutputDirs.Persistence)\SuspiciousRootCerts.csv"
        if (Test-Path $certFile) {
            $certs = @(Import-Csv $certFile -ErrorAction SilentlyContinue)
            if ($certs.Count -gt 0) {
                $anomalyId++
                [void]$anomalies.Add([PSCustomObject]@{
                    ID          = "ANO-{0:D4}" -f $anomalyId
                    Severidad   = $Script:AnomalySeverity.High
                    Categoria   = "Certificado raiz sospechoso"
                    Titulo      = "$($certs.Count) certificados raiz no estandar en el almacen de confianza"
                    Descripcion = "Se detectaron certificados raiz en Cert:\LocalMachine\Root que no corresponden a autoridades de certificacion reconocidas. Esto puede indicar interceptacion de trafico HTTPS (MITM), adware o herramientas de monitorizacion de red."
                    Evidencia   = $certFile
                    Recomendacion = "Examinar cada certificado. Verificar si corresponde a software corporativo legitimo (proxies, DLP) o a software no autorizado."
                })
            }
        }
    } catch { }

    # --- A11: COM Hijacking ---
    try {
        $comFile = Join-Path $OutputPath "$($Script:OutputDirs.Persistence)\COMHijacking.csv"
        if (Test-Path $comFile) {
            $comEntries = Import-Csv $comFile -ErrorAction SilentlyContinue
            $highRisk = @($comEntries | Where-Object { $_.Riesgo -eq 'Alta' })
            if ($highRisk.Count -gt 0) {
                $anomalyId++
                [void]$anomalies.Add([PSCustomObject]@{
                    ID          = "ANO-{0:D4}" -f $anomalyId
                    Severidad   = $Script:AnomalySeverity.High
                    Categoria   = "COM Hijacking"
                    Titulo      = "$($highRisk.Count) entradas CLSID en HKCU apuntan a ubicaciones de usuario"
                    Descripcion = "Se detectaron objetos COM registrados en HKCU\Software\Classes\CLSID con servidores (InprocServer32/LocalServer32) que apuntan a directorios de usuario. Esta tecnica es utilizada para persistencia y evasion."
                    Evidencia   = $comFile
                    Recomendacion = "Verificar cada CLSID. Comprobar si los ejecutables referenciados son legitimos."
                })
            }
        }
    } catch { }

    # --- Exportar resultados ---
    if ($anomalies.Count -gt 0) {
        Export-CollectionToCSV -Data $anomalies -OutputPath (Join-Path $analysisPath "Anomalies.csv") -Phase "ANALISIS" -Description "Anomalias detectadas"
        Export-CollectionToJSON -Data $anomalies -OutputPath (Join-Path $analysisPath "Anomalies.json") -Phase "ANALISIS" -Description "Anomalias (JSON)"

        $summary = [PSCustomObject]@{
            TotalAnomalias = $anomalies.Count
            Criticas = @($anomalies | Where-Object { $_.Severidad -eq $Script:AnomalySeverity.Critical }).Count
            Altas    = @($anomalies | Where-Object { $_.Severidad -eq $Script:AnomalySeverity.High }).Count
            Medias   = @($anomalies | Where-Object { $_.Severidad -eq $Script:AnomalySeverity.Medium }).Count
            Bajas    = @($anomalies | Where-Object { $_.Severidad -eq $Script:AnomalySeverity.Low }).Count
        }

        Write-Host ""
        Write-Host "  ┌──────────────────────────────────────────┐" -ForegroundColor White
        Write-Host "  │      RESUMEN DE ANOMALIAS DETECTADAS     │" -ForegroundColor White
        Write-Host "  ├──────────────────────────────────────────┤" -ForegroundColor White
        if ($summary.Criticas -gt 0) {
            Write-Host "  │  CRITICAS:  $($summary.Criticas.ToString().PadRight(28))│" -ForegroundColor Red
        }
        if ($summary.Altas -gt 0) {
            Write-Host "  │  ALTAS:     $($summary.Altas.ToString().PadRight(28))│" -ForegroundColor DarkYellow
        }
        if ($summary.Medias -gt 0) {
            Write-Host "  │  MEDIAS:    $($summary.Medias.ToString().PadRight(28))│" -ForegroundColor Yellow
        }
        if ($summary.Bajas -gt 0) {
            Write-Host "  │  BAJAS:     $($summary.Bajas.ToString().PadRight(28))│" -ForegroundColor Cyan
        }
        Write-Host "  │  TOTAL:     $($summary.TotalAnomalias.ToString().PadRight(28))│" -ForegroundColor White
        Write-Host "  └──────────────────────────────────────────┘" -ForegroundColor White
    } else {
        Write-Host "  [+] No se detectaron anomalias significativas." -ForegroundColor Green
    }

    $sw.Stop()
    Write-ForensicLog -Phase "ANALISIS" -Action "ANOMALIAS_COMPLETADAS" -Target "$($anomalies.Count) anomalias" -Result "OK" -DurationMs $sw.ElapsedMilliseconds

    return $anomalies.Count
}
