param(
    [Parameter(Mandatory=$true)][string]$Text,
    [string]$AsRoot = "D:\APP\Android\Android Studio",
    [string]$PluginRoot = "d:\XiangMuYuanMa\zh.232.322\extracted_jar"
)

# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File find_string.ps1 -Text "Some English string"
# 作用: 在 Android Studio 的所有 JAR 中查找包含该英文文本的 .properties 条目,
#       输出它属于哪个资源包(bundle)、键(key)、英文值, 以及插件中是否已有对应翻译。

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path $AsRoot)) { Write-Output "Android Studio 路径不存在: $AsRoot"; exit 1 }

$jars = @()
$jars += Get-ChildItem -Path (Join-Path $AsRoot "lib") -Filter "*.jar" -File -Recurse -ErrorAction SilentlyContinue
$jars += Get-ChildItem -Path (Join-Path $AsRoot "plugins") -Filter "*.jar" -File -Recurse -ErrorAction SilentlyContinue

$needle = $Text.ToLower()
$hits = 0
$seen = New-Object 'System.Collections.Generic.Dictionary[string,int]'

foreach ($jar in $jars) {
    try { $zip = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName) } catch { continue }
    foreach ($e in $zip.Entries) {
        if (-not $e.FullName.EndsWith(".properties")) { continue }
        if ($seen.ContainsKey($e.FullName)) { continue }
        try {
            $sr = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
            $content = $sr.ReadToEnd(); $sr.Close()
        } catch { continue }
        if ($content.ToLower().Contains($needle)) {
            $seen[$e.FullName] = 1
            foreach ($line in ($content -split "`r?`n")) {
                $t = $line.Trim()
                if ($t -eq "" -or $t.StartsWith("#") -or $t.StartsWith("!")) { continue }
                $idx = $t.IndexOf("=")
                if ($idx -le 0) { continue }
                if ($t.ToLower().Contains($needle)) {
                    $k = $t.Substring(0,$idx).Trim()
                    $v = $t.Substring($idx+1)
                    $hits++
                    Write-Output "----------------------------------------------------------------"
                    Write-Output ("资源包 : " + $e.FullName)
                    Write-Output ("键     : " + $k)
                    Write-Output ("英文值 : " + $v)
                    Write-Output ("来源JAR: " + $jar.FullName)
                    # 插件中是否已有该键
                    $zp = Join-Path $PluginRoot ($e.FullName -replace '/','\')
                    if (Test-Path $zp) {
                        $hasKey = $false
                        foreach ($zl in [System.IO.File]::ReadAllLines($zp, [System.Text.Encoding]::UTF8)) {
                            $zt = $zl.Trim()
                            $zi = $zt.IndexOf("=")
                            if ($zi -gt 0 -and $zt.Substring(0,$zi).Trim() -eq $k) { $hasKey = $true; break }
                        }
                        if ($hasKey) {
                            Write-Output "插件状态: 已存在该键(可能已翻译; 若界面仍为英文, 请检查值或大小写)"
                        } else {
                            Write-Output "插件状态: 缺失 -> 请在插件文件的该资源包路径下追加: $k=中文翻译"
                        }
                    } else {
                        Write-Output "插件状态: 该资源包文件在插件中不存在 -> 需新建文件并追加: $k=中文翻译"
                    }
                    Write-Output ("目标文件: " + (Join-Path $PluginRoot ($e.FullName -replace '/','\')))
                }
            }
        }
    }
    $zip.Dispose()
}

Write-Output "================================================================"
if ($hits -eq 0) {
    Write-Output "未找到包含该英文文本的资源包条目。可能原因:"
    Write-Output "  1) 文本来自代码中硬编码的字符串(非 .properties 资源), 无法通过语言包翻译;"
    Write-Output "  2) 文本被 IDE 动态拼接(占位符), 请尝试搜索其中一段连续的英文片段;"
    Write-Output "  3) Android Studio 路径不对, 请用 -AsRoot 指定。"
} else {
    Write-Output ("共找到 $hits 处匹配。")
    Write-Output "下一步: 在『目标文件』末尾追加 `键=中文` 行(UTF-8), 然后运行 final_package.ps1 重新打包。"
}
