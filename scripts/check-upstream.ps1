# 检查上游 Renly1994/xiaotang-daozai 是否有新提交，并给出同步提示。
param([switch]$NoFetch)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $remote = git remote get-url origin 2>$null
    if (-not $remote) { throw '未配置 origin 远端，无法检查上游。' }
    if (-not $NoFetch) {
        Write-Output "正在获取上游：$remote"
        git fetch origin --quiet
        if ($LASTEXITCODE -ne 0) { throw 'git fetch 失败，请检查网络或代理。' }
    }
    $local = git log -1 --format='%h %ad %s' --date=short HEAD
    $upstream = git log -1 --format='%h %ad %s' --date=short origin/main
    $behind = [int](git rev-list --count HEAD..origin/main)
    Write-Output "本地基线：$local"
    Write-Output "上游最新：$upstream"
    if ($behind -gt 0) {
        Write-Output ""
        Write-Output "上游有 $behind 个新提交："
        git log --oneline --no-decorate HEAD..origin/main | Select-Object -First 20 | ForEach-Object { Write-Output "  $_" }
        if ($behind -gt 20) { Write-Output "  …（仅显示前 20 条）" }
        Write-Output ""
        Write-Output '同步步骤见 docs/UPSTREAM.md：git merge origin/main → 运行 scripts\rebrand-upstream.ps1 → 按清单检查 → 构建安装。'
    } else {
        Write-Output '已包含上游全部提交。'
    }
} finally { Pop-Location }
