#region ============================================================
# MaPeriT.SW - MOTOR DE HASHING E INTEGRIDAD
# SHA-256, manifiestos, HMAC, verificacion
# ============================================================

function Get-ForensicHash {
    param(
        [string]$FilePath
    )
    try {
        if (-not (Test-Path $FilePath)) { return "FILE_NOT_FOUND" }
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256 -ErrorAction Stop
        return $hash.Hash
    } catch {
        return "HASH_ERROR: $($_.Exception.Message)"
    }
}

# Get-RelativeEvidencePath ya no se define aqui: se comparte con MaPeriT.OF
# via ..\Common\PathHelpers.ps1 (incluido por Build.ps1 antes de este
# fichero) para no mantener dos copias que puedan divergir o repetir el
# mismo bug de anclaje de ruta por separado. Ver ese fichero para el
# historial completo del bug que motivo la correccion original.

function Get-ScriptSelfHash {
    param(
        [string]$ScriptPath
    )
    if ([string]::IsNullOrEmpty($ScriptPath) -or -not (Test-Path $ScriptPath)) {
        return "SELF_HASH_UNAVAILABLE"
    }
    return Get-ForensicHash -FilePath $ScriptPath
}

function New-HashManifest {
    param(
        [string]$EvidenceRootPath,
        [string]$ManifestPath
    )
    Write-ForensicLog -Phase "INTEGRIDAD" -Action "GENERANDO_MANIFIESTO" -Target $EvidenceRootPath
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $manifestData = [System.Collections.ArrayList]::new()

    # Logs\ActionLog.csv es el registro vivo de la ejecucion: se sigue escribiendo
    # despues de generar el manifiesto (como minimo, la propia linea
    # MANIFIESTO_GENERADO de esta funcion). Incluido en el manifiesto, -VerifyPath
    # daba SIEMPRE "INTEGRIDAD COMPROMETIDA" sobre una adquisicion intacta. Se
    # excluye; cada evidencia sigue con su hash en Logs\ChainOfCustody.csv.
    $files = @(Get-ChildItem -Path $EvidenceRootPath -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { -not $Script:ActionLogPath -or $_.FullName -ne $Script:ActionLogPath })
    $total = $files.Count
    $current = 0

    foreach ($file in $files) {
        $current++
        if ($current % 50 -eq 0) {
            Write-Host "`r  [*] Calculando hashes: $current/$total" -ForegroundColor Yellow -NoNewline
        }
        try {
            $hash = Get-ForensicHash -FilePath $file.FullName
            $relativePath = Get-RelativeEvidencePath -FullPath $file.FullName -RootPath $EvidenceRootPath
            $lastMod = $file.LastWriteTimeUtc.ToString($Script:Defaults.DateFormat)
            [void]$manifestData.Add([PSCustomObject]@{
                FilePath = $relativePath
                SHA256 = $hash
                FileSize = $file.Length
                LastModified = $lastMod
            })
        } catch {
            $relativePath = Get-RelativeEvidencePath -FullPath $file.FullName -RootPath $EvidenceRootPath
            [void]$manifestData.Add([PSCustomObject]@{
                FilePath = $relativePath
                SHA256 = "HASH_ERROR"
                FileSize = 0
                LastModified = "ERROR"
            })
        }
    }

    Write-Host ""
    $manifestData | Export-Csv -Path $ManifestPath -NoTypeInformation -Encoding UTF8
    $sw.Stop()

    Write-ForensicLog -Phase "INTEGRIDAD" -Action "MANIFIESTO_GENERADO" -Target "$total ficheros hasheados" -Result "OK" -DurationMs $sw.ElapsedMilliseconds
    return $total
}

function Test-HashManifest {
    <#
        Unica implementacion de verificacion de integridad contra un manifiesto de
        hashes. Antes existia esta funcion (sin usar en ningun sitio) Y una segunda
        copia casi identica de la misma logica duplicada directamente en el bloque
        -VerifyPath de Main.ps1 -- dos sitios que mantener sincronizados para el mismo
        calculo de seguridad. Ahora -VerifyPath llama a esta funcion con -ShowProgress.
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
    $missing = 0
    $total = $manifestData.Count
    $current = 0

    foreach ($entry in $manifestData) {
        $current++
        if ($ShowProgress -and ($current % 25 -eq 0)) {
            Write-Host "`r  [*] Verificando: $current/$total" -ForegroundColor Yellow -NoNewline
        }

        $filePath = Join-Path $EvidenceRootPath $entry.FilePath
        $expectedHash = $entry.SHA256

        if ($expectedHash -like "HASH_ERROR*") { continue }

        if (-not (Test-Path $filePath)) {
            if ($ShowProgress) { Write-Host "`n  [-] FALTA: $($entry.FilePath)" -ForegroundColor Red }
            $mismatchList += [PSCustomObject]@{
                File = $entry.FilePath
                Expected = $expectedHash
                Actual = "FILE_MISSING"
                Status = "FALLO"
            }
            $missing++
            continue
        }

        $actualHash = Get-ForensicHash -FilePath $filePath
        if ($actualHash -ne $expectedHash) {
            if ($ShowProgress) {
                Write-Host "`n  [-] MODIFICADO: $($entry.FilePath)" -ForegroundColor Red
                Write-Host "      Esperado: $expectedHash" -ForegroundColor DarkGray
                Write-Host "      Actual:   $actualHash" -ForegroundColor DarkGray
            }
            $mismatchList += [PSCustomObject]@{
                File = $entry.FilePath
                Expected = $expectedHash
                Actual = $actualHash
                Status = "FALLO"
            }
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
            $mismatchList | ForEach-Object {
                Write-Host "      $($_.File): $($_.Status)" -ForegroundColor Red
            }
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

function New-EvidenceHMAC {
    param(
        [string]$ManifestPath,
        [string]$Key,
        [string]$OutputPath
    )
    if ([string]::IsNullOrEmpty($Key)) {
        Write-ForensicLog -Phase "INTEGRIDAD" -Action "HMAC_OMITIDO" -Target "No se proporciono clave HMAC" -Result "SKIP"
        return
    }

    try {
        $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($Key)
        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = $keyBytes

        $fileBytes = [System.IO.File]::ReadAllBytes($ManifestPath)
        $hashBytes = $hmac.ComputeHash($fileBytes)
        $hmacHex = [BitConverter]::ToString($hashBytes) -replace '-', ''

        $content = @"
HMAC-SHA256 del Manifiesto de Evidencias
==========================================
Fichero:  $(Split-Path $ManifestPath -Leaf)
Fecha:    $(Get-Date -Format $Script:Defaults.DateFormat)
HMAC:     $hmacHex

Para verificar la integridad del manifiesto, recalcule el HMAC-SHA256
del fichero HashManifest.csv usando la misma clave y compare con el
valor anterior.
"@
        $content | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-ForensicLog -Phase "INTEGRIDAD" -Action "HMAC_GENERADO" -Target $OutputPath -Result "OK"
    } catch {
        Write-ForensicLog -Phase "INTEGRIDAD" -Action "HMAC_ERROR" -Target $OutputPath -Result "ERROR" -ErrorMessage $_.Exception.Message
    } finally {
        if ($hmac) { $hmac.Dispose() }
    }
}
