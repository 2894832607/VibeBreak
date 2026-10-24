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
    `${JSON.stringify({ version: 1, source: "amp", ...event })}\n`,
    { mode: 0o600 },
  )
}

export default function registerVibeBreak(amp) {
  amp.on("agent.start", async (event) => {
    const threadID = event.thread.id
    await emit({
      event: "started",
      thread_id: threadID,
      task_id: threadID,
    })
  })

  amp.on("agent.end", async (event) => {
    const threadID = event.thread.id
    await emit({
      event: "finished",
      thread_id: threadID,
      task_id: threadID,
      reason: "completed",
    })
  })
}
