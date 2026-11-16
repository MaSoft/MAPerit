#region ============================================================
# MaPeriT.TN - SISTEMA DE MARCADORES Y ANOTACIONES
# ============================================================

$Script:Bookmarks     = [System.Collections.Generic.List[PSCustomObject]]::new()
$Script:BookmarksPath = ""

function Initialize-Bookmarks {
    param([string]$ProjectPath)
    $Script:BookmarksPath = Join-Path $ProjectPath "TN_Bookmarks.json"
    $Script:Bookmarks.Clear()
    if (Test-Path $Script:BookmarksPath) {
        try {
            $loaded = Get-Content $Script:BookmarksPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($b in $loaded) {
                $Script:Bookmarks.Add([PSCustomObject]@{
                    FilePath   = [string]$b.FilePath
                    LineNumber = if ($b.PSObject.Properties['LineNumber'] -and $b.LineNumber) { [int]$b.LineNumber } else { 0 }
                    ColumnName = if ($b.PSObject.Properties['ColumnName']) { [string]$b.ColumnName } else { "" }
                    CellValue  = if ($b.PSObject.Properties['CellValue'])  { [string]$b.CellValue  } else { "" }
                    Label      = [string]$b.Label
                    Severity   = [string]$b.Severity
                    Note       = [string]$b.Note
                    Timestamp  = [string]$b.Timestamp
                }) | Out-Null
            }
        } catch {}
    }
}

function Save-Bookmarks {
    if ([string]::IsNullOrEmpty($Script:BookmarksPath)) { return }
    try {
        $Script:Bookmarks | ConvertTo-Json -Depth 5 |
            Set-Content $Script:BookmarksPath -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Add-Bookmark {
    param(
        [string]$FilePath,
        [string]$Label      = "",
        [string]$Severity   = "Info",
        [string]$Note       = "",
        [int]   $LineNumber = 0,
        [string]$ColumnName = "",
        [string]$CellValue  = ""
    )
    $existing = $Script:Bookmarks | Where-Object {
        $_.FilePath -eq $FilePath -and [int]$_.LineNumber -eq $LineNumber -and $_.ColumnName -eq $ColumnName
    } | Select-Object -First 1
    if ($existing) {
        if ($Label)    { $existing.Label    = $Label    }
        if ($Severity) { $existing.Severity = $Severity }
        if ($Note)     { $existing.Note     = $Note     }
        $existing.Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    } else {
        $Script:Bookmarks.Add([PSCustomObject]@{
            FilePath   = $FilePath
            LineNumber = $LineNumber
            ColumnName = $ColumnName
            CellValue  = $CellValue
            Label      = if ($Label) { $Label } else { [System.IO.Path]::GetFileName($FilePath) }
            Severity   = $Severity
            Note       = $Note
            Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }) | Out-Null
    }
    Save-Bookmarks
}

function Remove-Bookmark {
    param([PSCustomObject]$Bookmark)
    if ($Bookmark -and $Script:Bookmarks.Remove($Bookmark)) { Save-Bookmarks }
}

function Get-IsBookmarked {
    param([string]$FilePath)
    return ($Script:Bookmarks | Where-Object { $_.FilePath -eq $FilePath }).Count -gt 0
}

function Get-BookmarksTable {
    $tbl = [System.Data.DataTable]::new("Bookmarks")
    foreach ($c in @('Severity','Label','FilePath','LineNumber','ColumnName','CellValue','Note','Timestamp')) {
        [void]$tbl.Columns.Add($c, [string])
    }
    foreach ($b in $Script:Bookmarks) {
        $row = $tbl.NewRow()
        $row['Severity']   = $b.Severity
        $row['Label']      = $b.Label
        $row['FilePath']   = $b.FilePath
        $row['LineNumber'] = if ($b.LineNumber -gt 0) { $b.LineNumber.ToString() } else { "" }
        $row['ColumnName'] = $b.ColumnName
        $row['CellValue']  = $b.CellValue
        $row['Note']       = $b.Note
        $row['Timestamp']  = $b.Timestamp
        [void]$tbl.Rows.Add($row)
    }
    Write-Output -NoEnumerate $tbl
}

function New-BookmarksPanelContent {
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
    $titleLbl.Text       = "Marcadores del Proyecto"
    $titleLbl.FontSize   = 12
    $titleLbl.FontWeight = [System.Windows.FontWeights]::SemiBold
    $titleLbl.Foreground = New-WpfBrush $Script:Colors.Text
    $titleLbl.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($titleLbl, 'Left')
    $tbDP.Children.Add($titleLbl) | Out-Null

    $rightSP = New-Object System.Windows.Controls.StackPanel
    $rightSP.Orientation = 'Horizontal'
    [System.Windows.Controls.DockPanel]::SetDock($rightSP, 'Right')
    foreach ($btnTxt in @("Exportar HTML", "Eliminar sel.")) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content     = $btnTxt
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

    # DataGrid — usa DataTable para que WPF pueda reflejar las propiedades
    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly          = $true
    $dg.AutoGenerateColumns = $false
    $dg.SelectionMode       = 'Extended'
    $dg.SelectionUnit       = 'FullRow'
    $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    Apply-DataGridDarkTheme $dg
    foreach ($cd in @(
        @{ H="Severidad"; B="Severity";   W=80  },
        @{ H="Etiqueta";  B="Label";      W=150 },
        @{ H="Archivo";   B="FilePath";   W=200 },
        @{ H="Linea";     B="LineNumber"; W=55  },
        @{ H="Columna";   B="ColumnName"; W=90  },
        @{ H="Valor";     B="CellValue";  W=160 },
        @{ H="Nota";      B="Note";       W=200 },
        @{ H="Fecha";     B="Timestamp";  W=130 }
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
        $bg = switch ($item['Severity']) {
            "Critical" { New-WpfBrush $Script:Colors.RowCritical }
            "High"     { New-WpfBrush $Script:Colors.RowDanger   }
            "Medium"   { New-WpfBrush $Script:Colors.RowWarning  }
            default    { $null }
        }
        if ($null -ne $bg) { $e.Row.Background = $bg }
    })

    $bmTable = Get-BookmarksTable
    $dg.Tag        = $bmTable
    $dg.ItemsSource = $bmTable.DefaultView
    [System.Windows.Controls.Grid]::SetRow($dg, 1)
    $outer.Children.Add($dg) | Out-Null

    $dg.Add_MouseDoubleClick({
        param($s, $e)
        $item = $s.SelectedItem -as [System.Data.DataRowView]
        if ($item) {
            $fp = $item['FilePath'] -as [string]
            if (-not [string]::IsNullOrEmpty($fp) -and (Test-Path $fp)) {
                Open-FileInTab -FilePath $fp
            }
        }
    })

    # Status
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Text       = "$($Script:Bookmarks.Count) marcadores  ·  Doble clic para abrir"
    $statusLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $statusLabel.FontSize   = 11
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    foreach ($btn in ($rightSP.Children | Where-Object { $_ -is [System.Windows.Controls.Button] })) {
        $btn.Tag = [PSCustomObject]@{ DG = $dg; Status = $statusLabel }
        $btn.Add_Click({
            param($sender, $e)
            $ctx = $sender.Tag
            switch -Wildcard ($sender.Content) {
                "Exportar*" { Export-BookmarksReport }
                "Eliminar*" {
                    $sel = @($ctx.DG.SelectedItems | ForEach-Object { $_ })
                    foreach ($drv in $sel) {
                        $rv = $drv -as [System.Data.DataRowView]
                        if ($rv) {
                            $fp  = $rv['FilePath'] -as [string]
                            $ln  = 0; [int]::TryParse($rv['LineNumber'], [ref]$ln) | Out-Null
                            $col = $rv['ColumnName'] -as [string]
                            $bm  = $Script:Bookmarks | Where-Object {
                                $_.FilePath -eq $fp -and [int]$_.LineNumber -eq $ln -and $_.ColumnName -eq $col
                            } | Select-Object -First 1
                            if ($bm) { Remove-Bookmark -Bookmark $bm }
                        }
                    }
                    $newTbl = Get-BookmarksTable
                    $ctx.DG.Tag        = $newTbl
                    $ctx.DG.ItemsSource = $newTbl.DefaultView
                    $ctx.Status.Text   = "$($Script:Bookmarks.Count) marcadores"
                }
            }
        })
    }
    return $outer
}

function Show-AddBookmarkDialog {
    param(
        [string]$FilePath,
        [int]   $LineNumber = 0,
        [string]$ColumnName = "",
        [string]$CellValue  = ""
    )

    $hasLineCtx = $LineNumber -gt 0

    $dlg = New-Object System.Windows.Window
    $dlg.Title                 = "Anadir Marcador"
    $dlg.Width                 = 440
    $dlg.Height = if ($hasLineCtx) {
        if (-not [string]::IsNullOrEmpty($CellValue)) { 455 } else { 405 }
    } else { 355 }
    $dlg.Background            = New-WpfBrush $Script:Colors.BgPanel
    $dlg.WindowStartupLocation = 'CenterScreen'
    $dlg.ResizeMode            = 'NoResize'

    $existing = $Script:Bookmarks | Where-Object {
        $_.FilePath -eq $FilePath -and [int]$_.LineNumber -eq $LineNumber -and $_.ColumnName -eq $ColumnName
    } | Select-Object -First 1

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = [System.Windows.Thickness]::new(20,14,20,14)

    $mkLbl = {
        param($t)
        $l = New-Object System.Windows.Controls.TextBlock
        $l.Text = $t; $l.Foreground = New-WpfBrush $Script:Colors.TextMuted
        $l.FontSize = 11; $l.Margin = [System.Windows.Thickness]::new(0,8,0,3)
        return $l
    }
    $mkBox = {
        param($val)
        $b = New-Object System.Windows.Controls.TextBox
        $b.Text = $val; $b.Background = New-WpfBrush $Script:Colors.BgSurface
        $b.Foreground = New-WpfBrush $Script:Colors.Text
        $b.CaretBrush = [System.Windows.Media.Brushes]::White
        $b.BorderBrush = New-WpfBrush $Script:Colors.Border
        $b.Padding = [System.Windows.Thickness]::new(6,4,6,4); $b.FontSize = 12
        return $b
    }

    $sp.Children.Add((& $mkLbl "Archivo:")) | Out-Null
    $pathLbl = New-Object System.Windows.Controls.TextBlock
    $pathLbl.Text = [System.IO.Path]::GetFileName($FilePath)
    $pathLbl.Foreground = New-WpfBrush $Script:Colors.Text
    $pathLbl.FontSize = 12; $pathLbl.TextWrapping = 'Wrap'
    $sp.Children.Add($pathLbl) | Out-Null

    if ($hasLineCtx) {
        $sp.Children.Add((& $mkLbl "Fila / Linea:")) | Out-Null
        $lineInfo = New-Object System.Windows.Controls.TextBlock
        $lineInfo.Text = if ($ColumnName) { "Linea $LineNumber  ·  Columna: $ColumnName" } else { "Linea $LineNumber" }
        $lineInfo.Foreground = New-WpfBrush $Script:Colors.Info
        $lineInfo.FontSize = 12
        $sp.Children.Add($lineInfo) | Out-Null

        if (-not [string]::IsNullOrEmpty($CellValue)) {
            $sp.Children.Add((& $mkLbl "Valor de celda:")) | Out-Null
            $cellLbl = New-Object System.Windows.Controls.TextBlock
            $cellLbl.Text        = if ($CellValue.Length -gt 80) { $CellValue.Substring(0,80) + "..." } else { $CellValue }
            $cellLbl.Foreground  = New-WpfBrush $Script:Colors.TextMuted
            $cellLbl.FontSize    = 11
            $cellLbl.TextWrapping= 'Wrap'
            $sp.Children.Add($cellLbl) | Out-Null
        }
    }

    $sp.Children.Add((& $mkLbl "Etiqueta:")) | Out-Null
    $defLabel = if ($existing) { $existing.Label } elseif ($hasLineCtx -and $ColumnName) {
        "$([System.IO.Path]::GetFileNameWithoutExtension($FilePath)) L$LineNumber $ColumnName"
    } else { [System.IO.Path]::GetFileName($FilePath) }
    $labelBox = & $mkBox $defLabel
    $sp.Children.Add($labelBox) | Out-Null

    $sp.Children.Add((& $mkLbl "Severidad:")) | Out-Null
    $sevCombo = New-Object System.Windows.Controls.ComboBox
    $sevCombo.Background = New-WpfBrush $Script:Colors.BgSurface
    $sevCombo.Foreground = New-WpfBrush $Script:Colors.Text
    $sevCombo.FontSize   = 12
    $sevCombo.Padding    = [System.Windows.Thickness]::new(6,4,6,4)

    # El popup del ComboBox siempre usa fondo blanco del sistema (no override fiable en WPF).
    # Solución: texto oscuro en items (legible sobre blanco) + trigger azul en hover.
    # La cabecera cerrada usa $sevCombo.Foreground (color del tema), no el ItemContainerStyle.
    $icStyle = New-Object System.Windows.Style([System.Windows.Controls.ComboBoxItem])
    foreach ($sd in @(
        @{ P=[System.Windows.Controls.Control]::BackgroundProperty; V=[System.Windows.Media.Brushes]::Transparent },
        @{ P=[System.Windows.Controls.Control]::ForegroundProperty; V=(New-WpfBrush "#111827")                    },
        @{ P=[System.Windows.Controls.Control]::PaddingProperty;    V=([System.Windows.Thickness]::new(8,4,8,4))  }
    )) {
        $setter = New-Object System.Windows.Setter; $setter.Property=$sd.P; $setter.Value=$sd.V
        $icStyle.Setters.Add($setter) | Out-Null
    }
    $hiTrigger = New-Object System.Windows.Trigger
    $hiTrigger.Property = [System.Windows.Controls.ListBoxItem]::IsHighlightedProperty
    $hiTrigger.Value    = $true
    foreach ($td in @(
        @{ P=[System.Windows.Controls.Control]::BackgroundProperty; V=(New-WpfBrush $Script:Colors.SelectionBg) },
        @{ P=[System.Windows.Controls.Control]::ForegroundProperty; V=[System.Windows.Media.Brushes]::White     }
    )) {
        $ts = New-Object System.Windows.Setter; $ts.Property=$td.P; $ts.Value=$td.V
        $hiTrigger.Setters.Add($ts) | Out-Null
    }
    $icStyle.Triggers.Add($hiTrigger) | Out-Null
    $sevCombo.ItemContainerStyle = $icStyle

    $sevOptions = [string[]]@("Info","Medium","High","Critical")
    $sevCombo.ItemsSource = $sevOptions
    $defSev = if ($existing) { $existing.Severity } else { "Info" }
    $sevCombo.SelectedIndex = [System.Array]::IndexOf($sevOptions, $defSev)
    if ($sevCombo.SelectedIndex -lt 0) { $sevCombo.SelectedIndex = 0 }
    $sp.Children.Add($sevCombo) | Out-Null

    $sp.Children.Add((& $mkLbl "Nota:")) | Out-Null
    $noteVal = if ($existing) { $existing.Note } else { "" }
    $noteBox = & $mkBox $noteVal
    $sp.Children.Add($noteBox) | Out-Null

    $btnRow = New-Object System.Windows.Controls.StackPanel
    $btnRow.Orientation         = 'Horizontal'
    $btnRow.HorizontalAlignment = 'Right'
    $btnRow.Margin              = [System.Windows.Thickness]::new(0,14,0,0)

    $btnOK = New-Object System.Windows.Controls.Button
    $btnOK.Content = "Guardar"; $btnOK.Width = 90; $btnOK.Height = 30
    $btnOK.Background = New-WpfBrush $Script:Colors.Accent
    $btnOK.Foreground = [System.Windows.Media.Brushes]::White
    $btnOK.FontSize   = 12; $btnOK.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnOK.Margin     = [System.Windows.Thickness]::new(0,0,8,0)
    $btnRow.Children.Add($btnOK) | Out-Null

    $btnCancel = New-Object System.Windows.Controls.Button
    $btnCancel.Content = "Cancelar"; $btnCancel.Width = 80; $btnCancel.Height = 30
    $btnCancel.Background = New-WpfBrush $Script:Colors.BgCard
    $btnCancel.Foreground = New-WpfBrush $Script:Colors.Text
    $btnCancel.FontSize   = 12; $btnCancel.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnRow.Children.Add($btnCancel) | Out-Null
    $sp.Children.Add($btnRow) | Out-Null
    $dlg.Content = $sp

    $btnOK.Tag = [PSCustomObject]@{
        Dlg        = $dlg
        LabelBox   = $labelBox
        SevCombo   = $sevCombo
        NoteBox    = $noteBox
        FilePath   = $FilePath
        LineNumber = $LineNumber
        ColumnName = $ColumnName
        CellValue  = $CellValue
    }
    $btnOK.Add_Click({
        param($sender, $e)
        $ctx = $sender.Tag
        try {
            $sev = if ($ctx.SevCombo.SelectedItem) { $ctx.SevCombo.SelectedItem.ToString() } else { "Info" }
            Add-Bookmark -FilePath   $ctx.FilePath `
                         -Label      $ctx.LabelBox.Text.Trim() `
                         -Severity   $sev `
                         -Note       $ctx.NoteBox.Text.Trim() `
                         -LineNumber $ctx.LineNumber `
                         -ColumnName $ctx.ColumnName `
                         -CellValue  $ctx.CellValue
            $ctx.Dlg.DialogResult = $true
            Set-Status "Marcador guardado: $($ctx.LabelBox.Text.Trim())" "$($Script:Bookmarks.Count) marcadores"
        } catch {
            [System.Windows.MessageBox]::Show("Error al guardar marcador:`n$_", "MaPeriT.TN", 'OK', 'Error')
        }
    })
    $btnCancel.Tag = $dlg
    $btnCancel.Add_Click({ param($s,$e); ($s.Tag).DialogResult = $false })
    [void]$dlg.ShowDialog()
}

function Export-BookmarksReport {
    if ($Script:Bookmarks.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No hay marcadores para exportar.", "MaPeriT.TN", 'OK', 'Information')
        return
    }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter   = "HTML (*.html)|*.html|CSV (*.csv)|*.csv"
    $dlg.FileName = "MaPeriT_Marcadores_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    if ($dlg.ShowDialog() -ne $true) { return }
    $out = $dlg.FileName
    if ($out -match '\.csv$') {
        $Script:Bookmarks | Export-Csv $out -NoTypeInformation -Encoding UTF8
    } else {
        $rows = ""
        foreach ($b in $Script:Bookmarks) {
            $bg  = switch ($b.Severity) { "Critical"{"#3B1010"} "High"{"#3B2210"} "Medium"{"#3B3210"} default{"#1F2937"} }
            $ln  = if ($b.LineNumber -gt 0) { $b.LineNumber.ToString() } else { "" }
            $rows += "<tr style='background:$bg'>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.Severity))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.Label))</td>"
            $rows += "<td style='font-family:monospace;font-size:11px'>$([System.Net.WebUtility]::HtmlEncode($b.FilePath))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($ln))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.ColumnName))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.CellValue))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.Note))</td>"
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($b.Timestamp))</td></tr>`n"
        }
        $html = "<!DOCTYPE html><html lang='es'><head><meta charset='UTF-8'><title>MaPeriT.TN - Marcadores</title><style>body{background:#111827;color:#F1F5F9;font-family:'Segoe UI',sans-serif;padding:30px}h1{color:#3B82F6;font-weight:300}.sub{color:#64748B;font-size:13px;margin-bottom:24px}table{border-collapse:collapse;width:100%}th{background:#0F172A;color:#94A3B8;font-size:11px;text-transform:uppercase;padding:8px 12px;text-align:left;border-bottom:1px solid #334155}td{padding:7px 12px;font-size:12px;border-bottom:1px solid #1F2937;color:#CBD5E1}</style></head><body><h1>MaPeriT.TN - Informe de Marcadores</h1><p class='sub'>Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &nbsp;·&nbsp; $($Script:Bookmarks.Count) marcadores</p><table><thead><tr><th>Severidad</th><th>Etiqueta</th><th>Archivo</th><th>Linea</th><th>Columna</th><th>Valor</th><th>Nota</th><th>Fecha</th></tr></thead><tbody>$rows</tbody></table></body></html>"
        [System.IO.File]::WriteAllText($out, $html, [System.Text.Encoding]::UTF8)
        Start-Process $out
    }
    Set-Status "Informe exportado: $out"
}

#endregion
