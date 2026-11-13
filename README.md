<div align="center">

<img src="assets/ye-daozai-logo.png" width="112" alt="椰岛仔" />

# 椰岛仔 · ye-daozai

**一座小岛，装下桌面日常。**

Windows 桌面信息岛 · Rust + egui 构建 · 不依赖 Electron

</div>

> 本项目是基于开源项目 **岛仔 Daozai**（`Renly1994/xiaotang-daozai`，MIT License）代码改造的本地定制版：品牌、程序名与数据目录改为 **ye-daozai / 椰岛仔**，停用指向上游仓库的在线更新。核心功能与绝大部分代码来自原项目及其贡献者，版权声明见 [LICENSE](LICENSE) 与 [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt)。

椰岛仔平时收起在屏幕边缘，鼠标靠近就展开；切歌、看日程、复制验证码、记一条待办，都能顺手完成。小岛里的伙伴会眨眼、打盹、喝水，也会跟着音乐唱歌。可选刘海或胶囊形态，放在顶部、左侧或右侧，只保留自己需要的功能。

## 能力一览

| 模块 | 能力 |
| --- | --- |
| 音乐 | 通过 Windows 媒体会话（SMTC）读取播放信息，播放/暂停/切歌/音量/进度控制；展开歌词或收起单行歌词；兼容网易云、QQ 音乐、酷狗、汽水音乐 |
| 消息提醒 | 微信、QQ 未读提示，展开查看并点击切换到对应窗口；支持微信多开账号分开显示 |
| 邮件 | QQ、163、126、腾讯企业邮、iCloud、Gmail、自定义 IMAP；正文阅读、验证码识别与一键复制、已读/删除操作 |
| 日历 | 飞书、钉钉、企业微信、iCloud、自定义 CalDAV、Exchange ActiveSync、`.ics` 导入；月历与当日时间线、会议提醒、重复日程 |
| 日常 | 每周/每日重复待办、番茄专注、饮水记录与提醒 |
| 小工具 | 文件置物架（拖入文件临时收集）、文字剪贴板历史（30 条，可固定） |
| AI 额度 | Codex、Claude、Kimi、Grok Bot、Gemini、ZCode、WorkBuddy、DeepSeek、Kiro、豆包；多账号命名与配色 |
| 天气 | Open-Meteo 实况与四天预报，支持自动定位或手动城市，本地缓存 |
| 系统提示 | 电量与电源、网络变化、音量、大写锁定、输入语言、蓝牙设备状态 |
| 外观 | 五款皮肤（经典黑、奶油、毛玻璃浅/深、悬浮云）× 刘海/胶囊两种形态；三边停靠、多屏与自动避让、80%–140% 缩放 |
| 隐私 | 设置与记录保存在本机；邮箱/日历密码与 API Key 存入 Windows 凭据管理器；独立会话用 DPAPI 加密 |

更多操作说明见 [使用指南](docs/USAGE.md)，隐私细节见 [隐私与安全](docs/PRIVACY.md)。

## 系统要求

Windows 10 / 11 x64。默认使用 OpenGL，初始化失败时自动尝试 Direct3D 12。

## 从源码构建

需要 Rust stable、MSVC C++ 构建工具和 Windows SDK：

```powershell
rustup default stable-x86_64-pc-windows-msvc
cargo build --locked --release --bin ye-daozai
.\target\release\ye-daozai.exe
```

运行测试与打包：

```powershell
cargo test --locked --all-targets --features record -- --test-threads=1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\package.ps1
```

测试按单线程运行以隔离使用进程环境变量的数据目录测试。低内存设备可设置 `$env:CARGO_BUILD_JOBS = "1"`。

## 本机部署

推荐使用安装脚本（安装到 `%LOCALAPPDATA%\Programs\YeDaozai`，创建快捷方式并登记卸载信息）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\install.ps1
```

也可以直接双击仓库根目录的 `安装椰岛仔.cmd`，或直接运行构建产物作为便携版。

- 用户数据：`%APPDATA%\YeDaozai`；可用环境变量 `YE_DAOZAI_DATA_DIR` 指定独立目录。
- 升级：本地定制版已停用在线更新。获取新构建后重新运行安装脚本覆盖安装即可，设置与数据会保留。
- 卸载：使用 Windows「已安装的应用」中的卸载项，或 `installer\uninstall.ps1`；卸载保留用户数据。

## 项目结构

```
src/
├── main.rs               Windows 外壳：窗口、托盘、系统事件与后台服务衔接
├── app.rs / pages.rs     应用状态与主界面
├── native.rs / system.rs 原生窗口、输入、拖放与系统事件
├── composition.rs        毛玻璃底板与窗口合成
├── renderer.rs / graphics.rs / paint.rs   渲染与绘制
├── smtc.rs / lyrics.rs / *_playback.rs    媒体会话、歌词与播放器兼容
├── mail*.rs              IMAP、MIME、验证码与邮件 UI
├── calendar*.rs          CalDAV/EAS/ICS 与日历 UI
├── quota.rs / *_quota.rs AI 额度与各服务适配
├── messenger* / wechat.rs                 微信、QQ 未读监测
├── weather*.rs / clipboard.rs / icons.rs  天气、剪贴板与文件图标
├── bin/ye-daozai-record/ 无窗口演示录制器（软件光栅化）
└── ui_tests.rs           无窗口交互与布局回归测试
vendor/                   少量上游补丁（eframe/egui/imap/imap-proto/ureq）
installer/ scripts/       安装、卸载、打包与诊断脚本
```

技术要点：

- **Rust 2021 + eframe/egui 0.31**：即时模式 UI，自绘岛体、宠物与动画；`vendor/` 中维护少量上游补丁。
- **Windows 原生集成**（`windows` crate 0.58）：无边框透明置顶窗口、DWM 毛玻璃合成、系统托盘、单实例、全局输入、任务栏闪动与未读、蓝牙、电源、注册表开机自启。
- **WinRT 通知与媒体**：通过系统媒体传输控制（SMTC）与通知中心获取播放和消息信息。
- **后台服务线程**：邮件、日历、额度、微信/QQ 监听、图标缩略图等均以独立线程运行，UI 只消费事件快照。
- **无头测试**：大量 UI/布局回归测试在无窗口环境下直接驱动 `egui`；`record` 特性提供合成数据录制器。

## 开源与致谢

本项目代码沿用 MIT License。原项目「岛仔 Daozai」版权归其作者及贡献者所有；Rust 依赖、vendored 代码、第三方图标与素材沿用各自的许可或权利声明。详见 [第三方声明](THIRD_PARTY_NOTICES.txt) 和 [依赖说明](docs/DEPENDENCIES.md)。

本定制版重新生成了 ye-daozai / 椰岛仔的品牌图标，未使用原项目的商标与 Logo 素材。
