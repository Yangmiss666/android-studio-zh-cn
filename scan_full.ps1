param(
    [string]$AsRoot = "D:\APP\Android\Android Studio",
    [string]$PluginRoot = "d:\XiangMuYuanMa\zh.232.322\extracted_jar",
    [string]$OutCsv = "d:\XiangMuYuanMa\zh.232.322\scan_missing.csv"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$jars = @()
$jars += Get-ChildItem -Path (Join-Path $AsRoot "lib") -Filter "*.jar" -File -Recurse -ErrorAction SilentlyContinue
$jars += Get-ChildItem -Path (Join-Path $AsRoot "plugins") -Filter "*.jar" -File -Recurse -ErrorAction SilentlyContinue

# case-sensitive key set
function Get-KeySet([string]$text) {
    $set = New-Object 'System.Collections.Generic.Dictionary[string,int]'
    $lines = $text -split "`r?`n"; $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]; $t = $line.Trim()
        if ($t -ne "" -and -not $t.StartsWith("#") -and -not $t.StartsWith("!")) {
            $val = $line
            while ($true) {
                $tr = $val.TrimEnd(); $bs = 0
                for ($j = $tr.Length-1; $j -ge 0 -and $tr[$j] -eq '\'; $j--) { $bs++ }
                if ($bs % 2 -eq 1 -and ($i+1) -lt $lines.Count) { $i++; $val = $val + "`n" + $lines[$i] } else { break }
            }
            $idx = $t.IndexOf("=")
            if ($idx -gt 0) { $k = $t.Substring(0,$idx).Trim(); if ($k -ne "") { $set[$k] = 1 } }
        }
        $i++
    }
    return $set
}
function Get-Entries([string]$text) {
    # returns list of key=value blocks (value may be multiline)
    $out = New-Object System.Collections.ArrayList
    $lines = $text -split "`r?`n"; $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]; $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#") -or $t.StartsWith("!")) { $i++; continue }
        $block = $line
        while ($true) {
            $tr = $block.TrimEnd(); $bs = 0
            for ($j = $tr.Length-1; $j -ge 0 -and $tr[$j] -eq '\'; $j--) { $bs++ }
            if ($bs % 2 -eq 1 -and ($i+1) -lt $lines.Count) { $i++; $block = $block + "`n" + $lines[$i] } else { break }
        }
        $idx = $t.IndexOf("=")
        if ($idx -gt 0) {
            $k = $t.Substring(0,$idx).Trim()
            $v = $t.Substring($idx+1).Trim()
            if ($k -ne "") { [void]$out.Add([pscustomobject]@{ Key=$k; Value=$v; Block=$block }) }
        }
        $i++
    }
    return $out
}

$rows = New-Object System.Collections.ArrayList
$processed = New-Object 'System.Collections.Generic.Dictionary[string,int]'
$fileStats = New-Object System.Collections.ArrayList

foreach ($jar in $jars) {
    try { $zip = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName) } catch { continue }
    foreach ($e in $zip.Entries) {
        $fn = $e.FullName
        if (-not $fn.EndsWith(".properties")) { continue }
        # UI bundles only
        $isUi = $fn.StartsWith("messages/") -or $fn.StartsWith("bundle/") -or ($fn -match "(^|/)[A-Za-z0-9]+Bundle\.properties$") -or $fn.StartsWith("com/intellij/") -or $fn.StartsWith("com/android/") -or $fn.StartsWith("com/jetbrains/")
        if (-not $isUi) { continue }
        # exclude deprecated / other locales
        if ($fn -match "DeprecatedMessagesBundle") { continue }
        if ($fn -match "AgreementsBundle_(ja|ko)") { continue }
        if ($processed.ContainsKey($fn)) { continue }
        $processed[$fn] = 1

        try {
            $sr = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
            $enText = $sr.ReadToEnd(); $sr.Close()
        } catch { continue }
        $enEntries = Get-Entries $enText
        if ($enEntries.Count -eq 0) { continue }

        $zhPath = Join-Path $PluginRoot ($fn -replace '/','\')
        $zhKeys = $null
        if (Test-Path $zhPath) { $zhKeys = Get-KeySet ([System.IO.File]::ReadAllText($zhPath, [System.Text.Encoding]::UTF8)) }

        $miss = New-Object System.Collections.ArrayList
        foreach ($ent in $enEntries) {
            if ($zhKeys -eq $null -or -not $zhKeys.ContainsKey($ent.Key)) { [void]$miss.Add($ent) }
        }
        if ($miss.Count -gt 0) {
            [void]$fileStats.Add([pscustomobject]@{ File=$fn; Missing=$miss.Count; HaveFile=($zhKeys -ne $null) })
            foreach ($m in $miss) {
                [void]$rows.Add([pscustomobject]@{ File=$fn; Key=$m.Key; English=$m.Value })
            }
        }
    }
    $zip.Dispose()
}

$rows | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8

Write-Output ("UI bundle files with missing keys: " + $fileStats.Count)
Write-Output ("Total missing UI keys: " + $rows.Count)
Write-Output ""
Write-Output "=== per-file (missing desc) ==="
$fileStats | Sort-Object Missing -Descending | ForEach-Object {
    $tag = if ($_.HaveFile) { "PARTIAL" } else { "NOFILE " }
    Write-Output ("{0,6}  {1}  {2}" -f $_.Missing, $tag, $_.File)
}
Write-Output ""
Write-Output ("detail csv: " + $OutCsv)
