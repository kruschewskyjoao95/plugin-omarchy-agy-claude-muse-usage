# Plugins de uso para Omarchy — Antigravity, Argon, Claude e Muse

Quatro widgets de barra do [Omarchy](https://omarchy.org/) que mostram o uso
das assinaturas de IA: janela de 5 horas e cota semanal, com tempos de reset.

| Pasta | Plugin | O que mostra |
|---|---|---|
| `kruschewskyjoao95.antigravity-usage-bar` | Antigravity Usage Bar | `Antigravity <5h %> \| <dias p/ reset semanal> <semanal %>` |
| `kruschewskyjoao95.argon-usage-bar` | Argon Usage Bar | `Argon <dias p/ reset semanal> <semanal %>` (Argon/Gemini 4 só tem janela de 7 dias) |
| `kruschewskyjoao95.claude-usage-bar` | Claude Usage Bar | `Claude <5h %> \| <dias p/ reset semanal> <semanal %>` |
| `kruschewskyjoao95.muse-usage` | Muse Usage | `Muse <5h %> \| <dias p/ reset semanal> <semanal %>` |

Cada pasta é um plugin completo e independente, com seu próprio `README.md`.

## Instalação

Copie as pastas dos plugins que quiser para `~/.config/omarchy/plugins/`:

```bash
git clone https://github.com/kruschewskyjoao95/plugin-omarchy-agy-claude-muse-usage.git
cp -r plugin-omarchy-agy-claude-muse-usage/kruschewskyjoao95.* ~/.config/omarchy/plugins/
```

Depois adicione os ids à seção `right` da barra em `~/.config/omarchy/shell.json`
(ou use `omarchy bar move <id> --section right`) e recarregue a shell:

```bash
omarchy restart shell
```

## Dependências

- **Antigravity** e **Argon**: executam o coletor do plugin
  `jesseburlamaque.antigravity-usage` (`bin/omarchy-agent-usage-antigravity`),
  que lê os arquivos locais do Antigravity — instale esse plugin também.
- **Claude**: lê `~/.local/state/omarchy/agents/usage/claude.json`, mantido
  pelo painel de agentes do Omarchy.
- **Muse**: precisa do `muse` no `PATH`, logado (`muse login`), e de
  Python 3. Detalhes e custos de atualização no README do plugin.

## Licença

MIT — veja o `manifest.json` de cada plugin.
