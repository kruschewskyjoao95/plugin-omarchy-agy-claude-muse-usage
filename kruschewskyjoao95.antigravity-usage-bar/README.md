# Antigravity Usage Bar

Bar label for Antigravity Gemini limits: `Antigravity <5-hour %> | <days to weekly reset> <weekly %>`.

Reads `~/.local/state/omarchy/agents/usage/agy.json`, the record the Omarchy
agents panel maintains. Refreshing it reads local Antigravity files, so it does
not spend quota.

Clicking the label opens a popup with the 5-hour and weekly bars and their reset
times. Right-click refreshes the record now.
