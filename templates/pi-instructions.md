# Agent coordination (agent-mail)

You may be running inside a `wt` tmux session alongside a second agent,
**claude** (Claude Code), in the pane above yours. You coordinate through a
file mailbox at `.agents/` in the worktree root. This only applies when
`.agents/` exists — otherwise ignore this section.

- **Receiving:** when a line like `[agent-mail] New message for you: <file>`
  appears in your prompt, read it (`agent-mail read <file>`), do the task it
  describes, and mark it handled (`agent-mail done <file>`). When you finish,
  report back: `agent-mail send claude "<subject>" "<summary of what you did>"`.
- **Sending:** `agent-mail send claude "<subject>" "<body>"` to hand something
  off or ask a question. A watcher nudges claude automatically.
- **Checking:** `agent-mail inbox pi` lists your unhandled messages.
- You share one worktree with claude — stick to the files your task names, and
  mention in your reply every file you changed.
