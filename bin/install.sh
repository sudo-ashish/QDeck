#!/usr/bin/env bash
# QDeck: Forwarding wrapper: invokes root QDeck install.sh orchestrator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

exec "$REPO_ROOT/install.sh" "$@"
