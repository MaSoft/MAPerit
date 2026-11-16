#region ============================================================
# MaPeriT.TN - VISOR CSV
# ============================================================

# Helper compartido: convierte array de PSObjects a DataTable.
# Usa Write-Output -NoEnumerate para evitar que PS enumere el DataTable al retornarlo.
function ConvertTo-DataTable {
    param([object[]]$Data, [string]$TableName = "TNData")
    $tbl = [System.Data.DataTable]::new($TableName)
    if (-not $Data -or $Data.Count -eq 0) {
        Write-Output -NoEnumerate $tbl
        return
    }
    foreach ($prop in $Data[0].PSObject.Properties.Name) {
        [void]$tbl.Columns.Add($prop, [string])
    }
    foreach ($item in $Data) {
        $row = $tbl.NewRow()
        foreach ($c in $tbl.Columns) {
            $v = $item.($c.ColumnName)
            $row[$c.ColumnName] = if ($null -ne $v) { $v.ToString() } else { "" }
        }
        [void]$tbl.Rows.Add($row)
    }
    Write-Output -NoEnumerate $tbl
}

function Apply-DataGridDarkTheme {
    param([System.Windows.Controls.DataGrid]$DG)
    $DG.Background               = New-WpfBrush $Script:Colors.BgPanel
    $DG.RowBackground            = New-WpfBrush $Script:Colors.BgPanel
    $DG.AlternatingRowBackground = New-WpfBrush $Script:Colors.BgCard
    $DG.Foreground               = New-WpfBrush $Script:Colors.Text
    $DG.BorderBrush              = New-WpfBrush $Script:Colors.Border
    $DG.BorderThickness          = [System.Windows.Thickness]::new(0)
    $DG.GridLinesVisibility      = 'Horizontal'
    $DG.HorizontalGridLinesBrush = New-WpfBrush $Script:Colors.Border
    $DG.ColumnHeaderHeight       = 30
    $DG.RowHeight                = 26
    $DG.FontSize                 = 12

    $hStyle = New-Object System.Windows.Style([System.Windows.Controls.Primitives.DataGridColumnHeader])
    foreach ($s in @(
        @{ P=[System.Windows.Controls.Control]::BackgroundProperty;      V=(New-WpfBrush $Script:Colors.BgHeader)  },
        @{ P=[System.Windows.Controls.Control]::ForegroundProperty;      V=(New-WpfBrush $Script:Colors.TextMuted) },
        @{ P=[System.Windows.Controls.Control]::BorderBrushProperty;     V=(New-WpfBrush $Script:Colors.Border)    },
        @{ P=[System.Windows.Controls.Control]::BorderThicknessProperty; V=([System.Windows.Thickness]::new(0,0,1,1)) },
        @{ P=[System.Windows.Controls.Control]::PaddingProperty;         V=([System.Windows.Thickness]::new(8,0,8,0)) },
        @{ P=[System.Windows.Controls.Control]::FontWeightProperty;      V=([System.Windows.FontWeights]::SemiBold) },
        @{ P=[System.Windows.Controls.Control]::FontSizeProperty;        V=11.0 }
    )) {
        $setter = New-Object System.Windows.Setter
        $setter.Property = $s.P
        $setter.Value    = $s.V
        $hStyle.Setters.Add($setter) | Out-Null
    }
    $DG.ColumnHeaderStyle = $hStyle

    $rStyle = New-Object System.Windows.Style([System.Windows.Controls.DataGridRow])
    $rs2 = New-Object System.Windows.Setter
    $rs2.Property = [System.Windows.Controls.DataGridRow]::ForegroundProperty
    $rs2.Value    = New-WpfBrush $Script:Colors.Text
    $rStyle.Setters.Add($rs2) | Out-Null
    $DG.RowStyle = $rStyle

    $cStyle = New-Object System.Windows.Style([System.Windows.Controls.DataGridCell])
    foreach ($csDef in @(
        @{ P=[System.Windows.Controls.DataGridCell]::BorderThicknessProperty; V=[System.Windows.Thickness]::new(0)                },
        @{ P=[System.Windows.Controls.DataGridCell]::ForegroundProperty;      V=(New-WpfBrush $Script:Colors.Text)                }
    )) {
        $cs2 = New-Object System.Windows.Setter; $cs2.Property = $csDef.P; $cs2.Value = $csDef.V
        $cStyle.Setters.Add($cs2) | Out-Null
    }
    $selTrigger = New-Object System.Windows.Trigger
    $selTrigger.Property = [System.Windows.Controls.DataGridCell]::IsSelectedProperty
    $selTrigger.Value    = $true
    foreach ($tDef in @(
        @{ P=[System.Windows.Controls.DataGridCell]::BackgroundProperty; V=(New-WpfBrush $Script:Colors.SelectionBg) },
        @{ P=[System.Windows.Controls.DataGridCell]::ForegroundProperty; V=([System.Windows.Media.Brushes]::White)   }
    )) {
        $ts = New-Object System.Windows.Setter; $ts.Property = $tDef.P; $ts.Value = $tDef.V
        $selTrigger.Setters.Add($ts) | Out-Null
    }
    $cStyle.Triggers.Add($selTrigger) | Out-Null
    $DG.CellStyle = $cStyle
}

function New-CSVViewerContent {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    $r0 = New-Object System.Windows.Controls.RowDefinition; $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $r2 = New-Object System.Windows.Controls.RowDefinition; $r2.Height = [System.Windows.GridLength]::Auto
    $outer.RowDefinitions.Add($r0)
    $outer.RowDefinitions.Add($r1)
    $outer.RowDefinitions.Add($r2)

    # ── Toolbar ─────────────────────────────────────────────────────
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(8,5,8,5)

    $tbDP = New-Object System.Windows.Controls.DockPanel
    $tbDP.LastChildFill = $false

    $fileLabel = New-Object System.Windows.Controls.TextBlock
    $fileLabel.Text              = [System.IO.Path]::GetFileName($FilePath)
    $fileLabel.Foreground        = New-WpfBrush $Script:Colors.Text
    $fileLabel.FontWeight        = [System.Windows.FontWeights]::SemiBold
    $fileLabel.FontSize          = 12
    $fileLabel.VerticalAlignment = 'Center'
    $fileLabel.Margin            = [System.Windows.Thickness]::new(0,0,12,0)
    [System.Windows.Controls.DockPanel]::SetDock($fileLabel, 'Left')
    $tbDP.Children.Add($fileLabel) | Out-Null

    $rightSP = New-Object System.Windows.Controls.StackPanel
    $rightSP.Orientation = 'Horizontal'
    [System.Windows.Controls.DockPanel]::SetDock($rightSP, 'Right')

    $filterBox = New-Object System.Windows.Controls.TextBox
    $filterBox.Width       = 200
    $filterBox.Height      = 24
    $filterBox.Background  = New-WpfBrush $Script:Colors.BgSurface
    $filterBox.Foreground  = New-WpfBrush $Script:Colors.Text
    $filterBox.CaretBrush  = [System.Windows.Media.Brushes]::White
    $filterBox.BorderBrush = New-WpfBrush $Script:Colors.Border
    $filterBox.Padding     = [System.Windows.Thickness]::new(6,2,6,2)
    $filterBox.FontSize    = 11
    $filterBox.ToolTip     = "Filtrar filas (busca en todas las columnas)"
    $rightSP.Children.Add($filterBox) | Out-Null

    foreach ($btnInfo in @(
        @{ Text="Limpiar"    },
        @{ Text="Copiar sel."},
        @{ Text="Export CSV" }
    )) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content     = $btnInfo.Text
        $btn.Height      = 24
        $btn.Padding     = [System.Windows.Thickness]::new(8,2,8,2)
        $btn.Margin      = [System.Windows.Thickness]::new(4,0,0,0)
        $btn.Background  = New-WpfBrush $Script:Colors.BgSurface
        $btn.Foreground  = New-WpfBrush $Script:Colors.Text
        $btn.BorderBrush = New-WpfBrush $Script:Colors.Border
        $btn.FontSize    = 11
        $btn.Cursor      = [System.Windows.Input.Cursors]::Hand
        $rightSP.Children.Add($btn) | Out-Null
    }

    $tbDP.Children.Add($rightSP) | Out-Null
    $toolbar.Child = $tbDP
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # ── DataGrid ─────────────────────────────────────────────────────
    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly            = $true
    $dg.AutoGenerateColumns   = $true
    $dg.SelectionMode         = 'Extended'
    $dg.SelectionUnit         = 'FullRow'
    $dg.CanUserSortColumns    = $true
    $dg.CanUserResizeColumns  = $true
    $dg.CanUserReorderColumns = $true
    $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($dg, [System.Windows.Controls.VirtualizationMode]::Recycling)
    # Columnas con ancho FIJO tambien cuando se auto-generan (no Auto/SizeToHeader):
    # con datasets grandes y ancho Auto, WPF tiene que medir el contenido de
    # cada fila para calcular el ancho de columna, lo que fuerza preparar
    # muchos mas contenedores de fila de los que la virtualizacion realizaria
    # normalmente - ese camino (DataGridRow.PrepareRow) es donde se dispara un
    # bug conocido de WPF (DataGridItemAttachedStorage.TryGetValue) que puede
    # matar el proceso entero sin excepcion manejable (confirmado en
    # MaPeriT.SC con el mismo patron). CSVViewer es el visor mas usado del
    # ecosistema (cualquier CSV de SW/AN, muchas columnas, hasta 50000 filas).
    $dg.Add_AutoGeneratingColumn({
        param($s, $e)
        $e.Column.Width = New-Object System.Windows.Controls.DataGridLength(160)
    })
    Apply-DataGridDarkTheme $dg
    Add-DataGridRowContextMenu -DG $dg -FilePath $FilePath
    [System.Windows.Controls.Grid]::SetRow($dg, 1)
    $outer.Children.Add($dg) | Out-Null

    # ── Status bar ───────────────────────────────────────────────────
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $statusLabel.FontSize   = 11
    $statusLabel.Text       = "Cargando..."
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    # ── Overlay ───────────────────────────────────────────────────────
    $overlay = New-LoadingOverlay -Message "Cargando $([System.IO.Path]::GetFileName($FilePath))..." -RowSpan 3
    $outer.Children.Add($overlay) | Out-Null

    # ── Colorear filas por IOC/severidad ─────────────────────────────
    $dg.Add_LoadingRow({
        param($s, $e)
        $item = $e.Row.Item
        if ($item -isnot [System.Data.DataRowView]) { return }
        $sev = Get-RowSeverity $item.Row
        if ($sev -ne "Normal") { $e.Row.Background = Get-SeverityBrush $sev }
    })

    # ── Filtro: estado en filterBox.Tag (sin closures) ───────────────
    $filterBox.Tag = [PSCustomObject]@{ DG = $dg; Status = $statusLabel }
    $filterBox.Add_TextChanged({
        param($sender, $e)
        $ctx = $sender.Tag
        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl) { return }
        $txt = $sender.Text.Trim()
        if ([string]::IsNullOrEmpty($txt)) {
            $tbl.DefaultView.RowFilter = ""
        } else {
            $safeT = $txt -replace "'", "''"
            $exprs = $tbl.Columns | ForEach-Object {
                "CONVERT([{0}], 'System.String') LIKE '%{1}%'" -f $_.ColumnName, $safeT
            }
            try { $tbl.DefaultView.RowFilter = $exprs -join " OR " } catch { $tbl.DefaultView.RowFilter = "" }
        }
        $ctx.DG.ItemsSource = $tbl.DefaultView
        $ctx.Status.Text = if ([string]::IsNullOrEmpty($sender.Text.Trim())) {
            "$($tbl.Rows.Count) filas"
        } else {
            "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) filas  ·  '$($sender.Text.Trim())'"
        }
    })

    # ── Botones: estado en Tag del boton (sin closures) ──────────────
    foreach ($btn in ($rightSP.Children | Where-Object { $_ -is [System.Windows.Controls.Button] })) {
        $btn.Tag = [PSCustomObject]@{ DG = $dg; Status = $statusLabel; FilterBox = $filterBox; FilePath = $FilePath }
        $btn.Add_Click({
            param($sender, $e)
            $ctx = $sender.Tag
            switch -Wildcard ($sender.Content) {
                "Limpiar"   { $ctx.FilterBox.Text = "" }
                "Copiar*"   {
                    $sel = $ctx.DG.SelectedItems
                    if (-not $sel -or $sel.Count -eq 0) { return }
                    $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
                    $lines = New-Object "System.Collections.Generic.List[string]"
                    if ($tbl) { $lines.Add(($tbl.Columns | ForEach-Object { $_.ColumnName }) -join "`t") }
                    foreach ($item in $sel) {
                        $drv = $item -as [System.Data.DataRowView]
                        if ($drv) { $lines.Add(($drv.Row.ItemArray | ForEach-Object { $_.ToString() }) -join "`t") }
                    }
                    if ($lines.Count -gt 0) { [System.Windows.Clipboard]::SetText($lines -join "`n") }
                }
                "Export*"   {
                    $dlg = New-Object Microsoft.Win32.SaveFileDialog
                    $dlg.Filter   = "CSV (*.csv)|*.csv"
                    $dlg.FileName = "export_$([System.IO.Path]::GetFileNameWithoutExtension($ctx.FilePath))"
                    if ($dlg.ShowDialog() -eq $true) {
                        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
                        if ($tbl) { $tbl.DefaultView.ToTable() | Export-Csv $dlg.FileName -NoTypeInformation -Encoding UTF8 }
                    }
                }
            }
        })
    }

    # ── Ctrl+C para copiar seleccion ─────────────────────────────────
    $dg.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq 'C' -and ([System.Windows.Input.Keyboard]::Modifiers -band 'Control')) {
            $sel = $s.SelectedItems
            if (-not $sel -or $sel.Count -eq 0) { return }
            $tbl = $s.Tag -as [System.Data.DataTable]
            $lines = New-Object "System.Collections.Generic.List[string]"
            if ($tbl) { $lines.Add(($tbl.Columns | ForEach-Object { $_.ColumnName }) -join "`t") }
            foreach ($item in $sel) {
                $drv = $item -as [System.Data.DataRowView]
                if ($drv) { $lines.Add(($drv.Row.ItemArray | ForEach-Object { $_.ToString() }) -join "`t") }
            }
            if ($lines.Count -gt 0) { [System.Windows.Clipboard]::SetText($lines -join "`n") }
        }
    })

    # ── Carga async: Runspace en fondo, resultado al UI thread via DispatcherTimer ──
    $ui = [PSCustomObject]@{
        DG      = $dg
        Status  = $statusLabel
        Overlay = $overlay
        MaxRows = $Script:MaxRowsDefault
    }

    Invoke-AsyncCSVLoad -FilePath $FilePath -MaxRows $Script:MaxRowsDefault -UIContext $ui `
        -OnComplete {
            param($ui, $table, $totalRows)
            $ui.DG.Tag         = $table
            $ui.DG.ItemsSource = $table.DefaultView
            $info = if ($totalRows -gt $ui.MaxRows) {
                "Mostrando $($ui.MaxRows) de $totalRows filas  ·  Usa el filtro para buscar"
            } elseif ($totalRows -eq 0) { "CSV vacio" } else { "$totalRows filas" }
            $ui.Status.Text        = $info
            $ui.Overlay.Visibility = 'Collapsed'
        } `
        -OnError {
            param($ui, $msg)
            $ui.Status.Text        = "Error al cargar: $msg"
            $ui.Overlay.Visibility = 'Collapsed'
        }

    return $outer
}

#endregion
