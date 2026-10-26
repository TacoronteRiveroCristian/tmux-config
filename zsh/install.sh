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
#   1. zsh, zsh-autosuggestions, zsh-syntax-highlighting, fzf, zoxide, tealdeer
#      (el comando tldr), fd-find, bat y ncdu (tabla zsh/paquetes) los instala
#      antes ./install, si faltan. Lo que no esté en los repos activos (en
#      Rocky/RHEL vienen de EPEL; tealdeer no está en Ubuntu 22.04) se salta y
#      el plan dice qué se pierde: no añade repos por su cuenta, y zsh
#      funciona sin ellos. Los que instala
#      él los apunta en ~/.local/state/tmux-config/zsh.paquetes: ./uninstall zsh
#      quita esos y no los que ya estaban.
#   2. Descarga las páginas de tldr si no están (con --actualizar, de nuevo).
#   3. Comprueba que zsh/.zshrc carga sin errores con esa versión de zsh, y que
#      zsh/zshenv no escribe nada (lo leen también ssh host comando, scp, rsync).
#   4. Enlaza ~/.local/opt/tmux-config/zsh/.zshrc a este repo. ~/.zshrc no se
#      toca: los panes de tmux arrancan zsh con ZDOTDIR en ese directorio, y
#      "zsh" tecleado fuera de tmux sigue como lo trae la distro.
#   5. Si quedó el ~/.zshrc enlazado de la versión anterior, lo quita y
#      devuelve a su sitio tu ~/.zshrc de antes (el backup ~/.zshrc.bak.<fecha>).
#   6. Con --global, zsh también fuera de tmux: tu shell de login pasa a ser zsh
#      (con sudo), apuntando la de antes en ~/.local/state/tmux-config/zsh.global,
#      y ~/.zshenv carga zsh/zshenv (que lleva a zsh a esta config). Antes, el
#      plan avisa de lo que bash cargaba al entrar y zsh no leerá. Con
#      --solo-tmux, deshace eso: vuelve tu shell de antes y tu ~/.zshenv.
# Sin --global no cambia la shell de login: zsh arranca en los panes de tmux.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_SRC="$REPO_DIR/zsh/.zshrc"

. "$REPO_DIR/lib/comun.sh"
CONF_DST="$TC_DIR/zsh/.zshrc"
ZSHENV_SRC="$REPO_DIR/zsh/zshenv"
ZSHENV_LINK="$TC_DIR/zsh/zshenv"
SITIO="$(sitio zsh)"   # tmux o global: lo decide ./install

MODO=instalar ACTUALIZAR=0
for a in "$@"; do
    case "$a" in
        --plan)       MODO=plan ;;
        --actualizar) ACTUALIZAR=1 ;;
        *)            die "uso: ./install zsh [--actualizar] [--check] [-y]" ;;
    esac
done

# ~/.zshenv es nuestro: el de ahora (zshenv_nuestro) o el enlace al repo de
# antes, de este u otro clon. Se cambia o se quita sin backup
zshenv_es_nuestro() { zshenv_nuestro "$ZSHENV" || es_del_repo "$ZSHENV" zsh/zshenv; }

# que_es LÍNEA: qué hace una línea de bash, sin su valor, que puede ser un
# secreto (export NVM_DIR, alias gs, función f, carga ~/.cargo/env, eval de
# conda). Falla si no lo sabe
que_es() {
    local re_export='^[[:space:]]*export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)'
    local re_alias='^[[:space:]]*alias[[:space:]]+([^=[:space:]]+)='
    local re_funcion='^[[:space:]]*(function[[:space:]]+)?([A-Za-z_][A-Za-z0-9_:.-]*)[[:space:]]*\(\)'
    local re_var='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)='
    local re_carga='(^|[[:space:];&|])\\?(\.|source)[[:space:]]+"?([^[:space:]";&|]+)'
    local re_eval='eval[[:space:]]+"?\$\(([^[:space:])=]+)([[:space:])]|$)'
    if [[ $1 =~ $re_export ]]; then echo "export ${BASH_REMATCH[1]}"
    elif [[ $1 =~ $re_alias ]]; then echo "alias ${BASH_REMATCH[1]}"
    elif [[ $1 =~ $re_funcion ]]; then echo "función ${BASH_REMATCH[2]}"
    elif [[ $1 =~ $re_var ]]; then echo "${BASH_REMATCH[1]}="
    elif [[ $1 =~ $re_carga ]]; then echo "carga ${BASH_REMATCH[3]}"
    elif [[ $1 =~ $re_eval ]]; then echo "eval de ${BASH_REMATCH[1]##*/}"   # X=valor cmd: no
    else return 1
    fi
}

# Al pasar a --global: lo que bash carga al entrar y zsh no leerá. Lo que
# añadiste a ~/.bashrc y ~/.bash_profile (lo que no trae /etc/skel),
# ~/.bash_aliases (lo carga el ~/.bashrc de Debian y Ubuntu), ~/.bash_login y
# ~/.bashrc.d; sin el bloque de vim --global ni lo que ya está en
# ~/.zshrc.local. ~/.profile no: zsh/zshenv lo carga
lo_de_bash() {
    local f n l q otras items=()
    for f in "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME"/.bashrc.d/*; do
        [ -f "$f" ] || continue
        otras=0
        while IFS=$'\t' read -r n l; do
            if q="$(que_es "$l")"; then items+=("${f/#$HOME/\~}:$n  $q"); else otras=$((otras + 1)); fi
        done < <(awk -v skel="/etc/skel/${f#"$HOME"/}" -v loc="$HOME/.zshrc.local" -v ini="$BLOQUE_INI" -v fin="$BLOQUE_FIN" '
            BEGIN { while ((getline l < skel) > 0) ya[l] = 1; while ((getline l < loc) > 0) ya[l] = 1 }
            $0 == ini { d = 1 }
            d { if ($0 == fin) d = 0; next }
            /^[ \t]*(#|$)/ || ($0 in ya) { next }
            { print NR "\t" $0 }' "$f")
        [ "$otras" -eq 0 ] || items+=("${f/#$HOME/\~}: $otras $([ "$otras" -eq 1 ] && echo 'línea más' || echo 'líneas más')")
    done
    [ ${#items[@]} -gt 0 ] || return 0
    [ ${#items[@]} -le 12 ] || items=("${items[@]:0:11}" "y $((${#items[@]} - 11)) más")
    plan_linea aviso "zsh no leerá esto, que bash carga al entrar (lo que uses, cópialo a ~/.zshrc.local):" "${items[@]}"
}

# Lo de fuera de tmux en el plan de ./install, sin tocar nada: los paquetes los
# enseña él, y ~/.zshrc no se toca
plan() {
    local sh prev
    sh="$(shell_login)"
    if [ "$SITIO" = global ]; then
        if [[ "$sh" != */zsh ]]; then
            plan_linea cambiar "tu shell de login: $sh → zsh, con esta config también fuera de tmux (para volver: ./install zsh --solo-tmux)"
        elif ! zshenv_es_nuestro; then
            plan_linea cambiar "zsh, que ya es tu shell de login, carga esta config también fuera de tmux$([ -e "$HOME/.zshrc" ] && echo ', no tu ~/.zshrc')"
        else
            plan_linea ya "zsh también fuera de tmux (es tu shell de login)"
        fi
        if { [ -e "$ZSHENV" ] || [ -L "$ZSHENV" ]; } && ! zshenv_es_nuestro; then
            plan_linea backup "${ZSHENV/#$HOME/\~} no es de este repo: se guarda como ~/.zshenv.bak.<fecha>"
        fi
        # Si zsh ya era la shell de login, bash no se usaba al entrar: nada cambia
        es_global zsh || [[ "$sh" == */zsh ]] || lo_de_bash
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

# Lo nuestro de ~/.zshenv con --global (de ZSHENV_MARCA a ZSHENV_FIN)
texto_zshenv() {
    printf '%s\n' "$ZSHENV_MARCA" \
        '# Lo pone ./install zsh --global (lo quitan --solo-tmux y ./uninstall zsh):' \
        '# zsh, también fuera de tmux, con la config del repo (zsh/zshenv). Si el repo' \
        '# se ha movido o borrado, lo avisa en vez de dejar zsh sin config.' \
        'if [[ -r ~/.local/opt/tmux-config/zsh/zshenv ]]; then' \
        '    . ~/.local/opt/tmux-config/zsh/zshenv' \
        'elif [[ -o interactive ]]; then' \
        '    print -u2 "tmux-config: no encuentro la config de zsh (¿has movido o borrado el repo?). En su carpeta: ./install zsh --global"' \
        'fi' \
        "$ZSHENV_FIN"
}

# ~/.zshenv: el nuestro (de cualquier versión, también el enlace al repo de
# antes) se cambia sin más, conservando lo que alguien añadió debajo; otro, se
# aparta como ~/.zshenv.bak.<fecha>. Se escribe aparte y se mueve: un zsh que
# arranque a la vez no lo lee a medias
poner_zshenv() {
    local backup nuevo
    link_with_backup "$ZSHENV_SRC" "$ZSHENV_LINK" zsh/zshenv
    nuevo="$(texto_zshenv)"
    zshenv_nuestro "$ZSHENV" && nuevo="$nuevo"$'\n'"$(zshenv_resto "$ZSHENV")"
    nuevo="${nuevo%$'\n'}"
    if zshenv_nuestro "$ZSHENV" && [ "$(cat "$ZSHENV")" = "$nuevo" ]; then
        info "~/.zshenv ya carga esta config"
        return
    fi
    if ! zshenv_es_nuestro && { [ -e "$ZSHENV" ] || [ -L "$ZSHENV" ]; }; then
        backup="$ZSHENV.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$ZSHENV" "$backup"
        info "config anterior guardada en $backup"
    fi
    printf '%s\n' "$nuevo" > "$ZSHENV.tmp"
    mv -f "$ZSHENV.tmp" "$ZSHENV"
    info "~/.zshenv carga esta config (zsh/zshenv) y avisa si el repo se mueve"
}

# --global: zsh pasa a ser la shell de login, y ~/.zshenv lo lleva a esta
# config. Antes de cambiar la shell se apunta la de antes, para que --solo-tmux y
# ./uninstall zsh la devuelvan (si ya era zsh, vacío): así ningún corte deja la
# shell cambiada sin apuntar. Si el cambio falla (sin sudo, usuario de LDAP...),
# se borra lo apuntado y no queda nada a medias
fuera_global() {
    local sh zsh_bin st nuevo=0
    sh="$(shell_login)"
    zsh_bin="$(command -v zsh)"
    st="$(global_file zsh)"
    if ! es_global zsh; then
        mkdir -p "$STATE_DIR"
        if [[ "$sh" == */zsh ]]; then : > "$st"; else echo "$sh" > "$st"; fi
        nuevo=1
    fi
    if [[ "$sh" != */zsh ]]; then
        # Ctrl+C en la contraseña de sudo: tampoco queda apuntado
        [ "$nuevo" -eq 0 ] || trap 'rm -f "$st"; exit 130' INT TERM HUP
        ( cambiar_shell "$zsh_bin" ) || { [ "$nuevo" -eq 0 ] || rm -f "$st"; exit 1; }
        trap - INT TERM HUP
        info "tu shell de login es $zsh_bin: al entrar por SSH (en las sesiones nuevas), zsh con esta config; en el escritorio, cierra sesión y vuelve a entrar (hasta entonces, su terminal abre ${sh##*/})"
    fi
    poner_zshenv
    info "zsh también fuera de tmux; para volver a solo tmux: ./install zsh --solo-tmux"
}

# --solo-tmux tras --global: vuelve la shell de login de antes y tu ~/.zshenv. El
# ~/.zshenv, también si es el enlace de antes a otro clon del repo
fuera_solo_tmux() {
    local prev
    prev="$(cat "$(global_file zsh)")"
    if [ -n "$prev" ] && [[ "$(shell_login)" == */zsh ]]; then
        cambiar_shell "$prev"
        info "tu shell de login vuelve a ser $prev (en las sesiones nuevas; en el escritorio, al cerrar sesión y volver a entrar)"
    fi
    if zshenv_es_nuestro; then quitar_zshenv; fi
    if es_del_repo "$ZSHENV_LINK" zsh/zshenv; then rm "$ZSHENV_LINK"; fi
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

# .zshrc y zshenv cargan limpios (zsh_valida). Si no y ya están enlazados (un
# git pull a mano), los zsh nuevos ya los cargan así: lo dice
check_conf() {
    local err
    if ! err="$(zsh_valida "$CONF_SRC" "$ZSHENV_SRC")"; then
        link_is_ours "$CONF_SRC" "$CONF_DST" &&
            die "$err"$'\n'"y es la config que ya cargan los zsh nuevos (el enlace apunta al repo): arréglala o vuelve a la versión anterior con git"
        die "$err"$'\n'"no se ha enlazado nada"
    fi
    command -v script >/dev/null || aviso "falta el comando script: de zsh/.zshrc solo se ha comprobado la sintaxis"
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

link_with_backup "$CONF_SRC" "$CONF_DST" zsh/.zshrc
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
