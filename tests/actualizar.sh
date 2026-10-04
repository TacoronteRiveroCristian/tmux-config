#!/usr/bin/env bash
# shellcheck disable=SC2016  # comillas simples: se expanden dentro de "su -c"
# tests/actualizar.sh — ./actualizar con cambios de verdad en upstream, dentro del
# contenedor: pull, relanzarse con la versión nueva, qué detecta como
# instalado, --actualizar, y que con un pull imposible no instale nada.
. /tests/comun.sh
base
upstream
for u in u u2 u3; do mkuser $u; clonar $u; done

paso "argumentos"
out="$(as u3 "cd $D && ./actualizar --mal")"; r=$?
check "--mal falla y enseña el uso" bash -c "[ $r -ne 0 ] && grep -q 'uso: ./actualizar' <<<\"\$1\"" _ "$out"
out="$(as u3 "cd $D && ./actualizar -h")"; r=$?
check "-h explica qué hace" bash -c "[ $r -eq 0 ] && grep -q 'git pull + ./install' <<<\"\$1\"" _ "$out"

paso "nada instalado (u3)"
out="$(as u3 "cd $D && ./actualizar")"; r=$?
check "termina bien y lo dice" bash -c "[ $r -eq 0 ] && grep -q 'no hay nada instalado' <<<\"\$1\"" _ "$out"

paso "todo instalado (u) y upstream cambia ./actualizar y la guía"
out="$(as u "cd $D && ./install tmux zsh vim")"; r=$?
check "install tmux zsh vim" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -20
commit_upstream "marca" "sed -i 's/^info \"instalados:/info \"MARCA-NUEVA\"\ninfo \"instalados:/' actualizar && echo >> docs/GUIA.md"
out="$(as u "cd $D && ./actualizar")"; r=$?
echo "$out" | grep -E '^==> (git pull|instalados|MARCA|---)|Fast-forward|ERROR' | sangra ""
check "actualizar" [ $r -eq 0 ]
check "ha hecho el pull" [ "$(as u "git -C $D rev-parse HEAD")" = "$(git -C /srv/src rev-parse HEAD)" ]
check "se relanza con la versión nueva" has "MARCA-NUEVA" "$out"
check "detecta y aplica tmux zsh vim" bash -c "grep -q 'instalados: tmux zsh vim' <<<\"\$1\" && grep -q -- '--- tmux' <<<\"\$1\" && grep -q -- '--- zsh' <<<\"\$1\" && grep -q -- '--- vim' <<<\"\$1\"" _ "$out"

paso "otra vez, sin cambios"
t0=$(date +%s); out="$(as u "cd $D && ./actualizar")"; r=$?
check "idempotente: no reinstala paquetes" bash -c "[ $r -eq 0 ] && grep -q 'paquetes ya instalados (para actualizarlos: ./install vim' <<<\"\$1\"" _ "$out"
echo "      (tardó $(( $(date +%s) - t0 ))s)"

paso "solo tmux (u2), y --actualizar"
as u2 "cd $D && ./install tmux" >/dev/null; as u2 "git -C $D pull -q"
out="$(as u2 "cd $D && ./actualizar")"; r=$?
check "solo aplica tmux" bash -c "[ $r -eq 0 ] && grep -q 'instalados: tmux\$' <<<\"\$1\" && ! grep -qE -- '--- (zsh|vim)' <<<\"\$1\"" _ "$out"
out="$(as u2 "cd $D && ./actualizar --actualizar")"; r=$?
check "--actualizar llega a ./install" bash -c "[ $r -eq 0 ] && grep -q 'actualizando tmux' <<<\"\$1\"" _ "$out"

paso "pull imposible: commit local de u y otro en upstream"
as u "cd $D && echo local >> README.md && git commit -qam local"
commit_upstream "otro" "echo remoto >> README.md"
out="$(as u "cd $D && ./actualizar")"; r=$?
echo "$out" | grep -E 'ERROR|fatal' | sangra ""
check "falla con un error claro y no instala nada" bash -c "[ $r -ne 0 ] && grep -q 'ERROR: git pull no ha podido' <<<\"\$1\" && ! grep -q 'instalados:' <<<\"\$1\"" _ "$out"
fin
