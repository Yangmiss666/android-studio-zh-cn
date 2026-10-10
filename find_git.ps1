$candidates = @(
    (Join-Path $env:ProgramFiles "Git\cmd\git.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Git\cmd\git.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Git\cmd\git.exe"),
    (Join-Path $env:ProgramData "chocolatey\bin\git.exe")
)
foreach ($c in $candidates) { Write-Output ("check: " + $c + " -> " + (Test-Path $c)) }

Write-Output "--- GitHub Desktop bundled git ---"
Get-ChildItem (Join-Path $env:LOCALAPPDATA "GitHubDesktop") -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $g = Join-Path $_.FullName "resources\app\git\cmd\git.exe"
    Write-Output ($g + " -> " + (Test-Path $g))
}

Write-Output "--- scoop ---"
Get-ChildItem (Join-Path $env:USERPROFILE "scoop\apps\git\current\cmd\git.exe") -ErrorAction SilentlyContinue | ForEach-Object { Write-Output $_.FullName }

Write-Output "--- registry uninstall entries mentioning Git ---"
$paths = @(
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
foreach ($p in $paths) {
    Get-ItemProperty $p -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -like "*Git*" } |
      ForEach-Object { Write-Output ($_.DisplayName + "  @  " + $_.InstallLocation) }
}
