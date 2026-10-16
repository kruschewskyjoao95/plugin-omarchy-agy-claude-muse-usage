# Argon Usage Bar

Bar label for Gemini 4 Argon weekly limit: `Argon <days to weekly reset> <weekly %>`.

Since Argon only has a 7-day rolling limit and no 5-hour burst quota, both the
bar pill and the popup panel display only the 7-day window.

Runs `jesseburlamaque.antigravity-usage/bin/omarchy-agent-usage-antigravity`
every 3 minutes.
