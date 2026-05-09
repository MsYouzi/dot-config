# claude-opus / claude-gpt
#
# Two thin wrappers around Anthropic's Claude Code CLI that pin the model
# to a specific GitHub Copilot model (resolved by the local copilot-api
# proxy at http://localhost:4141 — see ~/.claude/settings.json).
#
# Why aliases instead of /model in-session?
#   Claude Code's built-in /model picker is hard-coded to Anthropic's own
#   lineup (Sonnet / Opus / Haiku) and offers no way to whitelist or replace
#   that list with arbitrary Copilot model names. The next-best UX is two
#   launchers, one per model — invoking `claude-opus` or `claude-gpt`
#   gives you exactly two visible "options" in your shell.
#
# In-session: `/model <name>` accepts free-form strings and they pass
# through the proxy unchanged, so you can still switch mid-session if
# you remember the Copilot model name.
#
# Requirements: copilot-api proxy listening on :4141 and `claude` on PATH.

alias claude-opus='claude --model claude-opus-4.7-xhigh'
alias claude-gpt='claude --model gpt-5.5'
