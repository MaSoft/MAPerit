#region ============================================================
# MaPeriT.SC - ESQUEMA DECLARATIVO DE FUENTES
# Mapeo categoria (wizard) -> ficheros CSV de AN -> columnas reales.
# Confirmado leyendo el codigo fuente de MaPeriT.AN (MFTParser.ps1,
# EVTXAnalyzer.ps1, BrowserSQLite.ps1, ShimcacheAmcache.ps1,
# USNJournal.ps1, Correlator.ps1) - no se ha supuesto ningun nombre
# de columna.
#
# Anadir una categoria/fuente nueva = anadir una entrada aqui, no tocar
# el motor de consulta (Query\QueryEngine.ps1).
# ============================================================

<#
Cada entrada de $Script:SC_SourceCatalog es un hashtable con:
  Key           : identificador unico, tambien nombre logico de la DataTable en memoria
  RelPath       : ruta relativa dentro de ANALISIS_AN
  Dynamic       : $true si las columnas dependen de una herramienta externa
                  (fsutil / extractor ShimCache de SW) y deben detectarse en runtime
  TimestampCol  : nombre de columna de fecha (fijo) o $null si es dinamica
  TimestampBestEffort : $true si el formato de fecha no esta garantizado (Amcache)
  UserCols      : array de columnas candidatas a usuario, en orden de prioridad,
                  o $null si la fuente no tiene usuario propio
  PathCol       : columna con ruta de fichero, usada para inferir usuario
                  por patron \Users\<usuario>\ cuando UserCols es $null
  DescCols      : columnas relevantes para descripcion/detalle del hallazgo
  DynamicTimeHint / DynamicPathHint : regex para localizar columnas en fuentes Dynamic
  Zona          : zona horaria de las fechas de la fuente (por defecto 'UTC', que es
                  como las escribe MaPeriT.AN); el USN Journal va en hora local
#>
$Script:SC_SourceCatalog = @(
    @{
        Key = 'EVTX_Logons'; RelPath = 'EVTX\EVTX_Logons.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('Categoria','Description','LogonType','WorkstationName','IPAddress')
    },
    @{
        Key = 'EVTX_FailedLogons'; RelPath = 'EVTX\EVTX_FailedLogons.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('Categoria','Description','LogonType','WorkstationName','IPAddress')
    },
    @{
        Key = 'EVTX_Procesos'; RelPath = 'EVTX\EVTX_Procesos.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('ProcessName','CommandLine','Description')
    },
    @{
        Key = 'EVTX_NuevosServicios'; RelPath = 'EVTX\EVTX_NuevosServicios.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('ServiceName','Description')
    },
    @{
        Key = 'EVTX_PowerShell4104'; RelPath = 'EVTX\EVTX_PowerShell4104.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('ScriptBlock')
    },
    @{
        Key = 'EVTX_LogBorrado'; RelPath = 'EVTX\EVTX_LogBorrado.csv'; Dynamic = $false
        TimestampCol = 'TimeCreated_UTC'
        UserCols = @('TargetUser','SubjectUser'); PathCol = $null
        DescCols = @('Description')
    },
    @{
        Key = 'Browser_Historial'; RelPath = 'Browsers\Browser_Historial.csv'; Dynamic = $false
        TimestampCol = 'FechaVisita'
        UserCols = @('Usuario'); PathCol = $null
        DescCols = @('Navegador','URL','Titulo','Visitas')
    },
    @{
        Key = 'Browser_Descargas'; RelPath = 'Browsers\Browser_Descargas.csv'; Dynamic = $false
        TimestampCol = 'Inicio'
        UserCols = @('Usuario'); PathCol = 'RutaDestino'
        DescCols = @('Navegador','RutaDestino','URLOrigen','TamanoBytes','TipoPeligro')
    },
    @{
        Key = 'Browser_Busquedas'; RelPath = 'Browsers\Browser_Busquedas.csv'; Dynamic = $false
        TimestampCol = 'Fecha'
        UserCols = @('Usuario'); PathCol = $null
        DescCols = @('Navegador','Busqueda','URL')
    },
    @{
        Key = 'MFT_Completo'; RelPath = 'MFT\MFT_Completo.csv'; Dynamic = $false
        TimestampCol = 'SI_Creado_UTC'
        UserCols = $null; PathCol = 'RutaCompleta'
        DescCols = @('Estado','NombreFichero','TamanoBytes','Timestomping')
    },
    @{
        Key = 'MFT_Borrados'; RelPath = 'MFT\MFT_Borrados.csv'; Dynamic = $false
        TimestampCol = 'SI_Modificado_UTC'
        UserCols = $null; PathCol = 'RutaCompleta'
        DescCols = @('NombreFichero','Estado','TamanoBytes')
    },
    @{
        Key = 'MFT_Timestomping'; RelPath = 'MFT\MFT_Timestomping.csv'; Dynamic = $false
        TimestampCol = 'FN_Modificado_UTC'
        UserCols = $null; PathCol = 'RutaCompleta'
        DescCols = @('NombreFichero','RazonTimestomp')
    },
    @{
        Key = 'Amcache_Ejecutables'; RelPath = 'MFT\Amcache_Ejecutables.csv'; Dynamic = $false
        # Sin columna de fecha: lo que guarda Amcache es la fecha de compilacion
        # (LinkDate) o de instalacion, nunca la de ejecucion. Antes se usaba como
        # fecha del hallazgo y se presentaba como "ejecucion" en esa fecha. Con un
        # filtro de fechas activo esta fuente no aporta filas.
        TimestampCol = $null; TimestampBestEffort = $true
        UserCols = $null; PathCol = 'RutaFichero'
        DescCols = @('Nombre','Publisher','SHA1','Version','FechaReferencia','TipoFecha')
    },
    @{
        Key = 'ShimCache_Completo'; RelPath = 'MFT\ShimCache_Completo.csv'; Dynamic = $true
        DynamicTimeHint = 'Time|TimeStamp|Fecha|timestamp'
        DynamicPathHint = 'Ruta|Path|FileName|Nombre'
        UserCols = $null; DescCols = @()
    },
    @{
        Key = 'USN_Borrados'; RelPath = 'MFT\USN_Borrados.csv'; Dynamic = $true
        Zona = 'hora local del equipo'   # fsutil escribe la hora local del equipo adquirido
        DynamicTimeHint = 'TimeStamp|Time|timestamp'
        DynamicPathHint = 'FileName|Name|filename'
        UserCols = $null; DescCols = @()
    },
    @{
        Key = 'USN_Renombrados'; RelPath = 'MFT\USN_Renombrados.csv'; Dynamic = $true
        Zona = 'hora local del equipo'   # fsutil escribe la hora local del equipo adquirido
        DynamicTimeHint = 'TimeStamp|Time|timestamp'
        DynamicPathHint = 'FileName|Name|filename'
        UserCols = $null; DescCols = @()
    },
    @{
        Key = 'USN_Ejecutables'; RelPath = 'MFT\USN_Ejecutables.csv'; Dynamic = $true
        Zona = 'hora local del equipo'   # fsutil escribe la hora local del equipo adquirido
        DynamicTimeHint = 'TimeStamp|Time|timestamp'
        DynamicPathHint = 'FileName|Name|filename'
        UserCols = $null; DescCols = @()
    },
    @{
        Key = 'USN_RutasSospechosas'; RelPath = 'MFT\USN_RutasSospechosas.csv'; Dynamic = $true
        Zona = 'hora local del equipo'   # fsutil escribe la hora local del equipo adquirido
        DynamicTimeHint = 'TimeStamp|Time|timestamp'
        DynamicPathHint = 'FileName|Name|filename'
        UserCols = $null; DescCols = @()
    }
)

# ── Categorias del wizard (paso 3) -> claves de $SC_SourceCatalog ────
$Script:SC_Categories = [ordered]@{
    'Sesiones'         = @{ Label = 'Inicios y cierres de sesion';                       Sources = @('EVTX_Logons','EVTX_FailedLogons') }
    'Programas'        = @{ Label = 'Programas ejecutados o registrados';                              Sources = @('EVTX_Procesos','Amcache_Ejecutables','ShimCache_Completo','USN_Ejecutables') }
    'Navegacion'       = @{ Label = 'Navegacion web (historial, descargas, busquedas)';   Sources = @('Browser_Historial','Browser_Descargas','Browser_Busquedas') }
    'Ficheros'         = @{ Label = 'Ficheros creados, borrados o renombrados';           Sources = @('MFT_Completo','MFT_Borrados','USN_Borrados','USN_Renombrados') }
    'Persistencia'     = @{ Label = 'Servicios nuevos y persistencia';                    Sources = @('EVTX_NuevosServicios') }
    'Manipulacion'     = @{ Label = 'Indicios de manipulacion (timestomping, log borrado)'; Sources = @('MFT_Timestomping','EVTX_LogBorrado') }
    'Scripts'          = @{ Label = 'Scripts de PowerShell ejecutados';                   Sources = @('EVTX_PowerShell4104') }
    'RutasSospechosas' = @{ Label = 'Actividad en rutas sospechosas (Temp, Descargas)';    Sources = @('USN_RutasSospechosas') }
}

function Get-SCSourceEntry {
    param([string]$Key)
    return $Script:SC_SourceCatalog | Where-Object { $_.Key -eq $Key } | Select-Object -First 1
}

function Get-SCSourcesForCategories {
    <# Devuelve la lista de Keys de fuente (sin duplicados) para un conjunto de categorias del wizard. #>
    param([string[]]$CategoryKeys)
    $keys = [System.Collections.Generic.List[string]]::new()
    foreach ($ck in $CategoryKeys) {
        if (-not $Script:SC_Categories.Contains($ck)) { continue }
        foreach ($sk in $Script:SC_Categories[$ck].Sources) {
            if (-not $keys.Contains($sk)) { $keys.Add($sk) }
        }
    }
    return $keys
}

#endregion
