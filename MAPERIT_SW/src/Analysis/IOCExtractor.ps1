#region ============================================================
# MaPeriT.SW - EXTRACCION DE IOCs (Indicators of Compromise)
# Consolida IPs, dominios y hashes de todas las fuentes
# ============================================================

function Export-ForensicIOCs {
    param([string]$OutputPath)

    $analysisPath = Join-Path $OutputPath $Script:OutputDirs.Analysis
    $iocs = [System.Collections.ArrayList]::new()

    Write-StepHeader "Extrayendo Indicadores de Compromiso (IOCs)"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # --- IPs remotas de conexiones TCP ---
    try {
        $tcpFile = Join-Path $OutputPath "$($Script:OutputDirs.Volatile)\NetworkConnections_TCP.csv"
        if (Test-Path $tcpFile) {
            Import-Csv $tcpFile -ErrorAction SilentlyContinue | Where-Object {
                $_.RemoteAddress -and $_.RemoteAddress -ne '0.0.0.0' -and $_.RemoteAddress -ne '::' -and
                $_.RemoteAddress -ne '127.0.0.1' -and $_.RemoteAddress -ne '::1' -and
                $_.RemoteAddress -notlike '192.168.*' -and $_.RemoteAddress -notlike '10.*' -and
                $_.RemoteAddress -notlike '172.1[6-9].*' -and $_.RemoteAddress -notlike '172.2[0-9].*' -and
                $_.RemoteAddress -notlike '172.3[0-1].*'
            } | ForEach-Object {
                [void]$iocs.Add([PSCustomObject]@{
                    Tipo    = "IP"
                    Valor   = $_.RemoteAddress
                    Fuente  = "TCP Connections"
                    Contexto = "Puerto: $($_.RemotePort), Proceso: $($_.ProcessName), Estado: $($_.State)"
                })
            }
        }
    } catch { }

    # --- Dominios de cache DNS ---
    try {
        $dnsFile = Join-Path $OutputPath "$($Script:OutputDirs.Volatile)\DnsCache.csv"
        if (Test-Path $dnsFile) {
            Import-Csv $dnsFile -ErrorAction SilentlyContinue | Where-Object { $_.Entry -and $_.Entry -ne '' } | ForEach-Object {
                [void]$iocs.Add([PSCustomObject]@{
                    Tipo    = "Dominio"
                    Valor   = $_.Entry
                    Fuente  = "DNS Cache"
                    Contexto = "Data: $($_.Data)"
                })
            }
        }
    } catch { }

    # --- Hashes de procesos ---
    try {
        $hashFile = Join-Path $OutputPath "$($Script:OutputDirs.Volatile)\ProcessHashes.csv"
        if (Test-Path $hashFile) {
            Import-Csv $hashFile -ErrorAction SilentlyContinue | ForEach-Object {
                [void]$iocs.Add([PSCustomObject]@{
                    Tipo    = "SHA256"
                    Valor   = $_.SHA256
                    Fuente  = "Procesos Activos"
                    Contexto = "PID: $($_.ProcessId), Nombre: $($_.Name), Ruta: $($_.Path)"
                })
            }
        }
    } catch { }

    # --- IPs de logons fallidos ---
    try {
        $failedFile = Join-Path $OutputPath "$($Script:OutputDirs.EventLogs)\Analysis\SecurityFailedLogon.csv"
        if (Test-Path $failedFile) {
            Import-Csv $failedFile -ErrorAction SilentlyContinue | Where-Object {
                $_.IPOrigen -and $_.IPOrigen -ne '-' -and $_.IPOrigen -ne '' -and $_.IPOrigen -ne '127.0.0.1'
            } | Group-Object IPOrigen | ForEach-Object {
                [void]$iocs.Add([PSCustomObject]@{
                    Tipo    = "IP"
                    Valor   = $_.Name
                    Fuente  = "Failed Logons"
                    Contexto = "$($_.Count) intentos fallidos"
                })
            }
        }
    } catch { }

    # --- Servidores RDP ---
    try {
        $rdpFile = Join-Path $OutputPath "$($Script:OutputDirs.Registry)\ExtractedValues\RDPHistory.csv"
        if (Test-Path $rdpFile) {
            Import-Csv $rdpFile -ErrorAction SilentlyContinue | ForEach-Object {
                [void]$iocs.Add([PSCustomObject]@{
                    Tipo    = "Host"
                    Valor   = $_.Servidor
                    Fuente  = "RDP History"
                    Contexto = "Usuario: $($_.Usuario), UsuarioRDP: $($_.UsuarioRDP)"
                })
            }
        }
    } catch { }

    # --- URLs de MRU ---
    try {
        $mruFile = Join-Path $OutputPath "$($Script:OutputDirs.Registry)\ExtractedValues\MRULists.csv"
        if (Test-Path $mruFile) {
            Import-Csv $mruFile -ErrorAction SilentlyContinue | Where-Object { $_.Tipo -eq 'TypedURLs' } | ForEach-Object {
                [void]$iocs.Add([PSCustomObject]@{
                    Tipo    = "URL"
                    Valor   = $_.Valor
                    Fuente  = "TypedURLs"
                    Contexto = "Usuario: $($_.Usuario)"
                })
            }
        }
    } catch { }

    # --- Deduplicar y exportar ---
    if ($iocs.Count -gt 0) {
        $uniqueIOCs = $iocs | Sort-Object Tipo, Valor -Unique
        Export-CollectionToCSV -Data $uniqueIOCs -OutputPath (Join-Path $analysisPath "IOCs.csv") -Phase "ANALISIS" -Description "IOCs consolidados"
        Export-CollectionToJSON -Data $uniqueIOCs -OutputPath (Join-Path $analysisPath "IOCs.json") -Phase "ANALISIS" -Description "IOCs (JSON)"
    }

    $sw.Stop()
    Write-ForensicLog -Phase "ANALISIS" -Action "IOC_EXTRACCION" -Target "$($iocs.Count) indicadores extraidos" -Result "OK" -DurationMs $sw.ElapsedMilliseconds

    return $iocs.Count
}
