$ErrorActionPreference = "Stop"
$extractDir = "d:\XiangMuYuanMa\zh.232.322\extracted_jar"
$pluginDir  = "d:\XiangMuYuanMa\zh.232.322\zh.262.322"
$jarPath    = Join-Path $pluginDir "lib\zh.262.322.jar"
$zipPath    = "d:\XiangMuYuanMa\zh.232.322\zh.262.322.zip"
$offDotnet  = "d:\XiangMuYuanMa\zh.232.322\official_242\zh.242.152\dotnet"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# 1) duplicate-key check on our properties
$dupFiles = 0
foreach ($p in (Get-ChildItem -Path $extractDir -Recurse -Filter "*.properties" -File)) {
    $keys = @{}; $dups = 0
    $lines = [System.IO.File]::ReadAllLines($p.FullName, [System.Text.Encoding]::UTF8)
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]; $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#") -or $t.StartsWith("!")) { $i++; continue }
        $val = $line
        while ($true) {
            $tr = $val.TrimEnd(); $bs = 0
            for ($j = $tr.Length-1; $j -ge 0 -and $tr[$j] -eq '\'; $j--) { $bs++ }
            if ($bs % 2 -eq 1 -and ($i+1) -lt $lines.Count) { $i++; $val = $val + "`n" + $lines[$i] } else { break }
        }
        $idx = $t.IndexOf("=")
        if ($idx -gt 0) { $k = $t.Substring(0,$idx).Trim(); if ($k -ne "") { if ($keys.ContainsKey($k)) { $dups++ } else { $keys[$k]=1 } } }
        $i++
    }
    if ($dups -gt 0) { $dupFiles++; Write-Output ("DUP($dups): " + $p.FullName.Substring($extractDir.Length)) }
}
Write-Output "Files with duplicate keys: $dupFiles"

# 2) update dotnet resources from official 242 (Rider .NET; harmless for Android Studio)
if (Test-Path $offDotnet) {
    $dstDotnet = Join-Path $pluginDir "dotnet"
    if (Test-Path $dstDotnet) { Remove-Item $dstDotnet -Recurse -Force }
    Copy-Item -Path $offDotnet -Destination $dstDotnet -Recurse -Force
    Write-Output "dotnet resources updated from official 242"
}

# 3) rebuild JAR (forward-slash entry paths)
if (Test-Path $jarPath) { Remove-Item $jarPath -Force }
$zip = [System.IO.Compression.ZipFile]::Open($jarPath, [System.IO.Compression.ZipArchiveMode]::Create)
$count = 0
foreach ($f in (Get-ChildItem -Path $extractDir -Recurse -File)) {
    $rel = $f.FullName.Substring($extractDir.Length + 1) -replace '\\','/'
    $entry = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
    $es = $entry.Open(); $fs = [System.IO.File]::OpenRead($f.FullName); $fs.CopyTo($es); $fs.Close(); $es.Close()
    $count++
}
$zip.Dispose()
Write-Output "JAR rebuilt: $count files, $((Get-Item $jarPath).Length) bytes"

# 4) rebuild distribution zip
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
$z = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
$baseParent = Split-Path $pluginDir -Parent
foreach ($f in (Get-ChildItem -Path $pluginDir -Recurse -File)) {
    $rel = $f.FullName.Substring($baseParent.Length + 1) -replace '\\','/'
    $entry = $z.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
    $es = $entry.Open(); $fs = [System.IO.File]::OpenRead($f.FullName); $fs.CopyTo($es); $fs.Close(); $es.Close()
}
$null = $z.CreateEntry("zh.262.322/lib/")
$z.Dispose()
Write-Output "ZIP rebuilt: $((Get-Item $zipPath).Length) bytes"

# 5) verify
$v = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
$px = $v.Entries | Where-Object { $_.FullName -eq "META-INF/plugin.xml" }
if ($px) {
    $sr = New-Object System.IO.StreamReader($px.Open()); $txt = $sr.ReadToEnd(); $sr.Close()
    $ver = ($txt -split "`n" | Where-Object { $_ -match "idea-version" }) -join ""
    Write-Output ("plugin.xml: " + $ver.Trim())
}
$v.Dispose()
