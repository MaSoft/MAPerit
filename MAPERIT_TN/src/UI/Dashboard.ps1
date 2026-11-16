#region ============================================================
# MaPeriT.TN - DASHBOARD DE PROYECTO
# ============================================================

function New-DashboardContent {
    param([hashtable]$Meta)

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility   = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'
    $scroll.Background = New-WpfBrush $Script:Colors.BgPrimary

    $root = New-Object System.Windows.Controls.StackPanel
    $root.Margin = [System.Windows.Thickness]::new(20,20,20,20)

    # ── Cabecera ─────────────────────────────────────────────────────
    $header = New-Object System.Windows.Controls.Border
    $header.Background      = New-WpfBrush $Script:Colors.BgCard
    $header.CornerRadius    = [System.Windows.CornerRadius]::new(6)
    $header.Padding         = [System.Windows.Thickness]::new(20,16,20,16)
    $header.Margin          = [System.Windows.Thickness]::new(0,0,0,16)

    $headerGrid = New-Object System.Windows.Controls.Grid
    $hc0 = New-Object System.Windows.Controls.ColumnDefinition
    $hc0.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $hc1 = New-Object System.Windows.Controls.ColumnDefinition
    $hc1.Width = [System.Windows.GridLength]::Auto
    $headerGrid.ColumnDefinitions.Add($hc0)
    $headerGrid.ColumnDefinitions.Add($hc1)

    $titleSP = New-Object System.Windows.Controls.StackPanel
    $caseLabel = New-Object System.Windows.Controls.TextBlock
    $caseLabel.Text       = if ($Meta.CaseNumber) { "Caso: $($Meta.CaseNumber)" } else { $Meta.Name }
    $caseLabel.FontSize   = 20
    $caseLabel.FontWeight = [System.Windows.FontWeights]::Light
    $caseLabel.Foreground = New-WpfBrush $Script:Colors.Text
    $titleSP.Children.Add($caseLabel) | Out-Null

    $infoLabel = New-Object System.Windows.Controls.TextBlock
    $infoLabel.FontSize   = 11
    $infoLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $infoLabel.Margin     = [System.Windows.Thickness]::new(0,4,0,0)
    $parts = @()
    if ($Meta.ComputerName) { $parts += "Equipo: $($Meta.ComputerName)" }
    if ($Meta.Examiner)     { $parts += "Perito: $($Meta.Examiner)" }
    if ($Meta.StartTime)    { $parts += "Adquisicion: $($Meta.StartTime)" }
    $infoLabel.Text = $parts -join "   ·   "
    $titleSP.Children.Add($infoLabel) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($titleSP, 0)
    $headerGrid.Children.Add($titleSP) | Out-Null

    if ($Meta.HasAN) {
        $anBadge = New-Object System.Windows.Controls.Border
        $anBadge.Background        = New-WpfBrush "#0F3460"
        $anBadge.CornerRadius      = [System.Windows.CornerRadius]::new(4)
        $anBadge.Padding           = [System.Windows.Thickness]::new(8,4,8,4)
        $anBadge.VerticalAlignment = 'Center'
        $anText = New-Object System.Windows.Controls.TextBlock
        $anText.Text       = "AN Disponible"
        $anText.Foreground = New-WpfBrush $Script:Colors.Accent
        $anText.FontSize   = 11
        $anText.FontWeight = [System.Windows.FontWeights]::SemiBold
        $anBadge.Child     = $anText
        [System.Windows.Controls.Grid]::SetColumn($anBadge, 1)
        $headerGrid.Children.Add($anBadge) | Out-Null
    }

    $header.Child = $headerGrid
    $root.Children.Add($header) | Out-Null

    # ── Tarjetas de estadisticas (WrapPanel en lugar de UniformGrid) ──
    $statsWrap = New-Object System.Windows.Controls.WrapPanel
    $statsWrap.Margin = [System.Windows.Thickness]::new(0,0,0,16)

    $anomalyColor = if ($Meta.AnomalyCount -gt 0) { $Script:Colors.Warning } else { $Script:Colors.Success }
    $statsData = @(
        @{ Label="Fases capturadas";   Value=$Meta.PhaseCount.ToString();                Color=$Script:Colors.Accent  },
        @{ Label="Artefactos CSV/JSON";Value=$Meta.ArtifactCount.ToString();             Color=$Script:Colors.Success },
        @{ Label="Anomalias SW";       Value=$Meta.AnomalyCount.ToString();              Color=$anomalyColor          },
        @{ Label="Tamano total";       Value=(Format-FileSize $Meta.FileSizeTotal);      Color=$Script:Colors.Info    }
    )

    foreach ($stat in $statsData) {
        $card = New-Object System.Windows.Controls.Border
        $card.Background      = New-WpfBrush $Script:Colors.BgCard
        $card.CornerRadius    = [System.Windows.CornerRadius]::new(6)
        $card.Padding         = [System.Windows.Thickness]::new(20,14,20,14)
        $card.Margin          = [System.Windows.Thickness]::new(0,0,10,10)
        $card.BorderBrush     = New-WpfBrush $Script:Colors.Border
        $card.BorderThickness = [System.Windows.Thickness]::new(1)
        $card.MinWidth        = 160

        $cardSP = New-Object System.Windows.Controls.StackPanel
        $valText = New-Object System.Windows.Controls.TextBlock
        $valText.Text       = $stat.Value
        $valText.FontSize   = 28
        $valText.FontWeight = [System.Windows.FontWeights]::Light
        $valText.Foreground = New-WpfBrush $stat.Color
        $cardSP.Children.Add($valText) | Out-Null

        $lblText = New-Object System.Windows.Controls.TextBlock
        $lblText.Text       = $stat.Label
        $lblText.FontSize   = 11
        $lblText.Foreground = New-WpfBrush $Script:Colors.TextMuted
        $lblText.Margin     = [System.Windows.Thickness]::new(0,2,0,0)
        $cardSP.Children.Add($lblText) | Out-Null

        $card.Child = $cardSP
        $statsWrap.Children.Add($card) | Out-Null
    }
    $root.Children.Add($statsWrap) | Out-Null

    # ── Fases presentes (WrapPanel) ───────────────────────────────────
    $sectionLabel = New-Object System.Windows.Controls.TextBlock
    $sectionLabel.Text       = "FASES DE ADQUISICION"
    $sectionLabel.FontSize   = 10
    $sectionLabel.FontWeight = [System.Windows.FontWeights]::SemiBold
    $sectionLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $sectionLabel.Margin     = [System.Windows.Thickness]::new(0,0,0,8)
    $root.Children.Add($sectionLabel) | Out-Null

    $phasesWrap = New-Object System.Windows.Controls.WrapPanel
    $phasesWrap.Margin = [System.Windows.Thickness]::new(0,0,0,20)

    foreach ($kv in $Script:SW_PhaseNames.GetEnumerator()) {
        $phaseDir = Join-Path $Meta.Path $kv.Key
        $exists   = Test-Path $phaseDir

        $pCard = New-Object System.Windows.Controls.Border
        $pBgColor = if ($exists) { $Script:Colors.BgCard } else { $Script:Colors.BgPanel }
        $pCard.Background      = New-WpfBrush $pBgColor
        $pCard.CornerRadius    = [System.Windows.CornerRadius]::new(4)
        $pCard.Padding         = [System.Windows.Thickness]::new(10,7,10,7)
        $pCard.Margin          = [System.Windows.Thickness]::new(0,0,6,6)
        $pCard.Opacity         = if ($exists) { 1.0 } else { 0.35 }
        $pCard.MinWidth        = 200

        $pSP = New-Object System.Windows.Controls.StackPanel
        $pSP.Orientation = 'Horizontal'

        # Indicador de estado (rectangulo coloreado en lugar de Ellipse para evitar namespace)
        $dot = New-Object System.Windows.Controls.Border
        $dot.Width         = 8
        $dot.Height        = 8
        $dotColor = if ($exists) { $Script:Colors.Success } else { $Script:Colors.TextDim }
        $dot.Background    = New-WpfBrush $dotColor
        $dot.CornerRadius  = [System.Windows.CornerRadius]::new(4)
        $dot.VerticalAlignment = 'Center'
        $dot.Margin        = [System.Windows.Thickness]::new(0,0,8,0)
        $pSP.Children.Add($dot) | Out-Null

        $pText = New-Object System.Windows.Controls.TextBlock
        $pText.Text       = $kv.Value
        $pText.FontSize   = 12
        $pFgColor = if ($exists) { $Script:Colors.Text } else { $Script:Colors.TextDim }
        $pText.Foreground = New-WpfBrush $pFgColor
        $pText.VerticalAlignment = 'Center'
        $pSP.Children.Add($pText) | Out-Null

        if ($exists) {
            $fCount = if ($Meta.PhaseCounts) { [int]($Meta.PhaseCounts[$kv.Key]) } else { 0 }
            $countText = New-Object System.Windows.Controls.TextBlock
            $countText.Text       = "  ($fCount)"
            $countText.FontSize   = 11
            $countText.Foreground = New-WpfBrush $Script:Colors.TextMuted
            $countText.VerticalAlignment = 'Center'
            $pSP.Children.Add($countText) | Out-Null
        }

        $pCard.Child = $pSP
        $phasesWrap.Children.Add($pCard) | Out-Null
    }
    $root.Children.Add($phasesWrap) | Out-Null

    # ── Ruta ──────────────────────────────────────────────────────────
    $pathLabel = New-Object System.Windows.Controls.TextBlock
    $pathLabel.Text         = "Ruta: $($Meta.Path)"
    $pathLabel.FontSize     = 11
    $pathLabel.Foreground   = New-WpfBrush $Script:Colors.TextDim
    $pathLabel.TextWrapping = 'Wrap'
    $root.Children.Add($pathLabel) | Out-Null

    $scroll.Content = $root
    return $scroll
}

#endregion
