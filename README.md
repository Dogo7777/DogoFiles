# 🎮 Arch Atômico — Dotfiles

Setup pessoal para Arch Linux com KDE Plasma, raiz imutável e containers Distrobox.

## O que está aqui

| Diretório | Conteúdo |
|-----------|----------|
| `zsh/` | `.zshrc`, `.p10k.zsh`, `.gitconfig` |
| `just/` | `.justfile` (task runner — equivalente ao `ujust` do Bazzite) |
| `kde/` | Configs do Plasma, KWin, temas, cores, fontes, wallpapers |
| `distrobox/` | Script de criação dos containers + lista de containers |
| `packages/` | Listas de pacotes (host, Arch-base, AUR, subsistema, Flatpak) |
| `scripts/` | `backup.sh`, `restore.sh`, `stow-all.sh`, `mic-celular.sh` |

## Containers

| Container | Distro | Uso |
|-----------|--------|-----|
| `Arch-base` | Arch Linux | pacman + yay (AUR) |
| `subsistema` | Ubuntu 24.04 | apt, Java, .deb |

## Instalação em máquina nova

```bash
# 1. Clone o repositório
git clone https://github.com/SEU_USUARIO/dotfiles.git ~/dotfiles

# 2. Execute o restaurador completo
bash ~/dotfiles/scripts/restore.sh
```

O `restore.sh` faz tudo automaticamente:
- Instala dependências base (stow, zsh, distrobox, just…)
- Aplica symlinks via GNU Stow
- Instala Oh My Zsh + Powerlevel10k + plugins
- Reinstala pacotes do host
- Cria e popula os containers distrobox
- Reconstrói cache de fontes

## Backup (máquina existente)

```bash
bash ~/dotfiles/scripts/backup.sh
cd ~/dotfiles
git add -A
git commit -m "backup: $(date '+%Y-%m-%d')"
git push
```

## Comandos do just

```bash
just           # lista todos os comandos
just pac pkg   # instala via pacman + exporta
just aur pkg   # instala via yay (AUR) + exporta
just apt pkg   # instala via apt (subsistema) + exporta
just deb f.deb # instala .deb local + exporta
just bin cmd   # exporta binário do subsistema pro host
just java17    # muda versão do Java (8/17/21/25)
just unlock    # monta raiz em RW
just lock      # volta raiz pra RO
just update-all# atualiza todos os containers
just status    # status dos containers
```

## Estrutura de symlinks (GNU Stow)

```
~/dotfiles/
├── zsh/
│   ├── .zshrc          → ~/.zshrc
│   └── .p10k.zsh       → ~/.p10k.zsh
├── just/
│   └── .justfile       → ~/.justfile
└── kde/
    ├── .config/
    │   ├── kdeglobals  → ~/.config/kdeglobals
    │   ├── kwinrc      → ~/.config/kwinrc
    │   └── ...
    └── .local/share/
        ├── fonts/      → ~/.local/share/fonts/
        └── ...
```

## Pós-restauração manual

- **KDE**: System Settings → Global Theme para reaplicar o visual
- **SSH/GPG**: copiar manualmente (não versionadas por segurança)
- **Senhas/tokens**: usar um gerenciador de senhas (Bitwarden, etc.)
