#region ============================================================
# MaPeriT.TN - LOGICA DE LA VENTANA PRINCIPAL
# ============================================================

$Script:OpenTabs    = @{}    # FilePath -> TabItem
$Script:CurrentProject = $null

# ── Helpers de UI ─────────────────────────────────────────────────────

function Set-Status {
    param([string]$Left = "", [string]$Right = "")
    $Script:TNControls.StatusLeft.Dispatcher.Invoke({
        if ($Left)  { $Script:TNControls.StatusLeft.Text  = $Left  }
        if ($Right) { $Script:TNControls.StatusRight.Text = $Right }
    })
}

function Show-EmptyState {
    param([bool]$Show)
    $Script:TNControls.GridEmptyState.Visibility = if ($Show) { 'Visible' } else { 'Collapsed' }
}

function New-TabHeader {
    param([string]$Title, [string]$Icon = "·")

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    $iconTB = New-Object System.Windows.Controls.TextBlock
    $iconTB.Text       = $Icon
    $iconTB.Foreground = New-WpfBrush $Script:Colors.Accent
    $iconTB.FontSize   = 11
    $iconTB.Margin     = [System.Windows.Thickness]::new(0,0,6,0)
    $iconTB.VerticalAlignment = 'Center'
    $sp.Children.Add($iconTB) | Out-Null

    $titleTB = New-Object System.Windows.Controls.TextBlock
    $titleTB.Text       = $Title
    $titleTB.Foreground = New-WpfBrush $Script:Colors.Text
    $titleTB.FontSize   = 12
    $titleTB.VerticalAlignment = 'Center'
    $sp.Children.Add($titleTB) | Out-Null

    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content    = "✕"
    $closeBtn.Width      = 18
    $closeBtn.Height     = 18
    $closeBtn.Margin     = [System.Windows.Thickness]::new(8,0,0,0)
    $closeBtn.Background = [System.Windows.Media.Brushes]::Transparent
    $closeBtn.Foreground = New-WpfBrush $Script:Colors.TextDim
    $closeBtn.BorderThickness = [System.Windows.Thickness]::new(0)
    $closeBtn.Padding    = [System.Windows.Thickness]::new(0)
    $closeBtn.FontSize   = 10
    $closeBtn.Cursor     = [System.Windows.Input.Cursors]::Hand
    $closeBtn.VerticalContentAlignment = 'Center'
    $closeBtn.HorizontalContentAlignment = 'Center'
    $closeBtn.ToolTip    = "Cerrar pestana"
    $sp.Children.Add($closeBtn) | Out-Null

    # Hover en close btn ($this = el propio boton en el handler)
    $closeBtn.Add_MouseEnter({ $this.Foreground = New-WpfBrush $Script:Colors.Danger })
    $closeBtn.Add_MouseLeave({ $this.Foreground = New-WpfBrush $Script:Colors.TextDim })

    # Menú contextual en la cabecera de la pestaña
    $cmTag = [PSCustomObject]@{ Key = "" }
    $tabCM = New-Object System.Windows.Controls.ContextMenu
    $tabCM.Background     = New-WpfBrush $Script:Colors.BgCard
    $tabCM.BorderBrush    = New-WpfBrush $Script:Colors.Border
    $tabCM.BorderThickness = [System.Windows.Thickness]::new(1)
    $tabCM.Padding        = [System.Windows.Thickness]::new(2)
    foreach ($mDef in @(
        @{ H="Cerrar";             A="Close"      },
        @{ H="Cerrar las demas";   A="CloseOther" },
        @{ H="Cerrar todas";       A="CloseAll"   },
        @{ H="-";                  A="-"          },
        @{ H="Copiar ruta";        A="CopyPath"   }
    )) {
        if ($mDef.A -eq "-") { $tabCM.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null }
        else {
            $mi = New-Object System.Windows.Controls.MenuItem
            $mi.Header     = $mDef.H
            $mi.Foreground = New-WpfBrush $Script:Colors.Text
            $mi.Background = New-WpfBrush $Script:Colors.BgCard
            $mi.FontSize   = 12
            $mi.Tag        = [PSCustomObject]@{ Action=$mDef.A; CMTag=$cmTag }
            $mi.Add_Click({
                param($s, $e)
                $ctx = $s.Tag
                $key = $ctx.CMTag.Key
                switch ($ctx.Action) {
                    "Close"      { if ($key) { Close-Tab $key } }
                    "CloseOther" {
                        $toClose = @($Script:OpenTabs.Keys | Where-Object { $_ -ne $key })
                        foreach ($k in $toClose) { Close-Tab $k }
                    }
                    "CloseAll"   { Close-AllTabs }
                    "CopyPath"   { if ($key) { [System.Windows.Clipboard]::SetText($key) } }
                }
            })
            $tabCM.Items.Add($mi) | Out-Null
        }
    }
    $sp.ContextMenu = $tabCM

    return @{ Panel=$sp; CloseBtn=$closeBtn; TitleBlock=$titleTB; CMTag=$cmTag }
}

# ── Menú contextual en filas de DataGrid ──────────────────────────────

function Add-DataGridRowContextMenu {
    param(
        [System.Windows.Controls.DataGrid]$DG,
        [string]$FilePath = ""
    )

    # Seleccionar la fila bajo el cursor en click derecho
    $DG.Add_PreviewMouseRightButtonDown({
        param($sender, $e)
        $elem = $e.OriginalSource -as [System.Windows.DependencyObject]
        while ($null -ne $elem) {
            if ($elem -is [System.Windows.Controls.DataGridRow]) {
                $sender.SelectedItem = $elem.Item
                break
            }
            try { $elem = [System.Windows.Media.VisualTreeHelper]::GetParent($elem) }
            catch { break }
        }
    })

    $cmTag = [PSCustomObject]@{ DG=$DG; FilePath=$FilePath }
    $rowCM = New-Object System.Windows.Controls.ContextMenu
    $rowCM.Background      = New-WpfBrush $Script:Colors.BgCard
    $rowCM.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $rowCM.BorderThickness = [System.Windows.Thickness]::new(1)
    $rowCM.Padding         = [System.Windows.Thickness]::new(2)
    $DG.ContextMenu   = $rowCM

    foreach ($mDef in @(
        @{ H="Copiar fila";               A="Copy"     },
        @{ H="-";                         A="-"        },
        @{ H="Anadir marcador en fila...";A="Bookmark" },
        @{ H="Escanear IOCs en fila";     A="IOC"      }
    )) {
        if ($mDef.A -eq "-") { $rowCM.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null }
        else {
            $mi = New-Object System.Windows.Controls.MenuItem
            $mi.Header     = $mDef.H
            $mi.Foreground = New-WpfBrush $Script:Colors.Text
            $mi.Background = New-WpfBrush $Script:Colors.BgCard
            $mi.FontSize   = 12
            $mi.Tag        = [PSCustomObject]@{ Action=$mDef.A; CMTag=$cmTag }
            $mi.Add_Click({
                param($s, $e)
                $ctx     = $s.Tag
                $dg      = $ctx.CMTag.DG
                $item    = $dg.SelectedItem
                if ($null -eq $item) { return }

                $tbl     = $dg.Tag -as [System.Data.DataTable]
                $rowView = $item -as [System.Data.DataRowView]
                $rowPath = $ctx.CMTag.FilePath
                $lineNum = 0
                $colName = ""
                $colVal  = ""

                if ($rowView -and $tbl) {
                    if ($tbl.Columns.Contains('Ruta')) {
                        $candidate = $rowView['Ruta'] -as [string]
                        if (-not [string]::IsNullOrEmpty($candidate)) { $rowPath = $candidate }
                    }
                    foreach ($lnCol in @('Linea','LineNumber','Line')) {
                        if ($tbl.Columns.Contains($lnCol)) {
                            $lv = 0
                            if ([int]::TryParse($rowView[$lnCol].ToString(), [ref]$lv) -and $lv -gt 0) {
                                $lineNum = $lv; break
                            }
                        }
                    }
                    foreach ($cc in @('Contenido','Message','Descripcion','Context','Match')) {
                        if ($tbl.Columns.Contains($cc)) {
                            $cv = $rowView[$cc] -as [string]
                            if (-not [string]::IsNullOrEmpty($cv)) {
                                $colName = $cc
                                $colVal  = if ($cv.Length -gt 120) { $cv.Substring(0,120) } else { $cv }
                                break
                            }
                        }
                    }
                }

                # Fallback: usar índice en DataTable como número de línea único por fila
                if ($lineNum -eq 0 -and $rowView -and $tbl) {
                    $lineNum = $tbl.Rows.IndexOf($rowView.Row) + 1
                }
                # Fallback: si no hay columna de contexto, usar la primera columna con valor
                if ([string]::IsNullOrEmpty($colName) -and $rowView -and $tbl) {
                    foreach ($col in $tbl.Columns) {
                        $cv = $rowView[$col.ColumnName] -as [string]
                        if (-not [string]::IsNullOrEmpty($cv)) {
                            $colName = $col.ColumnName
                            $colVal  = if ($cv.Length -gt 120) { $cv.Substring(0,120) } else { $cv }
                            break
                        }
                    }
                }

                switch ($ctx.Action) {
                    "Copy" {
                        if ($rowView) {
                            $vals = $rowView.Row.ItemArray | ForEach-Object { $_.ToString() }
                            [System.Windows.Clipboard]::SetText($vals -join "`t")
                        }
                    }
                    "Bookmark" {
                        Show-AddBookmarkDialog -FilePath   $rowPath `
                                               -LineNumber $lineNum `
                                               -ColumnName $colName `
                                               -CellValue  $colVal
                    }
                    "IOC" {
                        if (-not [string]::IsNullOrEmpty($rowPath) -and (Test-Path $rowPath)) {
                            Invoke-SingleFileIOCScan -FilePath $rowPath
                        }
                    }
                }
            })
            $rowCM.Items.Add($mi) | Out-Null
        }
    }
}

# ── Abrir archivo en pestana ───────────────────────────────────────────

function Open-FileInTab {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        Set-Status "Archivo no encontrado: $FilePath"
        return
    }

    # Si ya esta abierto, activar esa pestana
    if ($Script:OpenTabs.ContainsKey($FilePath)) {
        $Script:TNControls.TabsMain.SelectedItem = $Script:OpenTabs[$FilePath]
        return
    }

    $filename   = [System.IO.Path]::GetFileName($FilePath)
    $viewerType = Get-FileViewerType $FilePath
    $ext        = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $icon       = if ($Script:FileIcons.ContainsKey($ext)) { $Script:FileIcons[$ext] } else { $Script:FileIcons["default"] }

    Set-Status "Cargando $filename..."

    # Crear contenido del viewer
    $content = switch ($viewerType) {
        "CSV"   { New-CSVViewerContent  -FilePath $FilePath }
        "MFT"   { New-MFTViewerContent  -FilePath $FilePath }
        "EVTX"  { New-EVTXViewerContent -FilePath $FilePath }
        "JSON"  { New-JSONViewerContent -FilePath $FilePath }
        "Text"  { New-TextViewerContent -FilePath $FilePath }
        "HTML"  { New-HTMLViewerContent -FilePath $FilePath }
        "Hex"   { New-HexViewerContent  -FilePath $FilePath }
        default { New-TextViewerContent -FilePath $FilePath }
    }

    # Crear TabItem
    $tab = New-Object System.Windows.Controls.TabItem
    $headerParts = New-TabHeader -Title $filename -Icon $icon
    $tab.Header  = $headerParts.Panel
    $headerParts.CMTag.Key = $FilePath

    # Boton cerrar: guardar path en Tag del boton, leer con $this.Tag
    $headerParts.CloseBtn.Tag = $FilePath
    $headerParts.CloseBtn.Add_Click({
        Close-Tab ($this.Tag -as [string])
    })

    $tab.Content = $content
    $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
    $Script:TNControls.TabsMain.SelectedItem = $tab
    $Script:OpenTabs[$FilePath] = $tab

    Show-EmptyState $false
    Set-Status "$filename  ·  $viewerType" "$(($Script:OpenTabs.Keys).Count) pestanas abiertas"
}

function Close-Tab {
    param([string]$FilePath)
    if (-not $Script:OpenTabs.ContainsKey($FilePath)) { return }
    $tab = $Script:OpenTabs[$FilePath]
    $Script:TNControls.TabsMain.Items.Remove($tab)
    $Script:OpenTabs.Remove($FilePath)

    if ($Script:OpenTabs.Count -eq 0) {
        Show-EmptyState $true
        Set-Status "Listo" ""
    } else {
        Set-Status "$(($Script:OpenTabs.Keys).Count) pestanas abiertas" ""
    }
}

function Close-AllTabs {
    $paths = @($Script:OpenTabs.Keys)
    foreach ($p in $paths) { Close-Tab $p }
}

# ── Viewers simples (HTML y Hex) ───────────────────────────────────────

function New-HTMLViewerContent {
    param([string]$FilePath)
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.HorizontalAlignment = 'Center'
    $sp.VerticalAlignment   = 'Center'

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text       = "Informe HTML"
    $lbl.FontSize   = 18
    $lbl.Foreground = New-WpfBrush $Script:Colors.Accent
    $lbl.TextAlignment = 'Center'
    $lbl.Margin     = [System.Windows.Thickness]::new(0,0,0,12)
    $sp.Children.Add($lbl) | Out-Null

    $info = New-Object System.Windows.Controls.TextBlock
    $info.Text       = [System.IO.Path]::GetFileName($FilePath)
    $info.FontSize   = 12
    $info.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $info.TextAlignment = 'Center'
    $info.Margin     = [System.Windows.Thickness]::new(0,0,0,20)
    $sp.Children.Add($info) | Out-Null

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "Abrir en navegador"
    $btn.Padding = [System.Windows.Thickness]::new(16,8,16,8)
    $btn.Background  = New-WpfBrush $Script:Colors.Accent
    $btn.Foreground  = [System.Windows.Media.Brushes]::White
    $btn.BorderBrush = New-WpfBrush $Script:Colors.AccentDark
    $btn.FontSize    = 13
    $btn.Cursor      = [System.Windows.Input.Cursors]::Hand
    # BUG CONFIRMADO (verificado empiricamente): $capturedPath es local a esta
    # funcion; copiarla a otro nombre de variable NO la convierte en closure,
    # el scriptblock se invoca tras retornar la funcion y $capturedPath es
    # $null en ese momento -> Start-Process $null lanza una excepcion no
    # controlada (sin try/catch, sin manejador global) que puede tumbar toda
    # la aplicacion al abrir cualquier informe HTML. Se guarda en .Tag, que
    # SI viaja con el control con independencia del scope que lo creo.
    $btn.Tag = $FilePath
    $btn.Add_Click({
        param($s, $e)
        try { Start-Process $s.Tag } catch { Set-Status "No se pudo abrir en el navegador: $($_.Exception.Message)" "" }
    })
    $sp.Children.Add($btn) | Out-Null

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    $outer.Children.Add($sp) | Out-Null
    return $outer
}

function New-HexViewerContent {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    foreach ($h in @([System.Windows.GridLength]::Auto,
                     [System.Windows.GridLength]::Auto,
                     [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star),
                     [System.Windows.GridLength]::Auto)) {
        $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = $h
        $outer.RowDefinitions.Add($rd)
    }

    $size = if (Test-Path $FilePath) { Format-FileSize (Get-Item $FilePath).Length } else { "?" }
    $fileLen = if (Test-Path $FilePath) { (Get-Item $FilePath).Length } else { 0 }

    # Header
    $header = New-Object System.Windows.Controls.Border
    $header.Background      = New-WpfBrush $Script:Colors.BgCard
    $header.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $header.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $header.Padding         = [System.Windows.Thickness]::new(12,7,12,7)
    $hDP = New-Object System.Windows.Controls.DockPanel; $hDP.LastChildFill = $false
    $hTitle = New-Object System.Windows.Controls.TextBlock
    $hTitle.Text = "$([System.IO.Path]::GetFileName($FilePath))  ·  $size  ·  Hex Viewer"
    $hTitle.Foreground = New-WpfBrush $Script:Colors.Text; $hTitle.FontSize = 12
    $hTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
    $hTitle.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($hTitle, 'Left')
    $hDP.Children.Add($hTitle) | Out-Null
    $header.Child = $hDP
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    $outer.Children.Add($header) | Out-Null

    # Toolbar: offset + search
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgPanel
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(10,5,10,5)
    $tbSP = New-Object System.Windows.Controls.StackPanel; $tbSP.Orientation = 'Horizontal'

    foreach ($lbl in @("Ir a offset (hex):","  Buscar texto:")) {
        $l = New-Object System.Windows.Controls.TextBlock; $l.Text = $lbl
        $l.Foreground = New-WpfBrush $Script:Colors.TextMuted; $l.FontSize = 11
        $l.VerticalAlignment = 'Center'; $l.Margin = [System.Windows.Thickness]::new(0,0,6,0)
        $tbSP.Children.Add($l) | Out-Null
        $box = New-Object System.Windows.Controls.TextBox
        $box.Width = 110; $box.Height = 24
        $box.Background = New-WpfBrush $Script:Colors.BgSurface
        $box.Foreground = New-WpfBrush $Script:Colors.Text
        $box.CaretBrush = [System.Windows.Media.Brushes]::White
        $box.BorderBrush = New-WpfBrush $Script:Colors.Border
        $box.Padding = [System.Windows.Thickness]::new(6,2,6,2); $box.FontSize = 11
        $box.Margin = [System.Windows.Thickness]::new(0,0,12,0)
        $tbSP.Children.Add($box) | Out-Null
    }

    $btnCopy = New-Object System.Windows.Controls.Button
    $btnCopy.Content = "Copiar vista"; $btnCopy.Height = 24
    $btnCopy.Padding = [System.Windows.Thickness]::new(8,2,8,2)
    $btnCopy.Background = New-WpfBrush $Script:Colors.BgSurface
    $btnCopy.Foreground = New-WpfBrush $Script:Colors.Text
    $btnCopy.BorderBrush = New-WpfBrush $Script:Colors.Border
    $btnCopy.FontSize = 11; $btnCopy.Cursor = [System.Windows.Input.Cursors]::Hand
    $tbSP.Children.Add($btnCopy) | Out-Null

    $toolbar.Child = $tbSP
    [System.Windows.Controls.Grid]::SetRow($toolbar, 1)
    $outer.Children.Add($toolbar) | Out-Null

    # Hex content
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility   = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Auto'
    $scroll.Background = New-WpfBrush $Script:Colors.BgPrimary

    $monoFont = New-Object System.Windows.Media.FontFamily("Cascadia Code, Consolas, Courier New")
    $hexText = New-Object System.Windows.Controls.TextBlock
    $hexText.FontFamily = $monoFont; $hexText.FontSize = 11
    $hexText.Foreground = New-WpfBrush $Script:Colors.Text
    $hexText.Padding    = [System.Windows.Thickness]::new(14,10,14,10)
    $hexText.TextWrapping = 'NoWrap'; $hexText.VerticalAlignment = 'Top'

    $maxBytes = 65536  # 64 KB display limit
    $allHexLines = [System.Collections.Generic.List[string]]::new()
    try {
        $fs = [System.IO.File]::OpenRead($FilePath)
        $buf = [byte[]]::new([Math]::Min($maxBytes, $fs.Length))
        $read = $fs.Read($buf, 0, $buf.Length)
        $fs.Close()
        for ($i = 0; $i -lt $read; $i += 16) {
            $end   = [Math]::Min($i + 15, $read - 1)
            $chunk = $buf[$i..$end]
            $hex   = ($chunk | ForEach-Object { "{0:X2}" -f $_ }) -join " "
            $ascii = -join ($chunk | ForEach-Object { if ($_ -ge 32 -and $_ -le 126) { [char]$_ } else { "." } })
            $allHexLines.Add(("{0:X8}  {1,-47}  {2}" -f $i, $hex, $ascii))
        }
        $truncNote = if ($fileLen -gt $maxBytes) { "`n`n... ($size total — mostrando primeros 64 KB)" } else { "" }
        $hexText.Text = ($allHexLines -join "`n") + $truncNote
    } catch {
        $hexText.Text = "Error al leer el fichero: $_"
    }

    $scroll.Content = $hexText
    [System.Windows.Controls.Grid]::SetRow($scroll, 2)
    $outer.Children.Add($scroll) | Out-Null

    # Status
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLbl = New-Object System.Windows.Controls.TextBlock
    $statusLbl.Text = "Fichero binario  ·  $size  ·  $($allHexLines.Count) lineas"
    $statusLbl.Foreground = New-WpfBrush $Script:Colors.TextMuted; $statusLbl.FontSize = 11
    $statusBar.Child = $statusLbl
    [System.Windows.Controls.Grid]::SetRow($statusBar, 3)
    $outer.Children.Add($statusBar) | Out-Null

    # Toolbar interactions (offset + search + copy) — state in Tag
    $offsetBox = $tbSP.Children | Where-Object { $_ -is [System.Windows.Controls.TextBox] } | Select-Object -First 1
    $searchBox = $tbSP.Children | Where-Object { $_ -is [System.Windows.Controls.TextBox] } | Select-Object -Last 1

    $offsetBox.Tag = [PSCustomObject]@{ Scroll=$scroll; HexText=$hexText; Lines=$allHexLines; Status=$statusLbl }
    $offsetBox.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -ne 'Return') { return }
        $ctx = $sender.Tag
        $hexStr = $sender.Text.Trim() -replace "^0x",""
        $offset = 0
        if ([int64]::TryParse($hexStr, [System.Globalization.NumberStyles]::HexNumber, $null, [ref]$offset)) {
            $lineIdx = [int]($offset / 16)
            if ($lineIdx -ge 0 -and $lineIdx -lt $ctx.Lines.Count) {
                $approxY = $lineIdx * 17.0
                $ctx.Scroll.ScrollToVerticalOffset($approxY)
                $ctx.Status.Text = "Offset: 0x$('{0:X8}' -f $offset)  ·  Linea $($lineIdx+1)"
            }
        }
    })

    $searchBox.Tag = [PSCustomObject]@{ HexText=$hexText; Lines=$allHexLines; Status=$statusLbl; Scroll=$scroll }
    $searchBox.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -ne 'Return') { return }
        $ctx = $sender.Tag
        $q = $sender.Text.Trim()
        if ([string]::IsNullOrEmpty($q)) { return }
        $idx = -1
        for ($i = 0; $i -lt $ctx.Lines.Count; $i++) {
            if ($ctx.Lines[$i] -match [regex]::Escape($q)) { $idx = $i; break }
        }
        if ($idx -ge 0) {
            $ctx.Scroll.ScrollToVerticalOffset($idx * 17.0)
            $ctx.Status.Text = "Encontrado en linea $($idx+1)  ·  Offset 0x$('{0:X8}' -f ($idx*16))"
        } else {
            $ctx.Status.Text = "No encontrado: '$q'"
        }
    })

    $btnCopy.Tag = $hexText
    $btnCopy.Add_Click({
        param($sender, $e)
        $t = ($sender.Tag -as [System.Windows.Controls.TextBlock])
        if ($t) { [System.Windows.Clipboard]::SetText($t.Text) }
    })

    return $outer
}

# ── Cargar proyecto en el arbol ────────────────────────────────────────

function Load-ProjectTree {
    param([string]$ProjectPath)

    $ctrl = $Script:TNControls
    $ctrl.ProjectTree.Items.Clear()
    $ctrl.TxtProjectLabel.Text       = "Cargando proyecto..."
    $ctrl.TxtProjectLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    Set-Status "Cargando proyecto..." ""

    # Toda la E/S de disco en un runspace de fondo para no bloquear el hilo UI
    $bgScript = {
        param($projectPath, $swPhaseNames)

        $meta = [ordered]@{
            Path          = $projectPath
            Name          = (Split-Path $projectPath -Leaf)
            CaseNumber    = ""
            Examiner      = ""
            StartTime     = ""
            ComputerName  = ""
            HasAN         = $false
            AnomalyCount  = 0
            ArtifactCount = 0
            PhaseCount    = 0
            FileSizeTotal = 0
            PhaseCounts   = @{}
        }

        # Leer session.json (formato ideal, pero NI SW NI OF lo generan hoy -
        # se deja por si una version futura lo escribe; el fallback de abajo
        # con OSInfo.json es el que realmente funciona en la practica).
        foreach ($sf in @(
            (Join-Path $projectPath "Logs\session.json"),
            (Join-Path $projectPath "session.json")
        )) {
            if (Test-Path $sf) {
                try {
                    $s = Get-Content $sf -Raw | ConvertFrom-Json
                    if ($s.CaseNumber)   { $meta.CaseNumber   = $s.CaseNumber   }
                    if ($s.ExaminerName) { $meta.Examiner     = $s.ExaminerName }
                    if ($s.StartTime)    { $meta.StartTime    = $s.StartTime    }
                    if ($s.ComputerName) { $meta.ComputerName = $s.ComputerName }
                } catch {}
                break
            }
        }

        # Fallback: ComputerName desde OSInfo.json (SW: NombreEquipo, OF: CSName).
        # Sin esto, ComputerName queda vacio en TODOS los casos reales pese a que
        # el dato si esta disponible en el propio proyecto.
        if ([string]::IsNullOrEmpty($meta.ComputerName)) {
            $osInfoPath = Join-Path $projectPath "02_SystemInfo\OSInfo.json"
            if (Test-Path $osInfoPath) {
                try {
                    $osInfo = Get-Content $osInfoPath -Raw | ConvertFrom-Json
                    if ($osInfo.NombreEquipo)   { $meta.ComputerName = $osInfo.NombreEquipo }
                    elseif ($osInfo.CSName)     { $meta.ComputerName = $osInfo.CSName }
                } catch {}
            }
        }

        # Perito: de la portada del informe pericial de SW ("Perito") u OF ("Perito
        # Informatico"). Antes solo se buscaba en session.json, que no existe, y el
        # Dashboard nunca mostraba el perito.
        if ([string]::IsNullOrEmpty($meta.Examiner)) {
            $repPath = Join-Path $projectPath "Report\InformePericial.html"
            if (Test-Path $repPath) {
                try {
                    $rep = Get-Content $repPath -Raw -ErrorAction Stop
                    if ($rep -match "<label>Perito(?: Informatico)?</label>\s*<span>([^<]{1,80})</span>") {
                        $meta.Examiner = [System.Net.WebUtility]::HtmlDecode($Matches[1].Trim())
                    }
                } catch {}
            }
        }

        # Numero de caso del nombre del directorio (OF: "MaPeriT_OF_<caso>_<fecha>")
        if ([string]::IsNullOrEmpty($meta.CaseNumber)) {
            $dirName = Split-Path $projectPath -Leaf
            if ($dirName -match '^MaPeriT_(?:OF_)?(.+?)_\d{8}') { $meta.CaseNumber = $Matches[1] }
        }

        # Fases y modulo AN
        $meta.PhaseCount = @($swPhaseNames.Keys | Where-Object { Test-Path (Join-Path $projectPath $_) }).Count
        $meta.HasAN      = Test-Path (Join-Path $projectPath "ANALISIS_AN")

        # Conteo global de artefactos (operacion lenta — se ejecuta en background)
        try {
            $files = @(Get-ChildItem $projectPath -Recurse -Include "*.csv","*.json" -ErrorAction SilentlyContinue)
            $meta.ArtifactCount = $files.Count
            $meta.FileSizeTotal = ($files | Measure-Object -Property Length -Sum).Sum
        } catch {}

        # Anomalias: solo Analysis\Anomalies.csv de SW (ver Get-ProjectMetadata)
        $ap = Join-Path $projectPath "Analysis\Anomalies.csv"
        if (Test-Path $ap) {
            try { $meta.AnomalyCount = @(Import-Csv $ap -ErrorAction SilentlyContinue).Count } catch {}
        }

        # Conteo de ficheros por fase para el dashboard
        foreach ($dirKey in $swPhaseNames.Keys) {
            $phaseDir = Join-Path $projectPath $dirKey
            if (Test-Path $phaseDir) {
                try { $meta.PhaseCounts[$dirKey] = (Get-ChildItem $phaseDir -Recurse -File -ErrorAction SilentlyContinue).Count }
                catch { $meta.PhaseCounts[$dirKey] = 0 }
            }
        }

        # Arbol de navegacion: solo datos (PSObject), sin WPF
        function _TN_ChildNodes {
            param([string]$Path, [int]$Depth)
            if ($Depth -gt 5) { return }
            $nodes = [System.Collections.Generic.List[PSCustomObject]]::new()
            Get-ChildItem $Path -Directory -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
                $node = [PSCustomObject]@{
                    NodeType = "Folder"; Name = $_.Name; Path = $_.FullName
                    Children = [System.Collections.Generic.List[PSCustomObject]]::new()
                }
                foreach ($child in (_TN_ChildNodes $_.FullName ($Depth + 1))) {
                    $node.Children.Add($child) | Out-Null
                }
                $nodes.Add($node) | Out-Null
            }
            Get-ChildItem $Path -File -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
                $nodes.Add([PSCustomObject]@{
                    NodeType = "File"; Name = $_.Name; Path = $_.FullName
                    Ext      = $_.Extension.ToLower(); Size = $_.Length; Children = $null
                }) | Out-Null
            }
            return $nodes
        }

        $treeRoot = [PSCustomObject]@{
            NodeType = "Project"; Name = (Split-Path $projectPath -Leaf); Path = $projectPath
            Children = [System.Collections.Generic.List[PSCustomObject]]::new()
        }

        # Fases conocidas en orden
        foreach ($dirKey in $swPhaseNames.Keys) {
            $fullPath = Join-Path $projectPath $dirKey
            if (-not (Test-Path $fullPath -PathType Container)) { continue }
            $phaseNode = [PSCustomObject]@{
                NodeType = "Phase"; Name = $swPhaseNames[$dirKey]; Path = $fullPath
                Children = [System.Collections.Generic.List[PSCustomObject]]::new()
            }
            foreach ($child in (_TN_ChildNodes $fullPath 0)) {
                $phaseNode.Children.Add($child) | Out-Null
            }
            $treeRoot.Children.Add($phaseNode) | Out-Null
        }

        # Directorios no reconocidos
        $knownDirs = @($swPhaseNames.Keys)
        Get-ChildItem $projectPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $knownDirs } | ForEach-Object {
                $node = [PSCustomObject]@{
                    NodeType = "Folder"; Name = $_.Name; Path = $_.FullName
                    Children = [System.Collections.Generic.List[PSCustomObject]]::new()
                }
                foreach ($child in (_TN_ChildNodes $_.FullName 0)) {
                    $node.Children.Add($child) | Out-Null
                }
                $treeRoot.Children.Add($node) | Out-Null
            }

        # Ficheros en la raiz del proyecto
        Get-ChildItem $projectPath -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match '\.(csv|json|html|txt|log)$' } |
            Sort-Object Name | ForEach-Object {
                $treeRoot.Children.Add([PSCustomObject]@{
                    NodeType = "File"; Name = $_.Name; Path = $_.FullName
                    Ext      = $_.Extension.ToLower(); Size = $_.Length; Children = $null
                }) | Out-Null
            }

        Write-Output -NoEnumerate ([PSCustomObject]@{ Meta = $meta; Tree = $treeRoot; Err = "" })
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{
        projectPath  = $ProjectPath
        swPhaseNames = $Script:SW_PhaseNames
    })
    $handle = $ps.BeginInvoke()

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(300)
    $timer.Tag = [PSCustomObject]@{
        Ps          = $ps
        Handle      = $handle
        Rs          = $rs
        ProjectPath = $ProjectPath
    }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag
        if ($ctx.Ps.InvocationStateInfo.State -in 'Completed','Failed','Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                if ($null -eq $obj -or -not [string]::IsNullOrEmpty($obj.Err)) {
                    $errMsg = if ($obj -and $obj.Err) { $obj.Err } else { "Sin respuesta del proceso de carga" }
                    Set-Status "Error cargando proyecto: $errMsg" ""
                    $Script:TNControls.TxtProjectLabel.Text = "Error al cargar"
                    return
                }

                $meta = $obj.Meta
                $Script:CurrentProject = $meta

                $Script:TNControls.TxtProjectLabel.Text       = if ($meta.CaseNumber) { "Caso $($meta.CaseNumber)" } else { $meta.Name }
                $Script:TNControls.TxtProjectLabel.Foreground = New-WpfBrush $Script:Colors.Text

                Initialize-Bookmarks -ProjectPath $ctx.ProjectPath

                # Dashboard
                $dashKey = "__dashboard__$($ctx.ProjectPath)"
                if (-not $Script:OpenTabs.ContainsKey($dashKey)) {
                    $dashContent = New-DashboardContent -Meta $meta
                    $tab = New-Object System.Windows.Controls.TabItem
                    $headerParts = New-TabHeader -Title "Dashboard" -Icon "⊞"
                    $tab.Header  = $headerParts.Panel
                    $headerParts.CMTag.Key = $dashKey
                    $tab.Content = $dashContent
                    $Script:TNControls.TabsMain.Items.Insert(0, $tab)
                    $Script:TNControls.TabsMain.SelectedItem = $tab
                    $Script:OpenTabs[$dashKey] = $tab
                    $headerParts.CloseBtn.Tag = $dashKey
                    $headerParts.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
                    Show-EmptyState $false
                }

                # Construir arbol (solo operaciones WPF, datos ya calculados en background)
                Add-TreeNode -Node $obj.Tree -Control $Script:TNControls.ProjectTree | Out-Null

                Set-Status "Proyecto cargado: $($meta.Name)" "$($meta.PhaseCount) fases  ·  $($meta.ArtifactCount) artefactos"
            } catch {
                Set-Status "Error al procesar proyecto: $($_.Exception.Message)" ""
            } finally {
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
}

function Add-TreeNode {
    param($Node, $Control)

    $item = New-Object System.Windows.Controls.TreeViewItem

    # Header
    $headerSP = New-Object System.Windows.Controls.StackPanel
    $headerSP.Orientation = 'Horizontal'

    $iconTB = New-Object System.Windows.Controls.TextBlock
    $iconTB.Margin    = [System.Windows.Thickness]::new(0,0,5,0)
    $iconTB.FontSize  = 11
    $iconTB.VerticalAlignment = 'Center'

    $nameTB = New-Object System.Windows.Controls.TextBlock
    $nameTB.VerticalAlignment = 'Center'
    $nameTB.FontSize  = 12

    switch ($Node.NodeType) {
        "Project" {
            $iconTB.Text       = "P"
            $iconTB.Foreground = New-WpfBrush $Script:Colors.Accent
            $nameTB.Text       = $Node.Name
            $nameTB.FontWeight = [System.Windows.FontWeights]::SemiBold
            $nameTB.Foreground = New-WpfBrush $Script:Colors.Text
            $item.IsExpanded   = $true
        }
        "Phase" {
            $iconTB.Text       = "F"
            $iconTB.Foreground = New-WpfBrush $Script:Colors.Accent
            $nameTB.Text       = $Node.Name
            $nameTB.FontWeight = [System.Windows.FontWeights]::SemiBold
            $nameTB.Foreground = New-WpfBrush $Script:Colors.Text
            $item.IsExpanded   = $false
        }
        "Folder" {
            $iconTB.Text       = "+"
            $iconTB.Foreground = New-WpfBrush $Script:Colors.TextMuted
            $nameTB.Text       = $Node.Name
            $nameTB.Foreground = New-WpfBrush $Script:Colors.TextMuted
            $item.IsExpanded   = $false
        }
        "File" {
            $ext = $Node.Ext
            $iconTB.Text       = if ($Script:FileIcons.ContainsKey($ext)) { $Script:FileIcons[$ext] } else { $Script:FileIcons["default"] }
            $iconColor = switch ($ext) {
                ".csv"  { $Script:Colors.Success   }
                ".json" { $Script:Colors.Warning   }
                ".evtx" { $Script:Colors.Danger    }
                ".html" { $Script:Colors.Info      }
                default { $Script:Colors.TextMuted }
            }
            $iconTB.Foreground = New-WpfBrush $iconColor
            $nameTB.Text       = $Node.Name
            $nameTB.Foreground = New-WpfBrush $Script:Colors.Text
            $item.Cursor = [System.Windows.Input.Cursors]::Hand

            $item.Add_Selected({
                param($s, $e)
                $path = $s.Tag -as [string]
                if (-not [string]::IsNullOrEmpty($path)) {
                    $e.Handled = $true
                    Open-FileInTab -FilePath $path
                }
            })
            $item.Add_KeyDown({
                param($s, $e)
                if ($e.Key -eq 'Return') {
                    $path = $s.Tag -as [string]
                    if (-not [string]::IsNullOrEmpty($path)) {
                        $e.Handled = $true
                        Open-FileInTab -FilePath $path
                    }
                }
            })

            # Menú contextual
            $cm = New-Object System.Windows.Controls.ContextMenu
            $cm.Background      = New-WpfBrush $Script:Colors.BgCard
            $cm.BorderBrush     = New-WpfBrush $Script:Colors.Border
            $cm.BorderThickness = [System.Windows.Thickness]::new(1)
            $cm.Padding         = [System.Windows.Thickness]::new(2)
            foreach ($menuDef in @(
                @{ Header="Abrir en pestana";          Tag="Open"      },
                @{ Header="Anadir marcador...";        Tag="Bookmark"  },
                @{ Header="Escanear IOCs en fichero";  Tag="IOC"       },
                @{ Header="-"; Tag="-" },
                @{ Header="Copiar ruta";               Tag="CopyPath"  },
                @{ Header="Abrir ubicacion";           Tag="Explorer"  }
            )) {
                if ($menuDef.Tag -eq "-") {
                    $cm.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null
                } else {
                    $mi = New-Object System.Windows.Controls.MenuItem
                    $mi.Header     = $menuDef.Header
                    $mi.Foreground = New-WpfBrush $Script:Colors.Text
                    $mi.Background = New-WpfBrush $Script:Colors.BgCard
                    $mi.FontSize   = 12
                    $mi.Tag        = [PSCustomObject]@{ Action=$menuDef.Tag; ItemTag=$item }
                    $mi.Add_Click({
                        param($s, $e)
                        $ctx  = $s.Tag
                        $path = $ctx.ItemTag.Tag -as [string]
                        if ([string]::IsNullOrEmpty($path)) { return }
                        switch ($ctx.Action) {
                            "Open"     { Open-FileInTab -FilePath $path }
                            "Bookmark" { Show-AddBookmarkDialog -FilePath $path }
                            "IOC"      { Invoke-SingleFileIOCScan -FilePath $path }
                            "CopyPath" { [System.Windows.Clipboard]::SetText($path) }
                            "Explorer" { Start-Process "explorer.exe" "/select,`"$path`"" }
                        }
                    })
                    $cm.Items.Add($mi) | Out-Null
                }
            }
            $item.ContextMenu = $cm
        }
    }

    $headerSP.Children.Add($iconTB) | Out-Null
    $headerSP.Children.Add($nameTB) | Out-Null
    $item.Header = $headerSP
    $item.Tag    = $Node.Path

    # Tooltip con tamano para ficheros
    if ($Node.NodeType -eq "File" -and $Node.Size -gt 0) {
        $item.ToolTip = "$($Node.Name)`n$(Format-FileSize $Node.Size)`n$($Node.Path)"
    }

    # Agregar hijos
    if ($Node.Children -and $Node.Children.Count -gt 0) {
        foreach ($child in $Node.Children) {
            $childItem = Add-TreeNode -Node $child -Control $null
            $item.Items.Add($childItem) | Out-Null
        }
    }

    if ($null -ne $Control) { $Control.Items.Add($item) | Out-Null }
    return $item
}

# ── Filtro del arbol ───────────────────────────────────────────────────

function Apply-TreeFilter {
    param([string]$Filter, [System.Windows.Controls.ItemsControl]$Container)

    $anyVisible = $false
    foreach ($item in $Container.Items) {
        $tvi = $item -as [System.Windows.Controls.TreeViewItem]
        if ($null -eq $tvi) { continue }

        $node = $tvi.Tag -as [string]
        $headerText = ""
        try {
            $sp = $tvi.Header -as [System.Windows.Controls.StackPanel]
            if ($sp) {
                $headerText = ($sp.Children | Where-Object { $_ -is [System.Windows.Controls.TextBlock] } |
                    Select-Object -Last 1).Text
            }
        } catch {}

        $childVisible = Apply-TreeFilter -Filter $Filter -Container $tvi
        $selfMatch    = [string]::IsNullOrEmpty($Filter) -or ($headerText -match [regex]::Escape($Filter))

        $tvi.Visibility = if ($selfMatch -or $childVisible) { 'Visible' } else { 'Collapsed' }
        if ($tvi.Visibility -eq 'Visible') { $anyVisible = $true }
        if ($childVisible -and -not [string]::IsNullOrEmpty($Filter)) { $tvi.IsExpanded = $true }
    }
    return $anyVisible
}

# ── Busqueda global (multi-formato) ────────────────────────────────────

function Invoke-GlobalSearch {
    param([string]$Query)
    if ([string]::IsNullOrWhiteSpace($Query)) { return }
    if ($null -eq $Script:CurrentProject) { Set-Status "Abre un proyecto para usar la busqueda global"; return }

    Set-Status "Buscando '$Query' en todo el proyecto..."

    $searchKey = "__search__$Query"
    if ($Script:OpenTabs.ContainsKey($searchKey)) {
        $Script:TNControls.TabsMain.Items.Remove($Script:OpenTabs[$searchKey])
        $Script:OpenTabs.Remove($searchKey)
    }

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    foreach ($h in @([System.Windows.GridLength]::Auto,
                     [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star),
                     [System.Windows.GridLength]::Auto)) {
        $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = $h
        $outer.RowDefinitions.Add($rd)
    }

    $banner = New-Object System.Windows.Controls.Border
    $banner.Background      = New-WpfBrush $Script:Colors.BgCard
    $banner.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $banner.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $banner.Padding         = [System.Windows.Thickness]::new(10,7,10,7)
    $bannerLbl = New-Object System.Windows.Controls.TextBlock
    $bannerLbl.Text       = "Busqueda: '$Query'  ·  Buscando en CSV, JSON, TXT, LOG..."
    $bannerLbl.Foreground = New-WpfBrush $Script:Colors.Text
    $bannerLbl.FontSize   = 12
    $banner.Child = $bannerLbl
    [System.Windows.Controls.Grid]::SetRow($banner, 0)
    $outer.Children.Add($banner) | Out-Null

    $dg = New-Object System.Windows.Controls.DataGrid
    $dg.IsReadOnly = $true; $dg.AutoGenerateColumns = $false
    $dg.SelectionMode = 'Extended'; $dg.SelectionUnit = 'FullRow'
    $dg.EnableRowVirtualization = $true
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($dg, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($dg, [System.Windows.Controls.VirtualizationMode]::Recycling)
    Apply-DataGridDarkTheme $dg
    Add-DataGridRowContextMenu -DG $dg -FilePath ($Script:CurrentProject.Path)
    foreach ($cd in @(
        @{ H="Tipo";     B="Tipo";      W=55  },
        @{ H="Fichero";  B="Fichero";   W=200 },
        @{ H="Linea";    B="Linea";     W=55  },
        @{ H="Contenido";B="Contenido"; W=600 }
    )) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header = $cd.H; $col.Binding = New-Object System.Windows.Data.Binding($cd.B); $col.Width = $cd.W
        $dg.Columns.Add($col) | Out-Null
    }
    [System.Windows.Controls.Grid]::SetRow($dg, 1)
    $outer.Children.Add($dg) | Out-Null

    # BUG CONFIRMADO: $dg es local a esta funcion (closure rota, igual que el
    # resto de bugs de este fichero) - usar $s (el sender, que WPF entrega
    # vivo en cada invocacion con independencia del scope de creacion) en vez
    # de la variable local capturada.
    $dg.Add_MouseDoubleClick({
        param($s, $e)
        $item = $s.SelectedItem -as [System.Data.DataRowView]
        if ($item) {
            $ruta = $item['Ruta'] -as [string]
            if ($ruta -and (Test-Path $ruta)) { Open-FileInTab -FilePath $ruta }
        }
    })

    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLbl = New-Object System.Windows.Controls.TextBlock
    $statusLbl.Text = "Buscando..."; $statusLbl.Foreground = New-WpfBrush $Script:Colors.TextMuted; $statusLbl.FontSize = 11
    $statusBar.Child = $statusLbl
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    $overlay = New-LoadingOverlay -Message "Buscando '$Query'..." -RowSpan 3
    $outer.Children.Add($overlay) | Out-Null

    # Abrir pestaña de búsqueda antes del resultado (UX inmediato)
    $tab = New-Object System.Windows.Controls.TabItem
    $headerParts = New-TabHeader -Title "Busqueda: $Query" -Icon "S"
    $tab.Header = $headerParts.Panel; $tab.Content = $outer
    $headerParts.CMTag.Key = $searchKey
    $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
    $Script:TNControls.TabsMain.SelectedItem = $tab
    $Script:OpenTabs[$searchKey] = $tab
    $headerParts.CloseBtn.Tag = $searchKey
    $headerParts.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
    Show-EmptyState $false

    # Background search
    $bgScript = {
        param($rootPath, $query)
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        $extensions = @("*.csv","*.json","*.txt","*.log","*.inf","*.xml")
        $files = @(Get-ChildItem $rootPath -Recurse -Include $extensions -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -lt 20MB -and $_.Length -gt 0 })
        $pattern = [regex]::Escape($query)
        foreach ($file in $files) {
            try {
                $hits = Select-String -Path $file.FullName -Pattern $pattern -CaseSensitive:$false -ErrorAction SilentlyContinue
                foreach ($m in $hits) {
                    $line = $m.Line.Trim()
                    if ($line.Length -gt 300) { $line = $line.Substring(0,300) + "..." }
                    $results.Add([PSCustomObject]@{
                        Tipo      = $file.Extension.TrimStart('.').ToUpper()
                        Fichero   = $file.Name
                        Linea     = $m.LineNumber
                        Contenido = $line
                        Ruta      = $file.FullName
                    }) | Out-Null
                }
            } catch {}
        }
        Write-Output -NoEnumerate ([PSCustomObject]@{ Results=$results; FileCount=$files.Count; Err="" })
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{ rootPath=$Script:CurrentProject.Path; query=$Query })
    $handle = $ps.BeginInvoke()

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $timer.Tag = [PSCustomObject]@{
        Ps=$ps; Handle=$handle; Rs=$rs; DG=$dg; Status=$statusLbl
        Banner=$bannerLbl; Overlay=$overlay; Query=$Query
    }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag
        if ($ctx.Ps.InvocationStateInfo.State -in 'Completed','Failed','Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                $tbl = [System.Data.DataTable]::new("Search")
                foreach ($c in @('Tipo','Fichero','Linea','Contenido','Ruta')) { [void]$tbl.Columns.Add($c,[string]) }
                if ($obj -and $obj.Results) {
                    foreach ($r in $obj.Results) {
                        $row = $tbl.NewRow()
                        $row['Tipo']=$r.Tipo; $row['Fichero']=$r.Fichero; $row['Linea']=$r.Linea.ToString()
                        $row['Contenido']=$r.Contenido; $row['Ruta']=$r.Ruta
                        [void]$tbl.Rows.Add($row)
                    }
                }
                $ctx.DG.Tag = $tbl; $ctx.DG.ItemsSource = $tbl.DefaultView
                $ctx.Banner.Text  = "Busqueda: '$($ctx.Query)'  ·  $($tbl.Rows.Count) resultados en $($obj.FileCount) ficheros (CSV, JSON, TXT, LOG)"
                $ctx.Status.Text  = "$($tbl.Rows.Count) coincidencias  ·  Doble clic para abrir el fichero"
                Set-Status "$($tbl.Rows.Count) resultados para '$($ctx.Query)'" ""
            } catch { $ctx.Status.Text = "Error: $($_.Exception.Message)" }
            finally {
                $ctx.Overlay.Visibility = 'Collapsed'
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
}

# ── Escaneo IOC de fichero individual ──────────────────────────────────

function Invoke-SingleFileIOCScan {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) { return }
    Set-Status "Escaneando IOCs: $([System.IO.Path]::GetFileName($FilePath))..."

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $patternMap = [ordered]@{
        'EncodedCmd'     = @{ Pattern=$Script:IOCPatterns.EncodedCmd;     Severity='Critical'; Label='Comando codificado'     }
        'SuspiciousPath' = @{ Pattern=$Script:IOCPatterns.SuspiciousPath; Severity='High';     Label='Ruta anomala'           }
        'SuspiciousExe'  = @{ Pattern=$Script:IOCPatterns.SuspiciousExe;  Severity='High';     Label='Ejecutable sospechoso'  }
        'IPv4External'   = @{ Pattern=$Script:IOCPatterns.IPv4External;   Severity='Info';     Label='IP Externa'             }
        'SHA256'         = @{ Pattern=$Script:IOCPatterns.SHA256;          Severity='Info';     Label='Hash SHA256'            }
    }
    try {
        $lines = [System.IO.File]::ReadAllLines($FilePath, [System.Text.Encoding]::UTF8)
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            foreach ($key in $patternMap.Keys) {
                $pm = $patternMap[$key]
                $m = [regex]::Match($line, $pm.Pattern)
                if ($m.Success) {
                    $ctx = $line.Trim(); if ($ctx.Length -gt 250) { $ctx = $ctx.Substring(0,250) }
                    $results.Add([PSCustomObject]@{
                        Severity = $pm.Severity; IOCType = $pm.Label
                        Fichero  = [System.IO.Path]::GetFileName($FilePath)
                        Linea    = $lineNum; Match = $m.Value.Substring(0,[Math]::Min($m.Value.Length,120))
                        Context  = $ctx; Ruta = $FilePath
                    }) | Out-Null
                    break
                }
            }
        }
    } catch {}

    if ($results.Count -eq 0) { Set-Status "Sin IOCs detectados en $([System.IO.Path]::GetFileName($FilePath))"; return }

    $tbl = ConvertTo-DataTable @($results)
    $scanKey = "__iocsingle__$FilePath"
    if ($Script:OpenTabs.ContainsKey($scanKey)) {
        $Script:TNControls.TabsMain.Items.Remove($Script:OpenTabs[$scanKey])
        $Script:OpenTabs.Remove($scanKey)
    }
    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    foreach ($h in @([System.Windows.GridLength]::Auto, [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star))) {
        $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = $h; $outer.RowDefinitions.Add($rd)
    }
    $bann = New-Object System.Windows.Controls.Border
    $bann.Background = New-WpfBrush $Script:Colors.BgCard
    $bann.BorderBrush = New-WpfBrush $Script:Colors.Border; $bann.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $bann.Padding = [System.Windows.Thickness]::new(10,7,10,7)
    $bLbl = New-Object System.Windows.Controls.TextBlock
    $bLbl.Text = "IOC: $([System.IO.Path]::GetFileName($FilePath))  ·  $($results.Count) hallazgos"
    $bLbl.Foreground = New-WpfBrush $Script:Colors.Text; $bLbl.FontSize = 12
    $bann.Child = $bLbl; [System.Windows.Controls.Grid]::SetRow($bann, 0); $outer.Children.Add($bann) | Out-Null
    $dg2 = New-Object System.Windows.Controls.DataGrid
    $dg2.IsReadOnly = $true; $dg2.AutoGenerateColumns = $true
    $dg2.SelectionMode = 'Extended'; $dg2.SelectionUnit = 'FullRow'
    # Ancho fijo en columnas auto-generadas - ver comentario extenso en
    # CSVViewer.ps1 (riesgo de crash de WPF con DataGridItemAttachedStorage).
    $dg2.Add_AutoGeneratingColumn({
        param($s, $e)
        $e.Column.Width = New-Object System.Windows.Controls.DataGridLength(160)
    })
    Apply-DataGridDarkTheme $dg2
    Add-DataGridRowContextMenu -DG $dg2 -FilePath $FilePath
    $dg2.ItemsSource = $tbl.DefaultView; $dg2.Tag = $tbl
    [System.Windows.Controls.Grid]::SetRow($dg2, 1); $outer.Children.Add($dg2) | Out-Null
    $tab = New-Object System.Windows.Controls.TabItem
    $hp = New-TabHeader -Title "IOC: $([System.IO.Path]::GetFileName($FilePath))" -Icon "!"
    $tab.Header = $hp.Panel; $tab.Content = $outer
    $hp.CMTag.Key = $scanKey
    $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
    $Script:TNControls.TabsMain.SelectedItem = $tab
    $Script:OpenTabs[$scanKey] = $tab
    $hp.CloseBtn.Tag = $scanKey
    $hp.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
    Show-EmptyState $false
    Set-Status "$($results.Count) IOCs en $([System.IO.Path]::GetFileName($FilePath))" ""
}

# ── Cambio de tema ────────────────────────────────────────────────────

function Switch-Theme {
    $openFiles  = @($Script:OpenTabs.Keys | Where-Object { -not $_.StartsWith('__') })
    $projPath   = if ($Script:CurrentProject) { $Script:CurrentProject.Path } else { $null }

    $Script:TN_RestoreState = [PSCustomObject]@{
        OpenFiles   = $openFiles
        ProjectPath = $projPath
    }

    $Script:OpenTabs       = @{}
    $Script:CurrentProject = $null
    $Script:Bookmarks      = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($Script:TN_Theme -eq 'Dark') {
        $Script:TN_Theme = 'Light'
        $Script:Colors   = $Script:ColorsLight
    } else {
        $Script:TN_Theme = 'Dark'
        $Script:Colors   = $Script:ColorsDark
    }

    $Script:TN_ThemeRestart = $true
    $Script:TNControls.Window.Close()
}

# ── Inicializar ventana ────────────────────────────────────────────────

function Initialize-MainWindow {
    param([System.Windows.Window]$Window)

    # Recopilar controles nombrados
    $Script:TNControls = @{
        Window               = $Window
        BtnOpenProject       = $Window.FindName('BtnOpenProject')
        BtnOpenFile          = $Window.FindName('BtnOpenFile')
        BtnGlobalSearch      = $Window.FindName('BtnGlobalSearch')
        TxtGlobalSearch      = $Window.FindName('TxtGlobalSearch')
        TxtProjectLabel      = $Window.FindName('TxtProjectLabel')
        ProjectTree          = $Window.FindName('ProjectTree')
        TxtTreeFilter        = $Window.FindName('TxtTreeFilter')
        TabsMain             = $Window.FindName('TabsMain')
        GridEmptyState       = $Window.FindName('GridEmptyState')
        PanelLeft            = $Window.FindName('PanelLeft')
        StatusLeft           = $Window.FindName('TxtStatusLeft')
        StatusRight          = $Window.FindName('TxtStatusRight')
        MenuOpenProject      = $Window.FindName('MenuOpenProject')
        MenuOpenFile         = $Window.FindName('MenuOpenFile')
        MenuCloseAll         = $Window.FindName('MenuCloseAll')
        MenuToggleTree       = $Window.FindName('MenuToggleTree')
        MenuRefresh          = $Window.FindName('MenuRefresh')
        MenuExit             = $Window.FindName('MenuExit')
        MenuAbout            = $Window.FindName('MenuAbout')
        MenuIOCScan          = $Window.FindName('MenuIOCScan')
        MenuTimeline         = $Window.FindName('MenuTimeline')
        MenuBookmarks        = $Window.FindName('MenuBookmarks')
        MenuGlobalSearchAll  = $Window.FindName('MenuGlobalSearchAll')
        BtnEmptyProject      = $Window.FindName('BtnEmptyProject')
        BtnEmptyFile         = $Window.FindName('BtnEmptyFile')
        BtnThemeToggle       = $Window.FindName('BtnThemeToggle')
        TxtThemeIcon         = $Window.FindName('TxtThemeIcon')
    }

    $ctrl = $Script:TNControls

    # ── Override de colores de selección del TreeView ────────────────
    # {x:Static SystemColors.*BrushKey} en XamlReader resuelve a null; se hace en código.
    try {
        $hk  = [System.Windows.SystemColors]::HighlightBrushKey
        $htk = [System.Windows.SystemColors]::HighlightTextBrushKey
        $ik  = [System.Windows.SystemColors]::InactiveSelectionHighlightBrushKey
        $itk = [System.Windows.SystemColors]::InactiveSelectionHighlightTextBrushKey
        if ($hk)  { $ctrl.ProjectTree.Resources.Add($hk,  (New-WpfBrush $Script:Colors.SelectionBg)) }
        if ($htk) { $ctrl.ProjectTree.Resources.Add($htk, (New-WpfBrush $Script:Colors.SelectionFg)) }
        if ($ik)  { $ctrl.ProjectTree.Resources.Add($ik,  (New-WpfBrush $Script:Colors.BgSurface))   }
        if ($itk) { $ctrl.ProjectTree.Resources.Add($itk, (New-WpfBrush $Script:Colors.Text))         }
    } catch {}

    # ── Tema: icono inicial y click ──────────────────────────────────
    if ($ctrl.TxtThemeIcon) {
        $ctrl.TxtThemeIcon.Text = if ($Script:TN_Theme -eq 'Dark') { [char]0x2600 } else { [char]0x263D }
    }
    if ($ctrl.BtnThemeToggle) {
        $ctrl.BtnThemeToggle.Add_Click({ Switch-Theme })
    }

    # ── Eventos de botones y menus ──────────────────────────────────

    $openProjectAction = {
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Selecciona el directorio de salida de MaPeriT.SW o MaPeriT.OF"
        if ($dlg.ShowDialog() -eq 'OK') {
            $path = $dlg.SelectedPath
            if (Test-MaPeriTProject $path) {
                Load-ProjectTree -ProjectPath $path
            } else {
                [System.Windows.MessageBox]::Show(
                    "El directorio seleccionado no parece un proyecto de MaPeriT.SW ni de MaPeriT.OF`n`n$path",
                    "MaPeriT.TN", 'OK', 'Warning')
            }
        }
    }

    $openFileAction = {
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Filter = "Todos los soportados|*.csv;*.json;*.evtx;*.log;*.txt;*.html;*.xml;*.bin;*.dat;*.hve|CSV|*.csv|JSON|*.json|EVTX|*.evtx|Texto|*.log;*.txt;*.inf|Todos|*.*"
        $dlg.Title  = "Abrir archivo"
        if ($dlg.ShowDialog() -eq $true) {
            Open-FileInTab -FilePath $dlg.FileName
        }
    }

    $ctrl.BtnOpenProject.Add_Click($openProjectAction)
    $ctrl.BtnOpenFile.Add_Click($openFileAction)
    $ctrl.BtnEmptyProject.Add_Click($openProjectAction)
    $ctrl.BtnEmptyFile.Add_Click($openFileAction)
    $ctrl.MenuOpenProject.Add_Click($openProjectAction)
    $ctrl.MenuOpenFile.Add_Click($openFileAction)

    $ctrl.MenuCloseAll.Add_Click({ Close-AllTabs })

    # BUG CONFIRMADO (verificado empiricamente): $ctrl y $Window son variables
    # LOCALES de Initialize-MainWindow. Estos scriptblocks se invocan tras
    # ShowDialog(), cuando la funcion ya ha retornado y esas variables locales
    # ya no existen en la cadena de scopes - se resuelven a $null sin ningun
    # error visible (el "Salir" no cerraba, el toggle del arbol no hacia nada).
    # $Script:TNControls SI sobrevive porque es scope de script, no de funcion.
    $ctrl.MenuExit.Add_Click({ $Script:TNControls.Window.Close() })

    $ctrl.MenuToggleTree.Add_Click({
        $Script:TNControls.PanelLeft.Visibility = if ($Script:TNControls.MenuToggleTree.IsChecked) { 'Visible' } else { 'Collapsed' }
    })

    $ctrl.MenuRefresh.Add_Click({
        if ($Script:CurrentProject) { Load-ProjectTree -ProjectPath $Script:CurrentProject.Path }
    })

    $ctrl.MenuAbout.Add_Click({
        [System.Windows.MessageBox]::Show(
            "MaPeriT.TN v$($Script:TN_Version)`n`nVisor Forense del Ecosistema MaPeriT`nParte del proyecto MaPeriT de Peritacion Informatica Forense`n`nCompatible con proyectos MaPeriT.SW, MaPeriT.OF y MaPeriT.AN",
            "Acerca de MaPeriT.TN", 'OK', 'Information')
    })

    # ── Modulos de Analisis ──────────────────────────────────────────

    if ($ctrl.MenuIOCScan) {
        $ctrl.MenuIOCScan.Add_Click({
            if ($null -eq $Script:CurrentProject) { Set-Status "Abre un proyecto para escanear IOCs"; return }
            $key = "__iocscan__project"
            if ($Script:OpenTabs.ContainsKey($key)) {
                $Script:TNControls.TabsMain.SelectedItem = $Script:OpenTabs[$key]; return
            }
            $content = New-IOCScanViewerContent -ProjectPath $Script:CurrentProject.Path
            $tab = New-Object System.Windows.Controls.TabItem
            $hp = New-TabHeader -Title "IOC: Proyecto" -Icon "!"
            $tab.Header = $hp.Panel; $tab.Content = $content
            $hp.CMTag.Key = $key
            $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
            $Script:TNControls.TabsMain.SelectedItem = $tab
            $Script:OpenTabs[$key] = $tab
            $hp.CloseBtn.Tag = $key
            $hp.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
            Show-EmptyState $false
        })
    }

    if ($ctrl.MenuTimeline) {
        $ctrl.MenuTimeline.Add_Click({
            if ($null -eq $Script:CurrentProject) { Set-Status "Abre un proyecto para ver la timeline"; return }
            $key = "__timeline__project"
            if ($Script:OpenTabs.ContainsKey($key)) {
                $Script:TNControls.TabsMain.SelectedItem = $Script:OpenTabs[$key]; return
            }
            $content = New-TimelineViewerContent -ProjectPath $Script:CurrentProject.Path
            $tab = New-Object System.Windows.Controls.TabItem
            $hp = New-TabHeader -Title "Timeline" -Icon "T"
            $tab.Header = $hp.Panel; $tab.Content = $content
            $hp.CMTag.Key = $key
            $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
            $Script:TNControls.TabsMain.SelectedItem = $tab
            $Script:OpenTabs[$key] = $tab
            $hp.CloseBtn.Tag = $key
            $hp.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
            Show-EmptyState $false
        })
    }

    if ($ctrl.MenuBookmarks) {
        $ctrl.MenuBookmarks.Add_Click({
            try {
                $key = "__bookmarks__"
                if ($Script:OpenTabs.ContainsKey($key)) {
                    $Script:TNControls.TabsMain.Items.Remove($Script:OpenTabs[$key])
                    $Script:OpenTabs.Remove($key)
                }
                $content = New-BookmarksPanelContent
                $tab = New-Object System.Windows.Controls.TabItem
                $hp = New-TabHeader -Title "Marcadores" -Icon "B"
                $tab.Header = $hp.Panel; $tab.Content = $content
                $hp.CMTag.Key = $key
                $Script:TNControls.TabsMain.Items.Add($tab) | Out-Null
                $Script:TNControls.TabsMain.SelectedItem = $tab
                $Script:OpenTabs[$key] = $tab
                $hp.CloseBtn.Tag = $key
                $hp.CloseBtn.Add_Click({ Close-Tab ($this.Tag -as [string]) })
                Show-EmptyState $false
                Set-Status "$($Script:Bookmarks.Count) marcadores" ""
            } catch {
                Set-Status "Error al abrir marcadores: $($_.Exception.Message)" ""
            }
        })
    }

    if ($ctrl.MenuGlobalSearchAll) {
        $ctrl.MenuGlobalSearchAll.Add_Click({
            if ($null -eq $Script:CurrentProject) { Set-Status "Abre un proyecto para buscar"; return }
            $query = [Microsoft.VisualBasic.Interaction]::InputBox("Texto a buscar:", "Busqueda global", "")
            if (-not [string]::IsNullOrWhiteSpace($query)) { Invoke-GlobalSearch -Query $query }
        })
    }

    # Busqueda global (mismo bug de closure: $ctrl local no sobrevive al retorno de la funcion)
    $ctrl.BtnGlobalSearch.Add_Click({
        Invoke-GlobalSearch -Query $Script:TNControls.TxtGlobalSearch.Text.Trim()
    })
    $ctrl.TxtGlobalSearch.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq 'Return') { Invoke-GlobalSearch -Query $s.Text.Trim() }
    })

    # Filtro del arbol (mismo bug de closure)
    $ctrl.TxtTreeFilter.Add_TextChanged({
        param($s, $e)
        Apply-TreeFilter -Filter $s.Text.Trim() -Container $Script:TNControls.ProjectTree
    })

    # Atajos de teclado globales (mismo bug de closure: $ctrl local no sobrevive)
    $Window.Add_KeyDown({
        param($s, $e)
        $mods = [System.Windows.Input.Keyboard]::Modifiers
        $tc = $Script:TNControls
        switch ($e.Key) {
            'W' {
                if ($mods -band 'Control') {
                    $selectedTab = $tc.TabsMain.SelectedItem -as [System.Windows.Controls.TabItem]
                    if ($selectedTab) {
                        $pathToClose = $Script:OpenTabs.Keys | Where-Object { $Script:OpenTabs[$_] -eq $selectedTab } | Select-Object -First 1
                        if ($pathToClose) { Close-Tab $pathToClose }
                    }
                    $e.Handled = $true
                }
            }
            'F' {
                if ($mods -band 'Control') {
                    $tc.TxtGlobalSearch.Focus()
                    $tc.TxtGlobalSearch.SelectAll()
                    $e.Handled = $true
                }
            }
            'T' {
                if ($mods -band 'Control') {
                    if ($Script:CurrentProject) {
                        $key = "__timeline__project"
                        if ($Script:OpenTabs.ContainsKey($key)) { $tc.TabsMain.SelectedItem = $Script:OpenTabs[$key] }
                        else { $tc.MenuTimeline.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent)) }
                    }
                    $e.Handled = $true
                }
            }
            'I' {
                if ($mods -band 'Control') {
                    if ($Script:CurrentProject) {
                        $key = "__iocscan__project"
                        if ($Script:OpenTabs.ContainsKey($key)) { $tc.TabsMain.SelectedItem = $Script:OpenTabs[$key] }
                        else { $tc.MenuIOCScan.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent)) }
                    }
                    $e.Handled = $true
                }
            }
        }
    })

    # Dark title bar + restauracion de estado tras cambio de tema
    $Window.Add_Loaded({
        Set-DarkTitleBar $Window

        if ($null -ne $Script:TN_RestoreState) {
            $state = $Script:TN_RestoreState
            $Script:TN_RestoreState = $null

            if (-not [string]::IsNullOrEmpty($state.ProjectPath) -and (Test-Path $state.ProjectPath)) {
                Load-ProjectTree -ProjectPath $state.ProjectPath
            }
            foreach ($fp in $state.OpenFiles) {
                if (Test-Path $fp) { Open-FileInTab -FilePath $fp }
            }
        }
    })

    Set-Status "Listo  ·  MaPeriT.TN v$($Script:TN_Version)" ""
}

#endregion
