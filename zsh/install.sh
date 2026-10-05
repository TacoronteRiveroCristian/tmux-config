#!/usr/bin/env bash
# zsh/install.sh — instala zsh con sus plugins y enlaza su configuración.
#
# Se lanza desde la raíz del repo y se puede ejecutar tantas veces como se quiera:
#   ./install zsh               instalar lo que falte (sudo solo si falta algo) y enlazar
#   ./install zsh --actualizar  además, actualizar los paquetes a la última versión de la distro
#
# Qué hace:
#   1. zsh, zsh-autosuggestions, zsh-syntax-highlighting, fzf, zoxide y tealdeer
#      (el comando tldr; tabla zsh/paquetes) los instala antes ./install, si
#      faltan. Lo que no esté en los repos activos (en Rocky/RHEL vienen de EPEL;
#      tealdeer no está en Ubuntu 22.04) se salta y el plan dice qué se pierde:
#      no añade repos por su cuenta, y zsh funciona sin ellos. Los que instala
#      él los apunta en ~/.local/state/tmux-config/zsh.paquetes: ./uninstall zsh
#      quita esos y no los que ya estaban.
#   2. Descarga las páginas de tldr si no están (con --actualizar, de nuevo).
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

. "$REPO_DIR/lib/comun.sh"
CONF_DST="$TC_DIR/zsh/.zshrc"

MODO=instalar ACTUALIZAR=0
for a in "$@"; do
    case "$a" in
        --plan)       MODO=plan ;;
        --actualizar) ACTUALIZAR=1 ;;
        *)            die "uso: ./install zsh [--actualizar] [--check] [-y]" ;;
    esac
done
# Lo suyo del plan son los paquetes: ~/.zshrc no se toca
[ "$MODO" = instalar ] || exit 0

# tldr no trae páginas: hay que descargarlas (en ~/.cache/tealdeer)
tldr_paginas() {
    command -v tldr >/dev/null || return 0
    [ "$ACTUALIZAR" -eq 1 ] || ! tldr tar >/dev/null 2>&1 || return 0
    if tldr --update >/dev/null 2>&1 || tldr_a_mano; then
        info "páginas de tldr descargadas (tldr tar: ejemplos de uso de tar)"
    else
        aviso "no se han podido descargar las páginas de tldr (¿sin red?): tldr --update"
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
        aviso "falta el comando script: solo se ha comprobado la sintaxis"
        return
    fi
    tmp="$(mktemp -d)"
    ln -s "$CONF_SRC" "$tmp/.zshrc"
    err="$(HOME="$tmp" ZDOTDIR="$tmp" script -qec "zsh -i -c exit" /dev/null 2>&1 </dev/null)" || true
    rm -rf "$tmp"
    [ -z "$err" ] || die "$CONF_SRC no carga limpio con $(zsh --version); no se ha enlazado nada:"$'\n'"$err"
}

command -v zsh >/dev/null || die "falta zsh: ./install zsh lo instala"
info "$(zsh --version) instalado"
tldr_paginas

# Debian/Ubuntu dejan los atajos de fzf para zsh en /usr/share/doc, que las
# imágenes mínimas (Docker, cloud minimal) no instalan. Mismas rutas que .zshrc.
if command -v fzf >/dev/null &&
   [ ! -r /usr/share/doc/fzf/examples/key-bindings.zsh ] && [ ! -r /usr/share/fzf/shell/key-bindings.zsh ]; then
    aviso "fzf está, pero sin sus atajos de zsh (esta imagen no instala /usr/share/doc): Ctrl+R será el de zsh, sin fzf"
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
    aviso "~/.tmux.conf no es de este repo: tmux no arrancará en zsh (./install tmux)"
fi
info "tu shell de login no cambia: fuera de tmux todo sigue como lo trae la distro"
info "listo"
