# Run Copilot CLI cleanup after successful self-updates.
copilot() {
  command copilot "$@"
  local copilot_status=$?

  if [ "$copilot_status" -eq 0 ] && [ "${1:-}" = "update" ] && [ -x "$HOME/.copilot/cleanup-legacy.sh" ]; then
    "$HOME/.copilot/cleanup-legacy.sh" || true
  fi

  return "$copilot_status"
}
