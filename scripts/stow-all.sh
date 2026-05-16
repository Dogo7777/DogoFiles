#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# stow-all.sh — Aplica os symlinks via GNU Stow
#
# Deve ser executado DEPOIS do restore.sh ou numa máquina nova
# após clonar o repositório.
#
# Uso: bash ~/dotfiles/scripts/stow-all.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

DOTFILES="$HOME/dotfiles"
B='\033[38;5;39m'; G='\033[38;5;82m'; Y='\033[38;5;220m'
R='\033[0m';        E='\033[1;31m'

info()    { echo -e "${B}  →${R} $*"; }
success() { echo -e "${G}  ✔${R} $*"; }
warn()    { echo -e "${Y}  ⚠${R} $*"; }
section() { echo -e "\n${B}━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"; }

cd "$DOTFILES"

# ── Verifica dependências ─────────────────────────────────────────────────────

if ! command -v stow &>/dev/null; then
    echo -e "${E}GNU Stow não instalado.${R} Instale com: sudo pacman -S stow"
    exit 1
fi

# ── Função helper ─────────────────────────────────────────────────────────────

stow_pkg() {
    local pkg="$1"
    local target="${2:-$HOME}"
    if [ -d "$DOTFILES/$pkg" ]; then
        info "Aplicando $pkg → $target"
        # --restow: desfaz e refaz links (idempotente)
        stow --restow --target="$target" --dir="$DOTFILES" "$pkg" 2>&1 \
            | grep -v "^$" || true
        success "$pkg aplicado"
    else
        warn "Pacote '$pkg' não encontrado em $DOTFILES — pulando"
    fi
}

# ── Aplica pacotes ────────────────────────────────────────────────────────────

section "ZSH"
stow_pkg zsh

section "JUST"
stow_pkg just

section "KDE"
stow_pkg kde

section "SCRIPTS"
# Scripts vão para ~/.local/bin
mkdir -p "$HOME/.local/bin"
if [ -f "$DOTFILES/scripts/mic-celular.sh" ]; then
    ln -sf "$DOTFILES/scripts/mic-celular.sh" "$HOME/mic-celular.sh"
    success "mic-celular.sh linkado em ~/"
fi

# ── SSH ───────────────────────────────────────────────────────────────────────

section "SSH"
if [ -d "$DOTFILES/ssh" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ln -sf "$DOTFILES/ssh/config" "$HOME/.ssh/config" 2>/dev/null && \
        success "~/.ssh/config linkado" || warn "Falha ao linkar ~/.ssh/config"
fi

# ── Resultado ─────────────────────────────────────────────────────────────────

section "CONCLUÍDO"
echo ""
echo -e "${G}Todos os symlinks aplicados!${R}"
echo ""
echo "Verifique com:"
echo -e "  ${B}ls -la ~/.zshrc ~/.justfile ~/.p10k.zsh${R}"
echo -e "  ${B}ls -la ~/.config/kdeglobals${R}"
echo ""
echo -e "${Y}KDE:${R} Faça logout e login para aplicar os temas."
echo -e "${Y}ZSH:${R} Execute: source ~/.zshrc"
