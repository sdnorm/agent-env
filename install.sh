#!/usr/bin/env bash
#
# install.sh — set up agent-env on this machine.
# Idempotent: safe to rerun after a git pull.
#
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")" && pwd)"

echo "== agent-env install =="

# Dependency check (warn, don't fail — CLIs may be installed later)
for dep in tmux git; do
  command -v "$dep" >/dev/null || { echo "ERROR: $dep is required"; exit 1; }
done
for dep in claude pi ollama; do
  command -v "$dep" >/dev/null || echo "WARN: '$dep' not found — install and authenticate it before using wt"
done
command -v grok >/dev/null || echo "WARN: 'grok' not found — install: curl -fsSL https://x.ai/cli/install.sh | bash (auth: browser on first run, or XAI_API_KEY headless)"
for dep in basecamp fizzy; do
  command -v "$dep" >/dev/null || echo "NOTE: '$dep' CLI not found — agents can't reach it until installed and authed (basecamp: 'auth login --device-code'; fizzy: 'auth login')"
done
command -v lsof >/dev/null || command -v ss >/dev/null || echo "WARN: neither lsof nor ss found — port detection will fall back to nc"

# Scripts -> ~/.local/bin
mkdir -p "$HOME/.local/bin"
for f in "$repo_dir"/bin/*; do
  chmod +x "$f"
  ln -sfn "$f" "$HOME/.local/bin/$(basename "$f")"
  echo "linked ~/.local/bin/$(basename "$f")"
done
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "WARN: ~/.local/bin is not on PATH — add it to your shell profile" ;;
esac

# tmux.conf
if [ -f "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
  mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak"
  echo "backed up existing ~/.tmux.conf to ~/.tmux.conf.bak"
fi
ln -sfn "$repo_dir/tmux.conf" "$HOME/.tmux.conf"
echo "linked ~/.tmux.conf"

# qmd: searchable index over agent-mail history (optional)
if command -v qmd >/dev/null; then
  mkdir -p "$HOME/.agents-mail"
  if ! qmd collection list 2>/dev/null | grep -q "qmd://agent-mail/"; then
    qmd collection add "$HOME/.agents-mail" --name agent-mail
  fi
  echo "qmd collection 'agent-mail' registered"
else
  echo "WARN: qmd not found — mail-history search disabled (npm install -g @tobilu/qmd)"
fi

# Instruction blocks, wrapped in markers so reruns replace rather than duplicate
install_block() {
  local target="$1" template="$2"
  local begin="<!-- >>> agent-env managed block >>> -->"
  local end="<!-- <<< agent-env managed block <<< -->"
  mkdir -p "$(dirname "$target")"
  touch "$target"
  if grep -qF "$begin" "$target"; then
    # Replace existing block in place
    awk -v b="$begin" -v e="$end" '
      $0 == b { skip = 1; next }
      $0 == e { skip = 0; next }
      !skip { print }
    ' "$target" > "$target.tmp"
    mv "$target.tmp" "$target"
  fi
  { echo "$begin"; cat "$template"; echo "$end"; } >> "$target"
  echo "installed instructions into $target"
}

install_block "$HOME/.claude/CLAUDE.md" "$repo_dir/templates/claude-instructions.md"
install_block "$HOME/.pi/agent/AGENTS.md" "$repo_dir/templates/pi-instructions.md"

# Credential-guard PreToolUse hook in ~/.claude/settings.json (idempotent merge)
chmod +x "$repo_dir"/hooks/*.js
node - "$HOME/.claude/settings.json" "$repo_dir/hooks/credential-guard.js" << 'EOF'
const fs = require("fs");
const [file, hookPath] = process.argv.slice(2);
let s = {};
try { s = JSON.parse(fs.readFileSync(file, "utf8")); } catch {}
s.hooks = s.hooks || {};
s.hooks.PreToolUse = s.hooks.PreToolUse || [];
const present = s.hooks.PreToolUse.some(e =>
  (e.hooks || []).some(h => String(h.command || "").includes("credential-guard")));
let changed = false;
if (!present) {
  s.hooks.PreToolUse.push({
    matcher: "Bash|Read|Edit|Write",
    hooks: [{ type: "command", command: hookPath, timeout: 10 }],
  });
  changed = true;
  console.log("installed credential-guard hook into " + file);
} else {
  console.log("credential-guard hook already present in " + file);
}
// No AI attribution in commits/PRs (only set if the user hasn't configured it)
if (s.attribution === undefined) {
  s.attribution = { commit: "", pr: "", sessionUrl: false };
  changed = true;
  console.log("disabled commit/PR attribution in " + file);
}
if (changed) fs.writeFileSync(file, JSON.stringify(s, null, 2) + "\n");
EOF

echo "== done =="
