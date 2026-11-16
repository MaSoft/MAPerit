#region ============================================================
# MaPeriT.AN - ANALISIS SHIMCACHE Y AMCACHE
# ShimCache: registro de compatibilidad de aplicaciones.
# Amcache:   inventario de ejecutables y drivers instalados.
# Ambos revelan ejecucion de programas aunque no haya Event ID 4688.
# ============================================================

function Get-ANIOCHashSet {
    <#
        Carga una lista local de hashes conocidos (SHA1/SHA256/MD5, uno por linea;
        lineas vacias o que empiecen por # se ignoran) para correlacionar contra
        los hashes de Amcache. Coherente con la filosofia 100% offline del
        ecosistema (el aviso legal declara "No se realizan conexiones de red"):
        la lista la aporta el propio perito -- descargada aparte, de cualquier
        feed publico de IOCs que considere oportuno -- nunca se consulta nada en
        linea desde aqui.
    #>
    param([string]$Path)

    # Normalizado a MAYUSCULAS explicitamente (en vez de confiar en pasar
    # [System.StringComparer]::OrdinalIgnoreCase al constructor del HashSet):
    # verificado empiricamente que esa via NO aplicaba la comparacion insensible
    # a mayusculas/minusculas en este contexto - Contains() con una variante en
    # minusculas del mismo hash devolvia $false. Normalizar en el propio valor
    # es mas explicito y no depende de la resolucion de sobrecarga del
    # constructor.
    $set = [System.Collections.Generic.HashSet[string]]::new()
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) { return $set }

    try {
        $lines = Get-Content $Path -ErrorAction Stop
        foreach ($line in $lines) {
            $h = $line.Trim()
            if ([string]::IsNullOrEmpty($h) -or $h.StartsWith("#")) { continue }
            if ($h -match '^[A-Fa-f0-9]{32}$' -or $h -match '^[A-Fa-f0-9]{40}$' -or $h -match '^[A-Fa-f0-9]{64}$') {
                [void]$set.Add($h.ToUpper())
            }
        }
        Write-ANLog -Phase "IOC" -Action "IOC_HASHLIST_CARGADA" -Target "$($set.Count) hashes desde $Path" -Result "OK"
    } catch {
        Write-ANLog -Phase "IOC" -Action "IOC_HASHLIST_ERROR" -Target $Path -Result "WARNING" -Detail $_.Exception.Message
    }
    return $set
}

function Invoke-ShimcacheAnalysis {
    param(
        [string]$EvidencePath,
        [string]$OutputPath,
        [System.Collections.Generic.HashSet[string]]$IOCHashSet = $null
    )

    Write-ANSection "ANALISIS SHIMCACHE / AMCACHE"

    # ── ShimCache ───────────────────────────────────────────────────────
    # MaPeriT.SW deja ExtractedValues\ShimCache.csv (columna RutaEjecutable) y el
    # binario AppCompatCache.bin; MaPeriT.OF solo deja 04_Registry\AppCompatCache.bin.
    # Si no hay CSV se interpreta el binario (antes, con evidencias de OF, el
    # ShimCache no se analizaba).
    $regDir   = Join-Path $EvidencePath $Script:SW_Dirs.Registry
    $shimPath = Join-Path $regDir "ExtractedValues\ShimCache.csv"
    $shimData = @()
    if (Test-Path $shimPath) {
        $shimData = @(Import-Csv $shimPath -ErrorAction SilentlyContinue)
    } else {
        $binPath = @((Join-Path $regDir "ExtractedValues\AppCompatCache.bin"), (Join-Path $regDir "AppCompatCache.bin")) |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($binPath) {
            $shimData = @(ConvertFrom-ANShimCache -Data ([System.IO.File]::ReadAllBytes($binPath)))
            $shimPath = $binPath
        }
    }
    if ($shimPath -and (Test-Path $shimPath)) {
        if ($shimData.Count -gt 0) {
            Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_LEIDO" -Target "$($shimData.Count) entradas ($(Split-Path $shimPath -Leaf))" -Result "OK"

            # Filtrar ejecutables fuera de rutas estandar (mas sospechosos).
            # SW escribe la ruta en "RutaEjecutable"; se mantienen los nombres
            # alternativos por compatibilidad con CSV de versiones anteriores.
            $suspicious = @($shimData | Where-Object {
                $path = if ($_.RutaEjecutable) { $_.RutaEjecutable } elseif ($_.Ruta) { $_.Ruta } elseif ($_.Path) { $_.Path } elseif ($_.FileName) { $_.FileName } else { "" }
                # Prefijos de ruta NT ("\??\C:\..."), larga ("\\?\C:\...") y volumen del sistema ("SYSVOL\...")
                $norm = $path -replace '^\\\?\?\\', '' -replace '^\\\\\?\\', '' -replace '^SYSVOL\\', 'C:\'
                $norm -and
                $norm -notmatch "^[A-Za-z]:\\Windows\\" -and
                $norm -notmatch "^[A-Za-z]:\\Program Files" -and
                $norm -notmatch "^[A-Za-z]:\\ProgramData\\Microsoft"
            })

            Export-ANData -Data $shimData      -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\ShimCache_Completo.csv")     -Description "ShimCache completo"
            Export-ANData -Data $suspicious    -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\ShimCache_Sospechosos.csv")  -Description "ShimCache ejecutables fuera de rutas estandar"

            Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_SOSPECHOSOS" -Target "$($suspicious.Count) ejecutables fuera de rutas estandar" -Result $(if($suspicious.Count -gt 0){"WARNING"}else{"OK"})
        } else {
            Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_VACIO" -Target $shimPath -Result "WARNING"
        }
    } else {
        Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_NO_ENCONTRADO" -Target $shimPath -Result "WARNING"
    }

    # ── Amcache.hve (hive binario) ─────────────────────────────────────
    $amcachePath = Join-Path $EvidencePath "$($Script:SW_Dirs.Filesystem)\Amcache.hve"
    if (Test-Path $amcachePath) {
        Write-ANLog -Phase "SHIM" -Action "AMCACHE_ENCONTRADO" -Target $amcachePath -Result "OK"

        $amcacheData = @(Read-AmcacheHive -HivePath $amcachePath -OutputPath $OutputPath)
        if ($amcacheData.Count -gt 0) {
            Export-ANData -Data $amcacheData -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\Amcache_Ejecutables.csv") -Description "Amcache ejecutables"

            # Filtrar por hash SHA1 conocidos como maliciosos (listado basico de flags)
            # En produccion esto se conectaria con feeds de IOCs
            # FechaReferencia es texto crudo del registro (LinkDate/InstallDate, sin
            # formato garantizado) - un Sort-Object directo lo ordena como STRING,
            # no cronologicamente (p.ej. "9/1/2025" queda despues que "10/1/2025"),
            # por lo que "los 200 mas recientes" podia contener entradas antiguas y
            # omitir ejecuciones realmente recientes. Se ordena por fecha real
            # parseada (best-effort, sin descartar filas no parseables).
            $recentExes = @($amcacheData | Sort-Object -Descending -Property @{
                Expression = {
                    $dt = [datetime]::MinValue
                    if ($_.FechaReferencia) { [void][datetime]::TryParse($_.FechaReferencia, [ref]$dt) }
                    $dt
                }
            } | Select-Object -First 200)
            Export-ANData -Data $recentExes -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\Amcache_Recientes.csv") -Description "Amcache 200 mas recientes por fecha de referencia"

            # Correlacion con lista local de hashes IOC (opcional, ver -IOCHashListPath)
            if ($IOCHashSet -and $IOCHashSet.Count -gt 0) {
                $iocMatches = @($amcacheData | Where-Object { $_.SHA1 -and $IOCHashSet.Contains($_.SHA1.ToUpper()) })
                if ($iocMatches.Count -gt 0) {
                    Export-ANData -Data $iocMatches -Path (Join-Path $OutputPath "$($Script:AN_Dirs.MFT)\Amcache_IOCMatches.csv") -Description "Amcache - coincidencias con lista de IOCs"
                    Write-ANLog -Phase "SHIM" -Action "ALERTA_IOC_AMCACHE" -Target "$($iocMatches.Count) ejecutables coinciden con la lista de hashes IOC" -Result "WARNING"
                } else {
                    Write-ANLog -Phase "SHIM" -Action "IOC_SIN_COINCIDENCIAS" -Target "$($IOCHashSet.Count) hashes IOC comprobados, sin coincidencias en Amcache" -Result "OK"
                }
            }

            Write-ANLog -Phase "SHIM" -Action "AMCACHE_PROCESADO" -Target "$($amcacheData.Count) ejecutables en Amcache" -Result "OK"
        }
    } else {
        Write-ANLog -Phase "SHIM" -Action "AMCACHE_NO_ENCONTRADO" -Target $amcachePath -Result "WARNING"
    }
}

function ConvertFrom-ANShimCache {
    <#
        Interpreta el binario AppCompatCache (formato de Windows 10/11) que deja
        MaPeriT.OF en 04_Registry\AppCompatCache.bin. Mismo formato y misma
        logica que Parse-ShimCache de MaPeriT.SW 1.7.5 (comprobado contra datos
        reales); la fecha se da en UTC porque AN no se ejecuta en el equipo
        adquirido. Otros formatos (Windows 7/8) quedan anotados en el log.
    #>
    param([byte[]]$Data)

    $entries = [System.Collections.Generic.List[object]]::new()
    if ($null -eq $Data -or $Data.Length -lt 52) { return $entries }

    try {
        $offset = [int][BitConverter]::ToUInt32($Data, 0)
        if (($offset -ne 0x30 -and $offset -ne 0x34) -or [BitConverter]::ToUInt32($Data, $offset) -ne 0x73743031) {
            Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_FORMATO_NO_SOPORTADO" -Target ("Cabecera 0x{0:X}: solo se interpreta el formato de Windows 10/11" -f $offset) -Result "WARNING"
            return $entries
        }
        $indice = 0
        while ($offset + 14 -le $Data.Length) {
            if ([BitConverter]::ToUInt32($Data, $offset) -ne 0x73743031) { break }   # "10ts"
            $entrySize  = [int][BitConverter]::ToUInt32($Data, $offset + 8)
            $pathLength = [int][BitConverter]::ToUInt16($Data, $offset + 12)
            $pathOffset = $offset + 14
            if ($entrySize -le 0 -or $pathOffset + $pathLength + 8 -gt $Data.Length) { break }

            $path    = [System.Text.Encoding]::Unicode.GetString($Data, $pathOffset, $pathLength)
            $lastMod = ""
            $ticks   = [BitConverter]::ToInt64($Data, $pathOffset + $pathLength)
            if ($ticks -gt 0) {
                try { $lastMod = [DateTime]::FromFileTimeUtc($ticks).ToString("yyyy-MM-dd HH:mm:ss") } catch { }
            }

            [void]$entries.Add([PSCustomObject]@{
                Indice                 = $indice
                RutaEjecutable         = $path.TrimEnd("`0")
                UltimaModificacion_UTC = $lastMod
            })
            $indice++
            $offset = $offset + 12 + $entrySize
        }
    } catch {
        Write-ANLog -Phase "SHIM" -Action "SHIMCACHE_PARSE_ERROR" -Target $_.Exception.Message -Result "WARNING"
    }

    return $entries
}

function Read-AmcacheHive {
    param([string]$HivePath, [string]$OutputPath)

    $results = [System.Collections.Generic.List[object]]::new()
    $tempKey = "MAPE_AMCACHE_$(Get-Random)"
    $mounted = $false

    # NUNCA se monta el Amcache.hve de la evidencia: "reg load" abre el fichero en
    # lectura-escritura, puede reescribirlo y crea .LOG1/.LOG2 junto a el, lo que
    # rompia el hash registrado en el manifiesto de la adquisicion. Se monta una
    # copia de trabajo en la carpeta de salida de AN que se borra al terminar.
    $workDir = Join-Path $OutputPath "_amcache_trabajo_$(Get-Random)"
    try {
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workHive = Join-Path $workDir "Amcache.hve"
        foreach ($ext in @("", ".LOG1", ".LOG2")) {
            if (Test-Path -LiteralPath "$HivePath$ext") {
                Copy-Item -LiteralPath "$HivePath$ext" -Destination "$workHive$ext" -Force -ErrorAction Stop
                (Get-Item -LiteralPath "$workHive$ext" -Force).Attributes = 'Normal'
            }
        }

        # Montar la copia en HKU temporal
        $loadResult = & reg.exe load "HKU\$tempKey" $workHive 2>&1
        if ($LASTEXITCODE -eq 0) { $mounted = $true }
        if ($LASTEXITCODE -ne 0) {
            Write-ANLog -Phase "SHIM" -Action "AMCACHE_MOUNT_ERROR" -Target ($loadResult -join " ") -Result "WARNING"
            return $results
        }

        # Leer InventoryApplicationFile (ejecutables)
        $appFilePath = "Registry::HKU\$tempKey\Root\InventoryApplicationFile"
        if (Test-Path $appFilePath) {
            Get-ChildItem $appFilePath -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                    $results.Add([PSCustomObject]@{
                        Nombre        = if ($props.Name) {$props.Name} elseif ($props.'(default)') {$props.'(default)'} else {""}
                        RutaFichero   = if ($props.LowerCaseLongPath) {$props.LowerCaseLongPath} elseif ($props.LongPathHash) {$props.LongPathHash} else {""}
                        SHA1          = if ($props.FileId) { ($props.FileId -replace "^0000","") } else {""}
                        Version       = $props.Version
                        Publisher     = $props.Publisher
                        # LinkDate es la fecha de COMPILACION del ejecutable (cabecera PE),
                        # no la de ejecucion: antes se publicaba como "FechaEjecucion".
                        FechaReferencia = if ($props.LinkDate) { $props.LinkDate } else { "" }
                        TipoFecha     = if ($props.LinkDate) { "Compilacion del ejecutable (LinkDate)" } else { "" }
                        ProgramID     = $props.ProgramId
                        Arquitectura  = $props.Architecture
                    })
                } catch {}
            }
        }

        # Leer InventoryApplication (aplicaciones instaladas)
        $appPath = "Registry::HKU\$tempKey\Root\InventoryApplication"
        if (Test-Path $appPath) {
            Get-ChildItem $appPath -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                    $results.Add([PSCustomObject]@{
                        Nombre        = $props.Name
                        RutaFichero   = $props.RootDirPath
                        SHA1          = ""
                        Version       = $props.Version
                        Publisher     = $props.Publisher
                        FechaReferencia = $props.InstallDate
                        TipoFecha     = if ($props.InstallDate) { "Instalacion (InstallDate)" } else { "" }
                        ProgramID     = $props.ProgramId
                        Arquitectura  = ""
                    })
                } catch {}
            }
        }

    } catch {
        Write-ANLog -Phase "SHIM" -Action "AMCACHE_READ_ERROR" -Target $_.Exception.Message -Result "WARNING"
    } finally {
        if ($mounted) {
            # Liberar los manejadores que Get-ItemProperty deja abiertos sobre el hive;
            # sin esto "reg unload" puede fallar con "acceso denegado".
            [System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers()
            $null = & reg.exe unload "HKU\$tempKey" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-ANLog -Phase "SHIM" -Action "AMCACHE_UNLOAD_ERROR" -Target "HKU\$tempKey" -Result "WARNING" -Detail "Desmontar a mano con: reg unload HKU\$tempKey"
            }
        }
        Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    return $results
}
