#region ============================================================
# MaPeriT.TN - DETECCION DE IOCs Y SEVERIDAD DE FILAS
# ============================================================

function Get-CellSeverity {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "Normal" }

    if ($Value -match $Script:IOCPatterns.EncodedCmd)     { return "Critical" }
    if ($Value -match $Script:IOCPatterns.SuspiciousPath) { return "High" }
    if ($Value -match $Script:IOCPatterns.SuspiciousExe)  { return "High" }
    if ($Value -match $Script:IOCPatterns.IPv4External)   { return "Info" }
    if ($Value -match $Script:IOCPatterns.SHA256)         { return "Info" }
    return "Normal"
}

function Get-RowSeverity {
    param([System.Data.DataRow]$Row)

    $cols = $Row.Table.Columns | ForEach-Object { $_.ColumnName }

    # Columna Severity explicita
    foreach ($c in @('Severity','Severidad','Level','Nivel')) {
        if ($c -in $cols) {
            switch ($Row[$c].ToString().ToUpper()) {
                { $_ -in 'CRITICAL','CRITICA','CRITICO' } { return 'Critical' }
                { $_ -in 'HIGH','ALTA','ALTO' }           { return 'High' }
                { $_ -in 'MEDIUM','MEDIA','MEDIO' }       { return 'Medium' }
            }
        }
    }

    # EventID
    if ('EventID' -in $cols) {
        $eid = 0
        if ([int]::TryParse($Row['EventID'].ToString(), [ref]$eid)) {
            if ($eid -in $Script:EventSeverity.Critical) { return 'Critical' }
            if ($eid -in $Script:EventSeverity.High)     { return 'High' }
            if ($eid -in $Script:EventSeverity.Medium)   { return 'Medium' }
        }
    }

    # Analizar contenido de celdas
    $maxSev = "Normal"
    foreach ($col in $cols) {
        $sev = Get-CellSeverity $Row[$col].ToString()
        switch ($sev) {
            "Critical" { return "Critical" }
            "High"     { if ($maxSev -ne "Critical") { $maxSev = "High" } }
            "Medium"   { if ($maxSev -notin "Critical","High") { $maxSev = "Medium" } }
            "Info"     { if ($maxSev -eq "Normal") { $maxSev = "Info" } }
        }
    }
    return $maxSev
}

function Get-SeverityBrush {
    param([string]$Severity, [bool]$IsAlt = $false)
    $hexColor = switch ($Severity) {
        "Critical" { $Script:Colors.RowCritical  }
        "High"     { $Script:Colors.RowDanger    }
        "Medium"   { $Script:Colors.RowWarning   }
        "Info"     { $Script:Colors.RowInfo      }
        default    { if ($IsAlt) { $Script:Colors.BgCard } else { $Script:Colors.BgPanel } }
    }
    return New-WpfBrush $hexColor
}

function Get-TimestompBrush { return New-WpfBrush $Script:Colors.RowTimestomp }

#endregion
