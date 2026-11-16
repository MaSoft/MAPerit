#region ============================================================
# MaPeriT.AN - ANALISIS DE FICHEROS BORRADOS (MFT)
# ============================================================

function Invoke-DeletedFilesAnalysis {
    param([string]$MFTOutputPath)

    $mftDel = Join-Path $MFTOutputPath "MFT_Borrados.csv"
    if (-not (Test-Path $mftDel)) { return $null }

    $deleted = @(Import-Csv $mftDel -ErrorAction SilentlyContinue)
    if (-not $deleted) { return $null }

    # Agrupar por extension para el informe
    $byExt = $deleted | ForEach-Object {
        $ext = [System.IO.Path]::GetExtension($_.NombreFichero).ToLower()
        if (-not $ext) { $ext = "(sin extension)" }
        $ext
    } | Group-Object | Sort-Object Count -Descending | Select-Object -First 20 |
    ForEach-Object {
        [PSCustomObject]@{ Extension = $_.Name; Cantidad = $_.Count }
    }

    # Ficheros borrados potencialmente interesantes
    $interesting = $deleted | Where-Object {
        $_.NombreFichero -match "\.(doc|docx|pdf|xls|xlsx|ppt|pptx|zip|rar|7z|exe|dll|ps1|bat|cmd|vbs|js|py|txt|csv|db|sqlite|pfx|pem|key|cer)$"
    }

    return @{
        Total       = $deleted.Count
        ByExtension = $byExt
        Interesting = $interesting
        Data        = $deleted
    }
}
