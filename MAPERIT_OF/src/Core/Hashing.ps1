#region ============================================================
# MaPeriT.OF - HASHING Y HMAC
# ============================================================

function Get-ForensicHash {
    param([string]$FilePath)
    try {
        return (Get-FileHash -Path $FilePath -Algorithm SHA256 -ErrorAction Stop).Hash
    } catch {
        Write-ForensicLog -Action "HASH_ERROR" -Target $FilePath -Result "ERROR" -Detail $_.Exception.Message
        return "ERROR_HASH"
    }
}

function Get-StringHash {
    param([string]$InputString)
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash   = $sha256.ComputeHash($bytes)
    $sha256.Dispose()
    return [System.BitConverter]::ToString($hash) -replace '-', ''
}

function Get-HMACSignature {
    param([string]$FilePath, [string]$Key)
    try {
        $content   = [System.IO.File]::ReadAllBytes($FilePath)
        $keyBytes  = [System.Text.Encoding]::UTF8.GetBytes($Key)
        $hmac      = [System.Security.Cryptography.HMACSHA256]::new($keyBytes)
        $signature = $hmac.ComputeHash($content)
        $hmac.Dispose()
        return [System.BitConverter]::ToString($signature) -replace '-', ''
    } catch {
        Write-ForensicLog -Action "HMAC_ERROR" -Target $FilePath -Result "ERROR" -Detail $_.Exception.Message
        return "ERROR_HMAC"
    }
}

# Get-RelativeEvidencePath ya no se define aqui: se comparte con MaPeriT.SW
# via ..\Common\PathHelpers.ps1 (incluido por Build.ps1 antes de este
# fichero) para no mantener dos copias que puedan divergir o repetir el
# mismo bug de anclaje de ruta por separado.

function Test-HashManifest {
    <#
        Verifica la integridad de una adquisicion OF ya completada, comparando el
        HashManifest.csv contra los ficheros reales bajo -VerifyPath. Usa RelativePath
        (calculado en Add-ChainOfCustodyEntry) para reconstruir la ubicacion actual de
        cada fichero, no DestPath -- DestPath es la ruta ABSOLUTA del momento de la
        adquisicion y deja de ser fiable si la carpeta de evidencias se movio o se
        copio a otra unidad para su presentacion en sede judicial.
    #>
    param(
        [string]$ManifestPath,
        [string]$EvidenceRootPath,
        [switch]$ShowProgress
    )
    if (-not (Test-Path $ManifestPath)) {
        Write-Host "  [-] Manifiesto no encontrado: $ManifestPath" -ForegroundColor Red
        return [PSCustomObject]@{ Success = $false; Total = 0; Verified = 0; Missing = 0; Mismatches = 0 }
    }

    # @() obligatorio: Import-Csv con un manifiesto de UN solo fichero de evidencia
    # devuelve un objeto escalar (no un array) en PowerShell 5.1, y ese escalar no
    # tiene propiedad .Count -- $manifestData.Count quedaria en $null y "Total en
    # manifiesto" saldria vacio en el resumen, aunque la verificacion en si (el
    # foreach de mas abajo) funcione bien igualmente sobre un unico objeto.
    $manifestData = @(Import-Csv $ManifestPath -ErrorAction Stop)
    $mismatchList = @()
    $verified = 0
    $missing  = 0
    $total    = $manifestData.Count
    $current  = 0

    foreach ($entry in $manifestData) {
        $current++
        if ($ShowProgress -and ($current % 25 -eq 0)) {
            Write-Host "`r  [*] Verificando: $current/$total" -ForegroundColor Yellow -NoNewline
        }

        if ($entry.SHA256 -like "INVALIDO:*" -or $entry.SHA256 -like "ERROR_HASH*") { continue }

        # RelativePath puede no existir en manifiestos generados antes de esta version;
        # en ese caso, mejor esfuerzo con DestPath (funciona si no se ha movido la carpeta).
        $relPath = if ($entry.PSObject.Properties.Name -contains 'RelativePath' -and $entry.RelativePath) {
            $entry.RelativePath
        } else {
            $null
        }
        $filePath = if ($relPath) { Join-Path $EvidenceRootPath $relPath } else { $entry.DestPath }

        if (-not (Test-Path $filePath)) {
            if ($ShowProgress) { Write-Host "`n  [-] FALTA: $($entry.EvidenceID) ($filePath)" -ForegroundColor Red }
            $mismatchList += [PSCustomObject]@{ File = $filePath; Expected = $entry.SHA256; Actual = "FILE_MISSING"; Status = "FALLO" }
            $missing++
            continue
        }

        $actualHash = (Get-FileHash -Path $filePath -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
        if ($actualHash -ne $entry.SHA256) {
            if ($ShowProgress) {
                Write-Host "`n  [-] MODIFICADO: $($entry.EvidenceID) ($filePath)" -ForegroundColor Red
                Write-Host "      Esperado: $($entry.SHA256)" -ForegroundColor DarkGray
                Write-Host "      Actual:   $actualHash" -ForegroundColor DarkGray
            }
            $mismatchList += [PSCustomObject]@{ File = $filePath; Expected = $entry.SHA256; Actual = $actualHash; Status = "FALLO" }
        } else {
            $verified++
        }
    }
    if ($ShowProgress) { Write-Host "" }

    $success = ($mismatchList.Count -eq 0)
    if (-not $ShowProgress) {
        if ($success) {
            Write-Host "  [+] Verificacion de integridad OK: $verified ficheros verificados" -ForegroundColor Green
        } else {
            Write-Host "  [-] FALLOS DE INTEGRIDAD DETECTADOS: $($mismatchList.Count) ficheros" -ForegroundColor Red
            $mismatchList | ForEach-Object { Write-Host "      $($_.File): $($_.Status)" -ForegroundColor Red }
        }
    }

    return [PSCustomObject]@{
        Success    = $success
        Total      = $total
        Verified   = $verified
        Missing    = $missing
        Mismatches = ($mismatchList.Count - $missing)
    }
}

function Write-HMACSignature {
    param([string]$ManifestPath, [string]$Key)
    $signature  = Get-HMACSignature -FilePath $ManifestPath -Key $Key
    $sigFile    = $ManifestPath -replace '\.csv$', '_HMAC.txt'
    $sigContent = @"
MaPeriT.OF - Firma HMAC-SHA256 del Manifiesto de Evidencias
============================================================
Fichero firmado : $ManifestPath
Algoritmo       : HMAC-SHA256
Fecha de firma  : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Firma           : $signature

Para verificar: recalcule el HMAC-SHA256 del HashManifest.csv con la clave
secreta acordada y compare con el valor anterior.
"@
    $sigContent | Out-File -FilePath $sigFile -Encoding UTF8 -Force
    Write-ForensicLog -Action "HMAC_FIRMADO" -Target (Split-Path $sigFile -Leaf) -Result "OK"
}
