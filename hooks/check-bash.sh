#!/bin/bash
# PreToolUse hook for Bash commands
# Blocks dangerous operations, warns on risky ones
# Exit 0 = allow, exit 2 = block

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Block 1: Alembic autogenerate (must be run manually and reviewed)
if echo "$COMMAND" | grep -qE 'alembic\s+revision\s+--autogenerate'; then
  echo '{"decision": "block", "reason": "BLOCKED: Alembic autogenerate must be run manually. Run it yourself, review the output, and delete destructive operations before applying. See CLAUDE.md."}'
  exit 2
fi

# Block 2: Direct destructive SQL via psql or Python
if echo "$COMMAND" | grep -qiE '(DROP\s+(TABLE|INDEX|COLUMN|CONSTRAINT|DATABASE)|TRUNCATE\s|DELETE\s+FROM)' | grep -qvE '^\s*#|^\s*--'; then
  echo '{"decision": "block", "reason": "BLOCKED: Destructive SQL detected (DROP/TRUNCATE/DELETE). Ask the user for explicit approval first."}'
  exit 2
fi

# Allow everything else
exit 0
