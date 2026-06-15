# ~/.hermes/AGENTS.md — Hermes config contract

This file is the contract for `~/.hermes/` — the **operator-facing
configuration layer** of a Hermes Agent install. It is read by every agent
session that operates on this machine, so the contract here must stay
current and operational.

## What this is

`~/.hermes/` is a separate git repo from `hermes-agent/` (the code
checkout) and from every project under `~/Projects/`. It holds persona,
workflow rules, skills, cron jobs, kanban state, persistent memory, and
the version pin that ties this config to a known-good agent commit. It
is the file the user touches; the agent reads it.

The remote is whatever you configure (commonly `git@github.com:you/hermes-config.git`
or a LAN-only gitea/forgejo). Set it up yourself; the bundle does not
impose a remote.

## Dev setup

Fresh install on macOS or Linux:

1. Clone the agent code into `~/.hermes/hermes-agent/`:
   ```bash
   git clone https://github.com/NousResearch/hermes-agent.git ~/.hermes/hermes-agent
   ```
2. Run the agent's setup script — creates venv, installs deps, symlinks
   the `hermes` CLI into `~/.local/bin/`:
   ```bash
   cd ~/.hermes/hermes-agent
   ./setup-hermes.sh
   ```
3. Put this config bundle in place at `~/.hermes/`. The install script
   does this for you, but the manual version is:
   ```bash
   rsync -av --exclude='.git' hermes-starter-bundle/ ~/.hermes/
   echo 'export HERMES_HOME="$HOME/.hermes"' >> ~/.zshrc   # or ~/.bashrc
   ```
4. First-run wizard — `hermes setup` walks through provider keys, the
   messaging gateway (optional), and basic limits. Secrets land in
   `~/.hermes/auth.json` (chmod 600) and `~/.hermes/.env` (gitignored).
5. (Optional) Pin the agent version. If you enable the `update_watchdog`
   cron (see `scripts/`), it auto-updates `.hermes-agent-version` after
   a `git pull` inside `hermes-agent/`.

`setup-hermes.sh` is idempotent — it skips the venv if it already exists
and reuses the existing `.env`. Re-run it any time without harm.

## Run

```bash
# Interactive CLI (REPL)
hermes chat

# One-shot prompt, no REPL
hermes -p "summarise ~/Notes/today.md"

# Messaging gateway (Telegram, Discord, Slack, etc.)
hermes gateway
# → listens on http://127.0.0.1:9119 by default

# Kanban dashboard
hermes kanban serve
# → http://127.0.0.1:8765

# Cron watchdog for scheduled jobs
hermes cron list
hermes cron run <job_id>     # ad-hoc tick
```

The venv is at `~/.hermes/hermes-agent/venv/`. The symlink
`~/.local/bin/hermes` is what `setup-hermes.sh` installs; the venv's
`bin/hermes` works too if you source the venv directly.

## Test

The config repo has no test suite of its own — it's data, not code. The
hermes-agent checkout does, and you run it from there:

```bash
cd ~/.hermes/hermes-agent
source venv/bin/activate
pytest tests/                        # full suite
pytest tests/cli -k test_kanban      # one module
ruff check .                         # lint
mypy agent/                          # types
```

Companion watchdog scripts in `~/.hermes/scripts/` are tested implicitly
by their cron schedules — they print to stdout and exit non-zero on
error, so `hermes cron run <id>` doubles as a smoke test.

## Deploy

`git push` from your dev box and `git pull` wherever the agent runs:

```bash
# Dev box: commit + push a config change
cd ~/.hermes
git add -A
git commit -m "chore(hermes): <summary>"
git push origin main

# Mini / other host: pull the change
cd ~/.hermes && git pull
# Restart whatever depends on the change:
#   - gateway:   hermes gateway (no daemon; long-running process)
#   - kanban:    hermes kanban serve  (no daemon; long-running process)
#   - cron jobs: picked up automatically on next tick
```

## Key files (this repo)

- **`AGENTS.md`** (this file) — DOX contract: what this repo is, how to
  set it up, the rules every session must follow, and the things not to do.
- **`SOUL.md`** — persona placeholder. Edit to define a voice.
- **`config.yaml`** — main Hermes configuration. Providers, limits,
  delegation, toolset visibility, channel routing, kanban defaults.
- **`auth.json`** — credentials (chmod 600, NEVER in git).
- **`.env`** — additional secrets (gitignored).
- **`profile.yaml`** — the active profile's identity (display name,
  default workdir, channels).
- **`profiles/<name>/`** — per-profile overlays. The bundle ships with
  four: `worker` (general default), `coder` (code-domain implementer),
  `coder-planner` (decomposes multi-card work), `housekeeper` (maintenance).
- **`skills/`** — user-local skills. Pinned skills are protected from deletion.
- **`scripts/`** — companion watchdog / helper scripts. The
  `update_watchdog.py` + `update_watchdog.md` pair is the most useful;
  it auto-commits and pushes this repo when `hermes-agent/` HEAD moves.
- **`kanban/`, `cron/`** — kanban boards and scheduled tasks. Empty by
  default; the agent creates files in these dirs as needed.
- **`memories/MEMORY.md`**, **`memories/USER.md`** — persistent notes
  about the environment and the user. The agent reads these on startup.
- **`plans/`, `notes/`** — design docs and feature requests.
- **`CHANGELOG.md`** — user-visible changes to this config repo
  (Keep a Changelog 1.1.0 format).
- **`.hermes-agent-version`** — pin to the hermes-agent commit this
  config was tested with.

## Conventions

These apply workspace-wide. The home-root `~/AGENTS.md` (if present) and
each project's `AGENTS.md` are the per-context contracts; they reference
this file for the rules that apply everywhere.

### Two-layer config

- `~/.hermes/` is the **config repo** — what you tune. Tracked in git.
- `~/.hermes/hermes-agent/` is the **code checkout** — what you
  `git pull` to upgrade. NOT in the config repo's git history.

### Scratch / worktree directory layout

Three classes of scratch, each with a canonical home. Do not invent new
top-level dirs in `~/Projects/` for ad-hoc work:

1. **Worktree scratch for a kanban card** → `~/.hermes/.worktrees/t_<task_id>/`
2. **Ad-hoc scratch (route tests, smoke stubs, one-off clones)** →
   `~/Projects/.tmp/<session-name>-<topic>/` (single hidden dir, gitignored)
3. **Per-project test scratch** (e.g. tank's Playwright `pw-*` dirs) →
   inside the project, e.g. `<project>/.playwright-tmp/`

### Config-knob vs. code-path

`config.yaml` has 80+ keys. Some are schema placeholders that no Python
code reads. When something you set "doesn't take effect," check whether
the code path actually reads the key. Probe recipe in
`docs/diagnostics.md` in the bundle.

### Chat-channel UX

When the agent asks you a multiple-choice question on Telegram / Discord /
SMS, the `clarify` buttons don't always surface on mobile. Reply with the
number ("1", "2B", etc.) or the keyword. Always include "Default if
'go': X" so the agent can keep moving.

### Strict dev cycle (code changes only)

Applies to code changes in a project repo (new scripts, functions,
refactors, behaviour changes that ship as a commit):

1. Refine spec
2. TDD — write the failing test first
3. Implement
4. Verify
5. Commit + push

Trivial shell / env-var / config toggles (`export in ~/.zshenv`, `hermes
config set`, toolset enable/disable) are **not** in scope. Just do it,
smoke-test, report.

Hard line for explicit approval either way: `brew install`,
`pip install --user`, `crontab -e`, `systemctl enable`, anything
system-level. When in doubt, ask.

### DOX lives in the file, not the chat

The home-root reply does not get a "DOX entry — what / why / not doing:"
header. The contract is in the modified file or the commit body; the
chat reply is the summary.

### Sovereignty

**STRICT LAN-ONLY** by default for any service you expose. No Tailscale,
no port forwarding, no public DNS, no cross-internet exposure of
user-controlled services. Exceptions are explicit and per-service.

## Scaffolding a new project under `~/Projects/`

If you add a new top-level project, the per-project `AGENTS.md` must
include a `## See also` section that points to **both**:

- `~/AGENTS.md` — workspace layout / project index
- `~/.hermes/AGENTS.md` — this file (runtime contract / workflow rules)

Don't make a worker read your project AGENTS.md and have to guess at the
workspace-wide rules. The cross-references cost you 4 lines and save
every future agent a lookup.

## Things not to do

- **Don't `git init` the home root (`~/`).** The user wants a flat file
  tree, not a home-root git repo.
- **Don't commit `auth.json`, `.env`, or `*.token` files.** The `.gitignore`
  is set up to block this; respect it.
- **Don't run broad `sed` against the home root.** The home-root
  `AGENTS.md` is not auto-snapshotted; a clobbered file is not
  recoverable from this repo.
- **Don't create new top-level dirs in `~/Projects/` for scratch.** Use
  the `~/Projects/.tmp/` rule above.
- **Don't `pip install --user` anything globally without asking.** Use
  the agent's venv at `~/.hermes/hermes-agent/venv/`.
