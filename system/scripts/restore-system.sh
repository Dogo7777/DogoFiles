#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# restore-system.sh — Restaura a camada de sistema do Arch Atômico
#
# ATENÇÃO: Este script PRESSUPÕE que:
#   1. O Arch já está instalado e bootando
#   2. As partições btrfs já foram criadas (o script recria subvolumes)
#   3. Você clonou o repositório dotfiles em ~/dotfiles
#
# Ordem de execução:
#   Etapa 1 → módulos blacklist + sysctl   (sem reboot necessário)
#   Etapa 2 → zram                          (sem reboot)
#   Etapa 3 → serviços systemd              (sem reboot)
#   Etapa 4 → udev                          (udevadm reload)
#   Etapa 5 → GRUB                          (requer reboot)
#   Etapa 6 → kernel/mkinitcpio             (requer reboot)
#   Etapa 7 → microfone                     (requer reboot ou restart de pipewire)
#   Etapa 8 → fstab                         (requer reboot — CUIDADO)
#
# Uso: sudo bash ~/dotfiles/scripts/restore-system.sh
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

B='\033[38;5;39m'; G='\033[38;5;82m'; Y='\033[38;5;220m'
R='\033[0m';        E='\033[1;31m';    W='\033[1;37m'

info()    { echo -e "${B}  →${R} $*"; }
success() { echo -e "${G}  ✔${R} $*"; }
warn()    { echo -e "${Y}  ⚠${R} $*"; }
error()   { echo -e "${E}  ✖${R} $*"; exit 1; }
section() {
    echo -e "\n${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
    echo -e "${W}   $*${R}"
    echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
}

# ── Verificações ──────────────────────────────────────────────────────────────

[[ $EUID -ne 0 ]] && error "Rode com sudo: sudo bash ~/dotfiles/scripts/restore-system.sh"

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
DOTFILES="$REAL_HOME/dotfiles"
SYSDIR="$DOTFILES/system"

[[ ! -d "$SYSDIR" ]] && error "Diretório $SYSDIR não encontrado. Rode backup-system.sh primeiro."

clear
echo -e "\n${B}  Arch Atômico — Restauração de Sistema 🔧${R}"
echo -e "  ${Y}Leia cada etapa antes de confirmar.${R}\n"

# ── Confirmação global ────────────────────────────────────────────────────────

echo -e "${Y}⚠  Este script modifica configurações críticas do sistema.${R}"
echo -e "   Certifique-se de ter um backup do /etc/fstab atual antes de continuar."
echo ""
read -rp "   Continuar? [s/N] " CONFIRM
[[ "${CONFIRM,,}" != "s" ]] && echo "Cancelado." && exit 0

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 1 — Módulos blacklistados + sysctl
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 1/8 — Módulos blacklistados + sysctl"

# Módulos blacklistados
if ls "$SYSDIR/modules/"*.conf 2>/dev/null | grep -q .; then
    info "Restaurando /etc/modprobe.d/..."
    mkdir -p /etc/modprobe.d
    for f in "$SYSDIR/modules/"*.conf; do
        cp "$f" /etc/modprobe.d/
        success "/etc/modprobe.d/$(basename $f)"
    done

    # Verifica intel_powerclamp especificamente
    if grep -r "intel_powerclamp" /etc/modprobe.d/ &>/dev/null; then
        success "intel_powerclamp blacklistado ✔"
    fi
else
    warn "Nenhuma config de módulo encontrada no backup"
fi

# modules-load.d
if ls "$SYSDIR/kernel/modules-load.d/"*.conf 2>/dev/null | grep -q .; then
    mkdir -p /etc/modules-load.d
    cp "$SYSDIR/kernel/modules-load.d/"*.conf /etc/modules-load.d/
    success "modules-load.d restaurado"
fi

# sysctl
if ls "$SYSDIR/sysctl/"*.conf 2>/dev/null | grep -q .; then
    info "Restaurando /etc/sysctl.d/..."
    mkdir -p /etc/sysctl.d
    for f in "$SYSDIR/sysctl/"*.conf; do
        cp "$f" /etc/sysctl.d/
        success "/etc/sysctl.d/$(basename $f)"
    done
    # Aplica imediatamente sem reboot
    sysctl --system > /dev/null 2>&1
    success "sysctl aplicado ao sistema atual"
fi

if [ -f "$SYSDIR/sysctl/sysctl.conf" ]; then
    cp "$SYSDIR/sysctl/sysctl.conf" /etc/sysctl.conf
    success "/etc/sysctl.conf restaurado"
fi

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 2 — zram
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 2/8 — zram"

if [ -f "$SYSDIR/zram/zram-generator.conf" ]; then
    info "Restaurando zram-generator.conf..."
    # Instala o pacote se necessário
    pacman -Q zram-generator &>/dev/null \
        || pacman -S --noconfirm zram-generator
    cp "$SYSDIR/zram/zram-generator.conf" /etc/systemd/zram-generator.conf
    systemctl daemon-reload
    systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
    success "zram-generator.conf restaurado e serviço iniciado"
fi

if [ -f "$SYSDIR/zram/zramswap" ]; then
    cp "$SYSDIR/zram/zramswap" /etc/default/zramswap
    systemctl enable --now zramswap.service 2>/dev/null || true
    success "zramswap restaurado"
fi

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 3 — Serviços systemd
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 3/8 — Serviços systemd"

# Unidades de sistema
if ls "$SYSDIR/services/system/"*.{service,timer,socket,path,mount} 2>/dev/null | grep -q .; then
    info "Restaurando unidades de sistema..."
    for f in "$SYSDIR/services/system/"*; do
        [ -f "$f" ] || continue
        cp "$f" /etc/systemd/system/
        unit=$(basename "$f")
        # Habilita e inicia se for .service ou .timer
        if [[ "$unit" == *.service ]] || [[ "$unit" == *.timer ]]; then
            systemctl enable "$unit" 2>/dev/null || true
            systemctl start  "$unit" 2>/dev/null || true
            success "Ativado: $unit"
        fi
    done
fi

# Overrides (systemctl edit)
for d in "$SYSDIR/services/system/"*.d/; do
    [ -d "$d" ] || continue
    dirname=$(basename "$d")
    mkdir -p "/etc/systemd/system/$dirname"
    cp "$d"*.conf "/etc/systemd/system/$dirname/" 2>/dev/null || true
    success "Override restaurado: $dirname"
done

# Unidades de usuário
if ls "$SYSDIR/services/user/"*.{service,timer} 2>/dev/null | grep -q .; then
    info "Restaurando unidades de usuário..."
    mkdir -p "$REAL_HOME/.config/systemd/user"
    cp "$SYSDIR/services/user/"* "$REAL_HOME/.config/systemd/user/" 2>/dev/null || true
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config/systemd"
    sudo -u "$REAL_USER" systemctl --user daemon-reload 2>/dev/null || true
    success "Unidades de usuário restauradas"
fi

systemctl daemon-reload
success "daemon-reload executado"

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 4 — udev
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 4/8 — Regras udev"

if ls "$SYSDIR/udev/"*.rules 2>/dev/null | grep -q .; then
    info "Restaurando regras udev..."
    mkdir -p /etc/udev/rules.d
    for f in "$SYSDIR/udev/"*.rules; do
        cp "$f" /etc/udev/rules.d/
        success "/etc/udev/rules.d/$(basename $f)"
    done
    # Recarrega sem reiniciar
    udevadm control --reload-rules
    udevadm trigger
    success "udev recarregado"
else
    warn "Nenhuma regra udev no backup"
fi

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 5 — GRUB
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 5/8 — GRUB"

if [ -f "$SYSDIR/grub/grub-default" ]; then
    info "Restaurando /etc/default/grub..."

    # Backup do grub atual antes de sobrescrever
    cp /etc/default/grub /etc/default/grub.bak-before-restore

    cp "$SYSDIR/grub/grub-default" /etc/default/grub
    success "/etc/default/grub restaurado"

    # Scripts customizados de /etc/grub.d/
    if ls "$SYSDIR/grub/grub.d/"* 2>/dev/null | grep -q .; then
        for f in "$SYSDIR/grub/grub.d/"*; do
            cp "$f" /etc/grub.d/
            chmod +x "/etc/grub.d/$(basename $f)"
            success "grub.d/$(basename $f)"
        done
    fi

    # Tema GRUB
    if [ -d "$SYSDIR/grub/theme" ] && [ "$(ls -A "$SYSDIR/grub/theme")" ]; then
        THEME_DEST=$(grep "^GRUB_THEME=" /etc/default/grub \
            | cut -d'"' -f2 | xargs dirname 2>/dev/null || echo "/boot/grub/themes/custom")
        mkdir -p "$THEME_DEST"
        cp -r "$SYSDIR/grub/theme/." "$THEME_DEST/"
        success "Tema GRUB restaurado em $THEME_DEST"
    fi

    info "Regenerando grub.cfg..."
    grub-mkconfig -o /boot/grub/grub.cfg
    success "grub.cfg regenerado"
else
    warn "grub-default não encontrado no backup"
fi

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 6 — Kernel / mkinitcpio
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 6/8 — Kernel / mkinitcpio"

if [ -f "$SYSDIR/kernel/mkinitcpio.conf" ]; then
    info "Restaurando mkinitcpio.conf..."
    cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak-before-restore
    cp "$SYSDIR/kernel/mkinitcpio.conf" /etc/mkinitcpio.conf
    success "mkinitcpio.conf restaurado"
fi

if ls "$SYSDIR/kernel/mkinitcpio.d/"*.preset 2>/dev/null | grep -q .; then
    cp "$SYSDIR/kernel/mkinitcpio.d/"*.preset /etc/mkinitcpio.d/
    success "Presets de mkinitcpio restaurados"
fi

if [ -f "$SYSDIR/kernel/cmdline.txt" ]; then
    mkdir -p /etc/kernel
    cp "$SYSDIR/kernel/cmdline.txt" /etc/kernel/cmdline
    success "/etc/kernel/cmdline restaurado"
fi

if ls "$SYSDIR/kernel/modules-load.d/"*.conf 2>/dev/null | grep -q .; then
    mkdir -p /etc/modules-load.d
    cp "$SYSDIR/kernel/modules-load.d/"*.conf /etc/modules-load.d/
fi

# Regenera o initramfs
echo ""
warn "Regenerando initramfs (mkinitcpio -P) — pode demorar ~30s..."
mkinitcpio -P
success "Initramfs regenerado"

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 7 — Microfone por cabo
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 7/8 — Microfone por cabo"

# Script mic-celular.sh
if [ -f "$SYSDIR/mic/mic-celular.sh" ]; then
    cp "$SYSDIR/mic/mic-celular.sh" "$REAL_HOME/mic-celular.sh"
    chmod +x "$REAL_HOME/mic-celular.sh"
    chown "$REAL_USER:$REAL_USER" "$REAL_HOME/mic-celular.sh"
    success "mic-celular.sh restaurado"
fi

# PipeWire
if [ -d "$SYSDIR/mic/pipewire" ]; then
    mkdir -p "$REAL_HOME/.config/pipewire"
    cp -r "$SYSDIR/mic/pipewire/." "$REAL_HOME/.config/pipewire/"
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config/pipewire"
    success "Config PipeWire restaurada"
fi

# WirePlumber
if [ -d "$SYSDIR/mic/wireplumber" ]; then
    mkdir -p "$REAL_HOME/.config/wireplumber"
    cp -r "$SYSDIR/mic/wireplumber/." "$REAL_HOME/.config/wireplumber/"
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config/wireplumber"
    success "Config WirePlumber restaurada"
fi

# ALSA
[ -f "$SYSDIR/mic/.asoundrc" ] && \
    cp "$SYSDIR/mic/.asoundrc" "$REAL_HOME/.asoundrc" && \
    chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.asoundrc" && \
    success ".asoundrc restaurado"

[ -f "$SYSDIR/mic/asound.conf" ] && \
    cp "$SYSDIR/mic/asound.conf" /etc/asound.conf && \
    success "/etc/asound.conf restaurado"

# PulseAudio
if [ -d "$SYSDIR/mic/pulse" ]; then
    mkdir -p "$REAL_HOME/.config/pulse"
    cp -r "$SYSDIR/mic/pulse/." "$REAL_HOME/.config/pulse/"
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config/pulse"
    success "Config PulseAudio restaurada"
fi

# Regras udev de áudio do mic
for f in "$SYSDIR/mic/"*.rules; do
    [ -f "$f" ] || continue
    cp "$f" /etc/udev/rules.d/
    success "udev: $(basename $f)"
done

# Reinicia PipeWire do usuário sem reboot
sudo -u "$REAL_USER" systemctl --user restart pipewire pipewire-pulse wireplumber \
    2>/dev/null && success "PipeWire reiniciado" || warn "Reinicie o PipeWire manualmente"

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 8 — fstab (ÚLTIMA — mais arriscada)
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 8/8 — fstab"

echo ""
echo -e "${Y}⚠  ATENÇÃO: Restaurar o fstab de outra máquina pode impedir o boot${R}"
echo -e "   se os UUIDs dos discos forem diferentes."
echo ""
echo -e "   fstab do backup:"
echo ""
cat "$SYSDIR/btrfs/fstab" | grep -v "^#" | grep -v "^$" \
    | awk '{printf "   %-45s %-15s %-8s %s\n", $1, $2, $3, $4}'
echo ""
echo -e "   UUIDs dos discos DESTA máquina:"
blkid | grep -E "(btrfs|vfat|ext4)" \
    | awk -F'"' '{printf "   %s → UUID=%s\n", $1, $4}'
echo ""
echo -e "${Y}   Restaurar o fstab do backup? Recomendado APENAS se os UUIDs coincidirem.${R}"
read -rp "   Restaurar fstab? [s/N] " FSTAB_CONFIRM

if [[ "${FSTAB_CONFIRM,,}" == "s" ]]; then
    cp /etc/fstab /etc/fstab.bak-before-restore
    cp "$SYSDIR/btrfs/fstab" /etc/fstab
    success "/etc/fstab restaurado (backup em /etc/fstab.bak-before-restore)"
    warn "Verifique com: mount -a   antes de reiniciar!"
else
    warn "fstab NÃO restaurado — edite manualmente se necessário"
    info "Referência em: $SYSDIR/btrfs/fstab-annotated"
fi

# ══════════════════════════════════════════════════════════════════════════════
# RESUMO FINAL
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${B}╔══════════════════════════════════════════════════════╗${R}"
echo -e "${B}║${R}  ${G}✔  Restauração de sistema concluída!${R}               ${B}║${R}"
echo -e "${B}╚══════════════════════════════════════════════════════╝${R}"
echo ""
echo -e "${W}Próximos passos obrigatórios:${R}"
echo ""
echo -e "  ${B}1.${R} Verifique se o fstab está OK:  ${B}mount -a${R}"
echo -e "  ${B}2.${R} Reinicie o sistema:            ${B}reboot${R}"
echo -e "  ${B}3.${R} Após reboot, verifique o GRUB e o boot"
echo -e "  ${B}4.${R} Verifique o zram:              ${B}zramctl${R}"
echo -e "  ${B}5.${R} Verifique serviços:            ${B}systemctl --failed${R}"
echo -e "  ${B}6.${R} Teste o microfone:             ${B}~/mic-celular.sh${R}"
echo ""
echo -e "${Y}⚠  Backups dos arquivos originais:${R}"
echo -e "   /etc/default/grub.bak-before-restore"
echo -e "   /etc/mkinitcpio.conf.bak-before-restore"
echo -e "   /etc/fstab.bak-before-restore  (se restaurado)"
echo ""
