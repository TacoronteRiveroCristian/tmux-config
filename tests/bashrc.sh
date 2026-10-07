#!/usr/bin/env bash
# tests/bashrc.sh — el bloque que pone ./install vim --global al final de
# ~/.bashrc (poner_bloque y quitar_bloque, de lib/comun.sh): que quitarlo deje
# ~/.bashrc byte a byte como estaba (también sin salto de línea al final, vacío
# o sin existir, y con lo que se añadió detrás), que ponerlo dos veces no lo
# repita, que el de una versión anterior se cambie y que uno tocado a mano no se
# toque.
#
#   tests/bashrc.sh
#
# No necesita Docker: cada caso, con un HOME temporal. La CI lo pasa en cada push.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
REPO="$PWD"
T="$(mktemp -d)"; export T
trap 'rm -rf "$T"' EXIT

fallos=0
check() { local d="$1"; shift; if "$@"; then echo "OK    $d"; else echo "FALLO $d"; fallos=$((fallos + 1)); fi; }

# en CASO CÓDIGO: CÓDIGO en bash, con las funciones de lib/comun.sh y HOME en
# $T/h/CASO, nuevo. Fuera del HOME, en $T, quedan los ficheros para comprobar
en() {
    mkdir -p "$T/h/$1"
    HOME="$T/h/$1" XDG_STATE_HOME="" bash -c '. "$1/lib/comun.sh"; eval "$2"' _ "$REPO" "$2"
}
iguales() { cmp -s "$1" "$2"; }
bloques() { grep -cxF '# >>> tmux-config >>>' "$1"; }

printf '# .bashrc\nalias ll="ls -l"\n' > "$T/normal"
printf 'a\nb' > "$T/sin-salto"
: > "$T/vacio"

# shellcheck disable=SC2016  # el código se expande dentro de "en"
for c in normal sin-salto vacio; do
    en "$c" 'cp "$T/'"$c"'" "$BASHRC"; poner_bloque; poner_bloque; cp "$BASHRC" "$T/'"$c"'.puesto"
             quitar_bloque; cp "$BASHRC" "$T/'"$c"'.quitado"'
    check "$c: ponerlo dos veces no lo repite" [ "$(bloques "$T/$c.puesto")" -eq 1 ]
    check "$c: al quitarlo queda byte a byte como estaba" iguales "$T/$c" "$T/$c.quitado"
done

# shellcheck disable=SC2016
en no-existe 'poner_bloque; cp "$BASHRC" "$T/no-existe.puesto"; quitar_bloque; [ -e "$BASHRC" ] || touch "$T/no-existe.ok"'
check "sin ~/.bashrc: lo crea, y al quitarlo no queda" bash -c "[ -s '$T/no-existe.puesto' ] && [ -e '$T/no-existe.ok' ]"

# shellcheck disable=SC2016
en detras 'cp "$T/sin-salto" "$BASHRC"; poner_bloque; echo "export X=1" >> "$BASHRC"; quitar_bloque; cp "$BASHRC" "$T/detras.quitado"'
printf 'a\nb\nexport X=1\n' > "$T/detras.esperado"
check "lo añadido detrás del bloque se queda, entero" iguales "$T/detras.esperado" "$T/detras.quitado"

# shellcheck disable=SC2016
en permisos 'cp "$T/normal" "$BASHRC"; chmod 600 "$BASHRC"; poner_bloque; quitar_bloque; stat -c %a "$BASHRC" > "$T/permisos.modo"'
check "conserva los permisos (600)" [ "$(cat "$T/permisos.modo")" = 600 ]

# shellcheck disable=SC2016
en viejo 'cp "$T/normal" "$BASHRC"; poner_bloque; sed -i "s/NVIM_APPNAME=tmux-config-nvim/NVIM_APPNAME=viejo/" "$BASHRC"
          poner_bloque; cp "$BASHRC" "$T/viejo.puesto"; [ "$(bloque_actual)" = "$(texto_bloque)" ] && touch "$T/viejo.al-dia"
          quitar_bloque; cp "$BASHRC" "$T/viejo.quitado"'
check "el bloque de una versión anterior se cambia por el de ahora, sin repetirlo" bash -c "[ -e '$T/viejo.al-dia' ] && [ \"\$(grep -cxF '# >>> tmux-config >>>' '$T/viejo.puesto')\" -eq 1 ]"
check "y al quitarlo queda como estaba" iguales "$T/normal" "$T/viejo.quitado"

# shellcheck disable=SC2016
en tocado 'cp "$T/normal" "$BASHRC"; poner_bloque; sed -i "/^# <<< tmux-config <<<\$/d" "$BASHRC"; echo "export Y=1" >> "$BASHRC"
           cp "$BASHRC" "$T/tocado.antes"; estado_bloque > "$T/tocado.estado"
           quitar_bloque && touch "$T/tocado.quito"; poner_bloque && touch "$T/tocado.puso"; cp "$BASHRC" "$T/tocado.despues"'
check "sin la línea de cierre: está tocado a mano" [ "$(cat "$T/tocado.estado")" = 2 ]
check "tocado: ni quitarlo ni ponerlo hacen nada (no se come lo de debajo)" bash -c "[ ! -e '$T/tocado.quito' ] && [ ! -e '$T/tocado.puso' ] && cmp -s '$T/tocado.antes' '$T/tocado.despues'"

# shellcheck disable=SC2016
en repetido 'cp "$T/normal" "$BASHRC"; texto_bloque >> "$BASHRC"; texto_bloque >> "$BASHRC"; estado_bloque > "$T/repetido.estado"'
check "repetido: también está tocado a mano" [ "$(cat "$T/repetido.estado")" = 2 ]

# shellcheck disable=SC2016
en sintaxis 'texto_bloque | bash -n && touch "$T/sintaxis.ok"'
check "el bloque es bash válido" [ -e "$T/sintaxis.ok" ]

if [ "$fallos" -gt 0 ]; then
    echo "==> $fallos fallo(s) en el bloque de ~/.bashrc"
    exit 1
fi
echo "==> bloque de ~/.bashrc: ponerlo y quitarlo lo deja byte a byte como estaba"
