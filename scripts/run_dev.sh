#!/bin/bash
# scripts/run_dev.sh — Builds and launches "build/Persona Mode.app".
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

bash "$SCRIPT_DIR/build_app.sh"
open "$REPO_DIR/build/Persona Mode.app"

