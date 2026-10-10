param(
    [Parameter(Mandatory=$true)][string]$Text,
    [string]$AsRoot = "D:\APP\Android\Android Studio",
    [int]$MaxSize = 4000000
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$needle = $Text.ToLower()
$jars = @()
$jars += Get-ChildItem -Path (Join-Path $AsRoot "lib") -Filter "*.jar" -File -Recurse -ErrorAction SilentlyContinue
$jars += Get-ChildItem -Path (Join-Path $AsRoot "plugins") -Filter "*.jar" -File -Recurse -ErrorAction SilentlyContinue
$hits = 0
foreach ($jar in $jars) {
    try { $zip = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName) } catch { continue }
    foreach ($e in $zip.Entries) {
        if ($e.Length -gt $MaxSize -or $e.Length -eq 0) { continue }
        try {
            $s = $e.Open(); $ms = New-Object System.IO.MemoryStream; $s.CopyTo($ms); $s.Close()
            $bytes = $ms.ToArray(); $ms.Dispose()
        } catch { continue }
        $txt = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)
        if ($txt.ToLower().Contains($needle)) {
            $hits++
            Write-Output ($e.FullName + "   @ " + $jar.Name)
            if ($hits -ge 15) { break }
        }
    }
    $zip.Dispose()
    if ($hits -ge 15) { break }
}
Write-Output ("hits: " + $hits)
