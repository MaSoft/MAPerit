#region ============================================================
# MaPeriT.AN - DETECTOR DE TIMESTOMPING Y ANALISIS MFT
# ============================================================

function Invoke-TimestompAnalysis {
    param([string]$MFTOutputPath)

    $mftAll = Join-Path $MFTOutputPath "MFT_Completo.csv"
    $mftTs  = Join-Path $MFTOutputPath "MFT_Timestomping.csv"

    if (-not (Test-Path $mftTs)) { return $null }

    $tsData = @(Import-Csv $mftTs -ErrorAction SilentlyContinue)
    if (-not $tsData -or $tsData.Count -eq 0) { return $null }

    # Agrupar por tipo de razon
    $byReason = $tsData | Group-Object { $_.RazonTimestomp } |
                Sort-Object Count -Descending |
                ForEach-Object {
                    [PSCustomObject]@{
                        RazonTimestomp = $_.Name
                        Cantidad       = $_.Count
                        Ejemplos       = ($_.Group | Select-Object -First 3 | ForEach-Object { $_.RutaCompleta }) -join "; "
                    }
                }

    # Ficheros de sistema afectados (mas sospechosos)
    $sysAffected = $tsData | Where-Object { $_.RutaCompleta -match "Windows|System32|SysWOW64|Program Files" }

    return @{
        Total       = $tsData.Count
        ByReason    = $byReason
        SysAffected = $sysAffected
        Data        = $tsData
    }
}
