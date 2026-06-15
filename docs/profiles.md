# Profiles

Hermes supports multiple profiles — independent configurations that
share the same venv, git repo, and skill catalog, but can have
different model defaults, working directories, and toolset visibilities.

This bundle ships four starter profiles:

## `worker` (default)

The general-purpose default. **First stop for new kanban cards and
general tasks.** Inherits everything from the base `config.yaml`; the
profile-specific `profile.yaml` only carries the description.

When you don't know which profile to use, use this one.

## `coder`

The code-domain implementer. Used by the kanban dispatcher when a
card's body or `assignee` field points to code work. TDD-first,
commits when tests pass, no review gate.

To customize, edit `profiles/coder/config.yaml` and add overrides for:

- `model.default` (a code-strong model)
- `agent.reasoning_effort: xhigh` (more careful reasoning for code)
- `disabled_toolsets: [browser]` (focus on terminal + file)

## `coder-planner`

Decomposes multi-card work into per-card specs. Reads existing cards,
groups them by dep + parallel-safe, and emits new sub-cards with
deps + verification recipes.

This profile runs less often (planning is a discrete event), but it's
how a multi-day project gets broken into 1-commit cards.

## `housekeeper`

Maintenance — log rotation, cron watchdog health, repo state.
Runs on a `noagent=True` cron; never needs user interaction.

## Adding a new profile

```bash
# 1. Create the directory
mkdir -p ~/.hermes/profiles/<name>

# 2. Copy a starter profile
cp ~/.hermes/profiles/worker/profile.yaml ~/.hermes/profiles/<name>/

# 3. (Optional) Add profile-specific config overrides
cat > ~/.hermes/profiles/<name>/config.yaml <<'EOF'
model:
  default: claude-sonnet-4
agent:
  reasoning_effort: xhigh
EOF

# 4. Edit the description
$EDITOR ~/.hermes/profiles/<name>/profile.yaml

# 5. Use it
hermes profile use <name>
hermes chat
```

## Per-profile vs. base config

- `~/.hermes/config/config.yaml` is the **base**. Every profile
  inherits it.
- `~/.hermes/profiles/<name>/config.yaml` is the **overlay**. Keys
  here deep-merge on top of base.
- `~/.hermes/profiles/<name>/profile.yaml` is the **identity**:
  display name, description, channels.

The merge is per-key, deep (nested dicts merge recursively). So you
can override just one nested key without losing the rest of the base.

## Why multiple profiles?

The kanban dispatcher can route cards to different profiles based on
the card body or `assignee` field. A typical multi-day project looks
like:

1. `coder-planner` decomposes the parent card into N child cards.
2. `coder` implements each child card (TDD, commit, push).
3. `worker` handles general follow-ups (docs, config tweaks, replies).

The split is by **task shape**, not by user — all four profiles
typically run in the same session, switching as needed.

## Profile-related env vars

Hermes doesn't use env vars to switch profiles; that's the
`hermes profile use` CLI. The active profile is recorded in
`~/.hermes/state/profile`.
