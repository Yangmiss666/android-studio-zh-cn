param(
    [string]$AsRoot = "D:\APP\Android\Android Studio",
    [string]$PluginRoot = "d:\XiangMuYuanMa\zh.232.322\extracted_jar",
    [string]$OutCsv = "d:\XiangMuYuanMa\zh.232.322\scan_untranslated.csv"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Unescape([string]$v) {
    $v = $v -replace '\\\\','\'
    $v = $v -replace '\\:',':'
    $v = $v -replace '\\=','='
    $v = $v -replace '\\#','#'
    $v = $v -replace '\\!','!'
    $v = $v -replace "\\'","'"
    return $v.Trim()
}
function Get-Map([string]$text) {
    # returns case-sensitive dict key -> list of full values (normalized), handling continuations
    $map = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $lines = $text -split "`r?`n"; $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]; $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#") -or $t.StartsWith("!")) { $i++; continue }
        $full = $line
        while ($true) {
            $tr = $full.TrimEnd(); $bs = 0
            for ($j = $tr.Length-1; $j -ge 0 -and $tr[$j] -eq '\'; $j--) { $bs++ }
            if ($bs % 2 -eq 1 -and ($i+1) -lt $lines.Count) { $i++; $full = $full + "`n" + $lines[$i] } else { break }
        }
        $idx = $full.IndexOf("=")
        if ($idx -gt 0) {
            $k = $full.Substring(0,$idx).Trim()
            $v = $full.Substring($idx+1)
            if ($k -ne "") { $map[$k] = $v }
        }
        $i++
    }
    return $map
}

$jars = @()
$jars += Get-ChildItem -Path (Join-Path $AsRoot "lib") -Filter "*.jar" -File -Recurse -ErrorAction SilentlyContinue
$jars += Get-ChildItem -Path (Join-Path $AsRoot "plugins") -Filter "*.jar" -File -Recurse -ErrorAction SilentlyContinue

$rows = New-Object System.Collections.ArrayList
$processed = New-Object 'System.Collections.Generic.Dictionary[string,int]'
$stats = New-Object System.Collections.ArrayList

foreach ($jar in $jars) {
    try { $zip = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName) } catch { continue }
    foreach ($e in $zip.Entries) {
        $fn = $e.FullName
        if (-not $fn.EndsWith(".properties")) { continue }
        $isUi = $fn.StartsWith("messages/") -or $fn.StartsWith("bundle/") -or ($fn -match "(^|/)[A-Za-z0-9]+Bundle\.properties$") -or $fn.StartsWith("com/intellij/") -or $fn.StartsWith("com/android/") -or $fn.StartsWith("com/jetbrains/")
        if (-not $isUi) { continue }
        if ($fn -match "DeprecatedMessagesBundle") { continue }
        if ($fn -match "AgreementsBundle_(ja|ko)") { continue }
        if ($processed.ContainsKey($fn)) { continue }
        $processed[$fn] = 1

        $zhPath = Join-Path $PluginRoot ($fn -replace '/','\')
        if (-not (Test-Path $zhPath)) { continue }   # missing files handled by other scan

        try {
            $sr = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
            $enText = $sr.ReadToEnd(); $sr.Close()
        } catch { continue }
        $en = Get-Map $enText
        $zh = Get-Map ([System.IO.File]::ReadAllText($zhPath, [System.Text.Encoding]::UTF8))

        $cnt = 0
        foreach ($k in $en.Keys) {
            if (-not $zh.ContainsKey($k)) { continue }   # missing key: other scan
            $ev = Unescape $en[$k]
            $zv = Unescape $zh[$k]
            if ($ev -eq $zv -and $ev -match "[A-Za-z]{3,}") {
                # value unchanged (still English)
                [void]$rows.Add([pscustomobject]@{ File=$fn; Key=$k; English=($ev -replace "`r?`n"," ") })
                $cnt++
            }
        }
        if ($cnt -gt 0) { [void]$stats.Add([pscustomobject]@{ File=$fn; Untranslated=$cnt }) }
    }
    $zip.Dispose()
}

$rows | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
Write-Output ("Files with UNTRANSLATED values: " + $stats.Count)
Write-Output ("Total untranslated keys: " + $rows.Count)
Write-Output ""
$stats | Sort-Object Untranslated -Descending | Select-Object -First 60 | ForEach-Object { Write-Output ("{0,6}  {1}" -f $_.Untranslated, $_.File) }
Write-Output ""
Write-Output ("detail csv: " + $OutCsv)
