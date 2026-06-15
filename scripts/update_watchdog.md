# update_watchdog.py

A simple cron watchdog for `~/.hermes/`. Runs every 5 minutes via
`hermes cron run` with `no_agent=True` (stdout is delivered verbatim
to the originating chat, or saved to `~/.hermes/cron/output/`).

## What it does

1. **Detects uncommitted changes** in the config repo (`git status --porcelain`).
2. **Auto-commits** them with a `chore(hermes): <summary>` message.
3. **Pushes to `origin main`** (best-effort — push failures exit non-zero
   so the cron gateway surfaces them).
4. **Silent on success** — empty stdout means the cron gateway sends
   nothing. This is the canonical "watchdog" pattern.

## What it does NOT do

This is the simplest possible auto-commit watchdog. It deliberately
omits:

- **hermes-agent version-drift detection** — the full version in the
  upstream `~/.hermes/scripts/update_watchdog.py` rewrites
  `.hermes-agent-version` when `./hermes-agent/` HEAD moves. That
  watchdog is environment-specific (LAN forgejo, Telegram chat IDs,
  etc.) and isn't shipped in this bundle.
- **Push-failure healing** — the upstream `hermes_config_drift_healer.py`
  cron auto-recovers from repeated push failures. Out of scope here.
- **`config.yaml` integration** — does NOT honor
  `updates.non_interactive_local_changes: stash` (which would be the
  right behavior for a more sophisticated watchdog).
- **Telegram notifications on push failure** — exits non-zero, the cron
  gateway handles the rest.

If you need any of those, fork this script and add them.

## Dry-run mode

Set `UPDATE_WATCHDOG_DRY_RUN=1` in the env (or before the cron
registration) to print what *would* happen without committing or
pushing:

```bash
UPDATE_WATCHDOG_DRY_RUN=1 python3 ~/.hermes/scripts/update_watchdog.py
```

Output looks like:

```
🔍 DRY-RUN: would commit 3 files:
   - config/config.yaml
   - profiles/worker/profile.yaml
   - skills/foo/SKILL.md
   message: chore(hermes): track uncommitted changes (3 files)
   push:    origin main
```

## Register the cron job

After `./install.sh` has run, register the watchdog with:

```bash
hermes cron create \
  --no-agent \
  --script update_watchdog \
  --schedule "*/5 * * * *" \
  --name update_watchdog
```

This is a `no_agent=True` job — the scheduler just runs the script on
schedule and delivers its stdout. No LLM, no model override, no
clarify gates. Each tick is a few hundred milliseconds of git work.

## Verification

To smoke-test the registration:

```bash
# Force a tick now (or wait up to 5 minutes)
hermes cron run update_watchdog

# Check the agent log for the run
tail -f ~/.hermes/logs/agent.log | grep update_watchdog
```

A clean run produces no output (silent). A push failure exits non-zero
and produces a one-line error in the originating chat.

## Idempotency

`git commit` and `git push` are themselves the lock — if two ticks fire
near-simultaneously, the second one finds a clean worktree and exits
silently.

## Files

- `update_watchdog.py` — the script
- `update_watchdog.md` — this doc
