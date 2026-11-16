#region ============================================================
# MaPeriT.TN - LOGGING (consola)
# ============================================================

function Write-TNLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )
    $ts    = Get-Date -Format 'HH:mm:ss'
    $color = switch ($Level) {
        'WARNING' { 'Yellow'   }
        'ERROR'   { 'Red'      }
        'DEBUG'   { 'DarkGray' }
        default   { 'Cyan'     }
    }
    Write-Host "  [$ts][$Level] $Message" -ForegroundColor $color
}

#endregion
