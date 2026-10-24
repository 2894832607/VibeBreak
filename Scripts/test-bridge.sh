#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
export VIBEBREAK_TEST_BINARY="$(/usr/bin/swift build --show-bin-path)/vibebreak-bridge-emit"
python3 - <<'PY'
import json
import os
import subprocess
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory(prefix="vibebreak-bridge-test-") as directory:
    bridge = Path(directory) / "events.jsonl"
    environment = {
        **os.environ,
        "VIBEBREAK_BRIDGE_FILE": str(bridge),
        "VIBEBREAK_SOURCE_ID": "claude-code",
    }

    def emit(payload, success=True):
        result = subprocess.run(
            [os.environ["VIBEBREAK_TEST_BINARY"]],
            input=json.dumps(payload), text=True, capture_output=True,
            env=environment, check=False,
        )
        assert (result.returncode == 0) == success, result.stderr
        if success:
            assert json.loads(result.stdout) == {}

    def records():
        return [json.loads(line) for line in bridge.read_text().splitlines()]

    emit({"hook_event_name": "UserPromptSubmit", "session_id": "session/one"})
    emit({"hook_event_name": "UserPromptSubmit", "session_id": "session_one"})
    emit({"hook_event_name": "Stop", "session_id": "session/one"})
    emit({"hook_event_name": "Stop", "session_id": "session_one"})
    events = records()
    assert len(events) == 4
    assert events[0]["task_id"] == events[2]["task_id"]
    assert events[1]["task_id"] == events[3]["task_id"]
    assert events[0]["task_id"] != events[1]["task_id"]
    assert events[2]["thread_id"] == "session/one"
    assert events[3]["thread_id"] == "session_one"
    assert (Path(directory) / "state").is_dir()

    before = bridge.read_bytes()
    emit({
        "version": 1, "source": "trae", "event": "started",
        "thread_id": "", "task_id": "invalid",
    }, success=False)
    assert bridge.read_bytes() == before
    assert bridge.stat().st_mode & 0o777 == 0o600

print("Bridge executable tests passed: task pairing, path isolation, validation, permissions.")
PY
