#!/usr/bin/env python3
"""스킬·서브에이전트 사용 기록 훅.

UserPromptSubmit: 유저 지시를 기록하고 세션별 state에 최신 지시를 저장.
PostToolUse(Skill·Task·Agent): 사용 레코드에 유발 지시 스니펫을 임베드해 기록.
fail-open — 어떤 오류에도 exit 0. 기록 실패가 작업을 막지 않는다.
"""
import json
import os
import re
import sys
import time
from datetime import datetime, timezone

LOG_DIR = os.environ.get("USAGE_LOG_DIR") or os.path.expanduser("~/.claude/usage-log")
PROMPT_LIMIT = 500
DETAIL_LIMIT = 200
SESSION_STATE_TTL_DAYS = 7


def now_iso():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def truncate(text, limit):
    text = str(text or "").strip()
    return text if len(text) <= limit else text[:limit] + "…"


def log_path():
    return os.path.join(LOG_DIR, datetime.now().strftime("%Y-%m-%d") + ".jsonl")


def state_path(session_id):
    safe_id = re.sub(r"[^\w.-]", "_", session_id or "unknown")
    return os.path.join(LOG_DIR, ".sessions", safe_id + ".json")


def append_record(record):
    os.makedirs(LOG_DIR, exist_ok=True)
    with open(log_path(), "a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


def enforce_dir_permission():
    try:
        os.chmod(LOG_DIR, 0o700)
    except OSError:
        pass


def prune_stale_sessions():
    sessions_dir = os.path.join(LOG_DIR, ".sessions")
    cutoff = time.time() - SESSION_STATE_TTL_DAYS * 86400
    try:
        for entry in os.listdir(sessions_dir):
            path = os.path.join(sessions_dir, entry)
            if os.path.getmtime(path) < cutoff:
                os.remove(path)
    except OSError:
        pass


def save_instruction(session_id, prompt):
    path = state_path(session_id)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"instruction": truncate(prompt, PROMPT_LIMIT)}, f, ensure_ascii=False)


def load_instruction(session_id):
    try:
        with open(state_path(session_id), encoding="utf-8") as f:
            return json.load(f).get("instruction", "")
    except (OSError, ValueError):
        return ""


def base_record(event, data):
    return {
        "ts": now_iso(),
        "event": event,
        "session_id": data.get("session_id", ""),
        "cwd": data.get("cwd", ""),
    }


def handle_prompt(data):
    prompt = data.get("prompt", "")
    snippet = truncate(prompt, PROMPT_LIMIT)
    save_instruction(data.get("session_id"), prompt)

    record = base_record("prompt", data)
    record["prompt"] = snippet
    slash = re.match(r"^/([\w:-]+)", prompt.strip())
    if slash:
        record["slash_command"] = slash.group(1)
    append_record(record)

    if slash:
        skill_record = base_record("skill", data)
        skill_record["name"] = slash.group(1)
        skill_record["via"] = "slash"
        skill_record["instruction"] = snippet
        append_record(skill_record)

    enforce_dir_permission()
    prune_stale_sessions()


def handle_tool(data):
    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}
    if tool_name == "Skill":
        record = base_record("skill", data)
        record["name"] = tool_input.get("skill", "")
        record["via"] = "tool"
        args = truncate(tool_input.get("args", ""), DETAIL_LIMIT)
        if args:
            record["args"] = args
    elif tool_name in ("Task", "Agent"):
        record = base_record("agent", data)
        record["name"] = tool_input.get("subagent_type") or "general-purpose"
        record["detail"] = truncate(tool_input.get("description", ""), DETAIL_LIMIT)
    else:
        return
    record["instruction"] = load_instruction(data.get("session_id"))
    append_record(record)


def main():
    data = json.load(sys.stdin)
    event = data.get("hook_event_name", "")
    if event == "UserPromptSubmit":
        handle_prompt(data)
    elif event == "PostToolUse":
        handle_tool(data)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
