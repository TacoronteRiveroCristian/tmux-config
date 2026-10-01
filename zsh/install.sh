#!/usr/bin/env bash
# zsh/install.sh — instala zsh con sus plugins y enlaza su configuración.
#
# Se lanza desde la raíz del repo y se puede ejecutar tantas veces como se quiera:
#   ./install zsh               instalar lo que falte (sudo solo si falta algo) y enlazar
#   ./install zsh --actualizar  además, actualizar los paquetes a la última versión de la distro
#
# Qué hace:
#   1. Instala zsh, zsh-autosuggestions, zsh-syntax-highlighting y fzf si faltan.
#      En Rocky/RHEL los tres últimos están en EPEL: si EPEL no está activo no
#      los instala (no añade repos por su cuenta), y zsh funciona sin ellos.
#   2. Apunta los paquetes que ha instalado él en
#      ~/.local/state/tmux-config/zsh.paquetes: ./uninstall zsh quita esos y no
#      los que ya estaban.
#   3. Comprueba que zsh/.zshrc carga sin errores con esa versión de zsh.
#   4. Enlaza ~/.zshrc a este repo (con backup de la config anterior).
# No cambia la shell de login: zsh arranca en los panes de tmux.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_SRC="$REPO_DIR/zsh/.zshrc"
CONF_DST="$HOME/.zshrc"
PAQUETES=(zsh zsh-autosuggestions zsh-syntax-highlighting fzf)

. "$REPO_DIR/lib/comun.sh"

case "${1:-}" in
    "")           ACTUALIZAR=0 ;;
    --actualizar) ACTUALIZAR=1 ;;
    *)            die "uso: ./install zsh [--actualizar]" ;;
esac

install_paquetes() {
    local faltan=() instalar=() sin_repo=() p
    for p in "${PAQUETES[@]}"; do
        pkg_installed "$p" || faltan+=("$p")
    done
    if [ ${#faltan[@]} -eq 0 ] && [ "$ACTUALIZAR" -eq 0 ]; then
        info "paquetes ya instalados (para actualizarlos: ./install zsh --actualizar)"
        return
    fi

    need_sudo "instalar paquetes"
    case "$(pkg_manager)" in
        apt)
            $SUDO apt-get update -qq
            # install también actualiza los que ya están si hay versión nueva
            if [ "$ACTUALIZAR" -eq 1 ]; then instalar=("${PAQUETES[@]}"); else instalar=("${faltan[@]}"); fi
            info "instalando ${instalar[*]}"
            $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${instalar[@]}"
            ;;
        dnf)
            for p in "${faltan[@]}"; do
                if pkg_available "$p"; then instalar+=("$p"); else sin_repo+=("$p"); fi
            done
            if [ "$ACTUALIZAR" -eq 1 ]; then
                local ya=()
                for p in "${PAQUETES[@]}"; do pkg_installed "$p" && ya+=("$p"); done
                [ ${#ya[@]} -eq 0 ] || $SUDO dnf upgrade -y -q "${ya[@]}"
            fi
            if [ ${#instalar[@]} -gt 0 ]; then
                info "instalando ${instalar[*]}"
                $SUDO dnf install -y -q "${instalar[@]}"
            fi
            ;;
        *)
            die "gestor de paquetes no soportado (apt o dnf): instala ${faltan[*]} a mano y vuelve a ejecutar"
            ;;
    esac

    local nuevos=()
    for p in "${faltan[@]}"; do pkg_installed "$p" && nuevos+=("$p"); done
    [ ${#nuevos[@]} -eq 0 ] || state_add zsh "${nuevos[@]}"

    if [ ${#sin_repo[@]} -gt 0 ]; then
        info "AVISO: no están en los repos activos: ${sin_repo[*]}"
        info "       En Rocky/RHEL vienen de EPEL. Si quieres activarlo en esta máquina"
        info "       (Rocky/Alma): sudo dnf install epel-release && ./install zsh"
    fi
}

# Carga la config en un zsh interactivo aislado (HOME y ZDOTDIR temporales):
# no toca tu historial ni tu ~/.zshrc.local. Con un terminal de verdad (script):
# sin él, el fzf de EPEL avisa "can't change option: zle" aunque todo esté bien.
check_conf() {
    local tmp err
    zsh -n "$CONF_SRC" || die "$CONF_SRC tiene errores de sintaxis; no se ha enlazado nada"
    if ! command -v script >/dev/null; then
        info "AVISO: falta el comando script: solo se ha comprobado la sintaxis"
        return
    fi
    tmp="$(mktemp -d)"
    ln -s "$CONF_SRC" "$tmp/.zshrc"
    err="$(HOME="$tmp" ZDOTDIR="$tmp" script -qec "zsh -i -c exit" /dev/null 2>&1 </dev/null)" || true
    rm -rf "$tmp"
    [ -z "$err" ] || die "$CONF_SRC no carga limpio con $(zsh --version); no se ha enlazado nada:"$'\n'"$err"
}

install_paquetes
command -v zsh >/dev/null || die "zsh no está instalado"
info "$(zsh --version) instalado"

# Debian/Ubuntu dejan los atajos de fzf para zsh en /usr/share/doc, que las
# imágenes mínimas (Docker, cloud minimal) no instalan. Mismas rutas que .zshrc.
if command -v fzf >/dev/null &&
   [ ! -r /usr/share/doc/fzf/examples/key-bindings.zsh ] && [ ! -r /usr/share/fzf/shell/key-bindings.zsh ]; then
    info "AVISO: fzf está, pero sin sus atajos de zsh (esta imagen no instala /usr/share/doc): Ctrl+R será el de zsh, sin fzf"
fi

check_conf
info "config válida con $(zsh --version)"

link_with_backup "$CONF_SRC" "$CONF_DST"

# Los panes de tmux arrancan en zsh si ~/.tmux.conf es el de este repo
if link_is_ours "$REPO_DIR/.tmux.conf" "$HOME/.tmux.conf"; then
    if [ -n "$(tmux_sockets)" ]; then
        info "hay un tmux en marcha: Ctrl+B R (o 'tmux source-file ~/.tmux.conf') y los panes nuevos arrancan en zsh"
    else
        info "los panes de tmux arrancarán en zsh"
    fi
else
    info "AVISO: ~/.tmux.conf no es de este repo: tmux no arrancará en zsh (./install tmux, o escribe zsh)"
fi
info "tu shell de login no cambia. Para usar zsh también fuera de tmux (solo en tu propia cuenta): chsh -s $(command -v zsh)"
info "listo"
