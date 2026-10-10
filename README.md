# Android Studio 简体中文语言包（zh-CN）

> 适配 **Android Studio Rabbit 1**（2026.2.1 / IntelliJ Platform build 262）

将 Android Studio 界面汉化为简体中文的语言包。基于 JetBrains 官方中文语言包（插件 ID `com.intellij.zh`），扩展兼容范围并补全了大量 Android / Kotlin / Git / Java 等模块的翻译。

## 适配信息

| 项目 | 值 |
|------|-----|
| 插件 ID | `com.intellij.zh` |
| 插件版本 | `262.322` |
| 兼容范围 | build `232` ~ `262.*` |
| 目标 IDE | Android Studio Rabbit 1（2026.2.1，build 262） |
| 界面语言 | 简体中文（zh-CN） |

## 安装

### 方法一：从磁盘安装（推荐）

1. Android Studio → `Settings` → `Plugins`
2. 右上角齿轮 ⚙ → `Install Plugin from Disk...`
3. 选择 `zh.262.322.zip`
4. 重启 IDE
5. `Settings` → `Appearance & Behavior` → `System Settings` → `Language and Region` → 选择「中文」

> 如已安装旧版中文语言包（同为 `com.intellij.zh`），请先禁用以避免冲突。

### 方法二：解压到插件目录

将 `zh.262.322.zip` 解压到 Android Studio 的插件目录，解压后路径应为：

```
<配置目录>/plugins/zh.262.322/lib/zh.262.322.jar
```

Windows 配置目录通常为 `%APPDATA%\Google\AndroidStudio<版本>\plugins`。

## 目录结构

```
.
├── extracted_jar/          # 语言包源文件（各 .properties / search / tips 等）
├── zh.262.322/             # 成品插件目录
│   ├── lib/zh.262.322.jar  # 打包后的语言包 JAR
│   └── dotnet/             # Rider .NET 资源（Android Studio 用不到）
├── zh.262.322.zip          # 可分发的安装包
├── final_package.ps1       # 构建脚本：由 extracted_jar 生成 JAR 与 ZIP
├── find_string.ps1         # 定位工具：查某个英文串属于哪个资源包/键
├── scan_full.ps1           # 扫描缺失的键（键不存在）
└── scan_values.ps1         # 扫描未翻译的键（键存在但值仍是英文）
```

## 构建 / 重新打包

修改 `extracted_jar/` 下的翻译文件后，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "final_package.ps1"
```

脚本会重新生成 `zh.262.322/lib/zh.262.322.jar` 和 `zh.262.322.zip`，然后按上面的方法重新安装即可。**资源包在 IDE 启动时加载，改完必须重启。**

## 如何补充漏译

1. **定位**：把界面上看到的英文传给定位脚本

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "find_string.ps1" -Text "Optimize disk space"
   ```

   它会告诉你该串属于哪个资源包、哪个键、以及要修改的目标文件。

2. **翻译**：在 `extracted_jar` 对应的 `.properties` 文件里追加或替换（格式 `键=中文`，UTF-8，等号两侧不留空格）。

3. **重新打包**：运行 `final_package.ps1`，重新安装 `zh.262.322.zip`，重启 IDE。

> 批量排查可运行 `scan_full.ps1` / `scan_values.ps1`，结果会导出为 CSV。

## 已知限制

语言包的原理是**按路径覆盖 IDE 内置的 `.properties` 资源**，因此：

- **硬编码字符串无法翻译**：Android Studio 自己新写的部分面板（如「模拟器」设置页、「Android SDK」设置页、部分导航项）把英文字符串直接写死在 Kotlin/Java 代码里，语言包机制覆盖不到，这些位置仍会显示英文。这是上游（Google）未做本地化，官方中文语言包同样如此。
- **专有名词保持英文**：如 `Logcat`、`Studio Labs`、`Java`、`Gradle`、`XHTML` 等技术/产品名，按惯例保留英文。

## 来源与致谢

- 基于 JetBrains 官方中文语言包（`com.intellij.zh`）
- 合并官方 `242.152` 版语言包作为高质量基准
- Android 相关资源来自 Android Studio 自带资源文件

## 许可

本项目为语言资源文件的打包与补充，请遵循上游 JetBrains 语言包及 Android Studio 各自的相关许可与条款，仅供学习与个人使用。
