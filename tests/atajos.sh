#!/usr/bin/env bash
# tests/atajos.sh — comprueba que los atajos Espacio+tecla de neovim son los mismos
# en el código (nvim/lua) y en el mapa (sección "En neovim" de docs/CHEATSHEET.md):
# que no falte ninguno en el mapa y que el mapa no cite ninguno que ya no existe.
#
#   tests/atajos.sh
#
# No necesita Docker ni neovim: lee los ficheros. La CI lo pasa en cada push.
# En el mapa, "Espacio ca · cr · cf" son Espacio ca, Espacio cr y Espacio cf. Las
# teclas, letras, números o ?. Los grupos de which-key (group = ...) no cuentan.
set -euo pipefail
export LC_ALL=C   # sort y comm, con el mismo orden

cd "$(dirname "${BASH_SOURCE[0]}")/.."

codigo="$(grep -rh "'<leader>" nvim/lua | grep -v 'group =' | grep -o "'<leader>[^']*'" |
    sed "s/^'<leader>//; s/'\$//" | sort -u)"

mapa="$(awk '/^## / { dentro = /^## En neovim/ } dentro' docs/CHEATSHEET.md | awk '{
    linea = $0
    while (match(linea, /Espacio [A-Za-z0-9?]+( +· +[A-Za-z0-9?]+)*/)) {
        n = split(substr(linea, RSTART + 8, RLENGTH - 8), teclas, / +· +/)
        for (i = 1; i <= n; i++) print teclas[i]
        linea = substr(linea, RSTART + RLENGTH)
    }
}' | sort -u)"

[ -n "$codigo" ] || { echo "ERROR: no hay ningún '<leader>...' en nvim/lua"; exit 1; }
[ -n "$mapa" ] || { echo "ERROR: no hay ningún 'Espacio ...' en la sección \"En neovim\" de docs/CHEATSHEET.md"; exit 1; }

fallos=0
while read -r t; do
    [ -n "$t" ] || continue
    echo "FALTA en docs/CHEATSHEET.md: Espacio $t (está en nvim/lua)"
    fallos=$((fallos + 1))
done < <(comm -23 <(echo "$codigo") <(echo "$mapa"))
while read -r t; do
    [ -n "$t" ] || continue
    echo "NO EXISTE: Espacio $t (lo cita docs/CHEATSHEET.md, no está en nvim/lua)"
    fallos=$((fallos + 1))
done < <(comm -13 <(echo "$codigo") <(echo "$mapa"))

if [ "$fallos" -gt 0 ]; then
    echo "==> $fallos atajo(s) sin cuadrar entre nvim/lua y docs/CHEATSHEET.md"
    exit 1
fi
echo "==> atajos Espacio: los $(wc -l <<<"$codigo") del código están en docs/CHEATSHEET.md, y ninguno de más"
