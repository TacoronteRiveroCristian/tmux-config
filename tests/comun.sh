# shellcheck shell=bash
# tests/comun.sh — funciones de las pruebas, dentro del contenedor. tests/run
# monta el repo en /repo (solo lectura, con los cambios sin commit) y tests/ en /tests.
# shellcheck disable=SC2016  # comillas simples: se expanden dentro de "su -c"
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

fallos=0
check() { local d="$1"; shift; if "$@"; then echo "OK    $d"; else echo "FALLO $d"; fallos=$((fallos + 1)); fi; }
has()   { grep -qF -- "$1" <<<"$2"; }
hasnt() { ! grep -qF -- "$1" <<<"$2"; }
as()    { local u="$1"; shift; su - "$u" -c "$*" 2>&1; }
paso()  { echo "--- $* ($(date +%T))"; }
fin()   { echo "RESULTADO: $fallos fallos"; exit $((fallos > 0)); }
sangra() { sed "s/^/      ${1-}/"; }

# Lo mínimo de una máquina recién instalada. "-yqq install" y no "install -y -qq":
# esto último casa con la heurística de bash-completion de vim/install.sh
base() {
    apt-get update -qq >/dev/null
    apt-get -yqq install sudo ca-certificates curl git procps >/dev/null 2>&1
}

# Usuario con sudo sin contraseña, como el primero de Raspberry Pi OS
mkuser() {
    id "$1" >/dev/null 2>&1 || useradd -m -s /bin/bash "$1"
    echo "$1 ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$1"
    as "$1" 'git config --global user.email t@t && git config --global user.name t' >/dev/null
}

# "GitHub" local: /srv/remoto.git, con el árbol de /repo como último commit de
# main (encima de su historia: los commits viejos sirven de "desde"). Los
# cambios de upstream se hacen en /srv/src con commit_upstream.
upstream() {
    git config --system --add safe.directory '*'
    rm -rf /srv && mkdir -p /srv && cp -a /repo /srv/src
    cd /srv/src || exit 1
    git config user.email t@t && git config user.name t
    git checkout -q -B main && git add -A && git commit -q --allow-empty -m "árbol a probar"
    git clone -q --bare /srv/src /srv/remoto.git
    git remote remove origin 2>/dev/null; git remote add origin /srv/remoto.git
    chmod -R a+rwX /srv
    cd / || exit 1
}
# commit_upstream MENSAJE COMANDO: cambia algo en /srv/src y lo sube
commit_upstream() { (cd /srv/src && eval "$2" && git commit -qam "$1" && git push -q origin main) && chmod -R a+rwX /srv; }

# El clon, donde lo tiene el usuario en sus máquinas (la ~ la expande "su -c")
# shellcheck disable=SC2088
D='~/GitHub/personal/tmux-config'
clonar() { as "$1" "git clone -q /srv/remoto.git $D" >/dev/null; }
