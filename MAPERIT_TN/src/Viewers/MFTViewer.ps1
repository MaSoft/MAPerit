#region ============================================================
# MaPeriT.TN - VISOR MFT (CSV parseado de AN o raw $MFT)
# ============================================================

function New-MFTViewerContent {
    param([string]$FilePath)

    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if ($ext -eq ".csv") {
        return New-MFTCSVViewer -FilePath $FilePath
    }
    return New-MFTRawInfo -FilePath $FilePath
}

function New-MFTCSVViewer {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    $r0 = New-Object System.Windows.Controls.RowDefinition; $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::Auto
    $r2 = New-Object System.Windows.Controls.RowDefinition; $r2.Height = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $r3 = New-Object System.Windows.Controls.RowDefinition; $r3.Height = [System.Windows.GridLength]::Auto
    $outer.RowDefinitions.Add($r0)
    $outer.RowDefinitions.Add($r1)
    $outer.RowDefinitions.Add($r2)
    $outer.RowDefinitions.Add($r3)

    # ── Banner informativo ───────────────────────────────────────────
    $isMFTTimestomp = $FilePath -match 'MFT_Timestomping'
    $isMFTDeleted   = $FilePath -match 'MFT_Borrados'

    # Colores del tema activo (antes fijos de tema oscuro tambien en el claro)
    $bannerColor = if ($isMFTTimestomp) { $Script:Colors.RowTimestomp } elseif ($isMFTDeleted) { $Script:Colors.RowInfo } else { $Script:Colors.BgCard }
    $bannerText  = if ($isMFTTimestomp) {
        "POSIBLE TIMESTOMPING — Fechas de `$STANDARD_INFORMATION (SI_*) incoherentes con las de `$FILE_NAME (FN_*); el motivo de cada fila esta en RazonTimestomp. Fechas en UTC."
    } elseif ($isMFTDeleted) {
        "FICHEROS BORRADOS — Registros MFT marcados como no en uso (Estado = BORRADO) cuyo registro NTFS aun no ha sido reutilizado. Fechas en UTC."
    } else {
        "MFT COMPLETO — Todos los registros del Master File Table. SI_* son de `$STANDARD_INFORMATION (modificables). FN_* son de `$FILE_NAME (mas fiables). Fechas en UTC."
    }

    $banner = New-Object System.Windows.Controls.Border
    $banner.Background      = New-WpfBrush $bannerColor
    $banner.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $banner.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $banner.Padding         = [System.Windows.Thickness]::new(12,8,12,8)
    $bannerLabel = New-Object System.Windows.Controls.TextBlock
    $bannerLabel.Text         = $bannerText
    $bannerLabel.Foreground   = New-WpfBrush $Script:Colors.TextMuted
    $bannerLabel.FontSize     = 11
    $bannerLabel.TextWrapping = 'Wrap'
    $banner.Child = $bannerLabel
    [System.Windows.Controls.Grid]::SetRow($banner, 0)
    $outer.Children.Add($banner) | Out-Null

    # ── Toolbar ─────────────────────────────────────────────────────
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(8,5,8,5)

    $tbDP = New-Object System.Windows.Controls.DockPanel
    $tbDP.LastChildFill = $false

    $rightSP = New-Object System.Windows.Controls.StackPanel
    $rightSP.Orientation = 'Horizontal'
    [System.Windows.Controls.DockPanel]::SetDock($rightSP, 'Right')

    $chkNonSystem = New-Object System.Windows.Controls.CheckBox
    $chkNonSystem.Content          = "Solo fuera de System32/WinSxS"
    $chkNonSystem.Foreground       = New-WpfBrush $Script:Colors.Text
    $chkNonSystem.FontSize         = 11
    $chkNonSystem.VerticalAlignment= 'Center'
    $chkNonSystem.Margin           = [System.Windows.Thickness]::new(0,0,10,0)
    $rightSP.Children.Add($chkNonSystem) | Out-Null

    $filterBox = New-Object System.Windows.Controls.TextBox
    $filterBox.Width       = 200
    $filterBox.Height      = 24
    $filterBox.Background  = New-WpfBrush $Script:Colors.BgSurface
    $filterBox.Foreground  = New-WpfBrush $Script:Colors.Text
    $filterBox.CaretBrush  = [System.Windows.Media.Brushes]::White
    $filterBox.BorderBrush = New-WpfBrush $Script:Colors.Border
    $filterBox.Padding     = [System.Windows.Thickness]::new(6,2,6,2)
    $filterBox.FontSize    = 11
    $filterBox.ToolTip     = "Filtrar por ruta/nombre"
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
    [System.Windows.Controls.Grid]::SetRow($toolbar, 1)
    $outer.Children.Add($toolbar) | Out-Null

    # ── DataGrid ─────────────────────────────────────────────────────
    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly              = $true
    $dg.AutoGenerateColumns     = $true
    $dg.SelectionMode           = 'Extended'
    $dg.SelectionUnit           = 'FullRow'
    $dg.CanUserSortColumns      = $true
    $dg.CanUserResizeColumns    = $true
    $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($dg, [System.Windows.Controls.VirtualizationMode]::Recycling)
    # Ancho fijo tambien en columnas auto-generadas - ver comentario extenso
    # en CSVViewer.ps1 (mismo riesgo de crash de WPF con datasets MFT grandes).
    $dg.Add_AutoGeneratingColumn({
        param($s, $e)
        $e.Column.Width = New-Object System.Windows.Controls.DataGridLength(160)
    })
    Apply-DataGridDarkTheme $dg
    Add-DataGridRowContextMenu -DG $dg -FilePath $FilePath
    [System.Windows.Controls.Grid]::SetRow($dg, 2)
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
    $statusLabel.Text       = "Cargando MFT..."
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 3)
    $outer.Children.Add($statusBar) | Out-Null

    # ── Overlay de carga ──────────────────────────────────────────────
    $overlay = New-LoadingOverlay -Message "Cargando MFT..." -RowSpan 4
    $outer.Children.Add($overlay) | Out-Null

    # ── Colorear filas: timestomping (morado) y borradas (azul) ──────
    $dg.Add_LoadingRow({
        param($s, $e)
        $item = $e.Row.Item -as [System.Data.DataRowView]
        if ($null -eq $item) { return }
        $row = $item.Row

        # Timestomping: columna Timestomping de MaPeriT.AN (antes se buscaban
        # SI_Created/FN_Created, que AN no genera, y nunca se coloreaba nada)
        if ($row.Table.Columns.Contains('Timestomping') -and $row['Timestomping'].ToString() -eq 'True') {
            $e.Row.Background = Get-TimestompBrush
            return
        }
        # Compatibilidad con CSV de otras herramientas: SI_Created < FN_Created (margen 60 s)
        $siCol = $row.Table.Columns | Where-Object { $_.ColumnName -eq 'SI_Created' } | Select-Object -First 1
        $fnCol = $row.Table.Columns | Where-Object { $_.ColumnName -eq 'FN_Created' } | Select-Object -First 1
        if ($siCol -and $fnCol) {
            try {
                $siC = [datetime]::Parse($row['SI_Created'].ToString())
                $fnC = [datetime]::Parse($row['FN_Created'].ToString())
                if ($siC -lt $fnC.AddSeconds(-60)) {
                    $e.Row.Background = Get-TimestompBrush
                    return
                }
            } catch {}
        }

        # Ficheros borrados: Estado = BORRADO (AN) o InUse = false/0 (otras herramientas)
        $isDeleted = ($row.Table.Columns.Contains('Estado') -and $row['Estado'].ToString() -eq 'BORRADO') -or
                     ($row.Table.Columns.Contains('InUse') -and $row['InUse'].ToString() -match '^(false|0)$')
        if ($isDeleted) {
            $e.Row.Background = New-WpfBrush $Script:Colors.RowInfo
            return
        }

        $sev = Get-RowSeverity $row
        if ($sev -ne "Normal") { $e.Row.Background = Get-SeverityBrush $sev }
    })

    # ── Filtro: logica inline en los handlers, estado en Tag ─────────
    # filterBox.Tag: { DG, Status, Chk }
    # chkNonSystem.Tag: filterBox
    # Los handlers leen todo desde $sender.Tag — sin closures.

    $filterBox.Tag = [PSCustomObject]@{ DG = $dg; Status = $statusLabel; Chk = $chkNonSystem }

    $filterBox.Add_TextChanged({
        param($sender, $e)
        $ctx = $sender.Tag
        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl) { return }

        $txt           = $sender.Text.Trim()
        $onlyNonSystem = $ctx.Chk.IsChecked -eq $true
        $conditions    = @()

        if (-not [string]::IsNullOrEmpty($txt)) {
            $safeT = $txt -replace "'", "''"
            $exprs = $tbl.Columns | ForEach-Object {
                "CONVERT([{0}], 'System.String') LIKE '%{1}%'" -f $_.ColumnName, $safeT
            }
            $conditions += "(" + ($exprs -join " OR ") + ")"
        }

        if ($onlyNonSystem) {
            # RutaCompleta es la columna de AN (antes solo FullPath/Path: el filtro no hacia nada)
            $pathColObj = $tbl.Columns | Where-Object { $_.ColumnName -match '^(RutaCompleta|FullPath|Path)$' } | Select-Object -First 1
            if ($null -ne $pathColObj) {
                $pc = $pathColObj.ColumnName
                $conditions += "NOT (CONVERT([{0}], 'System.String') LIKE '%Windows%System32%' OR CONVERT([{0}], 'System.String') LIKE '%Windows%WinSxS%')" -f $pc
            }
        }

        try { $tbl.DefaultView.RowFilter = $conditions -join " AND " } catch { $tbl.DefaultView.RowFilter = "" }
        $ctx.DG.ItemsSource = $tbl.DefaultView
        $ctx.Status.Text    = "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) registros"
    })

    # El checkbox necesita re-ejecutar el mismo filtro.
    # chkNonSystem.Tag = filterBox → handler lee filterBox.Tag para el estado.
    $chkNonSystem.Tag = $filterBox
    $chkNonSystem.Add_Checked({
        param($sender, $e)
        $fb  = $sender.Tag    # filterBox
        $ctx = $fb.Tag        # PSCustomObject { DG, Status, Chk }
        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl) { return }

        $txt    = $fb.Text.Trim()
        $conditions = @()
        if (-not [string]::IsNullOrEmpty($txt)) {
            $safeT = $txt -replace "'", "''"
            $exprs = $tbl.Columns | ForEach-Object {
                "CONVERT([{0}], 'System.String') LIKE '%{1}%'" -f $_.ColumnName, $safeT
            }
            $conditions += "(" + ($exprs -join " OR ") + ")"
        }
        $pathColObj = $tbl.Columns | Where-Object { $_.ColumnName -match '^(RutaCompleta|FullPath|Path)$' } | Select-Object -First 1
        if ($null -ne $pathColObj) {
            $pc = $pathColObj.ColumnName
            $conditions += "NOT (CONVERT([{0}], 'System.String') LIKE '%Windows%System32%' OR CONVERT([{0}], 'System.String') LIKE '%Windows%WinSxS%')" -f $pc
        }
        try { $tbl.DefaultView.RowFilter = $conditions -join " AND " } catch { $tbl.DefaultView.RowFilter = "" }
        $ctx.DG.ItemsSource = $tbl.DefaultView
        $ctx.Status.Text    = "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) registros"
    })

    $chkNonSystem.Add_Unchecked({
        param($sender, $e)
        $fb  = $sender.Tag
        $ctx = $fb.Tag
        $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
        if ($null -eq $tbl) { return }

        $txt = $fb.Text.Trim()
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
        $ctx.Status.Text    = "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) registros"
    })

    # ── Copiar: estado en Tag del boton ───────────────────────────────
    $btnCopy.Tag = $dg
    $btnCopy.Add_Click({
        param($sender, $e)
        $dg2      = $sender.Tag -as [System.Windows.Controls.DataGrid]
        $selected = $dg2.SelectedItems
        if (-not $selected -or $selected.Count -eq 0) { return }
        $tbl   = $dg2.Tag -as [System.Data.DataTable]
        $lines = New-Object "System.Collections.Generic.List[string]"
        if ($tbl) { $lines.Add(($tbl.Columns | ForEach-Object { $_.ColumnName }) -join "`t") }
        foreach ($item in $selected) {
            $drv = $item -as [System.Data.DataRowView]
            if ($drv) { $lines.Add(($drv.Row.ItemArray | ForEach-Object { $_.ToString() }) -join "`t") }
        }
        if ($lines.Count -gt 0) { [System.Windows.Clipboard]::SetText($lines -join "`n") }
    })

    # ── Carga async ───────────────────────────────────────────────────
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
                "$($ui.MaxRows) de $totalRows registros (truncado)"
            } else { "$totalRows registros" }
            $ui.Status.Text        = $info
            $ui.Overlay.Visibility = 'Collapsed'
        } `
        -OnError {
            param($ui, $msg)
            $ui.Status.Text        = "Error: $msg"
            $ui.Overlay.Visibility = 'Collapsed'
        }

    return $outer
}

function New-MFTRawInfo {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.HorizontalAlignment = 'Center'
    $sp.VerticalAlignment   = 'Center'
    $sp.MaxWidth = 600

    $size = if (Test-Path $FilePath) { Format-FileSize (Get-Item $FilePath).Length } else { "?" }

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text          = "`$MFT  —  Fichero binario"
    $title.FontSize      = 20
    $title.FontWeight    = [System.Windows.FontWeights]::Light
    $title.Foreground    = New-WpfBrush $Script:Colors.Accent
    $title.TextAlignment = 'Center'
    $title.Margin        = [System.Windows.Thickness]::new(0,0,0,12)
    $sp.Children.Add($title) | Out-Null

    $info = New-Object System.Windows.Controls.TextBlock
    $info.Text           = "Tamano: $size`n`nEl `$MFT es el fichero binario del Master File Table de NTFS.`nPara un analisis completo ejecuta MaPeriT.AN sobre este directorio.`n`nMaPeriT.AN genera:`n  · MFT\MFT_Completo.csv`n  · MFT\MFT_Timestomping.csv`n  · MFT\MFT_Borrados.csv`n`nEstos CSVs tienen visor completo en MaPeriT.TN."
    $info.Foreground     = New-WpfBrush $Script:Colors.TextMuted
    $info.FontSize       = 13
    $info.TextWrapping   = 'Wrap'
    $info.TextAlignment  = 'Center'
    $info.LineHeight     = 22
    $sp.Children.Add($info) | Out-Null

    $outer.Children.Add($sp) | Out-Null
    return $outer
}

#endregion
