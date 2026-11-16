#region ============================================================
# MaPeriT.OF - CADENA DE CUSTODIA
# Mismo formato que SW -> HashManifest.csv compatible con AN
# ============================================================

$Script:ChainOfCustody = [System.Collections.Generic.List[PSCustomObject]]::new()
$Script:EvidenceCounter = 0

function Add-ChainOfCustodyEntry {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$Hash,
        [string]$Method   = "CopyItem",
        [long]$FileSize   = 0
    )
    $Script:EvidenceCounter++

    # Validar formato del hash antes de dejarlo constar en el acta de custodia (mismo
    # patron ya aplicado en MaPeriT.SW). Get-ForensicHash devuelve el texto literal
    # "ERROR_HASH" si el calculo falla; sin esta comprobacion ese texto quedaria escrito
    # en la columna SHA256 del manifiesto como si fuese un hash real, comprometiendo la
    # validez pericial de esa evidencia sin que nadie lo note.
    $isValidHash = $Hash -match '^[A-Fa-f0-9]{64}$'
    if (-not $isValidHash) {
        Write-ForensicLog -Action "HASH_INVALIDO_EN_CUSTODIA" -Target "$DestPath -> '$Hash'" -Result "ERROR" -Detail "El valor de hash no tiene formato SHA-256 valido (64 hex); revisar manualmente, puede que el fichero se haya eliminado o modificado tras la copia"
    }
    $hashField = if ($isValidHash) { $Hash } else { "INVALIDO:$Hash" }

    # Ruta relativa a la raiz de salida (anclada por prefijo, insensible a mayusculas),
    # para que -VerifyPath pueda reconstruir la ubicacion del fichero aunque la carpeta
    # de evidencias se haya movido o copiado a otra unidad para su presentacion judicial
    # -- DestPath por si solo queda "congelado" en la ruta absoluta del momento de la
    # adquisicion y deja de ser util si el perito mueve la carpeta despues.
    $relativePath = Get-RelativeEvidencePath -FullPath $DestPath -RootPath $Script:OFSession.OutputPath

    $entry = [PSCustomObject]@{
        EvidenceID        = "OF-{0:D5}" -f $Script:EvidenceCounter
        SourcePath        = $SourcePath
        DestPath          = $DestPath
        RelativePath      = $relativePath
        SHA256            = $hashField
        AcquisitionMethod = $Method
        Timestamp         = (Get-Date).ToString($Script:Defaults.DateFormat)
        FileSize          = $FileSize
    }
    $Script:ChainOfCustody.Add($entry)
}

function Export-HashManifest {
    param([string]$OutputPath, [string]$HMACKey = "")

    $manifestPath = Join-Path $OutputPath "HashManifest.csv"
    $Script:ChainOfCustody | Export-Csv -Path $manifestPath -NoTypeInformation -Encoding UTF8 -Force

    $hash = Get-ForensicHash -FilePath $manifestPath
    Write-ForensicLog -Action "HASH_MANIFEST_GENERADO" -Target "HashManifest.csv" -Result "OK" `
        -Detail "$($Script:ChainOfCustody.Count) evidencias | SHA256=$hash"

    if ($HMACKey) {
        Write-HMACSignature -ManifestPath $manifestPath -Key $HMACKey
    }

    return $manifestPath
}
