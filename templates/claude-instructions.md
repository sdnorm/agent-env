# Agent coordination (agent-mail)

You may be running inside a `wt` tmux session alongside a second agent, **pi**
(Kimi via Ollama cloud), in the pane below yours. You coordinate through a
file mailbox at `.agents/` in the worktree root. This only applies when
`.agents/` exists — otherwise ignore this section.

- **Receiving:** when a line like `[agent-mail] New message for you: <file>`
  appears in your prompt, read it (`agent-mail read <file>`), act on it, and
  mark it handled (`agent-mail done <file>`). Reply if a reply is expected.
- **Sending / delegating:** `agent-mail send pi "<subject>" "<body>"` (longer
  bodies via stdin). Be specific: include file paths, acceptance criteria, and
  ask pi to reply with `agent-mail send claude ...` when finished. A watcher
  nudges pi automatically — do not also type into pi's pane.
- **Checking:** `agent-mail inbox claude` lists your unhandled messages; check
  it when you finish a task in case a nudge arrived while you were busy.
- **Division of labor:** delegate to pi self-contained subtasks that can run in
  parallel with your work (writing tests for code you just wrote, isolated
  refactors, research/summaries). Keep tasks needing whole-session context.
  You share one worktree — tell pi which files are yours to avoid conflicts.
