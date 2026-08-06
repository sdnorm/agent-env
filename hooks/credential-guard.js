#!/usr/bin/env node
//
// credential-guard — Claude Code PreToolUse hook.
//
// Blocks credential and production access inside wt sessions unless the human
// has issued a time-limited grant (`agent-mail grant <scope>`). Outside a wt
// session (no .agent-mail mailbox in the tree) it allows everything — normal
// interactive sessions keep their usual permission prompts.
//
// Scopes, checked most-privileged first:
//   prod-write   deploys, prod migrations, prod config changes (5m grants)
//   prod-read    prod consoles/logs/status — "verify only"
//   credentials  master.key, config/credentials, rails credentials:*
//
const fs = require("fs");
const path = require("path");

const SCOPES = [
  {
    name: "prod-write",
    patterns: [
      /\bkamal\s+(deploy|redeploy|rollback|env\s+push|app\s+boot)/i,
      /\brailway\s+up\b/i,
      /\bfly(ctl)?\s+deploy\b/i,
      /\bheroku\s+(config:set|pipelines:promote)\b/i,
      /RAILS_ENV=production\S*\s+.*\bdb:(migrate|drop|seed|schema:load)/i,
      /\bgit\s+push\s+\S*(prod|production|heroku|dokku)/i,
    ],
  },
  {
    name: "prod-read",
    patterns: [
      /RAILS_ENV=production/i,
      /\bkamal\s+\w/i,
      /\bheroku\s+\w/i,
      /\brailway\s+\w/i,
      /\bfly(ctl)?\s+(ssh|logs|status|postgres|console)\b/i,
    ],
  },
  {
    name: "credentials",
    patterns: [
      /master\.key/i,
      /config\/credentials/i,
      /\bcredentials:(edit|show|diff)/i,
      /\brails\s+credentials\b/i,
    ],
  },
];

function findMailbox(startDir) {
  let dir = startDir;
  while (dir && dir !== path.dirname(dir)) {
    const candidate = path.join(dir, ".agent-mail");
    if (fs.existsSync(candidate)) return candidate;
    dir = path.dirname(dir);
  }
  return null;
}

function hasGrant(mailbox, scope) {
  try {
    const expiry = parseInt(fs.readFileSync(path.join(mailbox, "grants", scope), "utf8"), 10);
    return Number.isFinite(expiry) && expiry > Date.now() / 1000;
  } catch {
    return false;
  }
}

function deny(scope) {
  const reason =
    `Blocked by credential-guard: this touches '${scope}'. ` +
    `Ask the user for approval with: agent-mail request ${scope} "<one-line reason>" ` +
    `— then wait for them to grant it and retry. Do not work around this block.`;
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: reason,
      },
    })
  );
}

let raw = "";
process.stdin.on("data", (c) => (raw += c));
process.stdin.on("end", () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.exit(0); // never block on our own parse failure
  }

  const ti = input.tool_input || {};
  const text = [ti.command, ti.file_path, ti.notebook_path].filter(Boolean).join("\n");
  if (!text) process.exit(0);

  const scope = (() => {
    for (const s of SCOPES) {
      if (s.patterns.some((p) => p.test(text))) return s.name;
    }
    return null;
  })();
  if (!scope) process.exit(0);

  const mailbox = findMailbox(process.env.CLAUDE_PROJECT_DIR || process.cwd());
  if (!mailbox) process.exit(0); // not a wt session — normal permission flow applies

  // prod-write grant also satisfies prod-read
  if (hasGrant(mailbox, scope) || (scope === "prod-read" && hasGrant(mailbox, "prod-write"))) {
    process.exit(0);
  }

  deny(scope);
  process.exit(0);
});
