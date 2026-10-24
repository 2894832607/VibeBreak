// VibeBreak managed integration v1
import { appendFile, mkdir } from "node:fs/promises"
import { homedir } from "node:os"
import { dirname, join } from "node:path"

const eventFile = join(
  homedir(),
  "Library/Application Support/VibeBreak/bridge/events.jsonl",
)

async function emit(event) {
  await mkdir(dirname(eventFile), { recursive: true })
  await appendFile(
    eventFile,
    `${JSON.stringify({ version: 1, source: "opencode", ...event })}\n`,
    { mode: 0o600 },
  )
}

export const VibeBreakPlugin = async () => ({
  event: async ({ event }) => {
    if (event.type === "session.status") {
      const sessionID = event.properties.sessionID
      const status = event.properties.status.type

      if (status === "busy" || status === "retry") {
        await emit({
          event: "started",
          thread_id: sessionID,
          task_id: sessionID,
        })
      }

      if (status === "idle") {
        await emit({
          event: "finished",
          thread_id: sessionID,
          task_id: sessionID,
          reason: "completed",
        })
      }
    }

    if (event.type === "session.error") {
      const sessionID = event.properties.sessionID
      await emit({
        event: "finished",
        thread_id: sessionID,
        task_id: sessionID,
        reason: "failed",
      })
    }
  },
})
