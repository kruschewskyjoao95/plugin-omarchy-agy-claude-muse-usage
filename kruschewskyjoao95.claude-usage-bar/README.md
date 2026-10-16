# Claude Usage Bar

Bar label for Claude Code: `Claude <5-hour %> | <days to weekly reset> <weekly %>`.

Reads `~/.local/state/omarchy/agents/usage/claude.json`, the record the Omarchy
agents panel maintains. Refreshing it uses Anthropic's usage endpoint, not a
model turn, so it does not spend quota.
