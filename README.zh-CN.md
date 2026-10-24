# VibeBreak

[English](README.md) | 简体中文

VibeBreak 是一个本地 macOS 菜单栏应用，用 AI 编程 Agent 的任务生命周期
自动切换前台应用：

- 任务开始时，立即打开你选择的应用；
- 所有任务结束后，打开另一个应用，或保持当前应用。

VibeBreak 支持 Codex Desktop、Claude Code、Cursor、Gemini CLI、OpenCode、
Amp，以及任何实现本地 Agent Bridge 契约的工具。检测、状态管理和应用切换
全部在本机完成，不上传遥测，也不保存提示词内容。

> 当前为早期 Alpha。Codex Desktop 尚未提供公开的任务生命周期 API，因此
> 适配器被严格隔离；私有日志结构不兼容时会失败关闭，不会猜测事件。

## 功能

- 从任意已安装 macOS 应用中选择任务开始动作。
- 完成动作可选择打开指定应用、恢复首个任务开始前的应用，或保持当前应用。
- 使用明确的完成与中断事件，不依赖静默超时。
- 正确处理并发任务，最后一个任务结束后才执行完成动作。
- 只读访问 Codex Desktop 的 WAL SQLite 日志。
- Claude Code、Cursor、Gemini CLI、OpenCode 和 Amp 支持一键本地接入。
- 本地 JSONL Agent Bridge 支持 Trae 和后续显式事件来源。
- Schema/事件契约门禁、来源状态和本地诊断信息。
- 两阶段动作均可在设置中直接测试。
- 自动迁移旧版 Douyin Break 配置。

## 环境要求

- macOS 13 或更新版本
- 构建应用需要 Swift 5.10 或更新版本
- 执行 Swift Testing 测试需要 Swift 6、Xcode 16 或更新版本
- 使用 Codex 来源时需要 Codex Desktop
- 使用 Trae 来源时需要外部工具写入明确的 Bridge 生命周期事件

`make test` 支持当前 Apple Command Line Tools 和完整 Xcode；CI 与正式发布
仍建议使用完整 Xcode。

## 安装

```bash
cd codex-vibe-break
make install
```

应用安装到：

```text
~/Applications/VibeBreak.app
```

安装器会注册用户级 LaunchAgent，使 VibeBreak 登录后自动启动。卸载应用但
保留设置和日志：

```bash
make uninstall
```

## 配置

点击菜单栏中的闪电图标：

1. 开启自动切换。
2. 安装并启用至少一个事件来源。
3. 选择任务开始时打开的应用。
4. 选择任务完成后打开应用、恢复原应用，或保持当前应用。
5. 使用两个测试按钮验证动作。

设置文件：

```text
~/Library/Application Support/VibeBreak/settings.json
```

诊断日志：

```text
~/Library/Logs/VibeBreak.log
```

## 架构

```text
CodexSQLiteEventSource
JSONLBridgeEventSource
        │ 明确生命周期事件
        ▼
TaskStateMachine
        │ 空闲 ↔ 活跃
        ▼
FocusAutomation
        │ 用户配置
        ▼
MacApplicationOpener
```

核心包将 Agent 来源、协议解析、并发状态和 macOS 动作分层隔离。新增 Agent
时实现 `AgentEventSource`，无需修改任务状态机或设置界面。

更多信息：

- [架构](docs/architecture.md)
- [Codex 适配器契约](docs/codex-adapter.md)
- [Agent 支持矩阵](docs/support-matrix.md)
- [Agent Bridge](docs/agent-bridge.md)
- [Claude Code 接入](docs/claude-code-adapter.md)
- [Cursor 接入](docs/cursor-adapter.md)
- [Gemini CLI 接入](docs/gemini-cli-adapter.md)
- [OpenCode 接入](docs/opencode-adapter.md)
- [Amp 接入](docs/amp-adapter.md)
- [Trae 接入](docs/trae-adapter.md)
- [故障排查](docs/troubleshooting.md)
- [隐私说明](PRIVACY.md)

## 开发

```bash
make build
make test
make app
```

`make app` 生成 `dist/VibeBreak.app`。本项目采用 MIT 许可证，贡献前请阅读
[CONTRIBUTING.md](CONTRIBUTING.md)。

后续能力的优先级与明确非目标见 [ROADMAP.md](ROADMAP.md)。
