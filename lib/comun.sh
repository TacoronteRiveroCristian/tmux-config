# lib/comun.sh — funciones compartidas por los install.sh / uninstall.sh de
# cada componente. Se carga con:  . "$REPO_DIR/lib/comun.sh"

info() { printf '==> %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# El componente que se está instalando (el directorio del script); ./install lo
# cambia mientras enseña el plan de cada uno
TC_COMP="$(basename "$(dirname "$(readlink -f "$0")")")"

# aviso TEXTO [LÍNEA...]: algo que no impide seguir pero conviene leer. Sale
# ahora y, con ./install, otra vez en el resumen del final (TC_AVISOS)
aviso() {
    local l
    info "AVISO: $1"
    for l in "${@:2}"; do info "       $l"; done
    [ -z "${TC_AVISOS:-}" ] || apuntar "$TC_AVISOS" aviso "$@"
}

# --- Plan de ./install ----------------------------------------------------------
#
# plan_linea TIPO TEXTO [LÍNEA...]: una línea del plan que enseña ./install antes
# de tocar nada; las LÍNEAs van debajo. TIPO:
#   ya, instalar, actualizar, descargar   lo que hay y lo que hará
#   backup    aparta una config tuya (como *.bak.<fecha>)
#   cambiar   cambia algo de fuera de tmux (shell de login, ~/.bashrc): --global
#   sin       sigue sin ello · aviso: conviene leerlo (los dos, también en el resumen)
#   bloquea   no se instala nada
# instalar, actualizar, backup y cambiar piden confirmación. Con TC_PLAN (lo pone
# ./install) queda apuntada ahí, para el recuento y el resumen.
plan_linea() {
    local tipo="$1" e l; shift
    # a mano: printf rellena por bytes, y "está" tiene uno de más
    case "$tipo" in
        ya)         e="ya está   " ;;
        instalar)   e="instalar  " ;;
        actualizar) e="actualizar" ;;
        descargar)  e="descargar " ;;
        backup)     e="backup    " ;;
        cambiar)    e="cambiar   " ;;
        sin)        e="sin       " ;;
        aviso)      e="aviso     " ;;
        bloquea)    e="BLOQUEA   " ;;
        *)          die "plan_linea: tipo desconocido: $tipo" ;;
    esac
    printf '  %s %s\n' "$e" "$1"
    for l in "${@:2}"; do printf '  %10s %s\n' "" "$l"; done
    [ -z "${TC_PLAN:-}" ] || apuntar "$TC_PLAN" "$tipo" "$@"
}

# apuntar FICHERO TIPO TEXTO [LÍNEA...]: "TIPO<TAB>COMPONENTE<TAB>TEXTO", y una
# línea "+" por cada LÍNEA de debajo
apuntar() {
    local f="$1" tipo="$2" l; shift 2
    printf '%s\t%s\t%s\n' "$tipo" "$TC_COMP" "$1" >> "$f"
    for l in "${@:2}"; do printf '+\t%s\t%s\n' "$TC_COMP" "$l" >> "$f"; done
}

# Todo lo instalado del repo vive aquí, salvo ~/.tmux.conf (la única puerta):
# solo lo usa lo que arranca dentro de tmux. Fuera, nada lo lee ni está en el PATH.
# shellcheck disable=SC2034  # lo usan los scripts que cargan este fichero
TC_DIR="$HOME/.local/opt/tmux-config"

# sudo solo para el gestor de paquetes, y solo si no somos root
SUDO=""
need_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null || die "hace falta sudo (o ejecutar como root) para $1"
        SUDO="sudo"
    fi
}

pkg_manager() {
    if command -v apt-get >/dev/null; then echo apt
    elif command -v dnf >/dev/null; then echo dnf
    else echo ""
    fi
}

pkg_installed() {
    if command -v dpkg-query >/dev/null; then
        dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
    elif command -v rpm >/dev/null; then
        rpm -q "$1" >/dev/null 2>&1
    else
        return 1
    fi
}

# --- Enlaces --------------------------------------------------------------------

link_is_ours() { [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; }

# link_with_backup SRC DST: enlaza DST -> SRC. Si DST ya existía y no era
# nuestro, lo guarda como DST.bak.<fecha>.
link_with_backup() {
    local src="$1" dst="$2" backup
    if link_is_ours "$src" "$dst"; then
        info "${dst/#$HOME/\~} ya apunta a este repo"
        return
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        backup="$dst.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$backup"
        info "config anterior guardada en $backup"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    info "${dst/#$HOME/\~} -> $src"
}

# --- Migración: lo que dejó en $HOME la versión anterior del repo -------------
#
# Antes los enlaces iban en $HOME (~/.zshrc, ~/.vimrc, ~/.config/nvim/init.lua,
# ~/.local/bin) y se notaban fuera de tmux. Cada install.sh quita los suyos.

# es_del_repo ENLACE REL: ENLACE apunta a REL dentro de un clon de este repo,
# aunque sea otro clon, otra ruta al mismo o un fichero que ya no está (vim/vimrc).
# Es del repo si esa raíz tiene lib/comun.sh, o si ya no existe (clon borrado);
# un enlace a tus propios ficheros (otra raíz que sí existe) no lo es.
es_del_repo() {
    local t root
    [ -L "$1" ] || return 1
    t="$(readlink "$1")"
    [[ "$t" == */"$2" ]] || return 1
    [[ "$t" == /* ]] || t="$(dirname "$1")/$t"
    root="${t%/"$2"}"
    [ -e "$root/lib/comun.sh" ] || [ ! -e "$root" ]
}

# restore_backup DST REL: devuelve a DST la config que había antes de enlazarlo
# (el DST.bak.<fecha> que guardó link_with_backup). Solo si hay exactamente uno:
# con varios los enseña y no elige. No cuentan los que son a su vez un enlace a
# un clon de este repo (es_del_repo). Nunca borra un backup.
restore_backup() {
    local dst="$1" rel="$2" b cands=()
    if [ -e "$dst" ] || [ -L "$dst" ]; then return 0; fi
    for b in "$dst".bak.*; do
        [[ "$b" =~ \.bak\.[0-9]{8}-[0-9]{6}$ ]] || continue
        es_del_repo "$b" "$rel" && continue
        cands+=("$b")
    done
    case ${#cands[@]} in
        0) ;;
        1) mv "${cands[0]}" "$dst"
           info "tu config anterior vuelve a su sitio: ${cands[0]/#$HOME/\~} -> ${dst/#$HOME/\~}" ;;
        *) aviso "hay varios backups de ${dst/#$HOME/\~}; no se elige ninguno (mueve tú el que quieras):" \
               "${cands[@]/#$HOME/\~}" ;;
    esac
}

# unlink_old SRC DST: quita DST si es un enlace a SRC en este u otro clon del
# repo (es_del_repo) y restaura el backup de lo que había antes. Falla si no
# había nada que quitar.
unlink_old() {
    local dst="$2" rel="${1#"$REPO_DIR"/}"
    es_del_repo "$dst" "$rel" || return 1
    rm "$dst"
    info "quitado el enlace antiguo ${dst/#$HOME/\~} (fuera de tmux ya no se ve nada del repo)"
    restore_backup "$dst" "$rel"
}

# rmdir_vacio DIR...: quita los directorios que hayan quedado vacíos
rmdir_vacio() {
    local d
    for d in "$@"; do
        [ -d "$d" ] && rmdir "$d" 2>/dev/null && info "quitado ${d/#$HOME/\~} (vacío)"
    done
    return 0
}

# --- Estado: qué paquetes instaló cada componente -----------------------------
#
# Un fichero por componente con un paquete por línea. uninstall quita solo los
# que aparecen aquí: lo que ya estaba instalado antes no es nuestro.

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-config"

state_file() { echo "$STATE_DIR/$1.paquetes"; }

state_list() {
    local f; f="$(state_file "$1")"
    [ -f "$f" ] && cat "$f" || true
}

# state_add COMPONENTE PAQUETE...
state_add() {
    local comp="$1" f; shift
    f="$(state_file "$comp")"
    mkdir -p "$STATE_DIR"
    { state_list "$comp"; printf '%s\n' "$@"; } | sort -u > "$f.tmp"
    mv "$f.tmp" "$f"
}

# state_set COMPONENTE PAQUETE...: reemplaza la lista (vacía = borra el fichero)
state_set() {
    local comp="$1" f; shift
    f="$(state_file "$comp")"
    if [ $# -eq 0 ]; then
        rm -f "$f"
    else
        mkdir -p "$STATE_DIR"
        printf '%s\n' "$@" | sort -u > "$f"
    fi
}

# --- Instalado: su enlace apunta a un clon de este repo -------------------------
#
# También los enlaces de la versión anterior (~/.zshrc, ~/.config/nvim,
# ~/.vimrc): así ./actualizar los migra
instalado() {
    local conf="${XDG_CONFIG_HOME:-$HOME/.config}"
    case "$1" in
        tmux) es_del_repo "$HOME/.tmux.conf" .tmux.conf ;;
        zsh)  es_del_repo "$TC_DIR/zsh/.zshrc" zsh/.zshrc || es_del_repo "$HOME/.zshrc" zsh/.zshrc ;;
        vim)  es_del_repo "$conf/tmux-config-nvim/init.lua" nvim/init.lua \
                  || es_del_repo "$conf/nvim/init.lua" nvim/init.lua || es_del_repo "$HOME/.vimrc" vim/vimrc ;;
        *)    return 1 ;;
    esac
}

# --- zsh y vim: solo dentro de tmux o también fuera (--global) ------------------
#
# Por defecto, solo dentro de tmux. Con ./install --global, también fuera: zsh
# como shell de login (zsh/install.sh) y neovim con un bloque en ~/.bashrc
# (vim/install.sh). Queda apuntado en <componente>.global (el de zsh guarda la
# shell de login de antes, para devolverla) y ./actualizar lo mantiene.

global_file() { echo "$STATE_DIR/$1.global"; }
es_global()   { [ -e "$(global_file "$1")" ]; }

# sitio COMPONENTE: global o tmux. El que eligió ./install (TC_SITIO_<componente>)
# o, si el script va suelto, el apuntado
sitio() {
    local v="TC_SITIO_$1"
    if [ -n "${!v:-}" ]; then echo "${!v}"
    elif es_global "$1"; then echo global
    else echo tmux
    fi
}

# La shell de login de este usuario: la de /etc/passwd, no $SHELL (que es la de
# cuando entraste)
shell_login() { getent passwd "$(id -un)" | cut -d: -f7; }

# cambiar_shell RUTA: la shell de login pasa a ser RUTA (con sudo: chsh pediría
# la contraseña). Tiene que estar en /etc/shells: si no, no se podría entrar.
# Quien la llama la usa antes de tocar nada más: si falla, nada queda a medias
cambiar_shell() {
    grep -qxF "$1" /etc/shells || die "$1 no está en /etc/shells: tu shell de login no se cambia"
    need_sudo "cambiar tu shell de login"
    $SUDO usermod -s "$1" "$(id -un)" || die "no se pudo cambiar tu shell de login a $1"
}

# El bloque de vim --global al final de ~/.bashrc, entre las líneas BLOQUE_INI y
# BLOQUE_FIN (fijas: así se reconoce el de cualquier versión). poner_bloque
# apunta en BASHRC_ANTES si ~/.bashrc no existía o no acababa en salto de línea,
# y quitar_bloque lo deja byte a byte como estaba. Si el bloque está tocado a
# mano (falta una de las dos líneas, o está repetido), ninguna de las dos lo toca.
BASHRC="$HOME/.bashrc"
BASHRC_ANTES="$STATE_DIR/bashrc.antes"
BLOQUE_INI="# >>> tmux-config >>>"
BLOQUE_FIN="# <<< tmux-config <<<"

# shellcheck disable=SC2016  # el $ es para bash, al leer ~/.bashrc
texto_bloque() {
    printf '%s\n' "$BLOQUE_INI" \
        '# Lo pone ./install vim --global: nvim, vi, vim y EDITOR, también fuera de' \
        '# tmux (solo en bash interactivo). ./install vim --solo-tmux lo quita.' \
        'case $- in *i*)' \
        '    if [ -x "$HOME/.local/opt/tmux-config/bin/nvim" ]; then' \
        '        case ":$PATH:" in *":$HOME/.local/opt/tmux-config/bin:"*) ;; *) PATH="$HOME/.local/opt/tmux-config/bin:$PATH" ;; esac' \
        '        export NVIM_APPNAME=tmux-config-nvim' \
        '        export EDITOR="$HOME/.local/opt/tmux-config/bin/nvim" VISUAL="$HOME/.local/opt/tmux-config/bin/nvim"' \
        '    fi ;;' \
        'esac' \
        "$BLOQUE_FIN"
}

# estado_bloque: 0 no hay · 1 hay uno, bien cerrado · 2 está tocado a mano
estado_bloque() {
    [ -f "$BASHRC" ] || { echo 0; return; }
    awk -v ini="$BLOQUE_INI" -v fin="$BLOQUE_FIN" '
        $0 == ini { i++; if (!li) li = NR }
        $0 == fin { f++; lf = NR }
        END { if (!i && !f) print 0; else if (i == 1 && f == 1 && li < lf) print 1; else print 2 }' "$BASHRC"
}
hay_bloque() { [ "$(estado_bloque)" != 0 ]; }

# El bloque que hay ahora, si está bien cerrado
bloque_actual() {
    [ "$(estado_bloque)" = 1 ] || return 0
    awk -v ini="$BLOQUE_INI" -v fin="$BLOQUE_FIN" '$0 == ini {f = 1} f {print} f && $0 == fin {f = 0}' "$BASHRC"
}

# poner_bloque: el bloque al final de ~/.bashrc (el de una versión anterior, se
# cambia). Falla, sin tocar nada, si está tocado a mano
poner_bloque() {
    case "$(estado_bloque)" in
        2) return 1 ;;
        1) [ "$(bloque_actual)" != "$(texto_bloque)" ] || return 0
           quitar_bloque ;;
    esac
    mkdir -p "$STATE_DIR"
    rm -f "$BASHRC_ANTES"
    if [ ! -e "$BASHRC" ]; then
        echo no-existia > "$BASHRC_ANTES"
    elif [ -s "$BASHRC" ] && [ -n "$(tail -c 1 "$BASHRC")" ]; then
        # sin salto de línea al final, el bloque se pegaría a la última línea
        echo sin-salto > "$BASHRC_ANTES"
        echo >> "$BASHRC"
    fi
    texto_bloque >> "$BASHRC"
}

# quitar_bloque: deja ~/.bashrc como estaba antes de poner_bloque. Escribe con
# cat y no con mv: conserva sus permisos y su dueño. Falla, sin tocar nada, si
# el bloque está tocado a mano
quitar_bloque() {
    local tmp antes=""
    case "$(estado_bloque)" in 0) return 0 ;; 2) return 1 ;; esac
    [ ! -f "$BASHRC_ANTES" ] || antes="$(cat "$BASHRC_ANTES")"
    # el salto de línea que puso poner_bloque, solo si el bloque sigue al final
    [ "$antes" != sin-salto ] || [ "$(tail -n 1 "$BASHRC")" = "$BLOQUE_FIN" ] || antes=""
    tmp="$(mktemp)"
    awk -v ini="$BLOQUE_INI" -v fin="$BLOQUE_FIN" '$0 == ini {f = 1} !f {print} f && $0 == fin {f = 0}' "$BASHRC" > "$tmp"
    if [ "$antes" = no-existia ] && [ ! -s "$tmp" ]; then
        rm -f "$BASHRC"
    else
        [ "$antes" != sin-salto ] || truncate -s -1 "$tmp"
        cat "$tmp" > "$BASHRC"
    fi
    rm -f "$tmp" "$BASHRC_ANTES"
}

# --- tmux en marcha -------------------------------------------------------------

# Imprime los sockets de los servidores tmux vivos de este usuario
tmux_sockets() {
    local dir="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)" s
    command -v tmux >/dev/null && [ -d "$dir" ] || return 0
    for s in "$dir"/*; do
        [ -S "$s" ] && tmux -S "$s" ls >/dev/null 2>&1 && echo "$s"
    done
    return 0
}

# Aplica ~/.tmux.conf a los tmux en marcha de este usuario sin cerrar sesiones
# (lo mismo que Ctrl+B R). Solo a los que arrancaron con esa config o sin
# ninguna (tmux ya corría al instalar); los lanzados con otra (-f) no se tocan.
# Un atajo que se quite de la config sigue activo hasta reiniciar tmux.
tmux_reload() {
    local conf="$HOME/.tmux.conf" real s files f ok lista
    [ -e "$conf" ] || return 0
    real="$(readlink -f "$conf")"
    while read -r s; do
        [ -n "$s" ] || continue
        files="$(tmux -S "$s" display -p '#{config_files}' 2>/dev/null)" || continue
        ok=1
        IFS=, read -ra lista <<<"$files"
        for f in ${lista[@]+"${lista[@]}"}; do
            case "$f" in "$real"|/etc/tmux.conf) ;; *) ok=0 ;; esac
        done
        if [ "$ok" -eq 0 ]; then
            info "tmux '$(basename "$s")' arrancó con otra config ($files): no se toca"
        elif tmux -S "$s" source-file "$conf"; then
            info "config aplicada al tmux '$(basename "$s")' en marcha, sin cerrar sus sesiones"
        else
            aviso "no se pudo aplicar la config al tmux '$(basename "$s")'"
        fi
    done < <(tmux_sockets)
}
