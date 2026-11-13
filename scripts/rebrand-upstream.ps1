# 把上游「岛仔 Daozai」品牌机械映射为「椰岛仔 ye-daozai」。可重复执行（幂等）。
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File scripts\rebrand-upstream.ps1 [-Check]
# -Check 只扫描不写入，报告残留的上游品牌；发现残留时退出码为 1。
param([switch]$Check)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
$changed = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$residual = New-Object System.Collections.Generic.List[string]
$skipDirs = @('.git', 'vendor', 'target', 'dist', 'prebuilt', 'node_modules')
$textExts = @('.rs', '.toml', '.md', '.ps1', '.nsi', '.rc', '.cmd', '.bat', '.yml', '.yaml', '.json', '.txt', '.html', '.css', '.js')
$skipNames = @('THIRD_PARTY_NOTICES.txt', 'LICENSE')
# 这些文件本身记录/执行品牌规则，替换会破坏它们。
$skipRel = @('docs/UPSTREAM.md', 'scripts/rebrand-upstream.ps1', 'scripts/check-upstream.ps1')

# 顺序有意义：先处理具体前缀，再处理裸词；负向后顾保证已替换过的文本不会被二次替换。
$rules = @(
    @('xiaotang-daozai', 'ye-daozai'),
    @('xiaotang_daozai', 'ye_daozai'),
    @('(?<!ye[-_])daozai::', 'ye_daozai::'),
    @('(?<!ye[-_])daozai_', 'ye_daozai_'),
    @('(?<!YE_)DAOZAI', 'YE_DAOZAI'),
    @('(?<!Ye)Daozai', 'YeDaozai'),
    @('(?<!ye[-_])daozai', 'ye-daozai'),
    @('(?<!椰)岛仔', '椰岛仔')
)
$residualPattern = '(?<!椰)岛仔|(?<!ye[-_])daozai|(?<!Ye)Daozai|(?<!YE_)DAOZAI|xiaotang'
# 上游署名与外部测试夹具原样保留，不参与替换。
$protected = @(
    'Renly1994/xiaotang-daozai',
    '岛仔 Daozai',
    'DAOZAI-DATE-TEST'
)

function Read-Utf8([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $offset = if ($bom) { 3 } else { 0 }
    [pscustomobject]@{ Text = [System.Text.Encoding]::UTF8.GetString($bytes, $offset, $bytes.Length - $offset); Bom = $bom }
}
function Write-Utf8([string]$Path, [string]$Text, [bool]$Bom) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($Bom)))
}
function Rebrand([string]$Text) {
    $text = $Text
    $index = 0
    foreach ($token in $protected) {
        $marker = [char]1 + 'PROTECT' + $index + [char]1
        $text = $text.Replace($token, $marker)
        $index++
    }
    foreach ($rule in $rules) { $text = [regex]::Replace($text, $rule[0], $rule[1]) }
    $index = 0
    foreach ($token in $protected) {
        $text = $text.Replace([char]1 + 'PROTECT' + $index + [char]1, $token)
        $index++
    }
    return $text
}
function Remove-Protected([string]$Text) {
    $text = $Text
    foreach ($token in $protected) { $text = $text.Replace($token, '') }
    return $text
}
function Test-TextFile([System.IO.FileInfo]$File) {
    if ($skipNames -contains $File.Name) { return $false }
    if ($File.Name -eq 'Cargo.lock') { return $true }
    return $textExts -contains $File.Extension.ToLowerInvariant()
}
function Get-WalkFiles {
    Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object {
        $rel = $_.FullName.Substring($root.Length + 1)
        $parts = $rel.Split([IO.Path]::DirectorySeparatorChar)
        $skip = $false
        foreach ($part in $parts) { if ($skipDirs -contains $part) { $skip = $true } }
        -not $skip
    }
}

# 1) 内容替换：遍历文本文件。
foreach ($file in Get-WalkFiles) {
    if (-not (Test-TextFile $file)) { continue }
    $rel = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
    if ($skipRel -contains $rel) { continue }
    $io = Read-Utf8 $file.FullName
    $text = Rebrand $io.Text
    if ($rel -eq 'Cargo.toml') {
        # 不指回上游仓库；[lib] 的 crate 名必须是合法的下划线标识符，与包名 ye-daozai 不同。
        $text = [regex]::Replace($text, '(?m)^repository = "[^"]*";', 'repository = "https://example.invalid/ye-daozai";')
        $text = [regex]::Replace($text, '(\[lib\](?:\r?\n)name = ")ye-daozai(")', '${1}ye_daozai${2}')
    }
    if ($rel -eq 'src/updates.rs') {
        # 本定制版停用在线更新：固定占位地址，并在 check() 开头直接返回提示。
        $text = [regex]::Replace($text, '(?m)^const REPOSITORY: &str = "[^"]*";', 'const REPOSITORY: &str = "https://example.invalid/ye-daozai";')
        $text = [regex]::Replace($text, '(?m)^const API: &str = "[^"]*";', 'const API: &str = "https://api.github.com/repos/ye-daozai/releases/latest";')
        $text = [regex]::Replace($text, '(?m)^const RELEASES: &str = "[^"]*";', 'const RELEASES: &str = "https://example.invalid/ye-daozai/releases/latest";')
        $text = [regex]::Replace($text,
            '(fn check\(\) -> Result<Option<Release>, String> \{)(\r?\n)(\s*)(let response)',
            '${1}${2}${3}return Err("ye-daozai 为本地定制版，已停用在线更新。".into());${2}${3}${4}')
    }
    if ($text -ne $io.Text) {
        if ($Check) { $changed.Add($rel) }
        else { Write-Utf8 $file.FullName $text $io.Bom; $changed.Add($rel) }
    }
}

# 2) 已知改名：源路径 -> 目标路径，策略 keep-ours（自有资源，不让上游覆盖）或 upstream（上游内容经替换后接管）。
$renames = @(
    @('assets/daozai-logo.png', 'assets/ye-daozai-logo.png', 'keep-ours'),
    @('assets/daozai.ico', 'assets/ye-daozai.ico', 'keep-ours'),
    @('scripts/claude-statusline.ps1', 'scripts/ye-daozai-statusline.ps1', 'upstream'),
    @('安装岛仔.cmd', '安装椰岛仔.cmd', 'upstream'),
    @('收集岛仔诊断.cmd', '收集椰岛仔诊断.cmd', 'upstream'),
    @('src/bin/daozai-record', 'src/bin/ye-daozai-record', 'upstream-dir')
)
foreach ($item in $renames) {
    $source = Join-Path $root $item[0]
    $target = Join-Path $root $item[1]
    if (-not (Test-Path -LiteralPath $source)) { continue }
    if ($item[2] -eq 'keep-ours') {
        if (Test-Path -LiteralPath $target) {
            $warnings.Add("保留自有资源，删除上游文件：$($item[0])")
            if (-not $Check) { Remove-Item -LiteralPath $source -Force }
        } elseif (-not $Check) {
            Move-Item -LiteralPath $source -Destination $target
            $warnings.Add("自有资源缺失，已将上游文件改名：$($item[0]) -> $($item[1])")
        }
    } elseif ($item[2] -eq 'upstream') {
        if ($Check) { $warnings.Add("上游重新引入改名文件：$($item[0])（将合并到 $($item[1])）"); continue }
        if (Test-Path -LiteralPath $target) {
            $io = Read-Utf8 $source
            $text = Rebrand $io.Text
            Write-Utf8 $target $text (Read-Utf8 $target).Bom
            Remove-Item -LiteralPath $source -Force
        } else {
            Move-Item -LiteralPath $source -Destination $target
        }
        $warnings.Add("上游内容已合并到：$($item[1])")
    } else {
        if ($Check) { $warnings.Add("上游重新引入改名目录：$($item[0])"); continue }
        Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
            $sub = $_.FullName.Substring($source.Length).TrimStart('\')
            $dest = Join-Path $target $sub
            New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
            if (Test-TextFile $_) {
                $io = Read-Utf8 $_.FullName
                Write-Utf8 $dest (Rebrand $io.Text) $io.Bom
            } else {
                Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
            }
        }
        Remove-Item -LiteralPath $source -Recurse -Force
        $warnings.Add("上游目录已合并到：$($item[1])")
    }
}

# 3) 语义改造检查：这些是本定制版的手工改动，脚本只能提醒，不能自动恢复。
if (Test-Path -LiteralPath (Join-Path $root 'src/extras.rs')) {
    $extras = (Read-Utf8 (Join-Path $root 'src/extras.rs')).Text
    if ($extras -match 'fn support_author') { $warnings.Add('src/extras.rs 仍有上游“支持作者”区块：请替换为 license_note（见 docs/UPSTREAM.md）。') }
}
if (Test-Path -LiteralPath (Join-Path $root 'README.md')) {
    $readme = (Read-Utf8 (Join-Path $root 'README.md')).Text
    if ($readme -match '(?s)releases/latest.*releases/latest') { $warnings.Add('README.md 可能包含上游下载链接：保留本地定制版说明（见 docs/UPSTREAM.md）。') }
}

# 4) 残留扫描。
foreach ($file in Get-WalkFiles) {
    if (-not (Test-TextFile $file)) { continue }
    $rel = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
    if ($skipRel -contains $rel) { continue }
    $io = Read-Utf8 $file.FullName
    $lines = $io.Text.Split("`n")
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        $checkLine = Remove-Protected $line
        if ([regex]::IsMatch($checkLine, $residualPattern)) {
            $residual.Add(("{0}:{1}: {2}" -f $rel, ($i + 1), $line.Trim()))
        }
    }
}
Pop-Location

$mode = if ($Check) { '扫描' } else { '替换' }
Write-Output "== 品牌$mode完成：修改 $($changed.Count) 个文件 =="
foreach ($item in $changed) { Write-Output "  ~ $item" }
if ($warnings.Count -gt 0) {
    Write-Output '== 需要关注 =='
    foreach ($item in $warnings) { Write-Output "  ! $item" }
}
if ($residual.Count -gt 0) {
    Write-Output '== 残留上游品牌 =='
    foreach ($item in $residual) { Write-Output "  ? $item" }
}
if ($Check -and $residual.Count -gt 0) { exit 1 }
if ($Check -and $changed.Count -eq 0 -and $warnings.Count -eq 0) { Write-Output '没有需要替换的内容。' }
