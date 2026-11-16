#region ============================================================
# MaPeriT.TN - CARGA ASINCRONA (Runspace + DispatcherTimer)
# ============================================================
# Sin C#, sin closures. Estado en $timer.Tag. Handler: param($sender,$e).

function New-LoadingOverlay {
    param([string]$Message = "Cargando...", [int]$RowSpan = 3)
    $overlay = New-Object System.Windows.Controls.Border
    $overlay.Background = New-WpfBrush $Script:Colors.BgPrimary
    $overlay.Visibility = 'Visible'
    [System.Windows.Controls.Panel]::SetZIndex($overlay, 99)
    [System.Windows.Controls.Grid]::SetRowSpan($overlay, $RowSpan)

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.HorizontalAlignment = 'Center'
    $sp.VerticalAlignment   = 'Center'

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text          = $Message
    $lbl.FontSize      = 15
    $lbl.Foreground    = New-WpfBrush $Script:Colors.TextMuted
    $lbl.TextAlignment = 'Center'
    $sp.Children.Add($lbl) | Out-Null

    $sub = New-Object System.Windows.Controls.TextBlock
    $sub.Text          = "Cargando en segundo plano..."
    $sub.FontSize      = 11
    $sub.Foreground    = New-WpfBrush $Script:Colors.TextDim
    $sub.TextAlignment = 'Center'
    $sub.Margin        = [System.Windows.Thickness]::new(0,6,0,0)
    $sp.Children.Add($sub) | Out-Null

    $overlay.Child = $sp
    return $overlay
}

function Invoke-AsyncCSVLoad {
    <#
    Carga un CSV en un PS Runspace en segundo plano.
    UIContext : PSCustomObject { DG, Status, Overlay, MaxRows }
    OnComplete: scriptblock param($ui, $table, $totalRows)
    OnError   : scriptblock param($ui, $msg)
    #>
    param(
        [string]$FilePath,
        [int]$MaxRows              = $Script:MaxRowsDefault,
        [PSCustomObject]$UIContext,
        [scriptblock]$OnComplete,
        [scriptblock]$OnError
    )

    # Script que corre en el Runspace de fondo (PS completo, puede usar Import-Csv)
    $bgScript = {
        param($path, $max)
        try {
            $raw   = @(Import-Csv $path -Encoding UTF8 -ErrorAction Stop)
            $total = $raw.Count
            if ($total -gt $max) { $raw = $raw[0..($max - 1)] }

            $tbl = [System.Data.DataTable]::new("TNData")
            if ($raw.Count -gt 0) {
                foreach ($prop in $raw[0].PSObject.Properties.Name) {
                    [void]$tbl.Columns.Add($prop, [string])
                }
                foreach ($r in $raw) {
                    $row = $tbl.NewRow()
                    foreach ($c in $tbl.Columns) {
                        $v = $r.($c.ColumnName)
                        $row[$c.ColumnName] = if ($null -ne $v) { $v.ToString() } else { "" }
                    }
                    [void]$tbl.Rows.Add($row)
                }
            }
            Write-Output -NoEnumerate ([PSCustomObject]@{ Table = $tbl; Total = $total; Err = "" })
        } catch {
            Write-Output -NoEnumerate ([PSCustomObject]@{ Table = $null; Total = 0; Err = $_.Exception.Message })
        }
    }

    # Crear Runspace STA con acceso completo a PS
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($bgScript).AddParameters(@{ path = $FilePath; max = $MaxRows })
    $handle = $ps.BeginInvoke()

    # DispatcherTimer: todo el estado en Tag para evitar closures.
    # En el handler: param($sender,$e) donde $sender ES el DispatcherTimer.
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(150)
    $timer.Tag = [PSCustomObject]@{
        Ps         = $ps
        Handle     = $handle
        Rs         = $rs
        UI         = $UIContext
        OnComplete = $OnComplete
        OnError    = $OnError
    }
    $timer.Add_Tick({
        param($sender, $e)
        $ctx   = $sender.Tag
        $state = $ctx.Ps.InvocationStateInfo.State
        if ($state -in 'Completed', 'Failed', 'Stopped') {
            $sender.Stop()
            try {
                $col = $ctx.Ps.EndInvoke($ctx.Handle)
                $obj = if ($col -and $col.Count -gt 0) { $col[0] } else { $null }
                if ($obj -and ($obj.Table -is [System.Data.DataTable])) {
                    & $ctx.OnComplete $ctx.UI $obj.Table $obj.Total
                } else {
                    $msg = if ($obj -and $obj.Err) { $obj.Err } else { "No se pudieron cargar los datos" }
                    if ($ctx.OnError) { & $ctx.OnError $ctx.UI $msg }
                }
            } catch {
                if ($ctx.OnError) { & $ctx.OnError $ctx.UI $_.Exception.Message }
            } finally {
                try { $ctx.Rs.Close(); $ctx.Rs.Dispose() } catch {}
            }
        }
    })
    $timer.Start()
}

#endregion
