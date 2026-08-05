# agent-env

Portable dev-agent orchestration: git worktrees + tmux + a file mailbox that
lets Claude Code and pi (Kimi on Ollama cloud) hand off tasks to each other.

## Required tooling

Core (install.sh fails without these):

| Tool | Purpose | macOS | Debian/Ubuntu |
|------|---------|-------|---------------|
| git ≥2.5 | worktrees | `brew install git` | `apt install git` |
| tmux ≥3.2 | sessions/panes/nudges | `brew install tmux` | `apt install tmux` |

Agent CLIs (install.sh warns; needed before the panes are useful):

| Tool | Purpose | Install | Auth (one-time) |
|------|---------|---------|-----------------|
| claude | top-left pane | `npm install -g @anthropic-ai/claude-code` | `claude` (login flow) |
| [pi](https://pi.dev/) | bottom-left pane | `bun add -g --ignore-scripts @earendil-works/pi-coding-agent` | uses ollama (see below) |
| ollama | runs pi's Kimi model | [ollama.com/download](https://ollama.com/download) or `curl -fsSL https://ollama.com/install.sh \| sh` | `ollama signin` (cloud models) |
| qmd | mail-history search | `npm install -g @tobilu/qmd` (npm, **not bun** — see below) | none |

Runtimes and support tools:

- **Node.js ≥22** — for claude and qmd (`brew install node` / nvm / apt)
- **Bun** — for pi (`curl -fsSL https://bun.sh/install | bash`)
- **lsof** or **ss** — free-port detection; preinstalled on macOS, `apt install lsof` or `iproute2` on Linux
- **gh** (optional) — only for cloning this repo over HTTPS with auth / repo management
- A Rails project whose `bin/dev` respects the `PORT` env var (standard since Rails 7)

### pi notes

[pi](https://pi.dev/) ([docs](https://pi.dev/docs/latest) ·
[GitHub](https://github.com/earendil-works/pi)) is a minimal coding-agent
harness supporting 15+ providers. How it's used here:

- `wt` launches it via `ollama launch pi --model kimi-k3:cloud`, so the model
  comes from Ollama cloud — no separate pi API key, just `ollama signin`.
- Its global instructions live at `~/.pi/agent/AGENTS.md`, which is exactly
  where `install.sh` writes the agent-mail protocol block. pi also reads
  `AGENTS.md` from the project/worktree, so repo-level instructions still apply.
- Switch models mid-session with `/model` (or `Ctrl+L`); to change the default
  wt uses, set `WT_PI_CMD`.
- `pi -p "query"` is its non-interactive print mode — useful if you ever want
  claude to call pi directly for one-shot subtasks instead of via the mailbox.

## Setup on a new machine

```sh
git clone git@github.com:sdnorm/agent-env.git ~/agent-env && ~/agent-env/install.sh
```

`install.sh` is idempotent — rerun it after a `git pull` to pick up changes.
It symlinks the scripts and tmux.conf, installs the agent instruction blocks,
and registers the qmd collection. Then do the one-time auth steps in the
table above.

## Usage

```sh
wt my-branch          # create branch/worktree + tmux session, attach
wt done [my-branch]   # kill session, remove worktree (keeps branch; --force if dirty)
```

Layout per session — claude top-left, pi bottom-left, scratch shell top-right,
`bin/dev` on a free port bottom-right:

```
┌──────────────┬──────────────┐
│    claude    │  empty shell │
├──────────────┼──────────────┤
│      pi      │   bin/dev    │
└──────────────┴──────────────┘
```

## Agent coordination

Messages are markdown files under `~/.agents-mail/<repo>--<branch>/`, exposed
in each worktree as the `.agents` symlink. `agent-mail send|inbox|read|done`
is the CLI both agents use; `agent-mail-watch` (started by `wt`) nudges the
receiving agent's pane over tmux when a message lands. Mail history survives
`wt done`. Agent-facing protocol docs live in `templates/` and are installed
into `~/.claude/CLAUDE.md` and `~/.pi/agent/AGENTS.md` by `install.sh`.

Env overrides: `WT_CLAUDE_CMD`, `WT_PI_CMD` (pane commands), `WT_MAIL_ROOT`.

## Mail-history search (qmd)

[qmd](https://github.com/tobi/qmd) (`npm install -g @tobilu/qmd`, needs Node
≥22 — install via npm, not bun, so better-sqlite3's native bindings build)
indexes `~/.agents-mail` as the `agent-mail` collection so both agents can
search past handoffs (`qmd search` / `qmd query`). `install.sh` registers the
collection; `wt done` re-indexes in the background; `wt` runs a weekly
background `npm update -g @tobilu/qmd` (stamp file in `~/.agents-mail`).
First semantic query downloads ~2GB of local models; BM25 `qmd search` works
without them.
