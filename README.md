# hermes-starter-bundle

A pre-configured starter kit for [Hermes Agent](https://github.com/NousResearch/hermes-agent).
Extract → run the install script → answer a few prompts → chat with the
agent from your terminal.

This bundle ships a sensible default config, a 4-profile setup
(`worker` / `coder` / `coder-planner` / `housekeeper`), the workflow
contract that the agent reads on every session, and an install script
that handles all the macOS / Linux prerequisites.

It does **not** ship API keys, your home directory layout, or any
personal information. The config is generic; you bring your own
provider and tweak from there.

## What's in here

```
hermes-starter-bundle/
├── install.sh                  # one-shot installer (macOS / Linux)
├── README.md                   # you are here
├── config/                     # the files that land in ~/.hermes/
│   ├── AGENTS.md               # workflow contract (read by agent every session)
│   ├── SOUL.md                 # persona placeholder
│   ├── config.yaml             # main Hermes config
│   ├── auth.json.template      # template for credentials
│   └── profile.yaml            # active profile
├── profiles/                   # per-profile overlays
│   ├── worker/                 # general default
│   ├── coder/                  # code-domain implementer
│   ├── coder-planner/          # decomposes multi-card work
│   └── housekeeper/            # maintenance
├── scripts/                    # companion scripts
│   ├── update_watchdog.py      # generic auto-commit watchdog
│   └── update_watchdog.md      # its doc
├── examples/                   # reference templates
│   └── project-AGENTS.md.template
└── docs/                       # deeper documentation
    ├── configuration.md
    ├── profiles.md
    ├── diagnostics.md
    └── hooks.md
```

**Skills are NOT shipped in the bundle.** Install them on demand with
`hermes skills install <name>` (or write your own under
`~/.hermes/skills/<category>/<name>/SKILL.md`). This keeps the bundle
small and avoids embedding the full skill catalog.

## Install

### Quick start (macOS / Linux)

```bash
git clone <this-repo> hermes-starter-bundle
cd hermes-starter-bundle
chmod +x install.sh
./install.sh
```

The installer will:

1. Check you're on macOS or Linux (exit otherwise).
2. Check for Homebrew (macOS) or apt-get (Linux). Install if missing
   (with your confirmation).
3. Check for Python 3.11+ and Node 22. Install if missing.
4. Clone `NousResearch/hermes-agent` into `~/.hermes/hermes-agent/`.
5. Run `setup-hermes.sh` to create the venv + symlink the `hermes` CLI.
6. Copy this bundle's `config/`, `profiles/`, `scripts/`, `docs/`, and
   `examples/` into `~/.hermes/`.
7. Walk you through picking a provider + entering your API key, and
   write `auth.json` (chmod 600) for you.

Total time on a fresh Mac: 5–10 minutes, mostly `brew install` and
`pip install` waiting.

### What you'll be asked

The installer prompts for:

- **Provider choice** — Anthropic, OpenAI, OpenRouter, local Ollama, or
  MiniMax OAuth. Pick one to start; you can add more later.
- **API key** for the chosen provider (skipped for Ollama).
- **Whether to enable the messaging gateway** (Telegram / Discord /
  Slack). Defaults to "no" — you can run `hermes gateway` and configure
  platforms later.
- **Whether to install companion cron jobs** (`update_watchdog` and
  friends). Defaults to "yes" — they're cheap and very useful.

If you say "go" / "use defaults" to all of these, the agent comes up
with a working CLI configuration; you can wire up the messaging
gateway later.

## After install

```bash
# Interactive CLI (REPL) — try this first
hermes chat

# One-shot prompt
hermes -p "what can you do?"

# Switch active profile
hermes profile use coder
hermes profile list

# Run the messaging gateway
hermes gateway

# Inspect / tweak config
hermes config show
hermes config set agent.reasoning_effort high
```

The agent reads `~/.hermes/AGENTS.md` on every session, so edit that
file to define your workflow rules. The starter `AGENTS.md` already
includes the most important conventions — read it before changing
anything.

## Customizing

- **Persona** — edit `~/.hermes/SOUL.md`.
- **Workflow rules** — edit `~/.hermes/AGENTS.md`. Add/remove
  sections; the agent re-reads it on the next session.
- **Model + provider** — `hermes config set model.default <name>` or
  edit `~/.hermes/config.yaml` directly.
- **Profiles** — duplicate `profiles/worker/` to a new name, edit
  `profile.yaml`, and the agent will pick it up.
- **Skills** — `hermes skills install <name>` to grab more, or write
  your own under `~/.hermes/skills/<category>/<name>/SKILL.md`.
- **Cron jobs** — `hermes cron list` to see what's scheduled,
  `hermes cron new` to add one.

See `docs/configuration.md` for the full reference.

## Differences from the "default" Hermes install

This bundle is opinionated in a few ways:

- **4-profile setup** out of the box (`worker` / `coder` /
  `coder-planner` / `housekeeper`) so you can see the pattern.
- **Workflow conventions** baked into `AGENTS.md` (scratch layout,
  two-layer config, strict dev cycle, etc.).
- **`update_watchdog` cron** shipped + auto-registered, so the config
  repo auto-commits and pushes when you change things.
- **No skills preinstalled.** The upstream Hermes install may ship a
  starter set; this bundle deliberately does not, to keep the bundle
  small. Install what you need with `hermes skills install <name>`.

If you want the bare-default Hermes install instead, skip this bundle
and just follow the upstream README.

## Verifying the install

After `./install.sh` finishes, run:

```bash
hermes doctor          # health check: venv, config, models, etc.
hermes -p "hello"      # one-shot smoke test
hermes chat            # full REPL
hermes kanban serve    # start the kanban dashboard (browser at :8765)
```

If `hermes doctor` flags something, read the message — it's specific.
Common gotchas:

- **"No active provider"** → run `hermes setup` and add a provider.
- **"Permission denied" on auth.json** → `chmod 600 ~/.hermes/auth.json`.
- **"hermes: command not found"** → `~/.local/bin` isn't on your PATH.
  Add `export PATH="$HOME/.local/bin:$PATH"` to your `~/.zshrc` or `~/.bashrc`.

## License

This bundle is configuration + documentation, not code. Released under
the same terms as the upstream Hermes Agent (see the hermes-agent repo
for the exact license).
