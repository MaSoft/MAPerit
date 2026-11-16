#region ============================================================
# MaPeriT.TN - TIMELINE CONSOLIDADA (MFT + EVTX + CSV)
# ============================================================

function New-TimelineViewerContent {
    param([string]$ProjectPath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    foreach ($h in @([System.Windows.GridLength]::Auto,
                     [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star),
                     [System.Windows.GridLength]::Auto)) {
        $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = $h
        $outer.RowDefinitions.Add($rd)
    }

    # Toolbar
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(8,5,8,5)
    $tbDP = New-Object System.Windows.Controls.DockPanel
    $tbDP.LastChildFill = $false

    $titleLbl = New-Object System.Windows.Controls.TextBlock
    $titleLbl.Text       = "Timeline Consolidada — MFT + EVTX + Artefactos CSV"
    $titleLbl.FontSize   = 12
    $titleLbl.FontWeight = [System.Windows.FontWeights]::SemiBold
    $titleLbl.Foreground = New-WpfBrush $Script:Colors.Text
    $titleLbl.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($titleLbl, 'Left')
    $tbDP.Children.Add($titleLbl) | Out-Null

    $rightSP = New-Object System.Windows.Controls.StackPanel
    $rightSP.Orientation = 'Horizontal'
    [System.Windows.Controls.DockPanel]::SetDock($rightSP, 'Right')

    $filterBox = New-Object System.Windows.Controls.TextBox
    $filterBox.Width = 180; $filterBox.Height = 24
    $filterBox.Background = New-WpfBrush $Script:Colors.BgSurface
    $filterBox.Foreground = New-WpfBrush $Script:Colors.Text
    $filterBox.CaretBrush = [System.Windows.Media.Brushes]::White
    $filterBox.BorderBrush = New-WpfBrush $Script:Colors.Border
    $filterBox.Padding = [System.Windows.Thickness]::new(6,2,6,2)
    $filterBox.FontSize = 11; $filterBox.ToolTip = "Filtrar timeline"
    $rightSP.Children.Add($filterBox) | Out-Null

    $btnExport = New-Object System.Windows.Controls.Button
    $btnExport.Content = "Exportar CSV"; $btnExport.Height = 24
    $btnExport.Padding = [System.Windows.Thickness]::new(8,2,8,2)
    $btnExport.Margin  = [System.Windows.Thickness]::new(4,0,0,0)
    $btnExport.Background = New-WpfBrush $Script:Colors.BgSurface
    $btnExport.Foreground = New-WpfBrush $Script:Colors.Text
    $btnExport.BorderBrush = New-WpfBrush $Script:Colors.Border
    $btnExport.FontSize = 11; $btnExport.Cursor = [System.Windows.Input.Cursors]::Hand
    $rightSP.Children.Add($btnExport) | Out-Null

    $tbDP.Children.Add($rightSP) | Out-Null
    $toolbar.Child = $tbDP
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # DataGrid
    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly = $true; $dg.AutoGenerateColumns = $false
    $dg.SelectionMode = 'Extended'; $dg.SelectionUnit = 'FullRow'
    $dg.CanUserSortColumns = $true; $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($dg, [System.Windows.Controls.VirtualizationMode]::Recycling)
    Apply-DataGridDarkTheme $dg
    Add-DataGridRowContextMenu -DG $dg -FilePath $ProjectPath
    foreach ($cd in @(
        @{ H="Fecha/Hora";   B="Timestamp";   W=155 },
        @{ H="Zona horaria"; B="Zona";        W=110 },
        @{ H="Fuente";       B="Fuente";       W=60  },
        @{ H="Tipo";         B="Tipo";         W=150 },
        @{ H="Descripcion";  B="Descripcion";  W=420 },
        @{ H="Artefacto";    B="Artefacto";    W=180 },
        @{ H="EventID";      B="EventID";      W=65  }
    )) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header  = $cd.H
        $col.Binding = New-Object System.Windows.Data.Binding($cd.B)
        $col.Width   = $cd.W
        $dg.Columns.Add($col) | Out-Null
    }
    $dg.Add_LoadingRow({
        param($s, $e)
        $item = $e.Row.Item -as [System.Data.DataRowView]
        if ($null -eq $item) { return }
        $eid = 0
        if ([int]::TryParse($item['EventID'], [ref]$eid)) {
            if ($eid -in $Script:EventSeverity.Critical) { $e.Row.Background = New-WpfBrush $Script:Colors.RowCritical; return }
            if ($eid -in $Script:EventSeverity.High)     { $e.Row.Background = New-WpfBrush $Script:Colors.RowDanger;   return }
        }
        # Solo los registros MFT con indicio de timestomping (antes se coloreaba
        # cualquier fila del MFT como si lo fuera)
        if ($item['Fuente'] -eq 'MFT' -and $item['Tipo'] -eq 'Posible timestomping') { $e.Row.Background = New-WpfBrush $Script:Colors.RowTimestomp }
    })
    [System.Windows.Controls.Grid]::SetRow($dg, 1)
    $outer.Children.Add($dg) | Out-Null

    # Status
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Text       = "Construyendo timeline..."
    $statusLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $statusLabel.FontSize   = 11
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    $overlay = New-LoadingOverlay -Message "Construyendo timeline..." -RowSpan 3
    $outer.Children.Add($overlay) | Out-Null

    # Filter
    $filterBox.Tag = [PSCustomObject]@{ DG=$dg; Status=$statusLabel }
    $filterBox.Add_TextChanged({
        param($sender, $e)
        $ctx = $sender.Tag
        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl) { return }
        $txt = $sender.Text.Trim()
        if ([string]::IsNullOrEmpty($txt)) { $tbl.DefaultView.RowFilter = "" } else {
            $safeT = $txt -replace "'", "''"
            try { $tbl.DefaultView.RowFilter = "CONVERT([Fuente],'System.String') LIKE '%$safeT%' OR CONVERT([Descripcion],'System.String') LIKE '%$safeT%' OR CONVERT([Artefacto],'System.String') LIKE '%$safeT%' OR CONVERT([Tipo],'System.String') LIKE '%$safeT%'" }
            catch { $tbl.DefaultView.RowFilter = "" }
        }
        $ctx.DG.ItemsSource = $tbl.DefaultView
        $ctx.Status.Text = "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) eventos"
    })

    # Export
    $btnExport.Tag = [PSCustomObject]@{ DG=$dg }
    $btnExport.Add_Click({
        param($sender, $e)
        $tbl = ($sender.Tag).DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl -or $tbl.Rows.Count -eq 0) { return }
        $dlg2 = New-Object Microsoft.Win32.SaveFileDialog
        $dlg2.Filter = "CSV (*.csv)|*.csv"
        $dlg2.FileName = "Timeline_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        if ($dlg2.ShowDialog() -eq $true) {
            $tbl.DefaultView.ToTable() | Export-Csv $dlg2.FileName -NoTypeInformation -Encoding UTF8
            Set-Status "Timeline exportada: $($dlg2.FileName)"
        }
    })

    # Background build
    $bgScript = {
        param($projectPath, $maxEvtx, $criticalIds, $highIds)
        $events = [System.Collections.Generic.List[PSCustomObject]]::new()

        # EVTX
        foreach ($evtx in @(Get-ChildItem $projectPath -Recurse -Filter "*.evtx" -ErrorAction SilentlyContinue)) {
            try {
                foreach ($ev in @(Get-WinEvent -Path $evtx.FullName -MaxEvents $maxEvtx -ErrorAction Stop)) {
                    $msg = if ($ev.Message) { ($ev.Message -replace "[\r\n]+"," ").Substring(0,[Math]::Min(200,$ev.Message.Length)) } else { "" }
                    # En UTC, como el MFT y los CSV de AN (antes hora local del equipo
                    # en el que se ejecuta TN, mezclada sin aviso con fechas UTC)
                    $utc = $ev.TimeCreated.ToUniversalTime()
                    $events.Add([PSCustomObject]@{
                        SortKey    = $utc
                        Timestamp  = $utc.ToString("yyyy-MM-dd HH:mm:ss")
                        Zona       = "UTC"
                        Fuente     = "EVTX"
                        Tipo       = $ev.ProviderName
                        Descripcion= $msg
                        Artefacto  = $evtx.Name
                        EventID    = $ev.Id.ToString()
                    }) | Out-Null
                }
            } catch {}
        }

        # MFT CSVs de MaPeriT.AN (columnas SI_Modificado_UTC/SI_Creado_UTC/FN_Creado_UTC,
        # RutaCompleta/NombreFichero, Estado, Timestomping). Antes se buscaban nombres
        # en ingles que AN no genera y el MFT no entraba nunca en la timeline.
        # Primero los ficheros con indicios (timestomping, borrados) y despues el
        # completo; un mismo registro solo se incluye una vez.
        $mftSeen  = [System.Collections.Generic.HashSet[string]]::new()
        $mftFiles = @(Get-ChildItem $projectPath -Recurse -Filter "MFT_*.csv" -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 50MB } |
            Sort-Object { if ($_.Name -match 'Timestomping') { 0 } elseif ($_.Name -match 'Borrados') { 1 } else { 2 } })
        foreach ($mft in $mftFiles) {
            try {
                foreach ($row in @(Import-Csv $mft.FullName -ErrorAction Stop | Select-Object -First 3000)) {
                    # Prioridad explicita (no el orden de las columnas del CSV) y sin valores vacios
                    $tsCol = @('SI_Modificado_UTC','SI_Creado_UTC','FN_Creado_UTC','SI_Modified','SI_Created','FN_Created') |
                        Where-Object { $row.PSObject.Properties[$_] -and $row.$_ } | Select-Object -First 1
                    if (-not $tsCol) { continue }
                    $key = "$($row.RecordNum)|$($row.RutaCompleta)$($row.FullPath)"
                    if (-not $mftSeen.Add($key)) { continue }
                    $dt = [datetime]::MinValue
                    $ok = [datetime]::TryParseExact([string]$row.$tsCol, 'yyyy-MM-dd HH:mm:ss.fffffff', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$dt)
                    if (-not $ok) { $ok = [datetime]::TryParse([string]$row.$tsCol, [ref]$dt) }
                    if ($ok -and $dt.Year -gt 2000) {
                        $desc = if ($row.RutaCompleta) { $row.RutaCompleta } elseif ($row.NombreFichero) { $row.NombreFichero } elseif ($row.FullPath) { $row.FullPath } elseif ($row.FileName) { $row.FileName } else { "" }
                        $tipo = if ("$($row.Timestomping)" -eq 'True') { "Posible timestomping" } elseif ($row.Estado -eq 'BORRADO') { "Fichero borrado" } else { $tsCol }
                        $events.Add([PSCustomObject]@{
                            SortKey    = $dt
                            Timestamp  = $dt.ToString("yyyy-MM-dd HH:mm:ss")
                            Zona       = "UTC"
                            Fuente     = "MFT"
                            Tipo       = $tipo
                            Descripcion= $desc
                            Artefacto  = $mft.Name
                            EventID    = ""
                        }) | Out-Null
                    }
                }
            } catch {}
        }

        # Other CSVs with time columns
        foreach ($csv in @(Get-ChildItem $projectPath -Recurse -Filter "*.csv" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^MFT_' -and $_.Length -lt 15MB -and $_.Length -gt 0 })) {
            try {
                $rows = @(Import-Csv $csv.FullName -ErrorAction Stop | Select-Object -First 500)
                if ($rows.Count -eq 0) { continue }
                $tsCol = $rows[0].PSObject.Properties.Name | Where-Object { $_ -match '^(Time|Date|Fecha|Hora|Created|Modified|Timestamp|LastWrite|LastAccess)' } | Select-Object -First 1
                if (-not $tsCol) { continue }
                foreach ($row in $rows) {
                    $tsVal = $row.$tsCol
                    if ([string]::IsNullOrEmpty($tsVal)) { continue }
                    $dt = [datetime]::MinValue
                    if ([datetime]::TryParse($tsVal, [ref]$dt) -and $dt.Year -gt 2000 -and $dt.Year -lt 2100) {
                        $cols = $row.PSObject.Properties.Name | Where-Object { $_ -notmatch 'Time|Date|Hash|Id$' } | Select-Object -First 3
                        $desc = ($cols | ForEach-Object { "$_=$($row.$_)" }) -join " | "
                        if ($desc.Length -gt 200) { $desc = $desc.Substring(0,200) }
                        # Zona horaria: la que indique la propia fila (ZonaHoraria de la
                        # correlacion de AN) o el nombre de la columna (*_UTC); si no,
                        # es la hora del origen sin zona declarada (p.ej. hora local de SW).
                        $zona = if ($row.PSObject.Properties['ZonaHoraria'] -and $row.ZonaHoraria) { $row.ZonaHoraria } elseif ($tsCol -match 'UTC') { "UTC" } else { "Sin indicar (origen)" }
                        $events.Add([PSCustomObject]@{
                            SortKey    = $dt
                            Timestamp  = $dt.ToString("yyyy-MM-dd HH:mm:ss")
                            Zona       = $zona
                            Fuente     = "CSV"
                            Tipo       = [System.IO.Path]::GetFileNameWithoutExtension($csv.Name)
                            Descripcion= $desc
                            Artefacto  = $csv.Name
                            EventID    = ""
                        }) | Out-Null
                    }
                }
            } catch {}
        }

        $sorted = @($events | Sort-Object SortKey -Descending | Select-Object -First 50000)
        Write-Output -NoEnumerate ([PSCustomObject]@{ Events=$sorted; Total=$events.Count; Err="" })
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{
        projectPath = $ProjectPath
        maxEvtx     = $Script:MaxEVTXEvents
        criticalIds = $Script:EventSeverity.Critical
        highIds     = $Script:EventSeverity.High
    })
    $handle = $ps.BeginInvoke()

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Tag = [PSCustomObject]@{ Ps=$ps; Handle=$handle; Rs=$rs; DG=$dg; Status=$statusLabel; Overlay=$overlay }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag
        if ($ctx.Ps.InvocationStateInfo.State -in 'Completed','Failed','Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                $tbl = [System.Data.DataTable]::new("Timeline")
                foreach ($c in @('Timestamp','Zona','Fuente','Tipo','Descripcion','Artefacto','EventID')) { [void]$tbl.Columns.Add($c,[string]) }
                if ($obj -and $obj.Events) {
                    foreach ($ev in $obj.Events) {
                        $row = $tbl.NewRow()
                        $row['Timestamp']  = $ev.Timestamp; $row['Zona']      = $ev.Zona; $row['Fuente'] = $ev.Fuente
                        $row['Tipo']       = $ev.Tipo;      $row['Descripcion']= $ev.Descripcion
                        $row['Artefacto']  = $ev.Artefacto; $row['EventID']   = $ev.EventID
                        [void]$tbl.Rows.Add($row)
                    }
                }
                $ctx.DG.Tag = $tbl; $ctx.DG.ItemsSource = $tbl.DefaultView
                $ctx.Status.Text = "$($tbl.Rows.Count) eventos$(if($obj.Total -gt 50000){' (top 50.000)'})"
            } catch { $ctx.Status.Text = "Error: $($_.Exception.Message)" }
            finally {
                $ctx.Overlay.Visibility = 'Collapsed'
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
    return $outer
}

#endregion
