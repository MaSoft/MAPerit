#region ============================================================
# MaPeriT.SC - ASISTENTE POR PASOS
# Shell fijo en XAML.ps1, cada paso se construye por codigo y se
# inyecta en ContentHost. Estado del asistente en $Script:SCWizard.
# ============================================================

$Script:SCWizard = @{
    Controls  = @{}
    StepOrder = @('Project','Users','Categories','DateTime','Keyword','Summary','Results','Reports')
    StepIndex = 0
    State     = @{
        ProjectPath       = ""
        KnownUsers        = @()
        SelectedUsers     = @()
        SelectedCategories= @()
        DateFrom          = $null
        DateTo            = $null
        TimeFrom          = $null
        TimeTo            = $null
        Keyword           = ""
        ExcludeKeyword    = ""
        QueryResults      = @()
        QuerySummary      = $null
        ReportOutputDir   = ""
        ReportPaths       = @()
    }
}

$Script:SCStepTitles = [ordered]@{
    Project    = "Paso 1 de 8 · Proyecto"
    Users      = "Paso 2 de 8 · Ambito de usuario"
    Categories = "Paso 3 de 8 · Categorias de interes"
    DateTime   = "Paso 4 de 8 · Ventana temporal"
    Keyword    = "Paso 5 de 8 · Palabra clave (opcional)"
    Summary    = "Paso 6 de 8 · Resumen y confirmacion"
    Results    = "Paso 7 de 8 · Resultados"
    Reports    = "Paso 8 de 8 · Informes"
}

# ── Helpers de construccion de UI ─────────────────────────────────────

function Get-SCStyle { param([string]$Name) return $Script:SCWizard.Controls.Window.FindResource($Name) }

# ── Plantillas de busqueda (guardar/cargar criterios entre casos) ────────
# No incluyen Usuarios: la lista de usuarios se detecta por proyecto y no
# tiene sentido reutilizarla entre casos distintos.

function Get-SCSavedTemplates {
    if (-not (Test-Path $Script:SC_TemplatesDir)) { return @() }
    return @(Get-ChildItem $Script:SC_TemplatesDir -Filter *.json -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { $_.BaseName })
}

function Save-SCTemplate {
    param([string]$Name)
    $safe = ($Name -replace '[\\/:*?"<>|]', '_').Trim()
    if (-not $safe) { return $null }
    if (-not (Test-Path $Script:SC_TemplatesDir)) { New-Item -ItemType Directory -Path $Script:SC_TemplatesDir -Force | Out-Null }
    $data = [PSCustomObject]@{
        Categorias     = @($Script:SCWizard.State.SelectedCategories)
        DateFrom       = if ($Script:SCWizard.State.DateFrom) { $Script:SCWizard.State.DateFrom.ToString("o") } else { $null }
        DateTo         = if ($Script:SCWizard.State.DateTo)   { $Script:SCWizard.State.DateTo.ToString("o") }   else { $null }
        TimeFrom       = if ($Script:SCWizard.State.TimeFrom) { $Script:SCWizard.State.TimeFrom.ToString() }    else { $null }
        TimeTo         = if ($Script:SCWizard.State.TimeTo)   { $Script:SCWizard.State.TimeTo.ToString() }      else { $null }
        Keyword        = $Script:SCWizard.State.Keyword
        ExcludeKeyword = $Script:SCWizard.State.ExcludeKeyword
    }
    $path = Join-Path $Script:SC_TemplatesDir "$safe.json"
    $data | ConvertTo-Json | Set-Content -Path $path -Encoding UTF8
    return $path
}

function Import-SCTemplate {
    param([string]$Name)
    $path = Join-Path $Script:SC_TemplatesDir "$Name.json"
    if (-not (Test-Path $path)) { return $false }
    try { $data = Get-Content $path -Raw | ConvertFrom-Json } catch { return $false }
    $Script:SCWizard.State.SelectedCategories = @($data.Categorias)
    $Script:SCWizard.State.DateFrom       = if ($data.DateFrom) { [datetime]$data.DateFrom } else { $null }
    $Script:SCWizard.State.DateTo         = if ($data.DateTo)   { [datetime]$data.DateTo }   else { $null }
    $Script:SCWizard.State.TimeFrom       = if ($data.TimeFrom) { [TimeSpan]::Parse($data.TimeFrom) } else { $null }
    $Script:SCWizard.State.TimeTo         = if ($data.TimeTo)   { [TimeSpan]::Parse($data.TimeTo) }   else { $null }
    $Script:SCWizard.State.Keyword        = "$($data.Keyword)"
    $Script:SCWizard.State.ExcludeKeyword = "$($data.ExcludeKeyword)"
    return $true
}

function New-SCHeading {
    param([string]$Text)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 19
    $tb.FontWeight = 'SemiBold'
    $tb.Foreground = New-WpfBrush $Script:Colors.Text
    $tb.Margin = [System.Windows.Thickness]::new(0,0,0,6)
    return $tb
}

function New-SCParagraph {
    param([string]$Text)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 13
    $tb.TextWrapping = 'Wrap'
    $tb.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $tb.Margin = [System.Windows.Thickness]::new(0,0,0,4)
    return $tb
}

function New-SCLabel {
    param([string]$Text, [switch]$Bold)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 12.5
    if ($Bold) { $tb.FontWeight = 'SemiBold' }
    $tb.Foreground = New-WpfBrush $Script:Colors.Text
    $tb.Margin = [System.Windows.Thickness]::new(0,10,0,4)
    return $tb
}

function New-SCCheckList {
    <# Items: array de @{ Value=""; Label="" }. Devuelve StackPanel con CheckBox.Tag=Value #>
    param([array]$Items, [string[]]$CheckedValues = @())
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = [System.Windows.Thickness]::new(0,4,0,4)
    foreach ($it in $Items) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $it.Label
        $cb.Tag = $it.Value
        if ($CheckedValues -contains $it.Value) { $cb.IsChecked = $true }
        [void]$sp.Children.Add($cb)
    }
    return $sp
}

function Get-SCCheckedValues {
    param($Panel)
    $vals = [System.Collections.Generic.List[string]]::new()
    foreach ($child in $Panel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) { $vals.Add([string]$child.Tag) }
    }
    return @($vals)
}

function Set-SCValidationError {
    param([string]$Message)
    $st = $Script:SCWizard.Controls.StatusText
    $st.Text = $Message
    $st.Foreground = New-WpfBrush $Script:Colors.Danger
}

function Clear-SCValidationError {
    $st = $Script:SCWizard.Controls.StatusText
    $st.Text = ""
    $st.Foreground = New-WpfBrush $Script:Colors.TextMuted
}

function Set-SCBusy {
    param([string]$Message)
    $ctrl = $Script:SCWizard.Controls
    $ctrl.StatusText.Foreground = New-WpfBrush $Script:Colors.TextMuted
    $ctrl.StatusText.Text = $Message
    $ctrl.WizardProgressBar.Visibility = 'Visible'
    $ctrl.WizardProgressBar.Value = 0
    $ctrl.BtnNext.IsEnabled = $false
    $ctrl.BtnBack.IsEnabled = $false
}

function Clear-SCBusy {
    $ctrl = $Script:SCWizard.Controls
    $ctrl.WizardProgressBar.Visibility = 'Collapsed'
    $ctrl.StatusText.Text = ""
    $ctrl.BtnNext.IsEnabled = $true
    $ctrl.BtnBack.IsEnabled = $true
}

function Set-SCProgressText {
    param([string]$Text, [int]$Current = -1, [int]$Total = -1)
    $ctrl = $Script:SCWizard.Controls
    $ctrl.StatusText.Text = $Text
    if ($Total -gt 0) {
        $ctrl.WizardProgressBar.Maximum = $Total
        $ctrl.WizardProgressBar.Value = $Current
    }
}

# ── Paso 1: Proyecto ──────────────────────────────────────────────────

function Show-SCStepProject {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Selecciona el proyecto"))
    [void]$panel.Children.Add((New-SCParagraph "Elige la carpeta de evidencias generada por MaPeriT.SW u OF sobre la que ya se haya ejecutado MaPeriT.AN. Debe contener la subcarpeta ANALISIS_AN."))

    $row = New-Object System.Windows.Controls.Grid
    $row.Margin = [System.Windows.Thickness]::new(0,16,0,0)
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $c2.Width = [System.Windows.GridLength]::Auto
    [void]$row.ColumnDefinitions.Add($c1)
    [void]$row.ColumnDefinitions.Add($c2)

    $box = New-Object System.Windows.Controls.TextBox
    $box.Text = $Script:SCWizard.State.ProjectPath
    $box.VerticalContentAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($box,0)
    [void]$row.Children.Add($box)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "Examinar..."
    $btn.Style = (Get-SCStyle "SCBtn")
    $btn.Margin = [System.Windows.Thickness]::new(8,0,0,0)
    [System.Windows.Controls.Grid]::SetColumn($btn,1)
    $btn.Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Selecciona la carpeta de evidencias (con ANALISIS_AN dentro)"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $Script:SCWizard.Controls.ProjectPathBox.Text = $dlg.SelectedPath
        }
    })
    [void]$row.Children.Add($btn)
    [void]$panel.Children.Add($row)

    $Script:SCWizard.Controls.ProjectPathBox = $box
    return $panel
}

# ── Paso 2: Usuarios ──────────────────────────────────────────────────

function Show-SCStepUsers {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Ambito de usuario"))
    [void]$panel.Children.Add((New-SCParagraph "Elige 'Todos los usuarios' o selecciona uno o varios usuarios concretos detectados en este proyecto (sesiones de Windows y navegadores)."))

    $items = [System.Collections.Generic.List[object]]::new()
    $items.Add(@{ Value = '__ALL__'; Label = 'Todos los usuarios' })
    foreach ($u in $Script:SCWizard.State.KnownUsers) { $items.Add(@{ Value = $u; Label = $u }) }
    if ($Script:SCWizard.State.KnownUsers.Count -eq 0) {
        [void]$panel.Children.Add((New-SCParagraph "No se ha detectado ningun usuario en sesiones ni navegadores de este proyecto. Puedes continuar con 'Todos los usuarios'; los hallazgos sin usuario asociado se marcaran como tal."))
    }

    $checked = if ($Script:SCWizard.State.SelectedUsers.Count -eq 0) { @('__ALL__') } else { $Script:SCWizard.State.SelectedUsers }
    $list = New-SCCheckList -Items $items -CheckedValues $checked
    [void]$panel.Children.Add($list)
    $Script:SCWizard.Controls.UsersPanel = $list
    return $panel
}

# ── Paso 3: Categorias ────────────────────────────────────────────────

function Show-SCStepCategories {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Categorias de interes"))
    [void]$panel.Children.Add((New-SCParagraph "Selecciona sobre que tipo de actividad quieres consultar. Puedes marcar varias."))

    $templates = Get-SCSavedTemplates
    if ($templates.Count -gt 0) {
        [void]$panel.Children.Add((New-SCLabel "Cargar una plantilla guardada (opcional):" -Bold))
        $tplRow = New-Object System.Windows.Controls.StackPanel
        $tplRow.Orientation = 'Horizontal'
        $tplRow.Margin = [System.Windows.Thickness]::new(0,4,0,16)
        $tplCombo = New-Object System.Windows.Controls.ComboBox
        $tplCombo.Width = 220
        foreach ($t in $templates) { [void]$tplCombo.Items.Add($t) }
        $tplCombo.SelectedIndex = 0
        [void]$tplRow.Children.Add($tplCombo)
        $Script:SCWizard.Controls.TemplateCombo = $tplCombo
        $tplBtn = New-Object System.Windows.Controls.Button
        $tplBtn.Content = "Cargar"
        $tplBtn.Style = (Get-SCStyle "SCBtn")
        $tplBtn.Margin = [System.Windows.Thickness]::new(8,0,0,0)
        $tplBtn.Add_Click({
            $name = $Script:SCWizard.Controls.TemplateCombo.SelectedItem
            if ($name -and (Import-SCTemplate -Name $name)) {
                Render-SCStep
            }
        })
        [void]$tplRow.Children.Add($tplBtn)
        [void]$panel.Children.Add($tplRow)
    }

    $items = foreach ($key in $Script:SC_Categories.Keys) { @{ Value = $key; Label = $Script:SC_Categories[$key].Label } }
    $list = New-SCCheckList -Items $items -CheckedValues $Script:SCWizard.State.SelectedCategories
    [void]$panel.Children.Add($list)
    $Script:SCWizard.Controls.CategoriesPanel = $list
    return $panel
}

# ── Paso 4: Ventana temporal ──────────────────────────────────────────

function Show-SCStepDateTime {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Ventana temporal"))
    [void]$panel.Children.Add((New-SCParagraph "Rango de fechas (opcional, deja en blanco para no limitar) y, si quieres, una franja horaria recurrente dentro de ese rango. Las horas se comparan tal como las guarda cada fuente: en UTC, salvo el registro de cambios de ficheros (USN), que va en la hora local del equipo analizado."))

    $dateRow = New-Object System.Windows.Controls.StackPanel
    $dateRow.Orientation = 'Horizontal'
    $dateRow.Margin = [System.Windows.Thickness]::new(0,12,0,0)

    $lblFrom = New-Object System.Windows.Controls.TextBlock
    $lblFrom.Text = "Desde:"; $lblFrom.VerticalAlignment = 'Center'; $lblFrom.Margin = [System.Windows.Thickness]::new(0,0,8,0)
    [void]$dateRow.Children.Add($lblFrom)
    $dpFrom = New-Object System.Windows.Controls.DatePicker
    $dpFrom.Width = 150
    if ($Script:SCWizard.State.DateFrom) { $dpFrom.SelectedDate = $Script:SCWizard.State.DateFrom }
    [void]$dateRow.Children.Add($dpFrom)

    $lblTo = New-Object System.Windows.Controls.TextBlock
    $lblTo.Text = "Hasta:"; $lblTo.VerticalAlignment = 'Center'; $lblTo.Margin = [System.Windows.Thickness]::new(20,0,8,0)
    [void]$dateRow.Children.Add($lblTo)
    $dpTo = New-Object System.Windows.Controls.DatePicker
    $dpTo.Width = 150
    if ($Script:SCWizard.State.DateTo) { $dpTo.SelectedDate = $Script:SCWizard.State.DateTo }
    [void]$dateRow.Children.Add($dpTo)

    [void]$panel.Children.Add($dateRow)

    $useTime = New-Object System.Windows.Controls.CheckBox
    $useTime.Content = "Limitar ademas a una franja horaria recurrente (por ejemplo, de 23:00 a 06:00 en cualquier dia del rango)"
    $useTime.Margin = [System.Windows.Thickness]::new(0,18,0,4)
    $useTime.IsChecked = [bool]($Script:SCWizard.State.TimeFrom)
    [void]$panel.Children.Add($useTime)

    $timeRow = New-Object System.Windows.Controls.StackPanel
    $timeRow.Orientation = 'Horizontal'
    $timeRow.Margin = [System.Windows.Thickness]::new(0,4,0,0)

    $lblTf = New-Object System.Windows.Controls.TextBlock
    $lblTf.Text = "Hora inicio (HH:mm):"; $lblTf.VerticalAlignment = 'Center'; $lblTf.Margin = [System.Windows.Thickness]::new(0,0,8,0)
    [void]$timeRow.Children.Add($lblTf)
    $tbFrom = New-Object System.Windows.Controls.TextBox
    $tbFrom.Width = 70
    $tbFrom.Text = if ($Script:SCWizard.State.TimeFrom) { $Script:SCWizard.State.TimeFrom.ToString("hh\:mm") } else { "23:00" }
    [void]$timeRow.Children.Add($tbFrom)

    $lblTt = New-Object System.Windows.Controls.TextBlock
    $lblTt.Text = "Hora fin (HH:mm):"; $lblTt.VerticalAlignment = 'Center'; $lblTt.Margin = [System.Windows.Thickness]::new(20,0,8,0)
    [void]$timeRow.Children.Add($lblTt)
    $tbTo = New-Object System.Windows.Controls.TextBox
    $tbTo.Width = 70
    $tbTo.Text = if ($Script:SCWizard.State.TimeTo) { $Script:SCWizard.State.TimeTo.ToString("hh\:mm") } else { "06:00" }
    [void]$timeRow.Children.Add($tbTo)

    [void]$panel.Children.Add($timeRow)

    $Script:SCWizard.Controls.DateFromPicker    = $dpFrom
    $Script:SCWizard.Controls.DateToPicker      = $dpTo
    $Script:SCWizard.Controls.UseTimeWindowCheck= $useTime
    $Script:SCWizard.Controls.TimeFromBox       = $tbFrom
    $Script:SCWizard.Controls.TimeToBox         = $tbTo
    return $panel
}

# ── Paso 5: Palabra clave ─────────────────────────────────────────────

function Show-SCStepKeyword {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Palabra clave (opcional)"))
    [void]$panel.Children.Add((New-SCParagraph "Si buscas algo concreto (nombre de un programa, una web, un fichero...) escribelo aqui. Se buscara dentro de la descripcion de cada hallazgo. Dejalo en blanco para no filtrar."))
    $box = New-Object System.Windows.Controls.TextBox
    $box.Margin = [System.Windows.Thickness]::new(0,12,0,0)
    $box.Text = $Script:SCWizard.State.Keyword
    [void]$panel.Children.Add($box)
    $Script:SCWizard.Controls.KeywordBox = $box

    [void]$panel.Children.Add((New-SCLabel "Excluir si contiene (opcional)" -Bold))
    [void]$panel.Children.Add((New-SCParagraph "Independiente de lo anterior: cualquier hallazgo cuya descripcion contenga este texto se descarta. Util para quitar ruido conocido (por ejemplo, 'OneDrive\logs' o '.tmp'). Dejalo en blanco para no excluir nada."))
    $exBox = New-Object System.Windows.Controls.TextBox
    $exBox.Margin = [System.Windows.Thickness]::new(0,4,0,0)
    $exBox.Text = $Script:SCWizard.State.ExcludeKeyword
    [void]$panel.Children.Add($exBox)
    $Script:SCWizard.Controls.ExcludeKeywordBox = $exBox

    return $panel
}

# ── Paso 6: Resumen y confirmacion ────────────────────────────────────

function Show-SCStepSummary {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Resumen de la consulta"))
    [void]$panel.Children.Add((New-SCParagraph "Revisa los criterios antes de ejecutar la consulta. Se indica que fuentes de datos se van a consultar y cuales no estan disponibles en este proyecto."))

    # Guardar plantilla arriba del todo: si no vas a revisar el resto del
    # resumen, este bloque debe verse sin necesidad de bajar (ContentHost no
    # tiene scroll, y este paso puede ser largo).
    [void]$panel.Children.Add((New-SCLabel "Guardar estos criterios como plantilla (opcional):" -Bold))
    [void]$panel.Children.Add((New-SCParagraph "Guarda categorias, fechas, franja horaria y palabras clave (no el usuario, que depende de cada proyecto) para poder reutilizarlos en otro caso desde el paso de Categorias."))
    $saveRow = New-Object System.Windows.Controls.Grid
    $saveRow.Margin = [System.Windows.Thickness]::new(0,4,0,18)
    $sc1 = New-Object System.Windows.Controls.ColumnDefinition; $sc1.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $sc2 = New-Object System.Windows.Controls.ColumnDefinition; $sc2.Width = [System.Windows.GridLength]::Auto
    [void]$saveRow.ColumnDefinitions.Add($sc1); [void]$saveRow.ColumnDefinitions.Add($sc2)
    $nameBox = New-Object System.Windows.Controls.TextBox
    $nameBox.VerticalContentAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($nameBox,0)
    [void]$saveRow.Children.Add($nameBox)
    $Script:SCWizard.Controls.TemplateNameBox = $nameBox
    $saveBtn = New-Object System.Windows.Controls.Button
    $saveBtn.Content = "Guardar plantilla"
    $saveBtn.Style = (Get-SCStyle "SCBtn")
    $saveBtn.Margin = [System.Windows.Thickness]::new(8,0,0,0)
    [System.Windows.Controls.Grid]::SetColumn($saveBtn,1)
    $saveBtn.Add_Click({
        $n = $Script:SCWizard.Controls.TemplateNameBox.Text.Trim()
        if (-not $n) { Set-SCValidationError "Escribe un nombre para la plantilla."; return }
        $p = Save-SCTemplate -Name $n
        if ($p) { Set-SCProgressText -Text "Plantilla guardada: $p" } else { Set-SCValidationError "No se pudo guardar la plantilla." }
    })
    [void]$saveRow.Children.Add($saveBtn)
    [void]$panel.Children.Add($saveRow)

    $usersTxt = if ($Script:SCWizard.State.SelectedUsers.Count -eq 0 -or $Script:SCWizard.State.SelectedUsers -contains '__ALL__') { "Todos los usuarios" } else { $Script:SCWizard.State.SelectedUsers -join ', ' }
    $catsTxt  = ($Script:SCWizard.State.SelectedCategories | ForEach-Object { $Script:SC_Categories[$_].Label }) -join '; '
    $fromTxt  = if ($Script:SCWizard.State.DateFrom) { $Script:SCWizard.State.DateFrom.ToString("dd/MM/yyyy") } else { "(sin limite)" }
    $toTxt    = if ($Script:SCWizard.State.DateTo)   { $Script:SCWizard.State.DateTo.ToString("dd/MM/yyyy") }   else { "(sin limite)" }
    $timeTxt  = if ($Script:SCWizard.State.TimeFrom) { "$($Script:SCWizard.State.TimeFrom.ToString('hh\:mm')) - $($Script:SCWizard.State.TimeTo.ToString('hh\:mm')) (todos los dias del rango)" } else { "(sin restriccion horaria)" }
    $kwTxt    = if ($Script:SCWizard.State.Keyword) { $Script:SCWizard.State.Keyword } else { "(ninguna)" }
    $exKwTxt  = if ($Script:SCWizard.State.ExcludeKeyword) { $Script:SCWizard.State.ExcludeKeyword } else { "(ninguna)" }

    [void]$panel.Children.Add((New-SCLabel "Usuario(s):" -Bold))
    [void]$panel.Children.Add((New-SCParagraph $usersTxt))
    [void]$panel.Children.Add((New-SCLabel "Categorias:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph $catsTxt))
    [void]$panel.Children.Add((New-SCLabel "Rango de fechas:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph "$fromTxt a $toTxt"))
    [void]$panel.Children.Add((New-SCLabel "Franja horaria:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph $timeTxt))
    [void]$panel.Children.Add((New-SCLabel "Palabra clave:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph $kwTxt))
    [void]$panel.Children.Add((New-SCLabel "Excluir si contiene:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph $exKwTxt))

    $sourceKeys = Get-SCSourcesForCategories -CategoryKeys $Script:SCWizard.State.SelectedCategories
    $available  = [System.Collections.Generic.List[string]]::new()
    $missing    = [System.Collections.Generic.List[string]]::new()
    foreach ($k in $sourceKeys) {
        $entry = Get-SCSourceEntry -Key $k
        $p = Join-Path $Script:SCSession.ANOutputPath $entry.RelPath
        if (Test-Path $p) { $available.Add($k) } else { $missing.Add($k) }
    }

    [void]$panel.Children.Add((New-SCLabel "Fuentes que se consultaran:" -Bold))
    [void]$panel.Children.Add((New-SCParagraph ($(if ($available.Count -gt 0) { $available -join ', ' } else { '(ninguna disponible)' }))))
    if ($missing.Count -gt 0) {
        $warn = New-SCParagraph ("No disponibles en este proyecto (se omiten): " + ($missing -join ', '))
        $warn.Foreground = New-WpfBrush $Script:Colors.Warning
        [void]$panel.Children.Add($warn)
    }

    return $panel
}

# ── Paso 7: Resultados ────────────────────────────────────────────────

function Show-SCStepResults {
    # Cachear el panel entero (DataGrid + DataTable ya construidos) y
    # reutilizarlo tal cual al volver a este paso, en vez de reconstruirlo:
    # WPF permite reasignar el mismo elemento visual a un padre distinto sin
    # problema. Reconstruir la tabla de resultados de cero cada vez que se
    # vuelve atras desde "Informes" reexpone, en cada reconstruccion, el bug
    # de WPF (DataGridItemAttachedStorage, ver Main.ps1) ligado a timing del
    # GC - confirmado que cuantas mas veces se repite la construccion, mas
    # probable es que salte. La cache se invalida en Start-SCFullQuery cuando
    # se ejecuta una consulta nueva.
    if ($Script:SCWizard.Controls.ResultsPanelCache) {
        return $Script:SCWizard.Controls.ResultsPanelCache
    }

    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Resultados"))

    $n = $Script:SCWizard.State.QueryResults.Count
    $summary = $Script:SCWizard.State.QuerySummary
    $infoTxt = "$n hallazgo(s). Desmarca los que no quieras incluir en los informes finales."
    [void]$panel.Children.Add((New-SCParagraph $infoTxt))
    if ($summary -and $summary.TotalFilasSinUsuarioAsociado -gt 0) {
        [void]$panel.Children.Add((New-SCParagraph "Nota: $($summary.TotalFilasSinUsuarioAsociado) fila(s) evaluadas no tenian usuario asociado en su fuente de origen."))
    }

    $onlyConfirmedCheck = New-Object System.Windows.Controls.CheckBox
    $onlyConfirmedCheck.Content = "Mostrar solo Confianza = Confirmado (oculta los de usuario inferido, sin desmarcar su inclusion)"
    $onlyConfirmedCheck.Margin = [System.Windows.Thickness]::new(0,4,0,0)
    [void]$panel.Children.Add($onlyConfirmedCheck)
    $Script:SCWizard.Controls.OnlyConfirmedCheck = $onlyConfirmedCheck

    $grid = New-Object System.Windows.Controls.DataGrid
    $grid.Height = 340
    $grid.AutoGenerateColumns = $false
    $grid.CanUserAddRows = $false
    $grid.IsReadOnly = $false
    $grid.RowHeaderWidth = 0
    $grid.GridLinesVisibility = 'Horizontal'
    $grid.Margin = [System.Windows.Thickness]::new(0,10,0,0)
    # RowDetailsVisibilityMode a Collapsed (no se usa RowDetailsTemplate en
    # este grid): por defecto WPF usa VisibleWhenSelected, que activa el
    # seguimiento interno de DataGridItemAttachedStorage por cada fila. Ese
    # seguimiento tiene un bug conocido de WPF: TryGetValue puede lanzar
    # ArgumentNullException("key") al preparar/reciclar filas con volumenes
    # grandes. Como salta dentro del callback de render de Windows, no es una
    # excepcion manejable: mata el proceso con STATUS_FATAL_USER_CALLBACK_EXCEPTION.
    # Al no usar detalles de fila, se desactiva ese seguimiento por completo.
    $grid.RowDetailsVisibilityMode = [System.Windows.Controls.DataGridRowDetailsVisibilityMode]::Collapsed
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($grid, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($grid, 'Standard')

    # Anchos FIJOS en todas las columnas, nunca Auto: con miles de filas y
    # valores de alta cardinalidad (p.ej. una fecha distinta por fila), un
    # ancho Auto obliga a WPF a medir el contenido de cada fila para calcular
    # el ancho de columna, lo que fuerza preparar muchos mas contenedores de
    # fila de los que la virtualizacion normalmente realizaria - y ese camino
    # (DataGridRow.PrepareRow) es exactamente donde se dispara el bug conocido
    # de WPF que lanza ArgumentNullException("key") y mata el proceso entero.
    # Reproducido y confirmado: con valores de baja cardinalidad (pocos
    # valores distintos repetidos) el bug no aparecia; con 15000 fechas
    # distintas en una columna Auto, se disparaba siempre.
    $colWidths = @{ Fecha = 150; Fuente = 130; Usuario = 130; Confianza = 100; Descripcion = 260; Origen = 220 }
    $colChk = New-Object System.Windows.Controls.DataGridCheckBoxColumn
    $colChk.Header = "Incluir"; $colChk.Binding = New-Object System.Windows.Data.Binding("Incluir"); $colChk.Binding.Mode = 'TwoWay'
    [void]$grid.Columns.Add($colChk)
    foreach ($colName in @('Fecha','Fuente','Usuario','Confianza','Descripcion','Origen')) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header = $colName
        $col.Binding = New-Object System.Windows.Data.Binding($colName)
        $col.Width = $colWidths[$colName]
        [void]$grid.Columns.Add($col)
    }

    # Poblacion de la DataTable EN LINEA (no como llamada a funcion aparte):
    # reproducido y confirmado que llamar a esta misma logica a traves de una
    # funcion separada (con su propio scope/parametros) hacia mucho mas
    # probable el bug de WPF descrito en Main.ps1 sobre DataGridItemAttachedStorage
    # con volumenes grandes de filas - probablemente por la presion adicional
    # de recolector de basura que genera cada llamada a funcion. En linea,
    # con el manejador global de Main.ps1 como red de seguridad adicional.
    $tbl = [System.Data.DataTable]::new("SCResults")
    [void]$tbl.Columns.Add("Incluir", [bool])
    [void]$tbl.Columns.Add("Fecha", [string])
    [void]$tbl.Columns.Add("Fuente", [string])
    [void]$tbl.Columns.Add("Usuario", [string])
    [void]$tbl.Columns.Add("Confianza", [string])
    [void]$tbl.Columns.Add("Descripcion", [string])
    [void]$tbl.Columns.Add("Origen", [string])
    foreach ($r in $Script:SCWizard.State.QueryResults) {
        $row = $tbl.NewRow()
        $row["Incluir"]     = [bool]$r.Incluir
        $row["Fecha"]       = Format-SCFecha $r
        $row["Fuente"]      = $r.Fuente
        $row["Usuario"]     = if ($r.Usuario) { $r.Usuario } else { "(sin usuario asociado)" }
        $row["Confianza"]   = $r.Confianza
        $row["Descripcion"] = $r.Descripcion
        $row["Origen"]      = $r.Origen
        [void]$tbl.Rows.Add($row)
    }
    $grid.ItemsSource = $tbl.DefaultView

    # El filtro solo cambia que filas se VEN (DataView.RowFilter); la
    # DataTable subyacente y su columna "Incluir" no se tocan, asi que
    # Save-SCResultsSelection (que recorre $tbl.Rows por indice) sigue
    # funcionando igual este o no activo el filtro.
    $onlyConfirmedCheck.Add_Click({
        $t = $Script:SCWizard.Controls.ResultsTable
        if (-not $t) { return }
        $t.DefaultView.RowFilter = if ($Script:SCWizard.Controls.OnlyConfirmedCheck.IsChecked) { "Confianza = 'Confirmado'" } else { "" }
    })

    [void]$panel.Children.Add($grid)
    $Script:SCWizard.Controls.ResultsGrid = $grid
    $Script:SCWizard.Controls.ResultsTable = $tbl
    $Script:SCWizard.Controls.ResultsPanelCache = $panel
    return $panel
}

function Save-SCResultsSelection {
    $tbl = $Script:SCWizard.Controls.ResultsTable
    if (-not $tbl) { return }
    for ($i = 0; $i -lt $tbl.Rows.Count; $i++) {
        if ($i -lt $Script:SCWizard.State.QueryResults.Count) {
            $Script:SCWizard.State.QueryResults[$i].Incluir = [bool]$tbl.Rows[$i]["Incluir"]
        }
    }
}

# ── Paso 8: Informes ──────────────────────────────────────────────────

function Show-SCStepReports {
    $panel = New-Object System.Windows.Controls.StackPanel
    [void]$panel.Children.Add((New-SCHeading "Generar informes"))
    [void]$panel.Children.Add((New-SCParagraph "Se generaran dos informes con los mismos hallazgos confirmados: uno pericial formal y otro en lenguaje llano. Elige la carpeta de destino."))

    if (-not $Script:SCWizard.State.ReportOutputDir) {
        $Script:SCWizard.State.ReportOutputDir = Join-Path $Script:SCSession.ProjectPath "CONSULTAS_SC\Consulta_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }

    $row = New-Object System.Windows.Controls.Grid
    $row.Margin = [System.Windows.Thickness]::new(0,14,0,0)
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = [System.Windows.GridLength]::Auto
    [void]$row.ColumnDefinitions.Add($c1); [void]$row.ColumnDefinitions.Add($c2)

    $box = New-Object System.Windows.Controls.TextBox
    $box.Text = $Script:SCWizard.State.ReportOutputDir
    $box.VerticalContentAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($box,0)
    [void]$row.Children.Add($box)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "Examinar..."
    $btn.Style = (Get-SCStyle "SCBtn")
    $btn.Margin = [System.Windows.Thickness]::new(8,0,0,0)
    [System.Windows.Controls.Grid]::SetColumn($btn,1)
    $btn.Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Carpeta donde guardar los informes"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $Script:SCWizard.Controls.ReportDirBox.Text = $dlg.SelectedPath
        }
    })
    [void]$row.Children.Add($btn)
    [void]$panel.Children.Add($row)
    $Script:SCWizard.Controls.ReportDirBox = $box

    $resultBox = New-Object System.Windows.Controls.StackPanel
    $resultBox.Margin = [System.Windows.Thickness]::new(0,20,0,0)
    $Script:SCWizard.Controls.ReportResultPanel = $resultBox
    [void]$panel.Children.Add($resultBox)

    if ($Script:SCWizard.State.ReportPaths.Count -gt 0) {
        Show-SCReportResultLinks
    }

    return $panel
}

function Show-SCReportResultLinks {
    $rp = $Script:SCWizard.Controls.ReportResultPanel
    $rp.Children.Clear()
    $ok = New-SCParagraph "Informes generados correctamente:"
    $ok.Foreground = New-WpfBrush $Script:Colors.Success
    [void]$rp.Children.Add($ok)
    foreach ($p in $Script:SCWizard.State.ReportPaths) { [void]$rp.Children.Add((New-SCParagraph $p)) }

    $btnRow = New-Object System.Windows.Controls.StackPanel
    $btnRow.Orientation = 'Horizontal'
    $btnRow.Margin = [System.Windows.Thickness]::new(0,10,0,0)

    $btnOpen = New-Object System.Windows.Controls.Button
    $btnOpen.Content = "Abrir carpeta de informes"
    $btnOpen.Style = (Get-SCStyle "SCBtnPrimary")
    $btnOpen.HorizontalAlignment = 'Left'
    $btnOpen.Add_Click({ Start-Process explorer.exe $Script:SCWizard.State.ReportOutputDir })
    [void]$btnRow.Children.Add($btnOpen)

    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = "Cerrar aplicacion"
    $btnClose.Style = (Get-SCStyle "SCBtn")
    $btnClose.Margin = [System.Windows.Thickness]::new(8,0,0,0)
    $btnClose.Add_Click({ $Script:SCWizard.Controls.Window.Close() })
    [void]$btnRow.Children.Add($btnClose)

    [void]$rp.Children.Add($btnRow)
}

# ── Motor de transiciones asincronas ──────────────────────────────────

function Start-SCUserPreScan {
    Set-SCBusy -Message "Detectando usuarios del proyecto..."
    $keys = @('EVTX_Logons','EVTX_FailedLogons','Browser_Historial')
    $keyByPath = @{}
    $paths = foreach ($k in $keys) {
        $e = Get-SCSourceEntry -Key $k
        $p = Join-Path $Script:SCSession.ANOutputPath $e.RelPath
        $keyByPath[$p] = $k
        $p
    }
    Invoke-AsyncSourceIndexing -FilePaths $paths -UIContext ([PSCustomObject]@{ KeyByPath = $keyByPath }) `
        -OnProgress {
            param($ui, $cur, $tot, $file)
            Set-SCProgressText -Text "Detectando usuarios... ($cur/$tot) $file" -Current $cur -Total $tot
        } `
        -OnComplete {
            param($ui, $tablesByPath, $errorsByPath)
            foreach ($p in $tablesByPath.Keys) {
                $k = $ui.KeyByPath[$p]
                if ($k) { $Script:SCSession.LoadedTables[$k] = $tablesByPath[$p] }
            }
            $users = [System.Collections.Generic.List[string]]::new()
            foreach ($k in @('EVTX_Logons','EVTX_FailedLogons')) {
                $t = $Script:SCSession.LoadedTables[$k]
                if ($t) {
                    foreach ($r in $t.Rows) {
                        foreach ($col in @('TargetUser','SubjectUser')) {
                            if ($t.Columns.Contains($col)) {
                                $v = $r[$col]
                                if (-not [string]::IsNullOrWhiteSpace($v) -and -not $users.Contains($v)) { $users.Add($v) }
                            }
                        }
                    }
                }
            }
            $bt = $Script:SCSession.LoadedTables['Browser_Historial']
            if ($bt -and $bt.Columns.Contains('Usuario')) {
                foreach ($r in $bt.Rows) {
                    $v = $r['Usuario']
                    if (-not [string]::IsNullOrWhiteSpace($v) -and $v -ne 'desconocido' -and -not $users.Contains($v)) { $users.Add($v) }
                }
            }
            $realUsers = @($users | Where-Object { Test-SCIsRealUser $_ })
            $Script:SCWizard.State.KnownUsers = @($realUsers | Sort-Object)
            Clear-SCBusy
            Move-SCWizardTo -StepKey 'Users'
        }
}

function Start-SCFullQuery {
    $sourceKeys = Get-SCSourcesForCategories -CategoryKeys $Script:SCWizard.State.SelectedCategories
    $pending = $sourceKeys | Where-Object { -not $Script:SCSession.LoadedTables.ContainsKey($_) }

    # $runQuery recibe TODO su estado por parametro ($ui), nunca por closure
    # sobre variables locales de esta funcion: cuando se invoca de forma
    # diferida (tras el DispatcherTimer asincrono), Start-SCFullQuery ya ha
    # retornado y su pila de llamada (con $sourceKeys) ha dejado de existir -
    # una closure sobre $sourceKeys se resuelve a $null en ese momento y la
    # consulta se ejecuta con 0 fuentes. Mismo motivo por el que
    # AsyncLoader.ps1 evita closures y pasa todo por $timer.Tag.
    $runQuery = {
        param($ui)
        $usersSel = if ($Script:SCWizard.State.SelectedUsers -contains '__ALL__' -or $Script:SCWizard.State.SelectedUsers.Count -eq 0) { @() } else { $Script:SCWizard.State.SelectedUsers }
        $q = Invoke-SCQuery -SourceKeys $ui.SourceKeys -Users $usersSel `
                -DateFrom $Script:SCWizard.State.DateFrom -DateTo $Script:SCWizard.State.DateTo `
                -TimeFrom $Script:SCWizard.State.TimeFrom -TimeTo $Script:SCWizard.State.TimeTo `
                -Keyword $Script:SCWizard.State.Keyword -ExcludeKeyword $Script:SCWizard.State.ExcludeKeyword
        $Script:SCWizard.State.QueryResults = $q.Resultados
        $Script:SCWizard.State.QuerySummary = $q.Resumen
        $Script:SCWizard.Controls.ResultsPanelCache = $null   # consulta nueva -> invalidar cache del paso Resultados
        Clear-SCBusy
        Move-SCWizardTo -StepKey 'Results'
    }

    if ($pending.Count -eq 0) {
        Set-SCBusy -Message "Ejecutando consulta..."
        & $runQuery ([PSCustomObject]@{ SourceKeys = $sourceKeys })
        return
    }

    Set-SCBusy -Message "Cargando fuentes seleccionadas..."
    $keyByPath = @{}
    $paths = foreach ($k in $pending) {
        $e = Get-SCSourceEntry -Key $k
        $p = Join-Path $Script:SCSession.ANOutputPath $e.RelPath
        $keyByPath[$p] = $k
        $p
    }
    Invoke-AsyncSourceIndexing -FilePaths $paths -UIContext ([PSCustomObject]@{ KeyByPath = $keyByPath; RunQuery = $runQuery; SourceKeys = $sourceKeys }) `
        -OnProgress {
            param($ui, $cur, $tot, $file)
            Set-SCProgressText -Text "Cargando fuentes... ($cur/$tot) $file" -Current $cur -Total $tot
        } `
        -OnComplete {
            param($ui, $tablesByPath, $errorsByPath)
            foreach ($p in $tablesByPath.Keys) {
                $k = $ui.KeyByPath[$p]
                if ($k) { $Script:SCSession.LoadedTables[$k] = $tablesByPath[$p] }
            }
            Set-SCProgressText -Text "Ejecutando consulta..."
            & $ui.RunQuery $ui
        }
}

function Invoke-SCGenerateReports {
    $dir = $Script:SCWizard.Controls.ReportDirBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($dir)) { Set-SCValidationError "Indica una carpeta de destino."; return }
    $Script:SCWizard.State.ReportOutputDir = $dir
    try {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    } catch {
        Set-SCValidationError "No se pudo crear la carpeta: $($_.Exception.Message)"
        return
    }

    Set-SCBusy -Message "Generando informes..."
    $findings = @($Script:SCWizard.State.QueryResults | Where-Object { $_.Incluir })
    $criteria = [PSCustomObject]@{
        Usuarios   = if ($Script:SCWizard.State.SelectedUsers -contains '__ALL__' -or $Script:SCWizard.State.SelectedUsers.Count -eq 0) { @('Todos los usuarios') } else { $Script:SCWizard.State.SelectedUsers }
        Categorias = @($Script:SCWizard.State.SelectedCategories | ForEach-Object { $Script:SC_Categories[$_].Label })
        DateFrom   = $Script:SCWizard.State.DateFrom
        DateTo     = $Script:SCWizard.State.DateTo
        TimeFrom   = $Script:SCWizard.State.TimeFrom
        TimeTo     = $Script:SCWizard.State.TimeTo
        Keyword    = $Script:SCWizard.State.Keyword
        ExcludeKeyword = $Script:SCWizard.State.ExcludeKeyword
        Resumen    = $Script:SCWizard.State.QuerySummary
    }

    $paths = [System.Collections.Generic.List[string]]::new()
    try {
        $p1 = New-SCReportPericial -OutputDir $dir -Findings $findings -Criteria $criteria
        $paths.Add($p1)
        $p2 = New-SCReportLlano -OutputDir $dir -Findings $findings -Criteria $criteria
        $paths.Add($p2)
        $p3 = Export-SCResultsCsv -OutputDir $dir -Findings $findings
        $paths.Add($p3)
        $Script:SCWizard.State.ReportPaths = @($paths)
        Clear-SCBusy
        Show-SCReportResultLinks
    } catch {
        Clear-SCBusy
        Set-SCValidationError "Error generando los informes: $($_.Exception.Message)"
    }
}

function Export-SCResultsCsv {
    <# Exporta la tabla de hallazgos incluidos a CSV, junto a los dos
       informes HTML, para poder trabajarla en Excel (ordenar, tablas
       dinamicas...) sin depender del HTML. #>
    param([string]$OutputDir, [array]$Findings)
    $csvPath = Join-Path $OutputDir "Resultados_SC.csv"
    $rows = foreach ($f in $Findings) {
        [PSCustomObject]@{
            Fecha       = Format-SCFecha $f
            Fuente      = $f.Fuente
            Usuario     = $f.Usuario
            Confianza   = $f.Confianza
            Descripcion = $f.Descripcion
            Origen      = $f.Origen
        }
    }
    $rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Force
    return $csvPath
}

# ── Render / navegacion ────────────────────────────────────────────────

function Render-SCStep {
    Clear-SCValidationError
    $key = $Script:SCWizard.StepOrder[$Script:SCWizard.StepIndex]
    $ctrl = $Script:SCWizard.Controls
    $ctrl.StepIndicatorText.Text = $Script:SCStepTitles[$key]

    $content = switch ($key) {
        'Project'    { Show-SCStepProject }
        'Users'      { Show-SCStepUsers }
        'Categories' { Show-SCStepCategories }
        'DateTime'   { Show-SCStepDateTime }
        'Keyword'    { Show-SCStepKeyword }
        'Summary'    { Show-SCStepSummary }
        'Results'    { Show-SCStepResults }
        'Reports'    { Show-SCStepReports }
    }
    $ctrl.ContentHost.Child = $content

    $ctrl.BtnBack.IsEnabled = ($Script:SCWizard.StepIndex -gt 0)
    $ctrl.BtnNext.Content = switch ($key) {
        'Summary' { "Ejecutar consulta >" }
        'Results' { "Continuar a informes >" }
        'Reports' { "Generar informes" }
        default   { "Siguiente >" }
    }
}

function Move-SCWizardTo {
    param([string]$StepKey)
    $idx = [array]::IndexOf($Script:SCWizard.StepOrder, $StepKey)
    if ($idx -ge 0) { $Script:SCWizard.StepIndex = $idx; Render-SCStep }
}

function Move-SCWizardNext {
    Clear-SCValidationError
    $key = $Script:SCWizard.StepOrder[$Script:SCWizard.StepIndex]
    switch ($key) {
        'Project' {
            $path = $Script:SCWizard.Controls.ProjectPathBox.Text.Trim()
            if (-not (Test-SCProject -Path $path)) {
                Set-SCValidationError "La carpeta indicada no contiene un analisis MaPeriT.AN valido (se busca la subcarpeta ANALISIS_AN)."
                return
            }
            $Script:SCSession.ProjectPath  = $path
            $Script:SCSession.ANOutputPath = Join-Path $path $Script:AN_OutputFolderName
            $meta = Get-SCProjectMetadata -Path $path
            $Script:SCSession.CaseNumber = $meta.CaseNumber
            $Script:SCSession.Examiner   = $meta.Examiner
            $Script:SCWizard.State.ProjectPath = $path
            Start-SCUserPreScan
        }
        'Users' {
            $sel = Get-SCCheckedValues -Panel $Script:SCWizard.Controls.UsersPanel
            if ($sel.Count -eq 0) { Set-SCValidationError "Selecciona 'Todos los usuarios' o al menos un usuario concreto."; return }
            $Script:SCWizard.State.SelectedUsers = $sel
            Move-SCWizardTo -StepKey 'Categories'
        }
        'Categories' {
            $sel = Get-SCCheckedValues -Panel $Script:SCWizard.Controls.CategoriesPanel
            if ($sel.Count -eq 0) { Set-SCValidationError "Selecciona al menos una categoria de interes."; return }
            $Script:SCWizard.State.SelectedCategories = $sel
            Move-SCWizardTo -StepKey 'DateTime'
        }
        'DateTime' {
            $c = $Script:SCWizard.Controls
            $from = $c.DateFromPicker.SelectedDate
            $to   = $c.DateToPicker.SelectedDate
            if ($from -and $to -and $from -gt $to) { Set-SCValidationError "La fecha 'desde' no puede ser posterior a 'hasta'."; return }
            $Script:SCWizard.State.DateFrom = $from
            $Script:SCWizard.State.DateTo   = if ($to) { ([datetime]$to).Date.AddDays(1).AddSeconds(-1) } else { $null }
            if ($c.UseTimeWindowCheck.IsChecked) {
                $tf = New-Object TimeSpan; $tt = New-Object TimeSpan
                $okF = [TimeSpan]::TryParse($c.TimeFromBox.Text, [ref]$tf)
                $okT = [TimeSpan]::TryParse($c.TimeToBox.Text, [ref]$tt)
                if (-not ($okF -and $okT)) { Set-SCValidationError "Formato de hora invalido. Usa HH:mm, por ejemplo 23:00."; return }
                $Script:SCWizard.State.TimeFrom = $tf
                $Script:SCWizard.State.TimeTo   = $tt
            } else {
                $Script:SCWizard.State.TimeFrom = $null
                $Script:SCWizard.State.TimeTo   = $null
            }
            Move-SCWizardTo -StepKey 'Keyword'
        }
        'Keyword' {
            $Script:SCWizard.State.Keyword        = $Script:SCWizard.Controls.KeywordBox.Text.Trim()
            $Script:SCWizard.State.ExcludeKeyword = $Script:SCWizard.Controls.ExcludeKeywordBox.Text.Trim()
            Move-SCWizardTo -StepKey 'Summary'
        }
        'Summary' { Start-SCFullQuery }
        'Results' {
            Save-SCResultsSelection
            Move-SCWizardTo -StepKey 'Reports'
        }
        'Reports' { Invoke-SCGenerateReports }
    }
}

function Move-SCWizardBack {
    if ($Script:SCWizard.StepIndex -le 0) { return }
    $Script:SCWizard.StepIndex--
    Render-SCStep
}

function Show-SCWizard {
    param([System.Windows.Window]$Window)

    $Script:SCWizard.Controls.Window             = $Window
    $Script:SCWizard.Controls.ContentHost        = $Window.FindName("ContentHost")
    $Script:SCWizard.Controls.StepIndicatorText  = $Window.FindName("StepIndicatorText")
    $Script:SCWizard.Controls.StatusText         = $Window.FindName("StatusText")
    $Script:SCWizard.Controls.WizardProgressBar  = $Window.FindName("WizardProgressBar")
    $Script:SCWizard.Controls.BtnBack            = $Window.FindName("BtnBack")
    $Script:SCWizard.Controls.BtnNext            = $Window.FindName("BtnNext")
    $Script:SCWizard.Controls.BtnCancel          = $Window.FindName("BtnCancel")

    $Script:SCWizard.Controls.BtnNext.Add_Click({ Move-SCWizardNext })
    $Script:SCWizard.Controls.BtnBack.Add_Click({ Move-SCWizardBack })
    # La ventana del propio boton (antes $Window, que solo existia por casualidad en
    # el ambito del script principal)
    $Script:SCWizard.Controls.BtnCancel.Add_Click({ [System.Windows.Window]::GetWindow($this).Close() })

    $Script:SCWizard.StepIndex = 0
    Render-SCStep
}

#endregion
