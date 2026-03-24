#!/bin/bash
# PreToolUse hook for Edit/Write tools
# Blocks modifications to protected files
# Exit 0 = allow, exit 2 = block

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Protected files - notification system (stable, tested, do not touch)
case "$FILE" in
  */notification_manager.py|*/firebase_scheduler.py)
    echo '{"decision": "block", "reason": "BLOCKED: notification_manager.py and firebase_scheduler.py are protected. These are stable and tested - do not modify without explicit permission."}'
    exit 2
    ;;
esac

# Protected files - stable pipeline files
case "$FILE" in
  */services/feed_fetcher.py|*/services/deepseek_processor.py|*/services/data_sanitizer.py|*/services/trends_processor.py|*/threat_intel/ti_collector.py|*/threat_intel/ti_processor.py|*/threat_intel/threat_intel_pipeline.py)
    echo '{"decision": "block", "reason": "BLOCKED: This is a stable pipeline file. Do not modify without explicit permission from the user."}'
    exit 2
    ;;
esac

# Protected files - main.py router registration
case "$FILE" in
  */app/main.py)
    echo '{"decision": "block", "reason": "BLOCKED: main.py router registration is protected. Ask the user before modifying."}'
    exit 2
    ;;
esac

# Protected files - credentials and secrets
case "$FILE" in
  *.env|*/credentials/*|*/config/credentials/*)
    echo '{"decision": "block", "reason": "BLOCKED: Credential/secret files are protected."}'
    exit 2
    ;;
esac

exit 0
