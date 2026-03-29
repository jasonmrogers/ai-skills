#!/usr/bin/env bash
# next-wave.sh — run one wave of the build, then stop.
#
# Usage:
#   ./scripts/next-wave.sh           # run next wave, stop, review output
#   ./scripts/next-wave.sh --loop    # keep running until all done or failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORCHESTRATOR_PROMPT="$PROJECT_ROOT/specs/orchestrator.md"
LOOP=false

for arg in "$@"; do
  [[ "$arg" == "--loop" ]] && LOOP=true
done

if [[ ! -f "$ORCHESTRATOR_PROMPT" ]]; then
  echo "❌ orchestrator.md not found at $ORCHESTRATOR_PROMPT"
  exit 1
fi

run_wave() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Build — $(date '+%Y-%m-%d %H:%M:%S')"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  cd "$PROJECT_ROOT"
  claude -p "$(cat "$ORCHESTRATOR_PROMPT")"
  return $?
}

if [[ "$LOOP" == true ]]; then
  echo "Running in loop mode. Press Ctrl+C to stop between waves."
  while true; do
    run_wave
    EXIT=$?
    if [[ $EXIT -ne 0 ]]; then
      echo "❌ Orchestrator exited with code $EXIT. Stopping."
      exit $EXIT
    fi
    if ! grep -q "| todo |" "$PROJECT_ROOT/specs/"*"-tasks.md" 2>/dev/null; then
      echo "🎉 All tasks complete!"
      exit 0
    fi
    echo "Wave complete. Starting next wave in 3 seconds... (Ctrl+C to pause)"
    sleep 3
  done
else
  run_wave
fi
