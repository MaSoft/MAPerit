#region ============================================================
# MaPeriT.OF - FASE 6: NAVEGADORES WEB
# Copia artefactos de navegadores desde perfiles de usuario del disco objetivo
# ============================================================

function Invoke-Phase6-Browsers {
    param([string]$OutputPath)

    $phasePath = Join-Path $OutputPath $Script:OutputDirs.Browsers
    $phaseNum  = 6
    $collected = 0

    Write-PhaseHeader -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum]

    foreach ($user in Get-TargetUserPaths) {
        Write-StepHeader "6.x Navegadores - $($user.Name)"

        # --- Chromium (Chrome, Edge, Brave) ---
        foreach ($browser in @('Chrome','Edge','Brave')) {
            $profileBase = Join-Path $user.Root $Script:BrowserPaths[$browser]
            if (-not (Test-Path $profileBase)) { continue }

            $profiles = @("Default") + (Get-ChildItem $profileBase -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^Profile \d+$' } | Select-Object -ExpandProperty Name)

            foreach ($profile in $profiles) {
                $profilePath = Join-Path $profileBase $profile
                if (-not (Test-Path $profilePath)) { continue }

                # Misma estructura que MaPeriT.SW (<navegador>\<usuario>\<perfil>): es la
                # que espera MaPeriT.AN; con <usuario>\<navegador> no analizaba ninguno.
                $destBase = Join-Path $phasePath "$browser\$($user.Name)\$profile"

                foreach ($file in $Script:ChromiumFiles) {
                    $src = Join-Path $profilePath $file
                    if (Test-Path $src) {
                        $dest = Join-Path $destBase $file
                        if (Copy-ForensicFile -SourcePath $src -DestPath $dest -Phase "FASE_6" -Method "browser_copy") {
                            $collected++
                        }
                    }
                }
            }
        }

        # --- Firefox ---
        $ffBase = Join-Path $user.Root $Script:BrowserPaths.Firefox
        if (Test-Path $ffBase) {
            $ffProfiles = Get-ChildItem $ffBase -Directory -ErrorAction SilentlyContinue
            foreach ($ffProf in $ffProfiles) {
                $destBase = Join-Path $phasePath "Firefox\$($user.Name)\$($ffProf.Name)"
                foreach ($file in $Script:FirefoxFiles) {
                    $src = Join-Path $ffProf.FullName $file
                    if (Test-Path $src) {
                        $dest = Join-Path $destBase $file
                        if (Copy-ForensicFile -SourcePath $src -DestPath $dest -Phase "FASE_6" -Method "browser_copy") {
                            $collected++
                        }
                    }
                }
            }
        }

        # --- Internet Explorer / WebCache ---
        $ieBase = Join-Path $user.Root $Script:BrowserPaths.IE
        if (Test-Path $ieBase) {
            $destIE = Join-Path $phasePath "InternetExplorer\$($user.Name)"
            $n = Copy-ForensicDirectory -SourceDir $ieBase -DestDir $destIE -Phase "FASE_6" -Filter "*.dat" -Recurse
            if ($n -gt 0) { $collected += $n }
        }

        if ($collected -gt 0) {
            Write-ForensicLog -Phase "FASE_6" -Action "BROWSERS_USUARIO" -Target $user.Name -Result "OK" -Detail "$collected artefactos"
        }
    }

    Write-PhaseComplete -PhaseNumber $phaseNum -PhaseName $Script:PhaseNames[$phaseNum] -ItemsCollected $collected
    return $collected
}
