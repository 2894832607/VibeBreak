import Foundation
import VibeBreakCore

struct AgentSourceDescriptor: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let dataURL: URL

    static func builtIn(
        codexDatabaseURL: URL,
        bridgeEventURL: URL
    ) -> [AgentSourceDescriptor] {
        [
            AgentSourceDescriptor(
                id: AgentSourceID.codexDesktop.rawValue,
                name: "Codex Desktop",
                detail: "只读监听 Codex 本地 SQLite 日志",
                dataURL: codexDatabaseURL
            ),
            AgentSourceDescriptor(
                id: AgentSourceID.codexHooks.rawValue,
                name: "Codex Hooks（实验性）",
                detail: "实验性，手动启用并在 Codex /hooks 中信任；UserPromptSubmit / Stop / Interrupt；Stop 可被其他 hook 阻止并续跑，不保证最终完成；与 SQLite 来源互斥",
                dataURL: bridgeEventURL
            ),
            AgentSourceDescriptor(
                id: AgentSourceID.claudeCode.rawValue,
                name: "Claude Code",
                detail: "官方 hooks：UserPromptSubmit / Stop",
                dataURL: bridgeEventURL
            ),
            AgentSourceDescriptor(
                id: AgentSourceID.cursor.rawValue,
                name: "Cursor",
                detail: "官方 hooks：beforeSubmitPrompt / stop",
                dataURL: bridgeEventURL
            ),
            AgentSourceDescriptor(
                id: AgentSourceID.geminiCLI.rawValue,
                name: "Gemini CLI",
                detail: "官方 hooks：BeforeAgent / AfterAgent",
                dataURL: bridgeEventURL
            ),
            AgentSourceDescriptor(
                id: AgentSourceID.openCode.rawValue,
                name: "OpenCode",
                detail: "官方插件事件：session.status",
                dataURL: bridgeEventURL
            ),
            AgentSourceDescriptor(
                id: AgentSourceID.amp.rawValue,
                name: "Amp",
                detail: "官方插件事件：agent.start / agent.end",
                dataURL: bridgeEventURL
            ),
            AgentSourceDescriptor(
                id: AgentSourceID.trae.rawValue,
                name: "Trae",
                detail: "通用 Bridge，需要显式生命周期事件",
                dataURL: bridgeEventURL
            ),
        ]
    }
}
