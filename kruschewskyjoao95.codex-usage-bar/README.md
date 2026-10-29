# Codex Usage Bar

Bar label for Codex: `Codex <5-hour %> | <days to weekly reset> <weekly %>`.

Reads `~/.local/state/omarchy/agents/usage/codex.json`, the record the Omarchy
agents panel maintains. Refreshing it does not run a model turn, so it does not
spend quota.

Clicking the label opens a popup with the 5-hour and weekly bars and their reset
times. Right-click refreshes the record now.
