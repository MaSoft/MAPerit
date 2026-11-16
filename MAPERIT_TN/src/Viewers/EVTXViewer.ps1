#region ============================================================
# MaPeriT.TN - VISOR EVTX
# ============================================================

function New-EVTXViewerContent {
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
    [System.Windows.Controls.DockPanel]::SetDock($fileLabel, 'Left')
    $tbDP.Children.Add($fileLabel) | Out-Null

    $rightSP = New-Object System.Windows.Controls.StackPanel
    $rightSP.Orientation = 'Horizontal'
    [System.Windows.Controls.DockPanel]::SetDock($rightSP, 'Right')

    $filterBox = New-Object System.Windows.Controls.TextBox
    $filterBox.Width       = 180
    $filterBox.Height      = 24
    $filterBox.Background  = New-WpfBrush $Script:Colors.BgSurface
    $filterBox.Foreground  = New-WpfBrush $Script:Colors.Text
    $filterBox.CaretBrush  = [System.Windows.Media.Brushes]::White
    $filterBox.BorderBrush = New-WpfBrush $Script:Colors.Border
    $filterBox.Padding     = [System.Windows.Thickness]::new(6,2,6,2)
    $filterBox.FontSize    = 11
    $filterBox.ToolTip     = "Filtrar por EventID, proveedor o mensaje"
    $rightSP.Children.Add($filterBox) | Out-Null

    $btnCopy = New-Object System.Windows.Controls.Button
    $btnCopy.Content     = "Copiar sel."
    $btnCopy.Height      = 24
    $btnCopy.Padding     = [System.Windows.Thickness]::new(8,2,8,2)
    $btnCopy.Margin      = [System.Windows.Thickness]::new(4,0,0,0)
    $btnCopy.Background  = New-WpfBrush $Script:Colors.BgSurface
    $btnCopy.Foreground  = New-WpfBrush $Script:Colors.Text
    $btnCopy.BorderBrush = New-WpfBrush $Script:Colors.Border
    $btnCopy.FontSize    = 11
    $btnCopy.Cursor      = [System.Windows.Input.Cursors]::Hand
    $rightSP.Children.Add($btnCopy) | Out-Null

    $tbDP.Children.Add($rightSP) | Out-Null
    $toolbar.Child = $tbDP
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # ── DataGrid con columnas fijas ───────────────────────────────────
    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly              = $true
    $dg.AutoGenerateColumns     = $false
    $dg.SelectionMode           = 'Extended'
    $dg.SelectionUnit           = 'FullRow'
    $dg.CanUserSortColumns      = $true
    $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($dg, [System.Windows.Controls.VirtualizationMode]::Recycling)
    Apply-DataGridDarkTheme $dg
    Add-DataGridRowContextMenu -DG $dg -FilePath $FilePath

    foreach ($cd in @(
        @{ H="Fecha/Hora";  B="TimeCreated"; W=160 },
        @{ H="EventID";     B="Id";          W=70  },
        @{ H="Nivel";       B="Level";       W=70  },
        @{ H="Proveedor";   B="ProviderName";W=160 },
        @{ H="Mensaje";     B="Message";     W=500 },
        @{ H="Usuario";     B="UserId";      W=120 },
        @{ H="Equipo";      B="MachineName"; W=120 }
    )) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header  = $cd.H
        $col.Binding = New-Object System.Windows.Data.Binding($cd.B)
        $col.Width   = $cd.W
        $dg.Columns.Add($col) | Out-Null
    }

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
    $statusLabel.Text       = "Leyendo eventos..."
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    # ── Cargar eventos (sincrono: EVTX suelen ser manejables) ────────
    $rawEvents = @()
    $totalEvts = 0
    try {
        $rawEvents = @(Get-WinEvent -Path $FilePath -MaxEvents $Script:MaxEVTXEvents -ErrorAction Stop |
            Select-Object TimeCreated, Id, Level, ProviderName,
                @{ N='Message'; E={ ($_.Message -replace "`r`n"," " -replace "`n"," ").Substring(0, [Math]::Min(($_.Message -replace "`r`n"," " -replace "`n"," ").Length, 300)) } },
                @{ N='UserId';  E={ if ($_.UserId) { $_.UserId.Value } else { "" } } },
                MachineName)
        $totalEvts = $rawEvents.Count
    } catch {
        $statusLabel.Text = "Error al leer EVTX: $($_.Exception.Message)"
    }

    # Construir DataTable directamente (sin funciones que puedan enumerar)
    $tbl = [System.Data.DataTable]::new("EVTXData")
    if ($rawEvents.Count -gt 0) {
        foreach ($prop in $rawEvents[0].PSObject.Properties.Name) {
            [void]$tbl.Columns.Add($prop, [string])
        }
        foreach ($ev in $rawEvents) {
            $row = $tbl.NewRow()
            foreach ($c in $tbl.Columns) {
                $v = $ev.($c.ColumnName)
                $row[$c.ColumnName] = if ($null -ne $v) { $v.ToString() } else { "" }
            }
            [void]$tbl.Rows.Add($row)
        }
    }

    $dg.Tag         = $tbl
    $dg.ItemsSource = $tbl.DefaultView
    $statusLabel.Text = "$totalEvts eventos" + $(if ($totalEvts -ge $Script:MaxEVTXEvents) { " (limite $($Script:MaxEVTXEvents))" } else { "" })

    # ── Colorear filas por EventID ────────────────────────────────────
    $dg.Add_LoadingRow({
        param($s, $e)
        $item = $e.Row.Item -as [System.Data.DataRowView]
        if ($null -eq $item) { return }
        $eid = 0
        if ([int]::TryParse($item['Id'].ToString(), [ref]$eid)) {
            $bg = switch ($true) {
                ($eid -in $Script:EventSeverity.Critical) { New-WpfBrush $Script:Colors.RowCritical; break }
                ($eid -in $Script:EventSeverity.High)     { New-WpfBrush $Script:Colors.RowDanger;   break }
                ($eid -in $Script:EventSeverity.Medium)   { New-WpfBrush $Script:Colors.RowWarning;  break }
                default { $null }
            }
            if ($null -ne $bg) { $e.Row.Background = $bg }
        }
    })

    # ── Filtro: estado en filterBox.Tag (sin closures) ───────────────
    $filterBox.Tag = [PSCustomObject]@{ DG = $dg; Status = $statusLabel }
    $filterBox.Add_TextChanged({
        param($sender, $e)
        $ctx = $sender.Tag
        $tbl2 = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl2) { return }
        $txt = $sender.Text.Trim()
        if ([string]::IsNullOrEmpty($txt)) {
            $tbl2.DefaultView.RowFilter = ""
        } else {
            $safeT = $txt -replace "'", "''"
            try {
                $tbl2.DefaultView.RowFilter = "CONVERT([Id], 'System.String') LIKE '%$safeT%' OR CONVERT([Message], 'System.String') LIKE '%$safeT%' OR CONVERT([ProviderName], 'System.String') LIKE '%$safeT%'"
            } catch { $tbl2.DefaultView.RowFilter = "" }
        }
        $ctx.DG.ItemsSource = $tbl2.DefaultView
        $ctx.Status.Text    = "$($tbl2.DefaultView.Count) de $($tbl2.Rows.Count) eventos visibles"
    })

    # ── Copiar: estado en Tag del boton (sin closures) ───────────────
    $btnCopy.Tag = $dg
    $btnCopy.Add_Click({
        param($sender, $e)
        $dg2      = $sender.Tag -as [System.Windows.Controls.DataGrid]
        $selected = $dg2.SelectedItems
        if (-not $selected -or $selected.Count -eq 0) { return }
        $tbl3  = $dg2.Tag -as [System.Data.DataTable]
        $lines = New-Object "System.Collections.Generic.List[string]"
        if ($tbl3) { $lines.Add(($tbl3.Columns | ForEach-Object { $_.ColumnName }) -join "`t") }
        foreach ($item in $selected) {
            $drv = $item -as [System.Data.DataRowView]
            if ($drv) { $lines.Add(($drv.Row.ItemArray | ForEach-Object { $_.ToString() }) -join "`t") }
        }
        if ($lines.Count -gt 0) { [System.Windows.Clipboard]::SetText($lines -join "`n") }
    })

    return $outer
}

#endregion
