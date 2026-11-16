#region ============================================================
# MaPeriT.TN - VISOR JSON
# ============================================================

function New-JSONViewerContent {
    param([string]$FilePath)

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Background = New-WpfBrush $Script:Colors.BgPrimary
    $r0 = New-Object System.Windows.Controls.RowDefinition; $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $outer.RowDefinitions.Add($r0)
    $outer.RowDefinitions.Add($r1)

    # ── Toolbar ─────────────────────────────────────────────────────
    $toolbar = New-Object System.Windows.Controls.Border
    $toolbar.Background      = New-WpfBrush $Script:Colors.BgCard
    $toolbar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $toolbar.BorderThickness = [System.Windows.Thickness]::new(0,0,0,1)
    $toolbar.Padding         = [System.Windows.Thickness]::new(8,5,8,5)

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    $size = if (Test-Path $FilePath) { Format-FileSize (Get-Item $FilePath).Length } else { "" }
    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text       = "$([System.IO.Path]::GetFileName($FilePath))  ·  $size"
    $lbl.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $lbl.FontSize   = 11
    $lbl.VerticalAlignment = 'Center'
    $sp.Children.Add($lbl) | Out-Null

    $copyBtn = New-Object System.Windows.Controls.Button
    $copyBtn.Content     = "Copiar"
    $copyBtn.Height      = 24
    $copyBtn.Padding     = [System.Windows.Thickness]::new(8,2,8,2)
    $copyBtn.Margin      = [System.Windows.Thickness]::new(10,0,0,0)
    $copyBtn.Background  = New-WpfBrush $Script:Colors.BgSurface
    $copyBtn.Foreground  = New-WpfBrush $Script:Colors.Text
    $copyBtn.BorderBrush = New-WpfBrush $Script:Colors.Border
    $copyBtn.FontSize    = 11
    $copyBtn.Cursor      = [System.Windows.Input.Cursors]::Hand
    $sp.Children.Add($copyBtn) | Out-Null

    $toolbar.Child = $sp
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $outer.Children.Add($toolbar) | Out-Null

    # ── Contenido ────────────────────────────────────────────────────
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility   = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Auto'
    $scroll.Background = New-WpfBrush $Script:Colors.BgPrimary

    $textBlock = New-Object System.Windows.Controls.TextBlock
    $textBlock.FontFamily  = New-Object System.Windows.Media.FontFamily("Cascadia Code, Consolas, Courier New")
    $textBlock.FontSize    = 12
    $textBlock.Foreground  = New-WpfBrush $Script:Colors.Text
    $textBlock.Padding     = [System.Windows.Thickness]::new(16,12,16,12)
    $textBlock.TextWrapping= 'NoWrap'
    $textBlock.VerticalAlignment = 'Top'

    $rawText = ""
    try {
        if (Test-Path $FilePath) {
            $rawText = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
            # Pretty-print JSON
            try {
                $obj = $rawText | ConvertFrom-Json
                $rawText = $obj | ConvertTo-Json -Depth 20
            } catch {}
        }
    } catch { $rawText = "Error al leer: $_" }

    $textBlock.Text = $rawText
    $scroll.Content = $textBlock
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $outer.Children.Add($scroll) | Out-Null

    # BUG CONFIRMADO (verificado empiricamente): $rawText es local a esta
    # funcion; el boton se pulsa despues de que la funcion ya ha retornado,
    # asi que $rawText es $null en ese momento - SetText($null) no lanza
    # error pero deja el portapapeles vacio: el examinador cree que ha
    # copiado evidencia y en realidad no ha copiado nada. Se guarda en .Tag.
    $copyBtn.Tag = $rawText
    $copyBtn.Add_Click({ param($s, $e) [System.Windows.Clipboard]::SetText($s.Tag) })

    return $outer
}

#endregion
