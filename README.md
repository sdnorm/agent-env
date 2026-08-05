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
in each worktree as the `.agent-mail` symlink (not `.agents` — pi owns that
directory for its skills). `agent-mail send|inbox|read|done`
is the CLI both agents use; `agent-mail-watch` (started by `wt`) nudges the
receiving agent's pane over tmux when a message lands. Mail history survives
`wt done`. Agent-facing protocol docs live in `templates/` and are installed
into `~/.claude/CLAUDE.md` and `~/.pi/agent/AGENTS.md` by `install.sh`.

Env overrides: `WT_CLAUDE_CMD`, `WT_PI_CMD` (pane commands), `WT_DEV_CMD`,
`WT_SETUP_CMD`, `WT_MAIL_ROOT`.

## Rails assumptions & customizing for other stacks

`wt` is Rails-flavored in exactly three places (all in `bin/wt`):

1. **Bootstrap file copy** — fresh worktrees get `.env*`, `config/master.key`,
   and `config/credentials/*.key` copied from the main checkout (the
   "Untracked files worktrees don't inherit" block in `wt_start`). Other
   stacks keep secrets elsewhere (`.envrc`, `config/local.*`, etc.) — extend
   that block.
2. **Setup command** — fresh worktrees run `bin/setup` before the dev server.
   Override per-project with `WT_SETUP_CMD` (e.g. `npm install`, `mise run
   setup`, or `true` to skip).
3. **Dev server command** — the bottom-right pane runs `PORT=<port> bin/dev`.
   Override with `WT_DEV_CMD` (e.g. `npm run dev`, `cargo watch -x run`).
   Whatever you use must read the `PORT` env var, or ignore ports entirely.

Per-project overrides without editing anything: export `WT_*` vars from the
repo's own env (direnv `.envrc` in the main checkout works well, since `wt` is
run from inside the repo). Everything else — worktrees, tmux layout, mailbox,
watcher, qmd — is stack-agnostic. The port scan range (3000–3100) lives in
`find_free_port` if a stack conventionally uses other ports.

## Mail-history search (qmd)

[qmd](https://github.com/tobi/qmd) (`npm install -g @tobilu/qmd`, needs Node
≥22 — install via npm, not bun, so better-sqlite3's native bindings build)
indexes `~/.agents-mail` as the `agent-mail` collection so both agents can
search past handoffs (`qmd search` / `qmd query`). `install.sh` registers the
collection; `wt done` re-indexes in the background; `wt` runs a weekly
background update of qmd (`npm update -g`) and pi (`pi update`), tracked by a
stamp file in `~/.agents-mail`.
First semantic query downloads ~2GB of local models; BM25 `qmd search` works
without them.
