#!/bin/bash
# Sync Claude Code config to this repo for backup
# Run: ./sync.sh
# Auto-run: ./sync.sh --push (syncs and pushes to GitHub)

set -e
BACKUP_DIR="/home/manan/claude-config"
CLAUDE_DIR="/home/manan/.claude"

echo "Syncing Claude Code configuration..."

# 1. Global settings
cp "$CLAUDE_DIR/settings.json" "$BACKUP_DIR/global-settings.json"

# 2. Per-project memory files
for project_dir in "$CLAUDE_DIR"/projects/*/; do
  project_name=$(basename "$project_dir")
  memory_dir="$project_dir/memory"

  if [ -d "$memory_dir" ]; then
    target="$BACKUP_DIR/memory/$project_name"
    mkdir -p "$target"
    rsync -a --delete "$memory_dir/" "$target/"
    echo "  Synced memory: $project_name"
  fi
done

# 3. Per-project .claude directories (skills, hooks, rules, local settings)
for project_path in /home/manan/*/; do
  project_name=$(basename "$project_path")
  claude_dir="$project_path/.claude"

  if [ -d "$claude_dir" ]; then
    target="$BACKUP_DIR/projects/$project_name"
    mkdir -p "$target"
    # Copy everything except settings.local.json (may have machine-specific paths)
    rsync -a --exclude='settings.local.json' "$claude_dir/" "$target/"
    # Copy settings.local.json separately (for reference, clearly labeled)
    if [ -f "$claude_dir/settings.local.json" ]; then
      cp "$claude_dir/settings.local.json" "$target/settings.local.json"
    fi
    echo "  Synced project: $project_name"
  fi
done

# 4. Sudoers rule (for reference)
if [ -f /etc/sudoers.d/manan-claude ]; then
  sudo cat /etc/sudoers.d/manan-claude > "$BACKUP_DIR/sudoers-manan-claude.txt" 2>/dev/null || echo "# Could not read sudoers (need sudo)" > "$BACKUP_DIR/sudoers-manan-claude.txt"
fi

echo ""
echo "Sync complete. Files in $BACKUP_DIR"

# Auto-push if --push flag
if [ "$1" = "--push" ]; then
  cd "$BACKUP_DIR"
  git add -A
  if git diff --cached --quiet; then
    echo "No changes to push."
  else
    git commit -m "Sync Claude Code config $(date +%Y-%m-%d)"
    git push
    echo "Pushed to GitHub."
  fi
fi
