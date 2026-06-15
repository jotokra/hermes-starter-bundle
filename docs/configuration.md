# Configuration reference

This document maps the major sections of `~/.hermes/config/config.yaml` to
what they do. It's a quick orientation, not an exhaustive schema — for that,
read the upstream docs or `hermes config --help`.

## Top-level sections

| Section | Purpose |
|---------|---------|
| `model` | Default model + provider. Set these first. |
| `providers` | Named provider blocks (anthropic, openai, ollama, etc.). |
| `toolsets` | Which toolset plugins the agent can call. |
| `agent` | Agent loop config: turns, retries, reasoning effort, clarify timeout. |
| `terminal` | Shell tool config: backend, timeout, env passthrough. |
| `web` | Web search + extract backends (Brave, SerpAPI, Jina, etc.). |
| `browser` | Browser automation config: engine, timeouts, CDP. |
| `compression` | Conversation-history compression. Leave at defaults. |
| `auxiliary` | Per-task small-model overrides (vision, web extract, etc.). |
| `display` | UI behavior: streaming, inline diffs, file mutation verifier. |
| `dashboard` | Web dashboard (kanban) theme. |
| `privacy` | Secret redaction. **Leave `redact_secrets: true`**. |
| `delegation` | Subagent config: concurrency, depth limit. |
| `skills` | Skill subsystem: auto-load, curated-only. |
| `curator` | Auto-archive / unarchive unused skills. |
| `memory` | Persistent memory behavior. |
| `cron` | Scheduled-job subsystem. |
| `approvals` | When the agent must ask before running destructive commands. |
| `security` | URL allowlist, secret redaction, Tirith gating. |
| `commands` | Command allowlist (what the agent can run without asking). |
| `hooks` | Shell commands that fire on agent lifecycle events. |
| `lsp` | Language Server Protocol: go-to-def, find-refs. |
| `secrets` | Bitwarden Secrets integration (optional). |
| `platform_toolsets` | Per-platform toolset overrides (cli, telegram, discord, ...). |

## Channel integrations

Telegram, Discord, Slack, WhatsApp, Mattermost, Matrix, Yuanbao. Each
is a top-level block. Leave empty (`{}`) for platforms you don't use.
The gateway (`hermes gateway`) reads from these.

To add Telegram:

```bash
hermes setup                  # interactive wizard
# OR
hermes config set telegram.bot_token "..."
hermes config set telegram.allowed_chats "..."
```

## Provider setup

The `model:` block needs two things: a `default` model name and a
`provider` that's defined in your `auth.json`. The simplest starter:

```yaml
model:
  default: claude-sonnet-4
  provider: anthropic
```

To add a second provider, register it in `auth.json` and reference it
in `model.fallback_providers`.

## Common tweaks

- **Bump concurrency:** `max_concurrent_sessions: 14` (default 7). Watch
  your provider's rate limits.
- **Disable a noisy toolset:** `disabled_toolsets: [browser]`.
- **Make the agent more verbose:** `verbose: true` in the `agent` block.
- **Lengthen the clarify timeout** (how long a `clarify` waits for an
  answer): `agent.clarify_timeout: 7200` (2 hours, useful for
  Telegram-friendly workflows).
- **Disable stream-back on Telegram:** `display.platforms.telegram.streaming: false`.

## Editing config

Three equivalent ways:

```bash
# 1. CLI (auto-validates)
hermes config set model.default claude-sonnet-4
hermes config set agent.reasoning_effort high

# 2. Direct edit (you know what you're doing)
$EDITOR ~/.hermes/config/config.yaml

# 3. Python (for batch changes)
python3 -c "import yaml; d=yaml.safe_load(open('$HOME/.hermes/config/config.yaml')); d['model']['default']='claude-sonnet-4'; yaml.dump(d, open('$HOME/.hermes/config/config.yaml','w'))"
```

The CLI form is the safest — it validates against the schema. Direct
edits can break parsing if you mangle the YAML.

## When something "doesn't take effect"

The most common Hermes gotcha: you set a key in `config.yaml`, the agent
reloads, and the new value is ignored. Three possible causes:

1. **You set the wrong key.** 80+ keys, many with similar names. Use
   `hermes config show` to see the resolved value the agent is actually
   reading.
2. **The key is a schema placeholder.** Some keys exist in the schema
   but no Python code reads them. Run `grep -r "<key_name>" ~/.hermes/hermes-agent/`
   to see if anything reads it.
3. **The code path is hard-coded.** Some behaviors (e.g. CLI clarify
   timeout) are constants in the source. You can patch the code or
   override via env var if one exists.

See `docs/diagnostics.md` for the full triage recipe.
