# Muse Usage

Muse Code subscription usage in the Omarchy bar: the 5-hour window and the
weekly allowance, with reset times on hover.

```
Muse 87% | 7d 29%
```

## How it gets the numbers

Muse only reports its subscription usage after it serves a model turn, and it
does not save that report anywhere on disk. So `bin/omarchy-muse-usage` starts
`muse serve`, runs one minimal turn (`reasoningEffort: minimal`, input `ok`),
and reads the `usage/changed` notification. A refresh takes about 4 seconds.

Every live refresh spends a little of the quota it reports, so the collector
caches the last reading in `~/.cache/omarchy/muse-usage.json`:

- Within 1 hour of the last live reading, the cached record is reused.
- After 1 hour, the bar poll (every hour) runs a live turn.
- Once either window has reset, its percentages are stale, so it runs a live turn.
- Right-click on the bar forces a live turn.

If a live turn fails, the widget keeps the last known numbers and says they are
not current.

Each live turn also creates a short Muse session, saved under
`~/.local/share/muse/sessions`.

## Requirements

- `muse` on `PATH` (or `MUSE_BIN` set), signed in with `muse login`.
- Python 3 (stdlib only).

## Record

The collector prints one JSON record. Its `limits` array uses the same shape as
the Claude and Codex collectors in the agents panel, so it can be wired there later.

```json
{
  "id": "muse",
  "ready": true,
  "window": { "usedPercent": 87, "resetsAt": "...", "durationMins": 300 },
  "weekly": { "usedPercent": 29, "resetsAt": "..." },
  "limits": [ { "label": "Session (5-hour)", "percent": 87, "resetsAt": "..." } ]
}
```

## Manual check

```bash
~/.config/omarchy/plugins/kruschewskyjoao95.muse-usage/bin/omarchy-muse-usage          # cache-aware
~/.config/omarchy/plugins/kruschewskyjoao95.muse-usage/bin/omarchy-muse-usage --force  # live turn
```
