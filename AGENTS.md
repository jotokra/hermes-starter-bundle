# ~/Projects/hermes-starter-bundle/

A pre-configured starter kit for [Hermes Agent](https://github.com/NousResearch/hermes-agent),
designed to be shared with new users. The user hands a friend a tarball
(or a clone URL); the friend extracts, runs `install.sh`, and has a
working agent in 5–10 minutes.

## What this is

This is a **deliverable**, not an active coding project. There's no
build, no test, no deploy loop. The "test" for this bundle is:

1. Sanity-check: `./scripts/check-sanitization.sh` — must print
   "All sanitization checks passed." (the script does the 5-class
   leak check; see `docs/configuration.md` for the recipe).
2. `bash -n install.sh` — must succeed.
3. `python3 scripts/update_watchdog.py` in a clean git repo — must
   exit silently.
4. The python heredoc in `install.sh` (line ~344) — when run with
   `MODEL_DEFAULT=...` and `PROVIDER_ID=...` env vars, must update
   `config.yaml` idempotently.

## Dev setup

This bundle doesn't run anything; there's nothing to "set up." To
regenerate the bundle from your working `~/.hermes/`, see `MAINTENANCE.md`
(if/when it exists).

To smoke-test the bundle end-to-end:

```bash
# Use a temp HOME so the installer doesn't touch your real config
TMPHOME=$(mktemp -d)
HOME="$TMPHOME" ./install.sh
# Walk through the prompts. The installer will create a fully-functional
# ~/.hermes in $TMPHOME.
```

## Run

Nothing to run. The bundle is data + docs + one shell script. Users
run `install.sh` from inside the bundle after extracting.

## Test

The functional tests are described in the [AGENTS.md commit
message](#) (look for "Tests verified" lines). To re-run them:

```bash
# Install script syntax
bash -n install.sh

# update_watchdog scenarios
UPDATE_WATCHDOG_DRY_RUN=1 python3 scripts/update_watchdog.py  # in a clean repo
```

## Deploy

There is no deploy step. To share the bundle:

```bash
# Option A: tarball
tar -czf hermes-starter-bundle.tar.gz --exclude='.git' \
    -C ~/Projects hermes-starter-bundle/

# Option B: push to a remote (GitHub, GitLab, LAN forgejo, etc.)
cd ~/Projects/hermes-starter-bundle
git remote add origin <url>
git push -u origin main
```

The recipient does `tar -xzf` (or `git clone`), then `./install.sh`.

## Key files

- **`install.sh`** — the one-shot installer. **Read this carefully
  before changing** — it's the contract the user sees.
- **`config/`** — the files that land in `~/.hermes/`. `config.yaml`
  is the main config; `AGENTS.md` is the workflow contract.
- **`profiles/`** — 4 starter profiles (`worker` / `coder` /
  `coder-planner` / `housekeeper`).
- **`scripts/update_watchdog.py`** — generic auto-commit watchdog.
  Tested independently in 5 scenarios.
- **`docs/`** — reference docs (configuration, profiles, diagnostics,
  hooks).
- **`README.md`** — what the user sees first.

## See also

- `~/AGENTS.md` — workspace layout, project index, sovereignty rules.
- `~/.hermes/AGENTS.md` — runtime contract, workflow rules, scratch layout.
- `~/.hermes/hermes-agent/AGENTS.md` — the vendored agent's contract
  (the bundle's `install.sh` clones from this repo).

## Things not to do

- **Don't add personal info to this bundle.** It's a deliverable; the
  whole point is that it's safe to share. Run the sanity-check
  grep before committing.
- **Don't add the full skill catalog.** Curated > comprehensive for a
  starter. Add skills via `hermes skills install` after the user has
  the basics working.
- **Don't make the install script require a specific provider.** The
  script prompts for one but doesn't hard-code it. A bundle that
  hard-codes the author's preferred provider is not portable.
- **Don't `git init` the user's home directory.** The bundle goes in
  `~/Projects/hermes-starter-bundle/`, not at `~/`. (The bundle
  installs into `~/.hermes/`, but that's a *target*, not a *source*.)
