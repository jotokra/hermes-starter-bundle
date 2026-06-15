# Diagnostics

Quick triage recipes for "I changed X and the agent isn't using it."
The most common class of Hermes config issue.

## 1. "I set `Y` in `config.yaml` and the agent isn't using it"

**Recipe:**

```bash
# A. Check the agent's resolved view
hermes config show <section>.<key>

# B. Check if anything reads the key
grep -r "your_key_name" ~/.hermes/hermes-agent/ | grep -v ".pyc"
# (zero hits = schema placeholder, the agent ignores it)
```

**Common gotcha:** `agent.clarify_timeout` is a schema key the
**gateway** path reads, but the **CLI** path is hard-coded. See below.

## 2. "I can't tell which profile is active"

```bash
hermes profile list
hermes profile current
hermes profile use worker   # switch
```

Per-profile config lives at `~/.hermes/profiles/<name>/config.yaml`.
The base config is at `~/.hermes/config/config.yaml`. Profiles are
deep-merged on top of base.

## 3. "The agent is asking too many clarifying questions"

```yaml
# In config.yaml
agent:
  clarify_timeout: 7200        # wait 2h for an answer
  # OR set to 0 to never clarify:
  clarify_timeout: 0
```

Some platforms (Telegram, Discord) render clarify buttons that don't
work on mobile. The agent will fall back to inline numbered choices
with a default. Read `agent.clarify_timeout` *carefully* — see
"3 different clarify timeouts" below.

## 4. "The agent can't reach the gateway"

```bash
# Check the gateway is up
curl http://127.0.0.1:9119/health

# Check the gateway log
tail -f ~/.hermes/logs/gateway.log

# Restart the gateway
pkill -f "hermes gateway" || true
hermes gateway &
```

## 5. "I want to see the agent's tool calls"

```bash
# Run with verbose output
hermes -v chat

# Or in config.yaml
agent:
  verbose: true
```

## 6. "The agent is making up files / hallucinating edits"

Enable the file mutation verifier:

```yaml
display:
  file_mutation_verifier: true
```

This re-reads files after the agent claims to have edited them and
surfaces a warning if the on-disk state doesn't match what the agent
reported. Default is `true` in the bundle; if you've disabled it,
re-enable.

## 7. "The agent is stuck in a loop"

`tool_loop_guardrails` in config.yaml is your friend:

```yaml
tool_loop_guardrails:
  warnings_enabled: true
  hard_stop_enabled: true       # actually stop, not just warn
  hard_stop_after:
    exact_failure: 5            # stop after 5 identical failures
    same_tool_failure: 8
    idempotent_no_progress: 5
```

## 8. "Cron job never fires"

```bash
# Check the job is registered
hermes cron list

# Force a tick to test
hermes cron run <job_id>

# Check the log
tail -f ~/.hermes/logs/agent.log | grep <job_id>
```

If `hermes cron run` works but the schedule doesn't fire, the scheduler
itself may be down. Check `~/.hermes/state/scheduler.json` (if it
exists) and restart:

```bash
pkill -f "hermes scheduler" || true
hermes scheduler &
```

## 9. "My API key isn't being used"

```bash
# Check what's in auth.json (chmod 600)
cat ~/.hermes/auth.json | python3 -m json.tool

# Check the active provider matches
hermes config show model.provider
```

If `auth.json` is empty, run `hermes login` or use the install script's
provider setup step.

## 10. "The agent forgot what I told it last week"

Memory subsystem — `~/.hermes/memories/`:

- `MEMORY.md` — environment facts (this machine, this network, etc.)
- `USER.md` — about you (preferences, style, name)

Edit these directly. The agent reads them on every session. Don't
delete them — just append/remove specific entries.

For per-project memory, edit `~/Projects/<project>/AGENTS.md`.

## When all else fails

1. `hermes doctor` — health check for venv, config, models, secrets.
2. `tail -f ~/.hermes/logs/agent.log` — see what the agent is doing.
3. `git log --oneline -n 20` in `~/.hermes/` — see what changed
   recently (in case a `update_watchdog` cron silently committed
   something you didn't expect).
4. Re-run `./install.sh` from this bundle — it's idempotent.
