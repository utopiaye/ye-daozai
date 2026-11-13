# 跟随上游更新（源码级）

本仓库是 [Renly1994/xiaotang-daozai](https://github.com/Renly1994/xiaotang-daozai)（岛仔 Daozai，MIT）的本地定制版「椰岛仔 ye-daozai」。跟随上游只同步**源码**；应用内在线更新保持停用，安装包始终由本地构建。

## 原理

- `origin` 指向上游仓库，`main` 保存「上游代码 + 品牌替换 + 手工改造」的基线提交。
- `scripts/rebrand-upstream.ps1` 把上游品牌（岛仔 / daozai / Daozai / DAOZAI / xiaotang-daozai）机械映射为椰岛仔品牌，可重复执行，不会把已替换的文本二次替换。
- 手工改造无法机械恢复，合并后按下方清单逐项确认。

## 同步步骤

```bat
:: 1. 查看上游是否有新提交
检查上游更新.cmd

:: 2. 拉取并合并（在项目根目录）
git fetch origin
git merge origin/main

:: 3. 出现冲突时，代码与配置（.rs/.toml/.ps1/.nsi/.rc/.cmd/.yml）优先取上游版本：
git checkout --theirs Cargo.toml src\app.rs ...
git add Cargo.toml src\app.rs ...
:: README.md 冲突取本地版本：git checkout --ours README.md
:: Cargo.lock 冲突取上游版本后由下一步的脚本修正根包名
git checkout --theirs Cargo.lock

:: 4. 重新应用品牌替换（幂等，可反复运行）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\rebrand-upstream.ps1

:: 5. 扫描确认无残留
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\rebrand-upstream.ps1 -Check

:: 6. 按清单检查手工改造

:: 7. 构建、测试并覆盖安装
cargo build --locked --release --bin ye-daozai
cargo test --locked --release --lib
powershell -NoProfile -ExecutionPolicy Bypass -File installer\install.ps1
```

合并完成后提交一次，保持「一个上游版本对应一个本地基线提交」，便于下次继续合并和随时回滚（`git log` 找到上一个基线）。

## 手工改造清单

| 位置 | 要求 |
| --- | --- |
| `src/updates.rs` | 已由脚本自动处理：`REPOSITORY`/`API`/`RELEASES` 为占位地址，`check()` 开头直接返回「已停用在线更新」。不要恢复真实更新源。 |
| `src/extras.rs` 关于页 | 上游可能恢复“支持作者”区块（`fn support_author`）。保持本地版本：显示「开源与许可」说明（`license_note`），不出现赞助二维码。脚本会提醒。 |
| `README.md` | 保持本地定制版说明：能力表、构建/安装方式、上方保留上游署名与 MIT 说明。不恢复上游下载徽章、赞助与交流群入口。 |
| `docs/USAGE.md`、`docs/PRIVACY.md` | 「更新」章节保持“本地定制版，已停用在线更新；升级=重新运行 installer\install.ps1”。 |
| `assets/ye-daozai-logo.png`、`assets/ye-daozai.ico` | 自有生成图标。脚本在合并后会删除上游同名的 `daozai-*.png/.ico`，不会覆盖本地图标。 |
| `LICENSE`、`THIRD_PARTY_NOTICES.txt` | 保留上游版权署名，不得删除。 |
| `Cargo.toml` | 包名 `ye-daozai`、库名 `ye_daozai`（脚本自动修正 `[lib]`）、二进制 `ye-daozai` / `ye-daozai-record`、`repository` 不得指回上游。 |
| 数据与系统标识 | `%APPDATA%\YeDaozai`、`YE_DAOZAI_DATA_DIR`、注册表/托盘/互斥体 `YeDaozai`、keyring 槽位——脚本按规则替换，若上游引入新标识，运行 `-Check` 会报告残留。 |

## 允许保留的上游内容

- Markdown 中的署名链接 `Renly1994/xiaotang-daozai`（README 致谢、`docs/ai-quota-adapters.md` 的 PR 引用）。
- 测试夹具里的外部窗口标题（如 `src/smtc.rs` 中的抖音窗口名），它们模拟第三方程序，不属于产品品牌。
- `vendor/` 下的第三方依赖补丁，不参与替换。

## 版本号

`Cargo.toml` 的 `version` 跟随上游，构建出的安装包版本与上游发布号一致，便于对照上游更新记录（CHANGELOG）。
