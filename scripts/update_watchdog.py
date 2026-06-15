#!/usr/bin/env python3
"""
update_watchdog.py
------------------
A simple cron watchdog for ~/.hermes/.

Every 5 minutes (when registered as a cron with `no_agent=True`), it:

  1. Checks for uncommitted changes in the config repo.
  2. If any exist, commits them with a generic `chore(hermes):` prefix
     and pushes to `origin main`.
  3. Empty stdout if nothing happened (silent cron).
  4. Non-zero exit if the commit or push failed (you'll see a Telegram
     error alert).

This is the simplest possible auto-commit watchdog. It does NOT:
  - Detect hermes-agent version drift (that's a future enhancement)
  - Notify on push failure (just exits non-zero)
  - Handle complex merge situations
  - Honor `non_interactive_local_changes: stash` in config.yaml

If you need those, fork this and add them. The hermes-starter-bundle
keeps it small on purpose.

**Dry-run mode.** Set `UPDATE_WATCHDOG_DRY_RUN=1` to print what *would*
happen without committing. Useful for first-time testing.

Stdout is delivered to the originating Telegram chat verbatim (or saved
to ~/.hermes/cron/output/ for `deliver=local` jobs). Empty stdout is
silent — by design.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

HERMES_HOME = Path(os.environ.get("HERMES_HOME", Path.home() / ".hermes"))
DRY_RUN = os.environ.get("UPDATE_WATCHDOG_DRY_RUN", "0") == "1"


def run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess:
    """Run a shell command, raising on failure."""
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=True)


def main() -> int:
    if not (HERMES_HOME / ".git").is_dir():
        print(f"update_watchdog: {HERMES_HOME} is not a git repo, exiting.", file=sys.stderr)
        return 0

    # 1. Is the worktree dirty?
    status = run(["git", "status", "--porcelain"], cwd=HERMES_HOME)
    if not status.stdout.strip():
        # Nothing to do — silent.
        return 0

    changed_files = [line.split()[-1] for line in status.stdout.strip().splitlines()]
    n = len(changed_files)
    summary = f"track uncommitted changes ({n} file{'s' if n != 1 else ''})"

    if DRY_RUN:
        print(f"🔍 DRY-RUN: would commit {n} files:")
        for f in changed_files[:10]:
            print(f"   - {f}")
        if n > 10:
            print(f"   ... and {n - 10} more")
        print(f"   message: chore(hermes): {summary}")
        print(f"   push:    origin main")
        return 0

    # 2. Stage + commit.
    run(["git", "add", "-A"], cwd=HERMES_HOME)
    run(["git", "commit", "-m", f"chore(hermes): {summary}"], cwd=HERMES_HOME)

    # 3. Push (best-effort).
    push = subprocess.run(
        ["git", "push", "origin", "main"],
        cwd=HERMES_HOME,
        capture_output=True,
        text=True,
    )
    if push.returncode != 0:
        # Non-fatal: the local commit still landed. Surface the error.
        print(f"update_watchdog: commit OK, push failed: {push.stderr.strip()}")
        return 1

    # 4. Silent on success (or short report if a non-Telegram destination).
    if os.environ.get("HERMES_CRON_VERBOSE", "0") == "1":
        suffix = "" if n == 1 else "s"
        print(f"update_watchdog: committed and pushed {n} file{suffix}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
