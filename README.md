# agent-env

Portable dev-agent orchestration: git worktrees + tmux + a file mailbox that
lets Claude Code and pi (Kimi on Ollama cloud) hand off tasks to each other.

## Setup on a new machine

```sh
git clone <this repo> ~/agent-env && ~/agent-env/install.sh
```

Then install and authenticate the CLIs the panes run (one-time, manual):
`claude`, `pi`, and `ollama` (`ollama signin` for cloud models).

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
