#region ============================================================
# MaPeriT.SC - CARGA ASINCRONA DE FUENTES (Runspace + DispatcherTimer)
# Mismo patron anti-freeze validado en MaPeriT.TN: toda la I/O pesada
# (Import-Csv de ficheros que pueden tener cientos de miles de filas)
# corre en un Runspace STA separado. El hilo de UI solo hace polling
# via DispatcherTimer y nunca bloquea. Sin closures: todo el estado
# vive en $timer.Tag. Handler: param($sender,$e).
# ============================================================

function Invoke-AsyncSourceIndexing {
    <#
    Carga en segundo plano todos los CSV de $FilePaths (rutas completas)
    a DataTable, sin truncar filas (ver nota en Config.ps1).
    UIContext  : PSCustomObject libre, se reenvia tal cual a los callbacks.
    OnProgress : scriptblock param($ui, $current, $total, $currentFileName)
    OnComplete : scriptblock param($ui, $tablesByPath, $errorsByPath)
                 $tablesByPath es [hashtable] RutaCompleta -> DataTable
    #>
    param(
        [string[]]$FilePaths,
        [PSCustomObject]$UIContext,
        [scriptblock]$OnProgress,
        [scriptblock]$OnComplete
    )

    $progress = [hashtable]::Synchronized(@{ Current = 0; Total = $FilePaths.Count; CurrentFile = "" })

    $bgScript = {
        param($paths, $prog)
        $tables = [hashtable]::Synchronized(@{})
        $errors = [hashtable]::Synchronized(@{})
        foreach ($p in $paths) {
            $prog.CurrentFile = [System.IO.Path]::GetFileName($p)
            try {
                if (-not (Test-Path $p)) { $prog.Current++; continue }
                $raw = @(Import-Csv $p -Encoding UTF8 -ErrorAction Stop)
                $tbl = [System.Data.DataTable]::new([System.IO.Path]::GetFileNameWithoutExtension($p))
                if ($raw.Count -gt 0) {
                    foreach ($colName in $raw[0].PSObject.Properties.Name) {
                        [void]$tbl.Columns.Add($colName, [string])
                    }
                    foreach ($r in $raw) {
                        $row = $tbl.NewRow()
                        foreach ($c in $tbl.Columns) {
                            $v = $r.($c.ColumnName)
                            $row[$c.ColumnName] = if ($null -ne $v) { $v.ToString() } else { "" }
                        }
                        [void]$tbl.Rows.Add($row)
                    }
                }
                $tables[$p] = $tbl
            } catch {
                $errors[$p] = $_.Exception.Message
            }
            $prog.Current++
        }
        Write-Output -NoEnumerate ([PSCustomObject]@{ Tables = $tables; Errors = $errors })
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{ paths = $FilePaths; prog = $progress })
    $handle = $ps.BeginInvoke()

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $timer.Tag = [PSCustomObject]@{
        Ps         = $ps
        Handle     = $handle
        Rs         = $rs
        Progress   = $progress
        UI         = $UIContext
        OnProgress = $OnProgress
        OnComplete = $OnComplete
    }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag

        if ($ctx.OnProgress) {
            & $ctx.OnProgress $ctx.UI $ctx.Progress.Current $ctx.Progress.Total $ctx.Progress.CurrentFile
        }

        $state = $ctx.Ps.InvocationStateInfo.State
        if ($state -in 'Completed', 'Failed', 'Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                $tablesByPath = if ($obj) { $obj.Tables } else { @{} }
                $errorsByPath = if ($obj) { $obj.Errors } else { @{} }
                & $ctx.OnComplete $ctx.UI $tablesByPath $errorsByPath
            } catch {
                & $ctx.OnComplete $ctx.UI @{} @{ "__fatal__" = $_.Exception.Message }
            } finally {
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
}

#endregion
