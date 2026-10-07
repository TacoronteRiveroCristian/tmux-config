#!/usr/bin/env bash
# zsh/install.sh — instala zsh con sus plugins y enlaza su configuración.
#
# Se lanza desde la raíz del repo y se puede ejecutar tantas veces como se quiera:
#   ./install zsh               instalar lo que falte (sudo solo si falta algo) y enlazar
#   ./install zsh --actualizar  además, actualizar los paquetes a la última versión de la distro
#   ./install zsh --global      también fuera de tmux: zsh como shell de login
#   ./install zsh --solo-tmux   solo en los panes de tmux (lo de siempre)
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
#   6. Con --global, zsh también fuera de tmux: enlaza ~/.zshenv a zsh/zshenv
#      (que lleva a zsh a esta config) y tu shell de login pasa a ser zsh (con
#      sudo), apuntando la de antes en ~/.local/state/tmux-config/zsh.global.
#      Con --solo-tmux, deshace eso: vuelve tu shell de antes y tu ~/.zshenv.
# Sin --global no cambia la shell de login: zsh arranca en los panes de tmux.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_SRC="$REPO_DIR/zsh/.zshrc"

. "$REPO_DIR/lib/comun.sh"
CONF_DST="$TC_DIR/zsh/.zshrc"
ZSHENV_SRC="$REPO_DIR/zsh/zshenv"
ZSHENV="$HOME/.zshenv"
SITIO="$(sitio zsh)"   # tmux o global: lo decide ./install

MODO=instalar ACTUALIZAR=0
for a in "$@"; do
    case "$a" in
        --plan)       MODO=plan ;;
        --actualizar) ACTUALIZAR=1 ;;
        *)            die "uso: ./install zsh [--actualizar] [--check] [-y]" ;;
    esac
done

# Lo de fuera de tmux en el plan de ./install, sin tocar nada: los paquetes los
# enseña él, y ~/.zshrc no se toca
plan() {
    local sh prev
    sh="$(shell_login)"
    if [ "$SITIO" = global ]; then
        if [[ "$sh" != */zsh ]]; then
            plan_linea cambiar "tu shell de login: $sh → zsh, con esta config también fuera de tmux (para volver: ./install zsh --solo-tmux)"
        elif ! link_is_ours "$ZSHENV_SRC" "$ZSHENV"; then
            plan_linea cambiar "zsh, que ya es tu shell de login, carga esta config también fuera de tmux$([ -e "$HOME/.zshrc" ] && echo ', no tu ~/.zshrc')"
        else
            plan_linea ya "zsh también fuera de tmux (es tu shell de login)"
        fi
        if { [ -e "$ZSHENV" ] || [ -L "$ZSHENV" ]; } && ! link_is_ours "$ZSHENV_SRC" "$ZSHENV"; then
            plan_linea backup "${ZSHENV/#$HOME/\~} no es de este repo: se guarda como ~/.zshenv.bak.<fecha>"
        fi
    elif es_global zsh; then
        prev="$(cat "$(global_file zsh)")"
        if [ -n "$prev" ] && [[ "$sh" == */zsh ]]; then
            plan_linea cambiar "tu shell de login vuelve a ser $prev: zsh, solo dentro de tmux"
        else
            plan_linea cambiar "zsh fuera de tmux deja de cargar esta config (se quita ~/.zshenv): zsh, solo dentro de tmux"
        fi
    fi
}
if [ "$MODO" = plan ]; then plan; exit 0; fi

# --global: zsh pasa a ser la shell de login, y ~/.zshenv lo lleva a esta
# config. Primero la shell: si eso falla (sin sudo, usuario de LDAP...), no queda
# nada a medias. Luego se apunta la de antes, para que --solo-tmux y ./uninstall
# zsh la devuelvan (si ya era zsh, no se apunta nada)
fuera_global() {
    local sh zsh_bin
    sh="$(shell_login)"
    zsh_bin="$(command -v zsh)"
    if [[ "$sh" != */zsh ]]; then
        cambiar_shell "$zsh_bin"
        info "tu shell de login es $zsh_bin: al entrar por SSH (en las sesiones nuevas), zsh con esta config"
    fi
    if ! es_global zsh; then
        mkdir -p "$STATE_DIR"
        if [[ "$sh" == */zsh ]]; then : > "$(global_file zsh)"; else echo "$sh" > "$(global_file zsh)"; fi
    fi
    link_with_backup "$ZSHENV_SRC" "$ZSHENV"
    info "zsh también fuera de tmux; para volver a solo tmux: ./install zsh --solo-tmux"
}

# --solo-tmux tras --global: vuelve la shell de login de antes y tu ~/.zshenv. El
# ~/.zshenv, también si es de otro clon del repo (es_del_repo)
fuera_solo_tmux() {
    local prev
    prev="$(cat "$(global_file zsh)")"
    if [ -n "$prev" ] && [[ "$(shell_login)" == */zsh ]]; then
        cambiar_shell "$prev"
        info "tu shell de login vuelve a ser $prev (en las sesiones nuevas)"
    fi
    if es_del_repo "$ZSHENV" zsh/zshenv; then
        rm "$ZSHENV"
        info "enlace ~/.zshenv quitado"
        restore_backup "$ZSHENV" zsh/zshenv
    fi
    rm -f "$(global_file zsh)"
}

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
if [ "$SITIO" = global ]; then
    fuera_global
elif es_global zsh; then
    fuera_solo_tmux
else
    info "tu shell de login no cambia: fuera de tmux sigue la de la distro (zsh también fuera: ./install zsh --global)"
fi
info "listo"
