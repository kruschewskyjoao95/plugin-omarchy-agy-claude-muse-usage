# Codex Usage

Codex subscription usage in the Omarchy bar: the 5-hour window and weekly allowance, with reset times on hover.

```
Codex 87% | 7d 29%
```

## How it gets the numbers

Reads `~/.local/state/omarchy/agents/usage/codex.json`, maintained by the Omarchy agents panel. Right-clicking the bar forces `omarchy-agent-usage-update --force codex`. The widget polls every three minutes and watches the record for changes.

## Install

Keep the plugin folder and id as `kruschewskyjoao95.muse-usage` when replacing the existing Muse widget. Restart the shell after installing:

```bash
omarchy restart shell
```

## Record

The Codex record stores limits as fractions from 0 to 1; this widget displays them as percentages. It expects a 5-hour entry followed by a weekly entry in `limits`.
