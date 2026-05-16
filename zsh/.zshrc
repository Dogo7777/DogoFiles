# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# ==========================================
# PATH — garante que ~/.local/bin está na frente
# ==========================================
export PATH="$HOME/.local/bin:$PATH"


# ==========================================
# apx-install — instala pacote no subsistema e exporta
# ==========================================
apx-install() {
    if [ -z "$1" ]; then
        echo -e "❌ \033[1;31mErro:\033[0m Informe o nome do pacote."
        echo -e "Uso correto: \033[1;36mapx-install <pacote>\033[0m"
        return 1
    fi

    echo -e "📦 Buscando e instalando \033[1;32m$1\033[0m no subsistema..."

    # Separa update/install do export para checar o exit code da instalação corretamente
    distrobox enter subsistema -- bash -c "sudo apt-get update -qq > /dev/null 2>&1 && sudo apt install -y $1"

    if [ $? -eq 0 ]; then
        echo -e "✅ \033[1;32m$1\033[0m instalado com sucesso!"
        # Tenta exportar o app (pode falhar se for só CLI — tudo bem)
        distrobox enter subsistema -- distrobox-export --app "$1" > /dev/null 2>&1
    else
        echo -e "❌ \033[1;31mFalha ao instalar $1.\033[0m Verifique se o nome do pacote está correto."
        return 1
    fi
}


# ==========================================
# apx-bin — exporta binário do container pro Arch
# (definição única e correta)
# ==========================================
apx-bin() {
    if [ -z "$1" ]; then
        echo -e "❌ \033[1;31mErro:\033[0m Informe o nome do binário."
        return 1
    fi

    echo -e "🔍 Localizando \033[1;36m$1\033[0m no subsistema..."
    
    # 1. Tenta localizar via which
    BIN_PATH=$(distrobox enter subsistema -- which "$1" 2>/dev/null | tr -d '\r')

    # 2. Se falhar, tenta caminhos manuais conhecidos
    if [ -z "$BIN_PATH" ]; then
        if distrobox enter subsistema -- test -f /usr/local/bin/"$1"; then
            BIN_PATH="/usr/local/bin/$1"
        elif distrobox enter subsistema -- test -f /usr/bin/"$1"; then
            BIN_PATH="/usr/bin/$1"
        fi
    fi

    if [ -z "$BIN_PATH" ]; then
        echo -e "❌ \033[1;31mErro:\033[0m O comando '$1' não foi localizado em /usr/bin ou /usr/local/bin."
        echo -e "Dica: verifique o caminho real com \033[1;36mdistrobox enter subsistema\033[0m"
        return 1
    fi

    echo -e "🚀 Exportando de \033[1;32m$BIN_PATH\033[0m..."
    distrobox enter subsistema -- distrobox-export --bin "$BIN_PATH" --export-path ~/.local/bin > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo -e "✅ Comando \033[1;36m$1\033[0m integrado! Teste com: \033[1;32m$1\033[0m"
    else
        echo -e "❌ \033[1;31mErro fatal\033[0m na exportação."
        return 1
    fi
}
# ==========================================
# Câmbio Rápido de Java (Integração Subsistema)
#
# COMO FUNCIONA:
# O Java vive no subsistema (Ubuntu). Para usá-lo no Arch, precisamos:
#   1. Mudar o update-alternatives DENTRO do container
#   2. Exportar o binário 'java' atualizado para ~/.local/bin
#   3. Checar a versão usando o wrapper exportado (~/.local/bin/java)
# ==========================================

# Helper interno: muda o java no container e re-exporta o binário
_java_switch() {
    local version_path="$1"
    local label="$2"

    echo -e "🔄 $label"

    # Passo 1: Muda o alternatives dentro do container
    distrobox enter subsistema -- sudo update-alternatives --set java "$version_path" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "❌ \033[1;31mFalha ao trocar alternativa no subsistema.\033[0m"
        echo -e "Verifique se o caminho \033[1;33m$version_path\033[0m existe no container."
        return 1
    fi

    # Passo 2: Remove o wrapper antigo e re-exporta o java com o novo link
    rm -f "$HOME/.local/bin/java"
    distrobox enter subsistema -- distrobox-export --bin /usr/bin/java --export-path ~/.local/bin > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "❌ \033[1;31mFalha ao exportar o binário java para o Arch.\033[0m"
        return 1
    fi

    # Passo 3: Mostra a versão usando o wrapper agora atualizado
    echo -e "✅ Java trocado! Versão ativa:"
    "$HOME/.local/bin/java" -version 2>&1 || java -version
}

java8() {
    _java_switch \
        "/usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java" \
        "\033[1;33mMudando para Java 8 (Era Clássica / 1.12.2)...\033[0m"
}

java17() {
    _java_switch \
        "/usr/lib/jvm/java-17-openjdk-amd64/bin/java" \
        "\033[1;34mMudando para Java 17 (Era Moderna / 1.18+)...\033[0m"
}

java21() {
    _java_switch \
        "/usr/lib/jvm/java-21-openjdk-amd64/bin/java" \
        "\033[1;32mMudando para Java 21 (Era Atual / 1.20.5+)...\033[0m"
}

java25() {
    _java_switch \
        "/usr/lib/jvm/java-25-openjdk-amd64/bin/java" \
        "\033[1;35mMudando para Java 25 (Versão Ultra Recente / MC 26.1+)...\033[0m"
}


# ==========================================
# Instalador Automático de .DEB (Subsistema)
# ==========================================
apx-deb() {
    if [ -z "$1" ]; then
        echo -e "❌ \033[1;31mErro:\033[0m Você esqueceu de informar o arquivo."
        echo -e "Uso correto: \033[1;36mapx-deb nome-do-arquivo.deb\033[0m"
        return 1
    fi

    local DEB_FILE
    DEB_FILE=$(realpath "$1")

    if [ ! -f "$DEB_FILE" ]; then
        echo -e "❌ \033[1;31mErro:\033[0m Arquivo não encontrado: $DEB_FILE"
        return 1
    fi

    echo -e "📦 Iniciando instalação de \033[1;33m$1\033[0m no subsistema..."

    distrobox enter subsistema -- bash -c "sudo apt update -qq && sudo apt install -y '$DEB_FILE'"

    if [ $? -ne 0 ]; then
        echo -e "❌ \033[1;31mFalha ao instalar o .deb.\033[0m"
        return 1
    fi

    # Descobre o nome real do pacote para exportar o atalho
    local PKG_NAME
    PKG_NAME=$(distrobox enter subsistema -- dpkg-deb -W --showformat='${Package}' "$DEB_FILE" 2>/dev/null)

    if [ -n "$PKG_NAME" ]; then
        echo -e "🚀 Criando atalho do \033[1;36m$PKG_NAME\033[0m para o menu do Arch..."
        distrobox enter subsistema -- distrobox-export --app "$PKG_NAME" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "✅ \033[1;32mSucesso!\033[0m O aplicativo já deve estar no seu menu de iniciar."
        else
            echo -e "⚠️ \033[1;33mO pacote foi instalado, mas falhou ao criar o atalho.\033[0m"
            echo "Talvez não seja um app com interface. Se for um comando de terminal, use: apx-bin $PKG_NAME"
        fi
    else
        echo -e "⚠️ \033[1;33mNão foi possível detectar o nome do pacote para exportar o atalho.\033[0m"
    fi
}


# ==========================================
# Indicador de Status da Raiz no Prompt
# ==========================================
# Retorna 🔓 RW (vermelho) se a raiz está montada em escrita, ou 🔒 RO (verde) se está protegida
_get_root_mount_status() {
    if findmnt -n -o OPTIONS / | grep -q "\brw\b"; then
        echo "%F{red}🔓 RW%f"
    else
        echo "%F{green}🔒 RO%f"
    fi
}

# CORRIGIDO: era 'get_root_indicator' (inexistente), agora chama o nome correto
setopt PROMPT_SUBST
PROMPT='$(_get_root_mount_status) '$PROMPT


# ==========================================
# unlock / lock — alternar RW/RO na raiz imutável
# ==========================================
unlock() {
    if ! command -v sudo &> /dev/null; then
        echo "Erro: 'sudo' não encontrado."
        return 1
    fi
    echo "Tentando desbloquear a raiz (/) para escrita..."
    if sudo mount -o remount,rw /; then
        export SESSION_ROOT_UNLOCKED=1
        echo "Raiz desbloqueada com sucesso (RW)."
    else
        echo "Erro: Falha ao desbloquear a raiz."
        return 1
    fi
}

lock () {
    echo "Tentando bloquear a raiz (/) para leitura..."
    sync
    sudo systemctl stop systemd-journald.socket systemd-journald-dev-log.socket systemd-journald-audit.socket systemd-journald.service
    if sudo mount -o remount,ro /
    then
        sudo systemctl start systemd-journald.service
        unset SESSION_ROOT_UNLOCKED
        echo "Raiz bloqueada com sucesso (RO)."
    else
        sudo systemctl start systemd-journald.service
        echo "Erro: Falha ao bloquear a raiz."
        return 1
    fi
}

# Bloqueia a raiz automaticamente ao fechar o terminal, se estava desbloqueada
_cleanup_root_status() {
    if [[ -n "$SESSION_ROOT_UNLOCKED" ]]; then
        echo "Detectado que a raiz estava desbloqueada. Tentando bloquear automaticamente..."
        if sudo mount -o remount,ro / >/dev/null 2>&1; then
            echo "Raiz bloqueada automaticamente ao sair."
        else
            echo "Aviso: Falha ao bloquear a raiz automaticamente. Bloqueie manualmente com: lock"
        fi
    fi
}
add-zsh-hook zshexit _cleanup_root_status

# Cores ANSI
R="\033[0m" # Reset
B="\033[1m" # Bold
W="\033[1;37m" # White
G="\033[1;32m" # Green
C="\033[1;36m" # Cyan
Y="\033[1;33m" # Yellow

# Cores para o estilo Bazzite
BG_PURPLE="\033[48;5;54m" # Fundo roxo (aproximado)
FG_WHITE="\033[37m" # Texto branco
FG_RED="\033[31m" # Texto vermelho

# Cabeçalho "Welcome to Arch Atômico"
echo -e "${BG_PURPLE}${FG_WHITE} Welcome to Arch Atômico 🎮 ${R}"

# Tabela de Comandos
echo -e " ${W}>_ COMMAND      | DESCRIPTION${R}"
echo -e " ────────────────┼──────────────────────────────────────────"
echo -e " ${B}ujust               | Exibe este menu completo"
echo -e " ${B}ujust pac <pkg>${R} | Instala pacotes do Arch"
echo -e " ${B}ujust aur <pkg>${R} | Instala pacotes do AUR"
echo -e " ${B}ujust apt <pkg>${R} | Instala pacotes do Ubuntu"
echo -e " ${B}ujust deb <file>${R}| Instala pacotes .deb"
echo -e " ${B}ujust bin <cmd>${R} | Exporta comando para o Arch"
echo -e " ${B}ujust java17${R}    | Muda para Java 17 (MC 1.18+)"
echo -e " ${B}ujust unlock${R}    | Monta a raiz em RW"
echo -e " ${B}ujust lock${R}      | Bloqueia a raiz para RO"
echo -e " ${B}ujust info${R}      | Exibe informações do sistema"
echo -e " ${B}ujust update-all${R}| Atualiza pacman + AUR + apt"
echo -e " ${B}ujust check-updates${R}| Verifica atualizações"

# Informações Adicionais e Links
echo -e "\n ${W}• ${R} ${C}Problemas? ${R}Você pode reverter e fixar a versão anterior ou rebasear por data de build."
echo -e " ${W}• ${R} ${C}Reportar um problema: ${R}https://github.com/89luca89/distrobox/issues"
echo -e " ${W}• ${R} ${C}Documentação: ${R}https://wiki.archlinux.org/"
echo -e " ${W}• ${R} ${C}Ujust Docs: ${R}https://github.com/casey/just"

apx-pac() {
    export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$PATH"
    local DBOX_CMD=$(command -v distrobox)

    if [ -z "$1" ]; then
        echo -e "❌ \033[1;31mErro:\033[0m O que deseja instalar? Uso: apx-pac <pacote>"
        return 1
    fi

    local PKG="$1"
    local CONTAINER="Arch-base"
    echo -e "⚡ \033[1;36mForjando '$PKG' no $CONTAINER...\033[0m"

    # 1. Instalação
    "$DBOX_CMD" enter $CONTAINER -- sudo pacman -S --noconfirm "$PKG"

    if [ $? -eq 0 ]; then
        echo -e "🚀 \033[1;32mInstalado! Iniciando Extração Interna...\033[0m"

        # 2. O TRUQUE MESTRE: Executa toda a extração DE DENTRO do container
        "$DBOX_CMD" enter $CONTAINER -- sh -c '
            PACOTE="$1"
            
            echo -e "🔗 Extraindo binários:"
            for BIN in $(pacman -Ql "$PACOTE" 2>/dev/null | awk "/\/usr\/bin\// {print \$2}"); do
                if [ -f "$BIN" ]; then
                    NOME=$(basename "$BIN")
                    echo -e "   -> $NOME"
                    distrobox-export --bin "$BIN" --export-path ~/.local/bin > /dev/null 2>&1
                fi
            done

            echo -e "🖥️  Extraindo atalhos gráficos:"
            for DESKTOP in $(pacman -Ql "$PACOTE" 2>/dev/null | awk "/\/usr\/share\/applications\/.*\.desktop$/ {print \$2}"); do
                if [ -f "$DESKTOP" ]; then
                    APP=$(basename "$DESKTOP" .desktop)
                    echo -e "   -> $APP"
                    distrobox-export --app "$APP" > /dev/null 2>&1
                fi
            done
        ' -- "$PKG"

        # 3. Limpeza Extrema: Remove os rastros "(on Arch-base)" dos atalhos no host
        find ~/.local/share/applications -name "*.desktop" -exec sed -i "s/ (on $CONTAINER)//g" {} + 2>/dev/null

        echo -e "✅ \033[1;32mIntegração Extrema concluída!\033[0m"
        
        # Força o ZSH a reconhecer o novo comando imediatamente
        rehash 2>/dev/null
    else
        echo -e "❌ \033[1;31mFalha na instalação.\033[0m"
        return 1
    fi
}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

alias mic='~/mic-celular.sh'
alias zshreload='source ~/.zshrc'

apx-yay() {
    export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$PATH"
    local DBOX_CMD=$(command -v distrobox)
 
    if [ -z "$1" ]; then
        echo -e "❌ \033[1;31mErro:\033[0m O que deseja instalar? Uso: apx-yay <pacote>"
        return 1
    fi
 
    local PKG="$1"
    local CONTAINER="Arch-base"
    echo -e "⚡ \033[1;35mForjando '$PKG' no $CONTAINER via AUR (yay)...\033[0m"
 
    # 1. Instalação via yay (sem sudo — yay não aceita sudo)
    "$DBOX_CMD" enter $CONTAINER -- yay -S --noconfirm "$PKG"
 
    if [ $? -eq 0 ]; then
        echo -e "🚀 \033[1;32mInstalado! Iniciando Extração Interna...\033[0m"
 
        # 2. Extração de binários e atalhos, de dentro do container
        "$DBOX_CMD" enter $CONTAINER -- sh -c '
            PACOTE="$1"
 
            echo -e "🔗 Extraindo binários:"
            for BIN in $(pacman -Ql "$PACOTE" 2>/dev/null | awk "/\/usr\/bin\// {print \$2}"); do
                if [ -f "$BIN" ]; then
                    NOME=$(basename "$BIN")
                    echo -e "   -> $NOME"
                    distrobox-export --bin "$BIN" --export-path ~/.local/bin > /dev/null 2>&1
                fi
            done
 
            echo -e "🖥️  Extraindo atalhos gráficos:"
            for DESKTOP in $(pacman -Ql "$PACOTE" 2>/dev/null | awk "/\/usr\/share\/applications\/.*\.desktop$/ {print \$2}"); do
                if [ -f "$DESKTOP" ]; then
                    APP=$(basename "$DESKTOP" .desktop)
                    echo -e "   -> $APP"
                    distrobox-export --app "$APP" > /dev/null 2>&1
                fi
            done
        ' -- "$PKG"
 
        # 3. Remove o sufixo "(on Arch-base)" dos atalhos exportados
        find ~/.local/share/applications -name "*.desktop" -exec sed -i "s/ (on $CONTAINER)//g" {} + 2>/dev/null
 
        echo -e "✅ \033[1;35mIntegração AUR concluída!\033[0m"
 
        # Força o ZSH a reconhecer os novos comandos imediatamente
        rehash 2>/dev/null
    else
        echo -e "❌ \033[1;31mFalha na instalação via AUR.\033[0m Verifique se o pacote existe: https://aur.archlinux.org/packages/$PKG"
        return 1
    fi
}

export JUST_JUSTFILE="$HOME/.justfile"
alias ujust='just --unstable'

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
