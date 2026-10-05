# tmux

La config de tmux es [`../.tmux.conf`](../.tmux.conf), en la raíz del repo. Esta
carpeta solo tiene su instalador. Está en la raíz porque el `~/.tmux.conf` de
cada servidor enlaza a esa ruta, y `Alt+h` encuentra el repo a partir de ella:
moverla rompería los servidores ya instalados.

| Fichero | Qué es |
|---|---|
| `../.tmux.conf` | La config, comentada. **La que editas** |
| `install.sh` | Lo que hace `./install tmux` |
| `uninstall.sh` | Lo que hace `./uninstall tmux` |

## Cómo está organizada `.tmux.conf`

| Sección | Qué hay |
|---|---|
| General | Ratón, historial (50 000 líneas), numerar desde 1, colores, avisos de foco (neovim relee lo que cambia fuera), zsh en los panes |
| Atajos | Lo común a todos (`escape-time`) |
| Día a día: Alt | Los atajos `Alt+tecla`, sin prefijo. También la barra de abajo (`status-left`), junto al modo redimensionar que la usa |
| Ocasional: prefijo Ctrl+B | Los que van después de `Ctrl+B` |

## Cambiar o añadir un atajo

```tmux
bind -n -N "Nueva window" M-t new-window    # Alt+t, sin prefijo
bind -N "Recargar configuración" R ...      # Ctrl+B y luego R
```

- `-n` es sin prefijo. `M-` es Alt; Alt+Shift es la letra en mayúscula (`M-T`)
  o, con flechas, `M-S-Left`.
- `-N "texto"` es la descripción que sale en `Ctrl+B ?`. Ponla siempre.
- No uses `Alt+b`, `Alt+f`, `Alt+d` ni `Alt+.`: la shell los usa para editar
  la línea.
- Apunta el cambio en [docs/CHEATSHEET.md](../docs/CHEATSHEET.md), y en
  [docs/GUIA.md](../docs/GUIA.md) si sale allí: es lo que abre `Alt+h`.
- Si un `Alt` no llega, lo intercepta tu terminal (Windows Terminal, GNOME
  Terminal…): [mira el CHEATSHEET](../docs/CHEATSHEET.md#si-un-atajo-alt-no-hace-nada).

## Probar y aplicar

Desde una terminal **fuera de tmux** (dentro, el tmux de fuera se queda los
`Alt` y `Ctrl+B`), en la raíz del repo:

```bash
tmux -L prueba -f "$PWD/.tmux.conf" new -s prueba   # tmux aparte: no toca tus sesiones
tmux -L prueba kill-server                          # al terminar
```

Con ruta absoluta: con una relativa, `Ctrl+B R` falla al cambiar de directorio.

Tras `./actualizar`, la config se aplica sola a los tmux abiertos, sin cerrar
sesiones; a mano, `Ctrl+B R`. Un atajo que **quites** sigue activo hasta
reiniciar tmux (`tmux kill-server`, que cierra todas las sesiones).

tmux no tiene fichero local: lo que pongas en `.tmux.conf` va a todos los
servidores.

## Lo que hace `./install tmux`

Se puede ejecutar tantas veces como se quiera:

1. Instala tmux (apt o dnf) si falta, o si es anterior a la 3.2; solo entonces
   usa sudo, y lo apunta en `~/.local/state/tmux-config/tmux.paquetes`. Si los
   repos no tienen la 3.2, no toca nada (`BLOQUEA` en el plan). Con
   `--actualizar`, también lo actualiza a la última versión de la distro. Lo
   hace `./install` tras enseñar el plan, con la tabla `tmux/paquetes`.
2. Comprueba que `.tmux.conf` carga sin errores con esa versión, en un servidor
   tmux aislado que no toca las sesiones en marcha. Si no carga, no enlaza nada.
3. Enlaza `~/.tmux.conf` a este repo. Si ya había una config, la guarda como
   `~/.tmux.conf.bak.<fecha>`; el plan lo dice antes y pide confirmación.
4. Enlaza `tmux-guia` en `~/.local/opt/tmux-config/bin`. `Alt+h` la abre por su
   ruta en el repo, sin depender del PATH.
5. Aplica la config a los tmux en marcha, **sin cerrar sesiones** (lo mismo que
   `Ctrl+B R`). Los que se lanzaron con otra config (`-f`) no los toca.

Si existe `/etc/tmux.conf`, el plan lo avisa: tmux lo carga antes que `~/.tmux.conf`.

## Lo que hace `./uninstall tmux`

Se ejecuta **fuera de tmux**. Enseña la lista y pide confirmación antes de:

1. Cerrar los servidores tmux de tu usuario, con todas sus sesiones.
2. Quitar `~/.tmux.conf` y `tmux-guia`, solo si son enlaces a este repo
   (también el `~/.local/bin/tmux-guia` de la versión anterior).
3. Desinstalar el paquete tmux, solo si lo instaló `./install tmux`. apt/dnf
   vuelve a confirmar y enseña qué más se quita.

El tmux que ya estaba se queda (Ubuntu Server lo trae de serie). También el
que instaló una versión del repo anterior a octubre de 2026, que no lo
apuntaba: no hay forma de saber si ya estaba. Lo dice y da el comando para
quitarlo a mano.
