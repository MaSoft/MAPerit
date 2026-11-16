#region ============================================================
# MaPeriT.TN - ESCANER IOC DE PROYECTO COMPLETO
# ============================================================

function New-IOCScanViewerContent {
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
    $titleLbl.Text       = "Escaner IOC — Proyecto completo  ·  CSV · JSON · TXT · LOG"
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
    $filterBox.FontSize = 11; $filterBox.ToolTip = "Filtrar por tipo, fichero o coincidencia"
    $rightSP.Children.Add($filterBox) | Out-Null

    foreach ($bt in @("Export CSV","Export HTML")) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $bt; $btn.Height = 24
        $btn.Padding = [System.Windows.Thickness]::new(8,2,8,2)
        $btn.Margin  = [System.Windows.Thickness]::new(4,0,0,0)
        $btn.Background = New-WpfBrush $Script:Colors.BgSurface
        $btn.Foreground = New-WpfBrush $Script:Colors.Text
        $btn.BorderBrush = New-WpfBrush $Script:Colors.Border
        $btn.FontSize = 11; $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $rightSP.Children.Add($btn) | Out-Null
    }
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
        @{ H="Severidad"; B="Severity"; W=80  },
        @{ H="Tipo IOC";  B="IOCType";  W=130 },
        @{ H="Fichero";   B="Fichero";  W=200 },
        @{ H="Linea";     B="Linea";    W=55  },
        @{ H="Coincidencia"; B="Match"; W=260 },
        @{ H="Contexto";  B="Context";  W=380 }
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
            "Info"     { New-WpfBrush $Script:Colors.RowInfo     }
            default    { $null }
        }
        if ($null -ne $bg) { $e.Row.Background = $bg }
    })
    [System.Windows.Controls.Grid]::SetRow($dg, 1)
    $outer.Children.Add($dg) | Out-Null

    # BUG CONFIRMADO: $dg es local a esta funcion (mismo bug de closure que en
    # MainWindow.ps1) - usar $s (sender) en vez de la variable local capturada.
    $dg.Add_MouseDoubleClick({
        param($s, $e)
        $item = $s.SelectedItem -as [System.Data.DataRowView]
        if ($item) {
            $ruta = $item['Ruta'] -as [string]
            if ($ruta -and (Test-Path $ruta)) { Open-FileInTab -FilePath $ruta }
        }
    })

    # Status
    $statusBar = New-Object System.Windows.Controls.Border
    $statusBar.Background      = New-WpfBrush $Script:Colors.BgHeader
    $statusBar.BorderBrush     = New-WpfBrush $Script:Colors.Border
    $statusBar.BorderThickness = [System.Windows.Thickness]::new(0,1,0,0)
    $statusBar.Padding         = [System.Windows.Thickness]::new(8,3,8,3)
    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Text       = "Escaneando proyecto..."
    $statusLabel.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $statusLabel.FontSize   = 11
    $statusBar.Child = $statusLabel
    [System.Windows.Controls.Grid]::SetRow($statusBar, 2)
    $outer.Children.Add($statusBar) | Out-Null

    $overlay = New-LoadingOverlay -Message "Escaneando IOCs en el proyecto..." -RowSpan 3
    $outer.Children.Add($overlay) | Out-Null

    # Filter
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
            try {
                $tbl.DefaultView.RowFilter = "CONVERT([IOCType],'System.String') LIKE '%$safeT%' OR CONVERT([Match],'System.String') LIKE '%$safeT%' OR CONVERT([Fichero],'System.String') LIKE '%$safeT%' OR CONVERT([Severity],'System.String') LIKE '%$safeT%'"
            } catch { $tbl.DefaultView.RowFilter = "" }
        }
        $ctx.DG.ItemsSource = $tbl.DefaultView
        $ctx.Status.Text = "$($tbl.DefaultView.Count) de $($tbl.Rows.Count) IOCs"
    })

    # Export buttons
    foreach ($btn in ($rightSP.Children | Where-Object { $_ -is [System.Windows.Controls.Button] })) {
        $btn.Tag = [PSCustomObject]@{ DG = $dg }
        $btn.Add_Click({
            param($sender, $e)
            $ctx = $sender.Tag
            $tbl = $ctx.DG.Tag -as [System.Data.DataTable]
            if ($null -eq $tbl -or $tbl.Rows.Count -eq 0) { Set-Status "Sin IOCs para exportar"; return }
            if ($sender.Content -match 'CSV') {
                $dlg2 = New-Object Microsoft.Win32.SaveFileDialog
                $dlg2.Filter = "CSV (*.csv)|*.csv"
                $dlg2.FileName = "IOC_Scan_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                if ($dlg2.ShowDialog() -eq $true) {
                    $tbl.DefaultView.ToTable() | Export-Csv $dlg2.FileName -NoTypeInformation -Encoding UTF8
                    Set-Status "Exportado: $($dlg2.FileName)"
                }
            } else {
                Export-IOCScanHTML -Table $tbl
            }
        })
    }

    # Background IOC scan (Runspace)
    $bgScript = {
        param($projectPath, $patterns)
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        $patternMap = [ordered]@{
            'EncodedCmd'     = @{ Pattern=$patterns.EncodedCmd;     Severity='Critical'; Label='Comando codificado' }
            'SuspiciousPath' = @{ Pattern=$patterns.SuspiciousPath; Severity='High';     Label='Ruta anomala'       }
            'SuspiciousExe'  = @{ Pattern=$patterns.SuspiciousExe;  Severity='High';     Label='Ejecutable sospechoso' }
            'IPv4External'   = @{ Pattern=$patterns.IPv4External;   Severity='Info';     Label='IP Externa'         }
            'SHA256'         = @{ Pattern=$patterns.SHA256;          Severity='Info';     Label='Hash SHA256'        }
        }
        $files = @(Get-ChildItem $projectPath -Recurse -Include "*.csv","*.json","*.txt","*.log" -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -lt 30MB -and $_.Length -gt 0 })
        foreach ($file in $files) {
            try {
                $lines = [System.IO.File]::ReadAllLines($file.FullName, [System.Text.Encoding]::UTF8)
                $lineNum = 0
                foreach ($line in $lines) {
                    $lineNum++
                    if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
                    foreach ($key in $patternMap.Keys) {
                        $pm = $patternMap[$key]
                        $m = [regex]::Match($line, $pm.Pattern)
                        if ($m.Success) {
                            $ctx = $line.Trim()
                            if ($ctx.Length -gt 280) { $ctx = $ctx.Substring(0,280) + "..." }
                            $matchVal = $m.Value
                            if ($matchVal.Length -gt 140) { $matchVal = $matchVal.Substring(0,140) }
                            $results.Add([PSCustomObject]@{
                                Severity = $pm.Severity
                                IOCType  = $pm.Label
                                Fichero  = $file.Name
                                Linea    = $lineNum
                                Match    = $matchVal
                                Context  = $ctx
                                Ruta     = $file.FullName
                            }) | Out-Null
                            break  # one hit per line per pattern priority
                        }
                    }
                }
            } catch {}
        }
        $sorted = $results | Sort-Object @{E={ switch($_.Severity){"Critical"{0}"High"{1}default{2}} }}, Fichero, Linea
        Write-Output -NoEnumerate ([PSCustomObject]@{ Results=$sorted; Files=$files.Count; Err="" })
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{ projectPath=$ProjectPath; patterns=$Script:IOCPatterns })
    $handle = $ps.BeginInvoke()

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(400)
    $timer.Tag = [PSCustomObject]@{ Ps=$ps; Handle=$handle; Rs=$rs; DG=$dg; Status=$statusLabel; Overlay=$overlay }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag
        if ($ctx.Ps.InvocationStateInfo.State -in 'Completed','Failed','Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                $tbl = [System.Data.DataTable]::new("IOCScan")
                foreach ($c in @('Severity','IOCType','Fichero','Linea','Match','Context','Ruta')) {
                    [void]$tbl.Columns.Add($c, [string])
                }
                if ($obj -and $obj.Results) {
                    foreach ($r in $obj.Results) {
                        $row = $tbl.NewRow()
                        $row['Severity'] = $r.Severity; $row['IOCType'] = $r.IOCType
                        $row['Fichero']  = $r.Fichero;  $row['Linea']   = $r.Linea.ToString()
                        $row['Match']    = $r.Match;    $row['Context']  = $r.Context
                        $row['Ruta']     = $r.Ruta
                        [void]$tbl.Rows.Add($row)
                    }
                }
                $ctx.DG.Tag = $tbl
                $ctx.DG.ItemsSource = $tbl.DefaultView
                $ctx.Status.Text = "$($tbl.Rows.Count) IOCs detectados en $($obj.Files) ficheros"
            } catch {
                $ctx.Status.Text = "Error: $($_.Exception.Message)"
            } finally {
                $ctx.Overlay.Visibility = 'Collapsed'
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
    return $outer
}

function Export-IOCScanHTML {
    param([System.Data.DataTable]$Table)
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = "HTML (*.html)|*.html"
    $dlg.FileName = "IOC_Scan_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    if ($dlg.ShowDialog() -ne $true) { return }
    $rows = ""
    foreach ($row in $Table.DefaultView.ToTable().Rows) {
        $bg = switch ($row['Severity']) { "Critical"{"#3B1010"} "High"{"#3B2210"} default{"#0F2840"} }
        $rows += "<tr style='background:$bg'>"
        foreach ($c in @('Severity','IOCType','Fichero','Linea','Match','Context')) {
            $rows += "<td>$([System.Net.WebUtility]::HtmlEncode($row[$c].ToString()))</td>"
        }
        $rows += "</tr>`n"
    }
    $html = "<!DOCTYPE html><html lang='es'><head><meta charset='UTF-8'><title>MaPeriT.TN - IOC Scan</title><style>body{background:#111827;color:#F1F5F9;font-family:'Segoe UI',sans-serif;padding:30px}h1{color:#3B82F6;font-weight:300}.sub{color:#64748B;font-size:13px;margin-bottom:24px}table{border-collapse:collapse;width:100%}th{background:#0F172A;color:#94A3B8;font-size:11px;text-transform:uppercase;padding:8px 12px;text-align:left;border-bottom:1px solid #334155}td{padding:7px 12px;font-size:12px;border-bottom:1px solid #1F2937;color:#CBD5E1;word-break:break-all}</style></head><body><h1>MaPeriT.TN - Informe de IOCs</h1><p class='sub'>Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &nbsp;·&nbsp; $($Table.Rows.Count) hallazgos</p><table><thead><tr><th>Severidad</th><th>Tipo</th><th>Fichero</th><th>Linea</th><th>Coincidencia</th><th>Contexto</th></tr></thead><tbody>$rows</tbody></table></body></html>"
    [System.IO.File]::WriteAllText($dlg.FileName, $html, [System.Text.Encoding]::UTF8)
    Start-Process $dlg.FileName
    Set-Status "Informe IOC exportado: $($dlg.FileName)"
}

#endregion
