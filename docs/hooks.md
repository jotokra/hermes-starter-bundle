# Hooks

Hooks are shell commands that fire on agent lifecycle events. The
agent reads `~/.hermes/config.yaml`'s `hooks:` block to know which
commands to run when.

## Events

| Event | When it fires | Use it for |
|-------|---------------|------------|
| `SessionStart` | New session begins | Loading context, setting env vars |
| `UserPromptSubmit` | User sends a message | Injecting context, modifying the prompt |
| `PreToolUse` | Before a tool call | Approving, blocking, modifying tool input |
| `PostToolUse` | After a tool call | Logging, side effects, assertions |
| `Stop` | Agent stops (turn ends) | Cleanup, final notifications |
| `SessionEnd` | Session ends | Long-running cleanup, save state |

`PreToolUse` and `PostToolUse` are the most useful — they let you
gate every tool call.

## Configuring

In `~/.hermes/config/config.yaml`:

```yaml
hooks:
  PreToolUse:
    - name: log-tool-calls
      command: 'echo "[$(date)] tool=$TOOL_NAME" >> ~/.hermes/logs/tool.log'
      enabled: true
  PostToolUse:
    - name: notify-on-destructive
      command: 'osascript -e "display notification ..."'
      enabled: true
      # Only fire for specific tools:
      match_tools: [terminal]
```

Each hook is a dict with:

- `name` — display name (used in logs)
- `command` — shell command to run; receives env vars (`TOOL_NAME`,
  `TOOL_INPUT`, `TOOL_OUTPUT`) for tool-related events
- `enabled` — `true` to fire, `false` to skip
- `match_tools` — (PreToolUse / PostToolUse only) list of tool names
  to match; empty = all tools

## Security

Hooks run as your user with full shell. A malicious prompt can
trick the agent into calling a hook that does something destructive.
Two mitigations:

1. **`hooks_auto_accept: false`** in `config.yaml` (the default).
   The agent must explicitly invoke the hook; it can't be triggered
   silently.
2. **Review your hooks.** Anything in `hooks:` is part of your
   trusted config; treat it like a shell alias.

## Disabling hooks

```yaml
hooks_auto_accept: true   # turn off the prompt for *all* hooks
# OR
hooks:
  PreToolUse:
    - name: my-hook
      enabled: false        # disable just this one
```

## Reference

The exact schema and event list is defined in
`hermes-agent/agent/hooks.py` (in the upstream repo). When in doubt,
`grep -r "SessionStart\|PreToolUse\|PostToolUse" ~/.hermes/hermes-agent/`
shows every place the agent reads or fires a hook.
