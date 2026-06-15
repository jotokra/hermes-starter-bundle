#!/usr/bin/env bash
# install.sh — Hermes Agent starter bundle installer
#
# What it does:
#   1. Detects macOS / Linux. Refuses otherwise.
#   2. Checks for Homebrew (macOS) / apt (Linux) and installs if missing.
#   3. Checks for git, python3 (>=3.11), node (>=22). Installs if missing
#      (with explicit user confirmation for system-level installs).
#   4. Clones NousResearch/hermes-agent into ~/.hermes/hermes-agent/
#      (skip if already there).
#   5. Runs hermes-agent's setup-hermes.sh to create venv + symlink CLI.
#   6. Copies this bundle's config/, profiles/, scripts/, docs/,
#      examples/ into ~/.hermes/.
#   7. Walks you through provider + key + gateway setup.
#   8. Optionally installs companion cron jobs (update_watchdog, etc.).
#
# Idempotent — re-running skips already-done steps. Safe to re-run.

set -euo pipefail

# --- 0. Resolve paths and helpers ----------------------------------------

# The directory this script lives in. Used to find config/, profiles/, etc.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color helpers (only when stdout is a TTY).
if [ -t 1 ]; then
    BOLD="\033[1m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    RED="\033[0;31m"
    RESET="\033[0m"
else
    BOLD=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi

info()  { printf "${BOLD}==>${RESET} %s\n" "$*"; }
ok()    { printf "${GREEN}✓${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}!${RESET} %s\n" "$*"; }
err()   { printf "${RED}✗${RESET} %s\n" "$*" >&2; }

# Confirm with a default. Usage: confirm "question" "default-y-or-n"
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local reply
    if [ "$default" = "y" ]; then
        read -r -p "$(printf "${BOLD}%s${RESET} [Y/n] " "$prompt")" reply
        reply="${reply:-y}"
    else
        read -r -p "$(printf "${BOLD}%s${RESET} [y/N] " "$prompt")" reply
        reply="${reply:-n}"
    fi
    case "$reply" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

# Track whether a step was actually run, for the summary at the end.
INSTALLED_BREW=0
INSTALLED_PYTHON=0
INSTALLED_NODE=0
INSTALLED_HERMES_AGENT=0
COPIED_CONFIG=0
SETUP_PROVIDER=0
INSTALLED_CRON=0

# --- 1. Detect OS --------------------------------------------------------

OS="$(uname -s)"
case "$OS" in
    Darwin|Linux) ;;
    *)
        err "Unsupported OS: $OS"
        err "This installer supports macOS and Linux. For Windows, use WSL."
        exit 1
        ;;
esac
ok "Detected OS: $OS"

# --- 2. Check / install Homebrew (macOS) or apt (Linux) ------------------

if [ "$OS" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
        warn "Homebrew is not installed."
        if confirm "Install Homebrew? (required for the rest of the install)" "y"; then
            info "Running Homebrew installer..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            # Homebrew's install script adds itself to PATH for the next
            # shell session. Source the env file if it exists.
            if [ -f /opt/homebrew/bin/brew ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
                INSTALLED_BREW=1
            elif [ -f /usr/local/bin/brew ]; then
                eval "$(/usr/local/bin/brew shellenv)"
                INSTALLED_BREW=1
            fi
            ok "Homebrew installed."
        else
            err "Homebrew is required to continue. Aborting."
            exit 1
        fi
    else
        ok "Homebrew already installed."
    fi
else
    # Linux: just check for apt or dnf.
    if ! command -v apt-get >/dev/null 2>&1 && ! command -v dnf >/dev/null 2>&1; then
        err "Neither apt-get nor dnf found. This installer supports Debian/Ubuntu and RHEL/Fedora."
        err "For other distros, install git, python3.11+, and node 22+ manually, then re-run."
        exit 1
    fi
    ok "Found a package manager."
fi

# --- 3. Check git --------------------------------------------------------

if ! command -v git >/dev/null 2>&1; then
    warn "git is not installed."
    if confirm "Install git?" "y"; then
        if [ "$OS" = "Darwin" ]; then
            brew install git
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get install -y git
        else
            sudo dnf install -y git
        fi
        ok "git installed."
    else
        err "git is required. Aborting."
        exit 1
    fi
else
    ok "git found: $(git --version)"
fi

# --- 4. Check Python 3.11+ -----------------------------------------------

PYTHON_OK=0
if command -v python3 >/dev/null 2>&1; then
    PY_VERSION="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || echo 0.0)"
    PY_MAJOR="$(echo "$PY_VERSION" | cut -d. -f1)"
    PY_MINOR="$(echo "$PY_VERSION" | cut -d. -f2)"
    if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 11 ]; then
        PYTHON_OK=1
    fi
fi

if [ "$PYTHON_OK" = 0 ]; then
    warn "Python 3.11+ not found (have ${PY_VERSION:-none})."
    if confirm "Install Python 3.11+?" "y"; then
        if [ "$OS" = "Darwin" ]; then
            brew install python@3.11
            brew link --overwrite --force python@3.11
            INSTALLED_PYTHON=1
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get install -y python3.11 python3.11-venv python3-pip
            INSTALLED_PYTHON=1
        else
            sudo dnf install -y python3.11
            INSTALLED_PYTHON=1
        fi
        ok "Python 3.11+ installed."
    else
        err "Python 3.11+ is required. Aborting."
        exit 1
    fi
else
    ok "Python found: $PY_VERSION"
fi

# --- 5. Check Node 22+ ----------------------------------------------------

NODE_OK=0
if command -v node >/dev/null 2>&1; then
    NODE_VERSION="$(node --version 2>/dev/null | tr -d 'v' || echo 0.0)"
    NODE_MAJOR="$(echo "$NODE_VERSION" | cut -d. -f1)"
    if [ "$NODE_MAJOR" -ge 22 ]; then
        NODE_OK=1
    fi
fi

if [ "$NODE_OK" = 0 ]; then
    warn "Node 22+ not found (have ${NODE_VERSION:-none})."
    if confirm "Install Node 22+?" "y"; then
        if [ "$OS" = "Darwin" ]; then
            brew install node@22
            brew link --overwrite --force node@22
            INSTALLED_NODE=1
        elif command -v apt-get >/dev/null 2>&1; then
            # Use NodeSource for current LTS.
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt-get install -y nodejs
            INSTALLED_NODE=1
        else
            sudo dnf install -y nodejs npm
            INSTALLED_NODE=1
        fi
        ok "Node 22+ installed."
    else
        warn "Continuing without Node. Some agent features (browser automation, certain MCP servers) won't work."
    fi
else
    ok "Node found: $NODE_VERSION"
fi

# --- 6. Clone hermes-agent -----------------------------------------------

HERMES_AGENT_DIR="$HOME/.hermes/hermes-agent"
if [ -d "$HERMES_AGENT_DIR" ]; then
    ok "hermes-agent already cloned at $HERMES_AGENT_DIR"
else
    if confirm "Clone NousResearch/hermes-agent into $HERMES_AGENT_DIR?" "y"; then
        info "Cloning hermes-agent..."
        mkdir -p "$HOME/.hermes"
        git clone https://github.com/NousResearch/hermes-agent.git "$HERMES_AGENT_DIR"
        INSTALLED_HERMES_AGENT=1
        ok "hermes-agent cloned."
    else
        err "hermes-agent is required. Aborting."
        exit 1
    fi
fi

# --- 7. Run setup-hermes.sh ---------------------------------------------

if [ -f "$HERMES_AGENT_DIR/setup-hermes.sh" ]; then
    info "Running hermes-agent setup..."
    # The setup script is idempotent — safe to re-run.
    (cd "$HERMES_AGENT_DIR" && ./setup-hermes.sh)
    ok "hermes-agent setup complete."

    # Make sure ~/.local/bin is on PATH for the rest of this script.
    export PATH="$HOME/.local/bin:$PATH"

    # Persist PATH for future shells.
    SHELL_RC="$HOME/.zshrc"
    [ ! -f "$SHELL_RC" ] && [ -f "$HOME/.bashrc" ] && SHELL_RC="$HOME/.bashrc"
    if ! grep -q 'local/bin' "$SHELL_RC" 2>/dev/null; then
        if confirm "Add ~/.local/bin to your PATH in $SHELL_RC?" "y"; then
            echo '' >> "$SHELL_RC"
            echo '# Added by hermes-starter-bundle install.sh' >> "$SHELL_RC"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
            ok "PATH updated in $SHELL_RC (re-source or open a new terminal to use)."
        fi
    fi
else
    err "setup-hermes.sh not found at $HERMES_AGENT_DIR/setup-hermes.sh"
    err "The hermes-agent clone may be incomplete. Re-clone and try again."
    exit 1
fi

# --- 8. Copy bundle into ~/.hermes/ -------------------------------------

if [ -d "$HOME/.hermes" ] && [ -f "$HOME/.hermes/config/config.yaml" ]; then
    # Already populated — ask before overwriting.
    if confirm "Existing Hermes config found at ~/.hermes/. Overwrite with this bundle?" "n"; then
        info "Copying bundle files into ~/.hermes/..."
        rsync -av --update \
            --exclude='auth.json' \
            --exclude='.env' \
            --exclude='state.db*' \
            "$SCRIPT_DIR/config/" "$HOME/.hermes/config/"
        rsync -av --update "$SCRIPT_DIR/profiles/" "$HOME/.hermes/profiles/"
        rsync -av --update "$SCRIPT_DIR/scripts/" "$HOME/.hermes/scripts/"
        if [ -d "$SCRIPT_DIR/docs" ]; then
            rsync -av --update "$SCRIPT_DIR/docs/" "$HOME/.hermes/docs/"
        fi
        if [ -d "$SCRIPT_DIR/examples" ]; then
            rsync -av --update "$SCRIPT_DIR/examples/" "$HOME/.hermes/examples/"
        fi
        COPIED_CONFIG=1
        ok "Bundle files copied."
    else
        warn "Skipping bundle copy. Your existing config is preserved."
    fi
else
    info "Copying bundle files into ~/.hermes/..."
    mkdir -p "$HOME/.hermes"
    rsync -av "$SCRIPT_DIR/config/" "$HOME/.hermes/config/"
    rsync -av "$SCRIPT_DIR/profiles/" "$HOME/.hermes/profiles/"
    rsync -av "$SCRIPT_DIR/scripts/" "$HOME/.hermes/scripts/"
    if [ -d "$SCRIPT_DIR/docs" ]; then
        rsync -av "$SCRIPT_DIR/docs/" "$HOME/.hermes/docs/"
    fi
    if [ -d "$SCRIPT_DIR/examples" ]; then
        rsync -av "$SCRIPT_DIR/examples/" "$HOME/.hermes/examples/"
    fi
    COPIED_CONFIG=1
    ok "Bundle files copied."
fi

# --- 9. Set up auth.json (chmod 600) ------------------------------------

if [ ! -f "$HOME/.hermes/config/auth.json" ]; then
    if [ -f "$SCRIPT_DIR/config/auth.json.template" ]; then
        if confirm "Set up provider credentials now? (you can also do this later via 'hermes login')" "y"; then
            info "Provider setup. Pick one:"
            echo "  1) Anthropic (Claude)        — direct Anthropic API"
            echo "  2) OpenAI                    — direct OpenAI API"
            echo "  3) OpenRouter                — many models, one key"
            echo "  4) Ollama (local)            — no key, runs on http://127.0.0.1:11434"
            echo "  5) MiniMax OAuth             — group OAuth flow"
            echo "  6) Skip — I'll do this later"
            echo ""
            read -r -p "$(printf "${BOLD}Pick [1-6, default 6]:${RESET} ")" PROVIDER_CHOICE
            PROVIDER_CHOICE="${PROVIDER_CHOICE:-6}"

            case "$PROVIDER_CHOICE" in
                1) PROVIDER_ID="anthropic" ; MODEL_DEFAULT="claude-sonnet-4" ; BASE_URL="https://api.anthropic.com" ;;
                2) PROVIDER_ID="openai" ; MODEL_DEFAULT="gpt-4o" ; BASE_URL="https://api.openai.com/v1" ;;
                3) PROVIDER_ID="openrouter" ; MODEL_DEFAULT="anthropic/claude-sonnet-4" ; BASE_URL="https://openrouter.ai/api/v1" ;;
                4) PROVIDER_ID="custom:ollama" ; MODEL_DEFAULT="llama3.1" ; BASE_URL="http://127.0.0.1:11434/v1" ;;
                5) PROVIDER_ID="minimax-oauth" ; MODEL_DEFAULT="MiniMax-M3" ; BASE_URL="https://api.minimax.io/anthropic" ;;
                6) PROVIDER_ID="" ; MODEL_DEFAULT="" ; BASE_URL="" ;;
                *) err "Invalid choice." ; exit 1 ;;
            esac

            if [ -n "$PROVIDER_ID" ]; then
                API_KEY=""
                if [ "$PROVIDER_ID" != "custom:ollama" ] && [ "$PROVIDER_ID" != "minimax-oauth" ]; then
                    read -r -s -p "$(printf "${BOLD}API key for $PROVIDER_ID:${RESET} ")" API_KEY
                    echo ""
                fi

                # Build auth.json from the template.
                AUTH_JSON="$HOME/.hermes/config/auth.json"
                cat > "$AUTH_JSON" <<EOF
{
  "version": 1,
  "active_provider": "$PROVIDER_ID",
  "providers": {
    "$PROVIDER_ID": {
      "provider": "$PROVIDER_ID",
      "inference_base_url": "$BASE_URL",
      "api_key": "$API_KEY"
    }
  }
}
EOF
                chmod 600 "$AUTH_JSON"
                ok "auth.json written (chmod 600)."

                # Update config.yaml with the chosen model + provider.
                # Use Python (not sed) for safer YAML-ish editing.
                # The regex is permissive: between `model:` and `default:`,
                # any number of indented comment lines or blank lines may
                # appear. Anchored at the start of a line via MULTILINE.
                if [ -f "$HOME/.hermes/config/config.yaml" ]; then
                    MODEL_DEFAULT="$MODEL_DEFAULT" PROVIDER_ID="$PROVIDER_ID" python3 - <<'PYEOF'
import os
import re

path = os.path.expanduser("~/.hermes/config/config.yaml")
with open(path) as f:
    content = f.read()

new_default = os.environ["MODEL_DEFAULT"]
new_provider = os.environ["PROVIDER_ID"]

# (?:[ \t]*#[^\n]*\n|[ \t]*\n)*  matches zero-or-more comment or blank
# lines with the same indent as the `default:` key. This lets us land
# on `  default: ` even when the user has added comments between
# `model:` and `default:`.
between = r"(?:[ \t]*#[^\n]*\n|[ \t]*\n)*"

content = re.sub(
    rf"^(model:\n{between}  default: )[^\n]*$",
    rf"\g<1>{new_default}",
    content,
    count=1,
    flags=re.MULTILINE,
)
content = re.sub(
    rf"^(model:\n{between}  default: [^\n]*\n  provider: )[^\n]*$",
    rf"\g<1>{new_provider}",
    content,
    count=1,
    flags=re.MULTILINE,
)

with open(path, "w") as f:
    f.write(content)
print(f"config.yaml: model={new_default}, provider={new_provider}")
PYEOF
                fi
                SETUP_PROVIDER=1
                ok "Provider configured: $PROVIDER_ID / $MODEL_DEFAULT"
            else
                warn "Skipped. Run 'hermes setup' or 'hermes login' later to configure a provider."
            fi
        fi
    fi
else
    ok "auth.json already exists, leaving it alone."
fi

# --- 10. Optional: install companion cron jobs --------------------------

if [ -f "$HOME/.hermes/scripts/update_watchdog.py" ] && [ -f "$HOME/.hermes/scripts/update_watchdog.md" ]; then
    if confirm "Install the update_watchdog cron job? (auto-commits config changes every 5 min)" "y"; then
        if command -v hermes >/dev/null 2>&1; then
            info "Registering update_watchdog cron..."
            # Try the canonical no_agent registration. If the cron subsystem
            # isn't available, fall back to printing the manual command.
            if hermes cron create \
                --no-agent \
                --script update_watchdog \
                --schedule "*/5 * * * *" \
                --name update_watchdog 2>/dev/null; then
                INSTALLED_CRON=1
                ok "update_watchdog cron registered."
            else
                warn "Could not auto-register the cron. Run this in a new terminal:"
                warn "  hermes cron create --no-agent --script update_watchdog --schedule '*/5 * * * *' --name update_watchdog"
                warn "Full doc: ~/.hermes/scripts/update_watchdog.md"
            fi
        else
            warn "hermes CLI not on PATH yet. Open a new terminal and run:"
            warn "  hermes cron create --no-agent --script update_watchdog --schedule '*/5 * * * *' --name update_watchdog"
        fi
    fi
fi

# --- 10b. Optional: set up the web dashboard ----------------------------

INSTALLED_DASHBOARD=0

# Detect the dashboard subcommand. If the agent version doesn't have
# it (older versions), skip the prompt rather than failing.
if command -v hermes >/dev/null 2>&1 && hermes dashboard --help >/dev/null 2>&1; then
    if confirm "Set up the web dashboard now? (LAN-only admin panel at http://127.0.0.1:9119)" "n"; then
        # 1. Generate a random password and a cookie-signing secret if
        #    the user doesn't have them yet. Skip silently if the .env
        #    already has values (don't clobber).
        ENV_FILE="$HOME/.hermes/.env"
        touch "$ENV_FILE"
        chmod 600 "$ENV_FILE"

        NEED_WRITE=0
        for VAR in HERMES_DASHBOARD_BASIC_AUTH_USERNAME \
                   HERMES_DASHBOARD_BASIC_AUTH_PASSWORD \
                   HERMES_DASHBOARD_BASIC_AUTH_SECRET; do
            if ! grep -q "^${VAR}=" "$ENV_FILE" 2>/dev/null; then
                NEED_WRITE=1
                break
            fi
        done

        if [ "$NEED_WRITE" = 1 ]; then
            if confirm "Generate random username + password for the dashboard? (stored in ~/.hermes/.env, chmod 600)" "y"; then
                USERNAME="admin"
                PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
                SECRET=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)

                # Append the new vars without clobbering other content.
                {
                    echo ""
                    echo "# Web dashboard basic auth (added by hermes-starter-bundle install.sh)"
                    echo "HERMES_DASHBOARD_BASIC_AUTH_USERNAME=${USERNAME}"
                    echo "HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${PASSWORD}"
                    echo "HERMES_DASHBOARD_BASIC_AUTH_SECRET=${SECRET}"
                } >> "$ENV_FILE"

                ok "Generated and saved username + password to $ENV_FILE (chmod 600)."
                warn "SAVE THE PASSWORD: $PASSWORD"
                warn "(It's also in $ENV_FILE; back that file up to your password manager.)"
            else
                warn "Skipping dashboard auth. Set the env vars manually:"
                warn "  HERMES_DASHBOARD_BASIC_AUTH_USERNAME, _PASSWORD, _SECRET"
            fi
        else
            ok "Dashboard auth env vars already present in $ENV_FILE."
        fi

        # 2. Offer to start the dashboard.
        if confirm "Start the dashboard now? (binds 127.0.0.1:9119 by default — change --host for LAN)" "y"; then
            info "Starting dashboard in the background..."
            # nohup + disown so it survives the install script exiting.
            # Default --host is 127.0.0.1 (loopback only). The user can
            # change to 0.0.0.0 for LAN access — see docs/dashboard.md.
            nohup hermes dashboard --no-open --host 127.0.0.1 --port 9119 \
                > "$HOME/.hermes/logs/dashboard.log" 2>&1 &
            DASHBOARD_PID=$!
            disown $DASHBOARD_PID 2>/dev/null || true
            sleep 2
            if kill -0 $DASHBOARD_PID 2>/dev/null; then
                INSTALLED_DASHBOARD=1
                ok "Dashboard started (PID $DASHBOARD_PID). Open http://127.0.0.1:9119"
                ok "Log: tail -f ~/.hermes/logs/dashboard.log"
            else
                warn "Dashboard process didn't stay up. Check $HOME/.hermes/logs/dashboard.log"
            fi
        else
            info "To start later: hermes dashboard --no-open --host 127.0.0.1 --port 9119"
        fi
    fi
else
    warn "Skipping dashboard setup: 'hermes dashboard' not available in this agent version."
    warn "(The dashboard is built-in to recent Hermes versions; check `hermes dashboard --help`.)"
fi

# --- 11. Final summary ---------------------------------------------------

echo ""
echo "${BOLD}============================================================${RESET}"
echo "${BOLD}  Installation complete.${RESET}"
echo "${BOLD}============================================================${RESET}"
echo ""

# Print a summary of what was done.
[ "$INSTALLED_BREW" = 1 ]       && echo "  • Installed Homebrew"
[ "$INSTALLED_PYTHON" = 1 ]     && echo "  • Installed Python 3.11+"
[ "$INSTALLED_NODE" = 1 ]       && echo "  • Installed Node 22+"
[ "$INSTALLED_HERMES_AGENT" = 1 ] && echo "  • Cloned hermes-agent"
[ "$COPIED_CONFIG" = 1 ]        && echo "  • Copied bundle into ~/.hermes/"
[ "$SETUP_PROVIDER" = 1 ]       && echo "  • Configured provider + auth.json"
[ "$INSTALLED_CRON" = 1 ]       && echo "  • Installed update_watchdog cron"
[ "$INSTALLED_DASHBOARD" = 1 ] && echo "  • Set up and started the web dashboard"
echo ""

echo "${BOLD}Next steps:${RESET}"
echo ""
echo "  1. ${BOLD}Open a new terminal${RESET} (or 'source ~/.zshrc') to pick up the PATH change."
echo ""
echo "  2. ${BOLD}Smoke-test the install:${RESET}"
echo "       hermes doctor"
echo "       hermes -p \"hello, who are you?\""
echo ""
echo "  3. ${BOLD}Start the REPL:${RESET}"
echo "       hermes chat"
echo ""
echo "  4. ${BOLD}Customize the agent's voice:${RESET}"
echo "       edit ~/.hermes/config/SOUL.md"
echo ""
echo "  5. ${BOLD}Tune workflow rules:${RESET}"
echo "       edit ~/.hermes/config/AGENTS.md"
echo ""
echo "  6. ${BOLD}Wire up the messaging gateway (optional):${RESET}"
echo "       hermes gateway   # then add platforms via 'hermes setup'"
echo ""
echo "  7. ${BOLD}Open the web dashboard (optional):${RESET}"
echo "       open http://127.0.0.1:9119   # default loopback"
echo "       # See ~/.hermes/docs/dashboard.md for LAN setup"
echo ""
echo "${BOLD}Documentation:${RESET}"
echo "  • Bundle README:    $SCRIPT_DIR/README.md"
echo "  • Config reference: $HOME/.hermes/docs/configuration.md  (if shipped)"
echo "  • Workflow rules:   $HOME/.hermes/config/AGENTS.md"
echo ""
echo "If anything broke, see the troubleshooting section in $SCRIPT_DIR/README.md"
echo "or re-run this script (it's idempotent — already-done steps are skipped)."
echo ""
