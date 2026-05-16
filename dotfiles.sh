#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# dotfiles.sh — Menu central do Arch Atômico
# Uso: bash ~/dotfiles/dotfiles.sh
# ══════════════════════════════════════════════════════════════════════════════

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B='\033[38;5;39m'; G='\033[38;5;82m'; Y='\033[38;5;220m'
R='\033[0m'; W='\033[1;37m'; E='\033[1;31m'; D='\033[2m'

_header() {
    clear
    echo -e "\n${B}  ▤ Arch Atômico — Dotfiles Manager${R}"
    echo -e "${D}  $(date '+%d/%m/%Y %H:%M')  •  $(hostname)  •  $(uname -r)${R}\n"
}

_confirm() {
    echo -e "\n${Y}  ⚠  $1${R}"
    read -rp "     Confirmar? [s/N] " r
    [[ "${r,,}" == "s" ]]
}

_run_backup() {
    echo -e "\n${G}  → Backup de apps, KDE, zsh, just...${R}\n"
    bash "$DOTFILES/scripts/backup.sh"
}

_run_backup_system() {
    echo -e "\n${G}  → Backup de sistema (btrfs, grub, kernel, serviços...)${R}\n"
    sudo bash "$DOTFILES/scripts/backup-system.sh"
}

_run_restore() {
    echo -e "\n${G}  → Restaurando apps, KDE, zsh, just...${R}\n"
    bash "$DOTFILES/scripts/restore.sh"
}

_run_restore_system() {
    echo -e "\n${G}  → Restaurando sistema (grub, kernel, serviços...)${R}\n"
    sudo bash "$DOTFILES/scripts/restore-system.sh"
}

_run_stow() {
    echo -e "\n${G}  → Aplicando symlinks via GNU Stow...${R}\n"
    bash "$DOTFILES/scripts/stow-all.sh"
}

_git_push() {
    echo -e "\n${G}  → Commitando e subindo para o GitHub...${R}\n"
    cd "$DOTFILES"
    git add -A
    git status --short
    echo ""
    read -rp "  Mensagem do commit (Enter = data automática): " msg
    msg="${msg:-backup: $(date '+%Y-%m-%d %H:%M')}"
    git commit -m "$msg" && git push \
        && echo -e "\n${G}  ✔ Push concluído!${R}" \
        || echo -e "\n${E}  ✖ Falha no git push.${R}"
}

# ── Menu principal ────────────────────────────────────────────────────────────

while true; do
    _header

    echo -e "  ${W}BACKUP${R}"
    echo -e "  ${B}[1]${R}  Backup apps + KDE + zsh + just"
    echo -e "  ${B}[2]${R}  Backup sistema  (btrfs, grub, kernel, serviços, udev)"
    echo -e "  ${B}[3]${R}  Backup ${W}completo${R}  (1 + 2 + push automático)\n"

    echo -e "  ${W}RESTAURAR${R}"
    echo -e "  ${B}[4]${R}  Restaurar apps + KDE + zsh + just"
    echo -e "  ${B}[5]${R}  Restaurar sistema  (grub, kernel, serviços, udev)"
    echo -e "  ${B}[6]${R}  Restaurar ${W}completo${R}  (sistema primeiro, apps depois)\n"

    echo -e "  ${W}UTILITÁRIOS${R}"
    echo -e "  ${B}[7]${R}  Aplicar symlinks (GNU Stow)"
    echo -e "  ${B}[8]${R}  Git push  (commitar e subir dotfiles)\n"

    echo -e "  ${B}[0]${R}  Sair\n"

    read -rp "  Escolha: " OPT

    case "$OPT" in

        1)  _header
            _run_backup
            ;;

        2)  _header
            _run_backup_system
            ;;

        3)  _header
            if _confirm "Vai rodar backup COMPLETO (apps + sistema) e fazer git push."; then
                _run_backup
                echo ""
                _run_backup_system
                echo ""
                _git_push
            fi
            ;;

        4)  _header
            if _confirm "Restaurar apps, KDE, zsh e just na máquina atual?"; then
                _run_restore
            fi
            ;;

        5)  _header
            if _confirm "Restaurar sistema (grub, kernel, serviços)? Pode requerer reboot."; then
                _run_restore_system
            fi
            ;;

        6)  _header
            if _confirm "Restaurar TUDO? Sistema primeiro, depois apps. Pode requerer reboot."; then
                _run_restore_system
                echo ""
                _run_restore
            fi
            ;;

        7)  _header
            _run_stow
            ;;

        8)  _header
            _git_push
            ;;

        0)  echo -e "\n${D}  Saindo...${R}\n"
            exit 0
            ;;

        *)  echo -e "\n${E}  Opção inválida.${R}"
            sleep 1
            ;;
    esac

    echo -e "\n${D}  Pressione Enter para voltar ao menu...${R}"
    read -r
done
