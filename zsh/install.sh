#!/usr/bin/env bash
# zsh/install.sh — instala zsh con sus plugins y enlaza su configuración.
#
# Se lanza desde la raíz del repo y se puede ejecutar tantas veces como se quiera:
#   ./install zsh               instalar lo que falte (sudo solo si falta algo) y enlazar
#   ./install zsh --actualizar  además, actualizar los paquetes a la última versión de la distro
#
# Qué hace:
#   1. Instala zsh, zsh-autosuggestions, zsh-syntax-highlighting, fzf, zoxide y
#      tealdeer (el comando tldr) si faltan. Lo que no esté en los repos activos
#      (en Rocky/RHEL vienen de EPEL; tealdeer no está en Ubuntu 22.04) se salta
#      con un aviso: no añade repos por su cuenta, y zsh funciona sin ellos.
#      Descarga las páginas de tldr si no están (con --actualizar, de nuevo).
#   2. Apunta los paquetes que ha instalado él en
#      ~/.local/state/tmux-config/zsh.paquetes: ./uninstall zsh quita esos y no
#      los que ya estaban.
#   3. Comprueba que zsh/.zshrc carga sin errores con esa versión de zsh.
#   4. Enlaza ~/.local/opt/tmux-config/zsh/.zshrc a este repo. ~/.zshrc no se
#      toca: los panes de tmux arrancan zsh con ZDOTDIR en ese directorio, y
#      "zsh" tecleado fuera de tmux sigue como lo trae la distro.
#   5. Si quedó el ~/.zshrc enlazado de la versión anterior, lo quita y
#      devuelve a su sitio tu ~/.zshrc de antes (el backup ~/.zshrc.bak.<fecha>).
# No cambia la shell de login: zsh arranca en los panes de tmux.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_SRC="$REPO_DIR/zsh/.zshrc"
PAQUETES=(zsh zsh-autosuggestions zsh-syntax-highlighting fzf zoxide)
# tealdeer solo si falta el comando: hay otros clientes de tldr que chocan con él
command -v tldr >/dev/null || PAQUETES+=(tealdeer)

. "$REPO_DIR/lib/comun.sh"
CONF_DST="$TC_DIR/zsh/.zshrc"

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
            # lo que no está en los repos haría fallar el install entero
            local hay=()
            for p in "${instalar[@]}"; do
                if pkg_installed "$p" || pkg_available "$p"; then hay+=("$p"); else sin_repo+=("$p"); fi
            done
            if [ ${#hay[@]} -gt 0 ]; then
                info "instalando ${hay[*]}"
                # sin recomendados: solo lo imprescindible, que no cambie nada de lo que ya había
                $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "${hay[@]}"
            fi
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
        info "AVISO: no están en los repos activos: ${sin_repo[*]} (zsh funciona sin ellos)"
        if [ "$(pkg_manager)" = dnf ]; then
            info "       En Rocky/RHEL vienen de EPEL. Si quieres activarlo en esta máquina"
            info "       (Rocky/Alma): sudo dnf install epel-release && ./install zsh"
        fi
    fi
}

# tldr no trae páginas: hay que descargarlas (en ~/.cache/tealdeer)
tldr_paginas() {
    command -v tldr >/dev/null || return 0
    [ "$ACTUALIZAR" -eq 1 ] || ! tldr tar >/dev/null 2>&1 || return 0
    if tldr --update >/dev/null 2>&1 || tldr_a_mano; then
        info "páginas de tldr descargadas (tldr tar: ejemplos de uso de tar)"
    else
        info "AVISO: no se han podido descargar las páginas de tldr (¿sin red?): tldr --update"
    fi
}

# tealdeer anterior a la 1.7 (bookworm, Ubuntu 24.04) las pide a tldr.sh, que ya
# no las sirve: se bajan de GitHub a donde las lee. Solo inglés y español (todas
# son cientos de miles de ficheros)
tldr_a_mano() {
    local dir
    dir="$(tldr --show-paths 2>/dev/null | sed -n 's/^Pages dir: *//p')"
    dir="${dir%/}"
    [[ "$dir" == */tldr-pages ]] || return 1   # se borra entero: solo si es el suyo
    rm -rf "$dir" && mkdir -p "$dir" &&
        curl -fsSL https://github.com/tldr-pages/tldr/archive/refs/heads/main.tar.gz |
        tar -xz -C "$dir" --strip-components=1 --wildcards '*/pages/*' '*/pages.es/*' &&
        tldr tar >/dev/null 2>&1
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
tldr_paginas

# Debian/Ubuntu dejan los atajos de fzf para zsh en /usr/share/doc, que las
# imágenes mínimas (Docker, cloud minimal) no instalan. Mismas rutas que .zshrc.
if command -v fzf >/dev/null &&
   [ ! -r /usr/share/doc/fzf/examples/key-bindings.zsh ] && [ ! -r /usr/share/fzf/shell/key-bindings.zsh ]; then
    info "AVISO: fzf está, pero sin sus atajos de zsh (esta imagen no instala /usr/share/doc): Ctrl+R será el de zsh, sin fzf"
fi

check_conf
info "config válida con $(zsh --version)"

link_with_backup "$CONF_SRC" "$CONF_DST"
unlink_old "$CONF_SRC" "$HOME/.zshrc" || true

# Los panes de tmux arrancan en zsh si ~/.tmux.conf es el de este repo. En los
# tmux en marcha se aplica ya: los panes nuevos salen en zsh, los abiertos siguen igual.
if link_is_ours "$REPO_DIR/.tmux.conf" "$HOME/.tmux.conf"; then
    tmux_reload
    info "los panes nuevos de tmux arrancan en zsh"
else
    info "AVISO: ~/.tmux.conf no es de este repo: tmux no arrancará en zsh (./install tmux)"
fi
info "tu shell de login no cambia: fuera de tmux todo sigue como lo trae la distro"
info "listo"
