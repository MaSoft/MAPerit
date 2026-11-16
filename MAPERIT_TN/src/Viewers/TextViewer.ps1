#region ============================================================
# MaPeriT.TN - VISOR DE TEXTO / LOG
# ============================================================

function New-TextViewerContent {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    $r0 = New-Object System.Windows.Controls.RowDefinition
    $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = New-Object System.Windows.Controls.RowDefinition
    $r1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $outer.RowDefinitions.Add($r0)
    $outer.RowDefinitions.Add($r1)

    # ── Barra de herramientas ────────────────────────────────────────
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background     = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush    = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness= [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding        = [System.Windows.Thickness]::new(8,5,8,5)

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    # Info label
    $size = if (Test-Path $FilePath) { Format-FileSize (Get-Item $FilePath).Length } else { "" }
    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text       = "$([System.IO.Path]::GetFileName($FilePath))  ·  $size"
    $lbl.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $lbl.FontSize   = 11
    $lbl.VerticalAlignment = 'Center'
    $sp.Children.Add($lbl) | Out-Null

    # Separator
    $sepBorder = New-Object System.Windows.Controls.Border
    $sepBorder.Width            = 1
    $sepBorder.Background       = New-WpfBrush $Script:Colors.Border
    $sepBorder.Margin           = [System.Windows.Thickness]::new(10,2,10,2)
    $sp.Children.Add($sepBorder) | Out-Null

    # Search box
    $searchBox = New-Object System.Windows.Controls.TextBox
    $searchBox.Width      = 180
    $searchBox.Height     = 24
    $searchBox.Background = New-WpfBrush $Script:Colors.BgSurface
    $searchBox.Foreground = New-WpfBrush $Script:Colors.Text
    $searchBox.CaretBrush = [System.Windows.Media.Brushes]::White
    $searchBox.BorderBrush= New-WpfBrush $Script:Colors.Border
    $searchBox.Padding    = [System.Windows.Thickness]::new(6,2,6,2)
    $searchBox.FontSize   = 11
    $sp.Children.Add($searchBox) | Out-Null

    # Copy button
    $copyBtn = New-Object System.Windows.Controls.Button
    $copyBtn.Content          = "Copiar todo"
    $copyBtn.Height           = 24
    $copyBtn.Padding          = [System.Windows.Thickness]::new(8,2,8,2)
    $copyBtn.Margin           = [System.Windows.Thickness]::new(6,0,0,0)
    $copyBtn.Background       = New-WpfBrush $Script:Colors.BgSurface
    $copyBtn.Foreground       = New-WpfBrush $Script:Colors.Text
    $copyBtn.BorderBrush      = New-WpfBrush $Script:Colors.Border
    $copyBtn.FontSize         = 11
    $copyBtn.Cursor           = [System.Windows.Input.Cursors]::Hand
    $sp.Children.Add($copyBtn) | Out-Null

    $toolbar.Child = $sp
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # ── Contenido ────────────────────────────────────────────────────
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility   = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Auto'
    $scroll.Background = New-WpfBrush $Script:Colors.BgPrimary

    $contentGrid = New-Object System.Windows.Controls.Grid
    $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = [System.Windows.GridLength]::Auto
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $contentGrid.ColumnDefinitions.Add($c0)
    $contentGrid.ColumnDefinitions.Add($c1)

    $monoFont = New-Object System.Windows.Media.FontFamily("Cascadia Code, Consolas, Courier New")

    # Leer fichero
    $lines = @()
    try {
        if (Test-Path $FilePath) {
            $lines = [System.IO.File]::ReadAllLines($FilePath, [System.Text.Encoding]::UTF8)
        }
    } catch {
        try { $lines = Get-Content $FilePath -ErrorAction SilentlyContinue }
        catch { $lines = @("Error al leer el fichero: $_") }
    }

    # Panel de numeros de linea
    $lineNums = New-Object System.Windows.Controls.TextBlock
    $lineNums.FontFamily   = $monoFont
    $lineNums.FontSize     = 12
    $lineNums.Foreground   = New-WpfBrush $Script:Colors.TextDim
    $lineNums.Background   = New-WpfBrush $Script:Colors.BgHeader
    $lineNums.Padding      = [System.Windows.Thickness]::new(8,8,12,8)
    $lineNums.TextAlignment= 'Right'
    $lineNums.Text         = (1..$([Math]::Max(1,$lines.Count)) | ForEach-Object { $_ }) -join "`n"
    $lineNums.VerticalAlignment = 'Top'
    [System.Windows.Controls.Grid]::SetColumn($lineNums, 0)

    # Contenido de texto
    $textContent = New-Object System.Windows.Controls.TextBlock
    $textContent.FontFamily  = $monoFont
    $textContent.FontSize    = 12
    $textContent.Foreground  = New-WpfBrush $Script:Colors.Text
    $textContent.Padding     = [System.Windows.Thickness]::new(12,8,8,8)
    $textContent.TextWrapping= 'NoWrap'
    $textContent.Text        = $lines -join "`n"
    $textContent.VerticalAlignment = 'Top'
    [System.Windows.Controls.Grid]::SetColumn($textContent, 1)

    $contentGrid.Children.Add($lineNums) | Out-Null
    $contentGrid.Children.Add($textContent) | Out-Null
    $scroll.Content = $contentGrid
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $outer.Children.Add($scroll) | Out-Null

    # Eventos
    # BUG CONFIRMADO (mismo patron que JSONViewer.ps1): $allText es local,
    # el boton se pulsa tras retornar la funcion -> portapapeles vacio sin
    # ningun error visible. Se guarda en .Tag.
    $allText = $lines -join "`n"
    $copyBtn.Tag = $allText
    $copyBtn.Add_Click({ param($s, $e) [System.Windows.Clipboard]::SetText($s.Tag) })

    # Busqueda: scroll a primera ocurrencia + resalta en status
    $searchBox.Tag = [PSCustomObject]@{
        Scroll    = $scroll
        LineNums  = $lineNums
        Content   = $textContent
        Lines     = $lines
        LastMatch = -1
    }
    $searchBox.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -ne 'Return') { return }
        $ctx   = $sender.Tag
        $query = $sender.Text.Trim()
        if ([string]::IsNullOrEmpty($query)) { return }

        $startLine = if ($e.Key -eq 'Return' -and [System.Windows.Input.Keyboard]::Modifiers -band 'Shift') {
            [Math]::Max(0, $ctx.LastMatch - 1)
        } else { $ctx.LastMatch + 1 }

        $found = -1
        for ($i = $startLine; $i -lt $ctx.Lines.Count; $i++) {
            if ($ctx.Lines[$i] -match [regex]::Escape($query)) { $found = $i; break }
        }
        if ($found -eq -1 -and $startLine -gt 0) {
            for ($i = 0; $i -lt $startLine; $i++) {
                if ($ctx.Lines[$i] -match [regex]::Escape($query)) { $found = $i; break }
            }
        }
        if ($found -ge 0) {
            $ctx.LastMatch = $found
            $approxY = $found * 18.5
            $ctx.Scroll.ScrollToVerticalOffset($approxY)
            $sender.Background = New-WpfBrush "#1A3A1A"
        } else {
            $sender.Background = New-WpfBrush "#3A1A1A"
        }
    })
    $searchBox.Add_TextChanged({
        param($sender, $e)
        $ctx = $sender.Tag
        $ctx.LastMatch = -1
        $sender.Background = New-WpfBrush $Script:Colors.BgSurface
    })

    # ── Menú contextual en el área de texto ─────────────────────────
    $textCM = New-Object System.Windows.Controls.ContextMenu
    $textCM.Background      = New-WpfBrush $Script:Colors.BgCard
    $textCM.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $textCM.BorderThickness = [System.Windows.Thickness]::new(1)
    $textCM.Padding         = [System.Windows.Thickness]::new(2)
    foreach ($mDef in @(
        @{ H="Copiar todo";                    A="Copy"     },
        @{ H="-";                              A="-"        },
        @{ H="Anadir marcador del archivo..."; A="Bookmark" }
    )) {
        if ($mDef.A -eq "-") { $textCM.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null }
        else {
            $mItem = New-Object System.Windows.Controls.MenuItem
            $mItem.Header     = $mDef.H
            $mItem.Foreground = New-WpfBrush $Script:Colors.Text
            $mItem.Background = New-WpfBrush $Script:Colors.BgCard
            $mItem.FontSize   = 12
            $mItem.Tag = [PSCustomObject]@{ Action=$mDef.A; FilePath=$FilePath; AllText=$allText }
            $mItem.Add_Click({
                param($s, $e)
                $ctx = $s.Tag
                switch ($ctx.Action) {
                    "Copy"     { [System.Windows.Clipboard]::SetText($ctx.AllText) }
                    "Bookmark" { Show-AddBookmarkDialog -FilePath $ctx.FilePath }
                }
            })
            $textCM.Items.Add($mItem) | Out-Null
        }
    }
    $outer.ContextMenu = $textCM

    return $outer
}

#endregion
