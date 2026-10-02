#!/usr/bin/env bash
# vim/install.sh — instala neovim (dentro de tmux, también vi y vim) y enlaza su configuración.
#
# Se lanza desde la raíz del repo y se puede ejecutar tantas veces como se quiera:
#   ./install vim               instalar lo que falte (sudo solo si falta algo) y enlazar
#   ./install vim --actualizar  además, actualizar los paquetes a la última versión de la distro
#
# Fuera de tmux no cambia nada: los comandos quedan en ~/.local/opt/tmux-config/bin,
# que solo está en el PATH de los panes, y la config de neovim va aparte
# (NVIM_APPNAME=tmux-config-nvim), sin tocar ~/.config/nvim ni el vi de la distro.
#
# Qué hace:
#   1. Instala con apt/dnf lo que usa neovim: git, curl, unzip, ripgrep (buscar
#      texto), shellcheck, node y npm (servidores LSP). En Rocky/RHEL ripgrep
#      y shellcheck están en EPEL: sin EPEL avisa y sigue sin ellos. Apunta los
#      que instala en ~/.local/state/tmux-config/vim.paquetes: ./uninstall vim
#      quita esos y no los que ya estaban. vim no se instala.
#   2. Instala la versión oficial de neovim fijada abajo en
#      ~/.local/opt/tmux-config/nvim-<versión> (sin root), comprobando su sha256,
#      y enlaza nvim, vi, vim, view y vimdiff en ~/.local/opt/tmux-config/bin.
#      Las de las distros son demasiado antiguas (0.6 a 0.10) para los plugins.
#   3. Descarga los plugins (fijados a un commit) y los servidores LSP en
#      ~/.local/share/tmux-config-nvim, comprueba que todo carga y enlaza
#      ~/.config/tmux-config-nvim/init.lua.
#   4. neovim queda como editor por defecto (EDITOR y VISUAL: git commit,
#      crontab -e, sudoedit...) dentro de tmux: lo pone zsh/.zshrc. Fuera de
#      tmux sigue el de la distro; bash no se toca.
#   5. Quita lo que dejó en $HOME la versión anterior (~/.vimrc,
#      ~/.config/nvim/init.lua, ~/.local/bin/nvim y su neovim, sus plugins) y
#      devuelve a su sitio tus configs de antes (los backups *.bak.<fecha>).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_SRC="$REPO_DIR/nvim/init.lua"

NVIM_VERSION=v0.12.5
NVIM_SHA256_x86_64=bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875
NVIM_SHA256_arm64=1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725

. "$REPO_DIR/lib/comun.sh"

# Config, plugins y estado aparte de los de ~/.config/nvim: neovim los busca por
# este nombre. Exportado: los nvim --headless de abajo también lo usan (con -u
# incluido); sin él, los plugins acabarían en ~/.local/share/nvim.
export NVIM_APPNAME=tmux-config-nvim
NVIM_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/$NVIM_APPNAME"
NVIM_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/$NVIM_APPNAME"
NVIM_DIR="$TC_DIR/nvim-$NVIM_VERSION"
NVIM_LINK="$TC_DIR/bin/nvim"

# Lo de la versión anterior del repo, en $HOME (se quita en migrar)
VIEJO_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
VIEJO_ESTADO="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
VIEJO_DATOS="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
VIEJO_LINK="$HOME/.local/bin/nvim"

case "${1:-}" in
    "")           ACTUALIZAR=0 ;;
    --actualizar) ACTUALIZAR=1 ;;
    *)            die "uso: ./install vim [--actualizar]" ;;
esac

case "$(pkg_manager)" in
    apt) PAQUETES=(git unzip ripgrep shellcheck nodejs npm) ;;
    dnf) PAQUETES=(git unzip ripgrep ShellCheck nodejs npm) ;;
    *)   die "gestor de paquetes no soportado (apt o dnf)" ;;
esac
# curl solo si falta el comando: en Rocky viene curl-minimal, que choca con el paquete curl
command -v curl >/dev/null || PAQUETES+=(curl)

install_paquetes() {
    local faltan=() instalar=() sin_repo=() ya=() nuevos=() p
    for p in "${PAQUETES[@]}"; do
        pkg_installed "$p" || faltan+=("$p")
    done
    if [ ${#faltan[@]} -eq 0 ] && [ "$ACTUALIZAR" -eq 0 ]; then
        info "paquetes ya instalados (para actualizarlos: ./install vim --actualizar)"
        return
    fi

    need_sudo "instalar paquetes"
    case "$(pkg_manager)" in
        apt)
            $SUDO apt-get update -qq
            # install también actualiza los que ya están si hay versión nueva
            if [ "$ACTUALIZAR" -eq 1 ]; then instalar=("${PAQUETES[@]}"); else instalar=("${faltan[@]}"); fi
            info "instalando ${instalar[*]}"
            # sin recomendados: solo lo imprescindible, que no cambie nada de lo
            # que ya había (con ellos, npm traía bash-completion y build-essential)
            $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "${instalar[@]}"
            ;;
        dnf)
            for p in "${faltan[@]}"; do
                if pkg_available "$p"; then instalar+=("$p"); else sin_repo+=("$p"); fi
            done
            if [ "$ACTUALIZAR" -eq 1 ]; then
                for p in "${PAQUETES[@]}"; do pkg_installed "$p" && ya+=("$p"); done
                [ ${#ya[@]} -eq 0 ] || $SUDO dnf upgrade -y -q "${ya[@]}"
            fi
            if [ ${#instalar[@]} -gt 0 ]; then
                info "instalando ${instalar[*]}"
                $SUDO dnf install -y -q "${instalar[@]}"
            fi
            ;;
    esac

    for p in "${faltan[@]}"; do pkg_installed "$p" && nuevos+=("$p"); done
    [ ${#nuevos[@]} -eq 0 ] || state_add vim "${nuevos[@]}"

    if [ ${#sin_repo[@]} -gt 0 ]; then
        info "AVISO: no están en los repos activos: ${sin_repo[*]} (neovim funciona sin ellos)"
        info "       En Rocky/RHEL vienen de EPEL. Si quieres activarlo en esta máquina"
        info "       (Rocky/Alma): sudo dnf install epel-release && ./install vim"
    fi
}

# neovim oficial en ~/.local/opt/tmux-config/nvim-<versión>, verificado con su
# sha256. Sin build oficial para esta arquitectura deja NVIM_OK=0.
NVIM_OK=1
install_nvim() {
    local arch sha url tmp d n
    case "$(uname -m)" in
        x86_64)        arch=x86_64; sha="$NVIM_SHA256_x86_64" ;;
        aarch64|arm64) arch=arm64;  sha="$NVIM_SHA256_arm64" ;;
        *) info "AVISO: no hay neovim oficial para $(uname -m): no se instala"; NVIM_OK=0; return 0 ;;
    esac
    if [ -x "$NVIM_DIR/bin/nvim" ]; then
        info "neovim $NVIM_VERSION ya instalado"
    else
        url="https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-linux-$arch.tar.gz"
        info "descargando neovim $NVIM_VERSION ($arch)"
        tmp="$(mktemp -d)"
        if ! curl -fsSL -o "$tmp/nvim.tar.gz" "$url"; then
            rm -rf "$tmp"; die "no se pudo descargar $url"
        fi
        if ! echo "$sha  $tmp/nvim.tar.gz" | sha256sum -c --status; then
            rm -rf "$tmp"; die "el sha256 de $url no coincide: no se instala"
        fi
        tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
        mkdir -p "$(dirname "$NVIM_DIR")"
        mv "$tmp/nvim-linux-$arch" "$NVIM_DIR"
        rm -rf "$tmp"
    fi
    "$NVIM_DIR/bin/nvim" --version >/dev/null 2>&1 || die "neovim $NVIM_VERSION no arranca en esta máquina"

    # Los comandos, en el PATH solo dentro de tmux (lo pone zsh/.zshrc). vi y vim
    # son este neovim: valen también para scripts y para core.editor=vim. view y
    # vimdiff son dos líneas del repo: nvim no cambia de modo según su nombre.
    mkdir -p "$TC_DIR/bin"
    ln -sfn "$NVIM_DIR/bin/nvim" "$NVIM_LINK"
    for n in vi vim; do ln -sfn nvim "$TC_DIR/bin/$n"; done
    for n in view vimdiff; do ln -sfn "$REPO_DIR/bin/$n" "$TC_DIR/bin/$n"; done
    info "nvim, vi, vim, view y vimdiff en ${TC_DIR/#$HOME/\~}/bin (en el PATH solo dentro de tmux)"

    # versiones anteriores: en ~/.local/opt/tmux-config todo es de este repo
    for d in "$TC_DIR"/nvim-v*; do
        if [ -d "$d" ] && [ "$d" != "$NVIM_DIR" ]; then
            rm -rf "$d"
            info "neovim anterior quitado: ${d/#$HOME/\~}"
        fi
    done
}

# undo y shada de la versión anterior (~/.local/state/nvim): se copian, no se
# mueven, antes de que neovim use la config nueva por primera vez (si no, su
# shada recién creado ya no se sobrescribe)
copiar_estado() {
    local d
    link_is_ours "$INIT_SRC" "$VIEJO_CONF/init.lua" || return 0
    for d in undo shada; do
        [ -d "$VIEJO_ESTADO/$d" ] || continue
        mkdir -p "$NVIM_STATE"
        if cp -an "$VIEJO_ESTADO/$d" "$NVIM_STATE/"; then
            info "copiado ${VIEJO_ESTADO/#$HOME/\~}/$d a ${NVIM_STATE/#$HOME/\~}"
        else
            info "AVISO: no se pudo copiar ${VIEJO_ESTADO/#$HOME/\~}/$d"
        fi
    done
}

# Plugins y servidores LSP, y comprobar que todo carga. Con la config del repo
# (-u): si algo falla, no se ha enlazado nada todavía.
setup_nvim() {
    local nvim="$NVIM_DIR/bin/nvim" out
    info "plugins de neovim (la primera vez tarda un poco)"
    if ! out="$("$nvim" --headless -u "$INIT_SRC" '+Lazy! sync' +qa 2>&1)"; then
        die "no se pudieron instalar los plugins de neovim:"$'\n'"$out"
    fi
    "$nvim" --headless -u "$INIT_SRC" -c 'lua require("tc.instalar").lsp()' 2>&1 \
        || die "no se pudieron instalar todos los servidores LSP (vuelve a ejecutar ./install vim)"
    if ! out="$("$nvim" --headless -u "$INIT_SRC" -c 'lua require("tc.instalar").comprobar()' 2>&1)" ||
       ! grep -q '^tc-ok' <<<"$out"; then
        die "la config de neovim no carga limpia; no se ha enlazado:"$'\n'"$out"
    fi
}

# Lo que dejó en $HOME la versión anterior, cada cosa solo si es de este repo.
# Se hace al final: si algo de arriba falla, lo anterior sigue funcionando.
MIGRADO=0
migrar() {
    local t d
    unlink_old "$REPO_DIR/vim/vimrc" "$HOME/.vimrc" || true
    if unlink_old "$INIT_SRC" "$VIEJO_CONF/init.lua"; then
        # init.vim también lo apartaba la versión anterior (chocaba con init.lua)
        restore_backup "$VIEJO_CONF/init.vim" nvim/init.vim
        # lo propio de esta máquina pasa a la config nueva
        if [ -e "$VIEJO_CONF/local.lua" ] && [ -e "$NVIM_CONF/local.lua" ]; then
            info "AVISO: hay dos local.lua; vale ${NVIM_CONF/#$HOME/\~}/local.lua y ${VIEJO_CONF/#$HOME/\~}/local.lua ya no se lee: júntalos a mano"
        elif [ -e "$VIEJO_CONF/local.lua" ]; then
            mkdir -p "$NVIM_CONF"
            mv "$VIEJO_CONF/local.lua" "$NVIM_CONF/local.lua"
            info "tu local.lua pasa a ${NVIM_CONF/#$HOME/\~}/local.lua"
        fi
        rmdir_vacio "$VIEJO_CONF"
    fi

    # El neovim de antes: solo el que enlazaba ~/.local/bin/nvim (se mira antes
    # de quitar el enlace). Otros ~/.local/opt/nvim-* no se tocan.
    t="$(readlink "$VIEJO_LINK" 2>/dev/null || true)"
    if [[ "$t" == "$HOME"/.local/opt/nvim-v*/bin/nvim ]]; then
        rm "$VIEJO_LINK"
        info "quitado el enlace antiguo ~/.local/bin/nvim (fuera de tmux ya no está en el PATH)"
        d="${t%/bin/nvim}"
        if [ -d "$d" ]; then
            rm -rf "$d"
            info "neovim anterior quitado: ${d/#$HOME/\~}"
        fi
        rmdir_vacio "$(dirname "$VIEJO_LINK")"
        MIGRADO=1
    fi

    # Sus plugins y servidores LSP: no se reaprovechan (mason guarda rutas absolutas)
    for d in "$VIEJO_DATOS/tmux-config" "$VIEJO_ESTADO/tmux-config-lazy-lock.json"; do
        if [ -e "$d" ]; then
            rm -rf "$d"
            info "quitado ${d/#$HOME/\~} (plugins de la versión anterior)"
        fi
    done
    rmdir_vacio "$VIEJO_DATOS"

    # El paquete vim que instalaba la versión anterior cambia vi fuera de tmux.
    # No se desinstala solo: puede que ya lo uses.
    if grep -qxE 'vim|vim-enhanced' < <(state_list vim); then
        if pkg_installed vim; then
            info "AVISO: la versión anterior instaló el paquete vim, que cambia el vi de fuera de tmux (vim.basic en vez de vim.tiny)."
            info "       Para dejarlo como estaba: sudo apt-get purge --autoremove vim (también lo quita ./uninstall vim)"
        elif pkg_installed vim-enhanced; then
            info "AVISO: la versión anterior instaló vim-enhanced, que cambia vi y view fuera de tmux (abren vim en vez de vim-minimal)."
            info "       Para dejarlo como estaba: sudo dnf remove vim-enhanced (también lo quita ./uninstall vim)"
        fi
    fi
}

# EDITOR lo pone zsh/.zshrc: aquí solo se comprueba que va a llegar
editor_nvim() {
    local ed
    if link_is_ours "$REPO_DIR/zsh/.zshrc" "$TC_DIR/zsh/.zshrc"; then
        info "neovim es el editor por defecto en los panes nuevos de tmux (git commit, crontab -e, sudoedit...); vi y vim también lo abren"
    else
        info "AVISO: sin ./install zsh, dentro de tmux ni nvim, ni vi, ni EDITOR llegan a este neovim"
    fi
    [ "$MIGRADO" -eq 0 ] ||
        info "AVISO: en los panes de tmux ya abiertos EDITOR apunta al neovim anterior (~/.local/bin/nvim, ya quitado): abre uno nuevo"
    # git usa su core.editor antes que EDITOR; vi o vim, dentro de tmux, son este neovim
    ed="$(git config --global --get core.editor 2>/dev/null || true)"
    case "$ed" in
        ""|vi|vim|nvim) ;;
        *) info "AVISO: git seguirá abriendo su core.editor ($ed). Para usar neovim: git config --global --unset core.editor" ;;
    esac
}

install_paquetes
install_nvim
if [ "$NVIM_OK" -eq 1 ]; then
    copiar_estado
    setup_nvim
    link_with_backup "$INIT_SRC" "$NVIM_CONF/init.lua"
fi
migrar
[ "$NVIM_OK" -eq 0 ] || editor_nvim

info "aprender: :Tutor dentro de neovim · Espacio ? (mapa de atajos)"
info "ficheros del sistema, en tmux: sudoedit /etc/fichero (neovim con tu config, sin abrirlo como root)"
info "listo"
