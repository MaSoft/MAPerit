#region ============================================================
# MaPeriT.AN - PARSER SQLite DE NAVEGADORES
# Lee los ficheros History/places.sqlite copiados por MaPeriT.SW.
# Intenta multiple metodos: Microsoft.Data.Sqlite, System.Data.SQLite,
# sqlite3.exe en PATH o en tools/. Sin internet.
# ============================================================

$Script:SQLiteAvailable = $false
$Script:SQLiteMethod    = "none"

function Initialize-SQLiteParser {
    # Metodo 1: Microsoft.Data.Sqlite (disponible en .NET 5+)
    try {
        Add-Type -AssemblyName "Microsoft.Data.Sqlite" -ErrorAction Stop
        $Script:SQLiteAvailable = $true
        $Script:SQLiteMethod    = "Microsoft.Data.Sqlite"
        Write-ANLog -Action "SQLITE_METODO" -Target "Microsoft.Data.Sqlite" -Result "OK"
        return $true
    } catch {}

    # Metodo 2: System.Data.SQLite
    $sqliteDllPaths = @(
        (Join-Path $env:ProgramFiles "System.Data.SQLite\System.Data.SQLite.dll"),
        (Join-Path $env:ProgramFiles "SQLite\System.Data.SQLite.dll"),
        "System.Data.SQLite.dll"
    )
    foreach ($dll in $sqliteDllPaths) {
        if (Test-Path $dll) {
            try {
                Add-Type -Path $dll -ErrorAction Stop
                $Script:SQLiteAvailable = $true
                $Script:SQLiteMethod    = "System.Data.SQLite"
                Write-ANLog -Action "SQLITE_METODO" -Target "System.Data.SQLite ($dll)" -Result "OK"
                return $true
            } catch {}
        }
    }

    # Metodo 3: sqlite3.exe en PATH o en carpeta tools de SW
    # Usar la ruta del script capturada al inicio (fiable en scripts compilados)
    $scriptDir = if ($Script:ANScriptRoot) { $Script:ANScriptRoot } else { $PSScriptRoot }
    $sqlite3Paths = @(
        "sqlite3.exe",
        (Join-Path $scriptDir "tools\sqlite3.exe"),
        (Join-Path $scriptDir "Bin\sqlite3.exe"),
        (Join-Path $scriptDir "sqlite3.exe"),
        (Join-Path $Script:ANSession.EvidencePath "tools\sqlite3.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Git\mingw64\bin\sqlite3.exe"),
        (Join-Path $env:ProgramFiles "Git\mingw64\bin\sqlite3.exe")
    )
    if ($env:ChocolateyInstall) {
        $sqlite3Paths += (Join-Path $env:ChocolateyInstall "bin\sqlite3.exe")
    }
    foreach ($s3 in $sqlite3Paths) {
        $resolved = Get-Command $s3 -ErrorAction SilentlyContinue
        if ($resolved -or (Test-Path $s3)) {
            $Script:SQLiteAvailable = $true
            $Script:SQLiteMethod    = "sqlite3.exe:$(if($resolved){$resolved.Source}else{$s3})"
            Write-ANLog -Action "SQLITE_METODO" -Target "sqlite3.exe" -Result "OK"
            return $true
        }
    }

    Write-ANLog -Action "SQLITE_NO_DISPONIBLE" -Target "Instale sqlite3.exe en PATH o en tools\" -Result "WARNING"
    return $false
}

function Invoke-SQLiteQuery {
    param([string]$DbPath, [string]$Query)

    if (-not (Test-Path $DbPath)) { return @() }

    # Trabajar sobre una copia temporal (los originales pueden estar en uso)
    $tmpDb = [System.IO.Path]::GetTempFileName() + ".db"
    Copy-Item $DbPath $tmpDb -Force -ErrorAction SilentlyContinue

    try {
        switch -Wildcard ($Script:SQLiteMethod) {
            "Microsoft.Data.Sqlite" {
                $connStr = "Data Source=$tmpDb;Mode=ReadOnly"
                $conn = New-Object Microsoft.Data.Sqlite.SqliteConnection($connStr)
                $conn.Open()
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = $Query
                $reader = $cmd.ExecuteReader()
                $results = @()
                while ($reader.Read()) {
                    $row = [ordered]@{}
                    for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                        $row[$reader.GetName($i)] = if ($reader.IsDBNull($i)) { "" } else { $reader.GetValue($i).ToString() }
                    }
                    $results += [PSCustomObject]$row
                }
                $reader.Close(); $conn.Close()
                return $results
            }
            "System.Data.SQLite" {
                $connStr = "Data Source=$tmpDb;Version=3;Read Only=True"
                $conn = New-Object System.Data.SQLite.SQLiteConnection($connStr)
                $conn.Open()
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = $Query
                $adapter = New-Object System.Data.SQLite.SQLiteDataAdapter($cmd)
                $dt = New-Object System.Data.DataTable
                [void]$adapter.Fill($dt)
                $conn.Close()
                return $dt.Rows | ForEach-Object {
                    $row = [ordered]@{}
                    foreach ($col in $dt.Columns) { $row[$col.ColumnName] = $_[$col.ColumnName].ToString() }
                    [PSCustomObject]$row
                }
            }
            "sqlite3.exe:*" {
                # BUG CONFIRMADO EN PRODUCCION: $Script:SQLiteMethod tiene forma
                # "sqlite3.exe:<ruta completa>", y la ruta completa (p.ej.
                # "I:\OneDrive\...\sqlite3.exe") tiene SU PROPIA letra de unidad
                # con dos puntos. Split(":") sin limite parte por TODOS los ":",
                # asi que [1] devolvia solo "I" en vez de la ruta - exactamente
                # el error visto en logs reales: "The term 'I' is not recognized".
                # Limitar a 2 partes (solo el primer ":") conserva la ruta intacta.
                $exe = ($Script:SQLiteMethod -split ':', 2)[1]
                $csv = & $exe $tmpDb ".mode csv" ".headers on" $Query 2>$null
                if ($csv) { return $csv | ConvertFrom-Csv }
                return @()
            }
        }
    } catch {
        Write-ANLog -Action "SQLITE_QUERY_ERROR" -Target $_.Exception.Message -Result "WARNING"
        return @()
    } finally {
        Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue
    }
}

# Convierte el timestamp de Chrome (microsegundos desde 1601-01-01 UTC) a texto UTC.
# AddTicks(us * 10) y no AddMicroseconds: este ultimo solo existe en .NET 7+ y en
# PowerShell 5.1 (.NET Framework) lanzaba excepcion -> TODAS las fechas de
# historial, descargas y busquedas salian vacias.
function ConvertFrom-ChromeTime {
    param([long]$ChromeTime)
    if ($ChromeTime -le 0) { return "" }
    try {
        $base = [datetime]::new(1601,1,1,0,0,0,[System.DateTimeKind]::Utc)
        return $base.AddTicks($ChromeTime * 10).ToString("yyyy-MM-dd HH:mm:ss")
    } catch { return "" }
}

# Firefox: microsegundos desde 1970-01-01 UTC
function ConvertFrom-FirefoxTime {
    param([long]$FirefoxTime)
    if ($FirefoxTime -le 0) { return "" }
    try {
        $base = [datetime]::new(1970,1,1,0,0,0,[System.DateTimeKind]::Utc)
        return $base.AddTicks($FirefoxTime * 10).ToString("yyyy-MM-dd HH:mm:ss")
    } catch { return "" }
}

function Invoke-BrowserAnalysis {
    param(
        [string]$BrowsersPath,
        [string]$OutputPath
    )

    Write-ANSection "ANALISIS NAVEGADORES - SQLite"
    $browsOut = Join-Path $OutputPath $Script:AN_Dirs.Browsers

    if (-not (Test-Path $BrowsersPath)) {
        Write-ANLog -Phase "BROWSER" -Action "CARPETA_NO_ENCONTRADA" -Target $BrowsersPath -Result "WARNING"
        return
    }

    $allHistory   = [System.Collections.Generic.List[object]]::new()
    $allDownloads = [System.Collections.Generic.List[object]]::new()
    $allSearches  = [System.Collections.Generic.List[object]]::new()

    # ── Chromium (Chrome, Edge, Brave) ────────────────────────────────
    foreach ($browser in @("Chrome","Edge","Brave")) {
        $browserDir = Join-Path $BrowsersPath $browser
        if (-not (Test-Path $browserDir)) { continue }

        Write-Host "  [*] Analizando $browser..." -ForegroundColor Yellow
        $histFiles = @(Get-ChildItem $browserDir -Recurse -Filter "History" -File -ErrorAction SilentlyContinue)

        foreach ($hf in $histFiles) {
            $userMatch = $hf.FullName -match "\\$browser\\([^\\]+)\\"
            $userName  = if ($userMatch) { $Matches[1] } else { "desconocido" }

            # URLs visitadas
            $urlQuery = "SELECT u.url, u.title, u.visit_count, u.last_visit_time, v.visit_time, v.from_visit, v.transition FROM urls u LEFT JOIN visits v ON u.id = v.url ORDER BY v.visit_time DESC LIMIT 50000"
            $rows = Invoke-SQLiteQuery -DbPath $hf.FullName -Query $urlQuery
            foreach ($row in $rows) {
                $allHistory.Add([PSCustomObject]@{
                    Navegador    = $browser
                    Usuario      = $userName
                    URL          = $row.url
                    Titulo       = $row.title
                    Visitas      = $row.visit_count
                    UltimaVisita = ConvertFrom-ChromeTime ([long]$row.last_visit_time)
                    FechaVisita  = ConvertFrom-ChromeTime ([long]$row.visit_time)
                })
            }

            # Descargas
            $dlQuery = "SELECT target_path, tab_url, start_time, end_time, total_bytes, danger_type, state FROM downloads ORDER BY start_time DESC LIMIT 5000"
            $dlRows = Invoke-SQLiteQuery -DbPath $hf.FullName -Query $dlQuery
            foreach ($row in $dlRows) {
                $allDownloads.Add([PSCustomObject]@{
                    Navegador    = $browser
                    Usuario      = $userName
                    RutaDestino  = $row.target_path
                    URLOrigen    = $row.tab_url
                    Inicio       = ConvertFrom-ChromeTime ([long]$row.start_time)
                    Fin          = ConvertFrom-ChromeTime ([long]$row.end_time)
                    TamanoBytes  = $row.total_bytes
                    TipoPeligro  = $row.danger_type
                    Estado       = $row.state
                })
            }

            # Busquedas (keywords extraidas de URLs)
            $searchQuery = "SELECT url, title, last_visit_time FROM urls WHERE url LIKE '%search%q=%' OR url LIKE '%?q=%' OR url LIKE '%&q=%' OR url LIKE '%query=%' OR url LIKE '%#q=%' ORDER BY last_visit_time DESC LIMIT 10000"
            $srRows = Invoke-SQLiteQuery -DbPath $hf.FullName -Query $searchQuery
            foreach ($row in $srRows) {
                $term = ""
                if ($row.url -match "[?&#]q=([^&]+)") { $term = [uri]::UnescapeDataString($Matches[1]) }
                elseif ($row.url -match "query=([^&]+)") { $term = [uri]::UnescapeDataString($Matches[1]) }
                if ($term) {
                    $allSearches.Add([PSCustomObject]@{
                        Navegador  = $browser
                        Usuario    = $userName
                        Busqueda   = $term
                        URL        = $row.url
                        Fecha      = ConvertFrom-ChromeTime ([long]$row.last_visit_time)
                    })
                }
            }
        }
        Write-ANLog -Phase "BROWSER" -Action "${browser}_ANALIZADO" -Target "$($histFiles.Count) perfiles" -Result "OK"
    }

    # ── Firefox ───────────────────────────────────────────────────────
    $ffDir = Join-Path $BrowsersPath "Firefox"
    if (Test-Path $ffDir) {
        Write-Host "  [*] Analizando Firefox..." -ForegroundColor Yellow
        $ffPlaces = @(Get-ChildItem $ffDir -Recurse -Filter "places.sqlite" -File -ErrorAction SilentlyContinue)
        foreach ($pf in $ffPlaces) {
            $userMatch = $pf.FullName -match "\\Firefox\\([^\\]+)\\"
            $userName  = if ($userMatch) { $Matches[1] } else { "desconocido" }

            # Firefox timestamps en microsegundos desde epoch Unix (diferente de Chrome)
            $ffQuery = "SELECT p.url, p.title, p.visit_count, p.last_visit_date, h.visit_date, h.visit_type FROM moz_places p LEFT JOIN moz_historyvisits h ON p.id = h.place_id ORDER BY h.visit_date DESC LIMIT 50000"
            $ffRows  = Invoke-SQLiteQuery -DbPath $pf.FullName -Query $ffQuery
            foreach ($row in $ffRows) {
                # Firefox usa microsegundos desde 1970-01-01 UTC
                $visitDate = if ($row.visit_date) { ConvertFrom-FirefoxTime ([long]$row.visit_date) } else { "" }
                $lastVisit = if ($row.last_visit_date) { ConvertFrom-FirefoxTime ([long]$row.last_visit_date) } else { "" }
                $allHistory.Add([PSCustomObject]@{
                    Navegador    = "Firefox"
                    Usuario      = $userName
                    URL          = $row.url
                    Titulo       = $row.title
                    Visitas      = $row.visit_count
                    UltimaVisita = $lastVisit
                    FechaVisita  = $visitDate
                })
            }
        }
        Write-ANLog -Phase "BROWSER" -Action "FIREFOX_ANALIZADO" -Target "$($ffPlaces.Count) perfiles" -Result "OK"
    }

    # ── Exportar ──────────────────────────────────────────────────────
    $Script:ANSession.BrowserURLs = $allHistory.Count

    Export-ANData -Data $allHistory.ToArray()   -Path (Join-Path $browsOut "Browser_Historial.csv")   -Description "Historial de navegacion"
    Export-ANData -Data $allDownloads.ToArray() -Path (Join-Path $browsOut "Browser_Descargas.csv")   -Description "Descargas"
    Export-ANData -Data $allSearches.ToArray()  -Path (Join-Path $browsOut "Browser_Busquedas.csv")   -Description "Terminos de busqueda"

    Write-ANLog -Phase "BROWSER" -Action "ANALISIS_COMPLETO" -Target "URLs=$($allHistory.Count) Descargas=$($allDownloads.Count) Busquedas=$($allSearches.Count)" -Result "OK"
}
