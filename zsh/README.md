# zsh

zsh para los panes de tmux. Por defecto, solo para ellos: la shell de login no
cambia, y fuera de tmux, en `ssh host comando`, en los scripts, como root y para
el resto de usuarios todo sigue en bash. Con `./install zsh --global`, también
fuera: [abajo](#también-fuera-de-tmux---global). Instálalo en tu cuenta, no en
cuentas compartidas (`ubuntu`, `admin`, root).

| Fichero | Qué es |
|---|---|
| `.zshrc` | Toda la config: alias, teclas, prompt, plugins. **El que editas** |
| `zshenv` | Con `--global`, `~/.zshenv` enlaza aquí: lleva al zsh de fuera de tmux a `.zshrc` |
| `install.sh` | Lo que hace `./install zsh` |
| `uninstall.sh` | Lo que hace `./uninstall zsh` |

## Qué trae

Sugerencias en gris según tu historial, búsqueda en el historial con fzf, saltar
a una carpeta por parte de su nombre (`z tmux`), ejemplos de uso de un comando
(`tldr tar`) y menú de completado con Tab. Las teclas están en la sección "En
zsh" de [docs/CHEATSHEET.md](../docs/CHEATSHEET.md#en-zsh-si-instalaste-install-zsh).

- Colores mientras escribes: un comando que no existe sale en rojo.
- El historial se comparte entre panes, y un comando que empieza por espacio
  no se guarda (para tokens y contraseñas).
- Se comporta como bash al pegar: admite `# comentarios`, y un `?` o `*` sin
  coincidencias se pasa tal cual.
- Alias de Ubuntu: `ll`, `la`, y `ls` y `grep` con colores.
- Prompt sin iconos: se ve igual con Nerd Font o sin ella, desde cualquier
  terminal. La fuente es cosa del terminal de tu PC, no de los servidores.
- Dentro de tmux pone neovim como editor (`EDITOR`, `VISUAL`), si está
  `./install vim`. Fuera de tmux (con zsh global), solo si vim también es
  global (`./install vim --global`).

## Cómo está organizado `.zshrc`

Por secciones. El orden importa:

| Sección | Qué va ahí |
|---|---|
| Historial | Tamaño, compartirlo entre panes |
| Comportamiento de bash al pegar | Opciones (`setopt`) |
| Teclado | Teclas de edición de la línea (`bindkey`) |
| Completado | Cómo se comporta Tab (`zstyle`) |
| Prompt | El `PROMPT` |
| Alias y colores | Los `alias`, el PATH y el editor |
| Plugins | fzf, zoxide, sugerencias y colores, si están instalados |
| Local | Carga `~/.zshrc.local` |

- Un alias nuevo va en "Alias y colores".
- Una tecla nueva va en "Teclado". Para ver qué envía una tecla, ejecuta `cat -v`
  y púlsala.
- Para cambiar una tecla de fzf (`Ctrl+R`, `Ctrl+T`, `Alt+c`), ponla en
  "Plugins", **después** de cargar fzf: si va antes, fzf la pisa.
- `zsh-syntax-highlighting` tiene que ser lo último que se carga (solo
  `~/.zshrc.local` va detrás).

## Solo en esta máquina: `~/.zshrc.local`

Se carga al final, no está en el repo y no lo toca ningún script. Es para lo que
solo vale en un servidor: tokens, rutas, alias de ese servidor. El repo es
público, así que un secreto nunca va en `.zshrc`. Al cargarse el último, puede
cambiar cualquier cosa del `.zshrc` (por ejemplo, `export EDITOR=nano`).

## Probar y aplicar

```bash
ZDOTDIR="$PWD/zsh" zsh    # desde la raíz del repo; exit para volver
```

Usa tu historial de verdad (`~/.zsh_history`).

Tras `./actualizar`, los panes nuevos cargan la config. En uno ya abierto:
`exec zsh`.

## Lo que hace `./install zsh`

Se puede ejecutar tantas veces como se quiera:

1. Instala `zsh`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `fzf`,
   `zoxide` y `tealdeer` (el comando `tldr`) si faltan (tabla `zsh/paquetes`;
   lo hace `./install` tras enseñar el plan), y descarga las páginas de `tldr`.
   Lo que no está en los repos activos se salta, y el plan dice qué se pierde
   sin cada uno: en Rocky/RHEL casi todo viene de EPEL (no lo activa por su
   cuenta) y `tealdeer` no está en Ubuntu 22.04. zsh funciona sin ellos; sin
   zsh 5.8 o superior, no se instala nada.
2. Apunta en `~/.local/state/tmux-config/zsh.paquetes` qué paquetes ha
   instalado él.
3. Comprueba que `.zshrc` carga sin errores con esa versión de zsh. Si no, no
   enlaza nada.
4. Enlaza `~/.local/opt/tmux-config/zsh/.zshrc` a este repo: los panes de tmux
   arrancan zsh con `ZDOTDIR` en ese directorio. `~/.zshrc` no se toca, así que
   `zsh` tecleado fuera de tmux carga el tuyo (o ninguno), no el del repo.

Si tmux ya está en marcha, los panes nuevos arrancan en zsh directamente; los
que ya estaban abiertos siguen en su shell.

## También fuera de tmux: `--global`

```bash
./install zsh --global      # zsh también al entrar por SSH, como shell de login
./install zsh --solo-tmux   # volver a solo los panes de tmux
```

La primera vez, con terminal, `./install zsh` lo pregunta; luego se queda
apuntado y `./actualizar` lo mantiene. Con `--global`:

1. `~/.zshenv` enlaza a `zsh/zshenv`, que pone `ZDOTDIR` donde está `.zshrc`:
   el zsh de fuera carga la misma config que los panes. Si ya tenías un
   `~/.zshenv`, se aparta como `~/.zshenv.bak.<fecha>`, y tu `~/.zshrc` deja de
   leerse (lo de esa máquina, en `~/.zshrc.local`).
2. Tu shell de login pasa a ser zsh (`sudo usermod -s`; tiene que estar en
   `/etc/shells`). La de antes queda en `~/.local/state/tmux-config/zsh.global`.
   Se nota en las sesiones nuevas.
3. Al entrar, `zsh/zshenv` carga también lo que bash lee al entrar y el zsh de
   Debian, Ubuntu y Raspberry Pi OS no: `/etc/profile`, `/etc/profile.d` y
   `~/.profile` (PATH, proxies, locale), como `sh`.
4. `ssh host comando` se ejecuta con `zsh -c`: casi todo lo de bash funciona,
   pero algún bash-ismo en esa línea (`shopt`, `read -p`) puede fallar. Los
   scripts con `#!/bin/bash`, root y los demás usuarios, igual que siempre.

`--solo-tmux` y `./uninstall zsh` lo deshacen: vuelve tu shell de antes y tu
`~/.zshenv`. Para volver a bash, usa `--solo-tmux` y no `chsh`: con zsh global
apuntado, el siguiente `./actualizar -y` volvería a poner zsh. Para neovim, vi y vim fuera de tmux: `./install vim --global`
([nvim/](../nvim/README.md#también-fuera-de-tmux---global)).

En imágenes mínimas de Debian/Ubuntu (Docker, cloud minimal) no se instala
`/usr/share/doc`, que es donde Debian deja los atajos de fzf para zsh. En ese
caso `Ctrl+R` es el de zsh, sin fzf, y `./install zsh` lo avisa.

## Lo que hace `./uninstall zsh`

Con `--global`, primero te devuelve tu shell de login de antes y quita
`~/.zshenv`. Luego quita el enlace (y el `~/.zshrc` enlazado de la versión
anterior), devuelve los panes nuevos de los tmux en marcha a la shell de login
y desinstala **solo los paquetes que instaló `./install zsh`**. zsh se queda si es la shell de login de
algún usuario, porque sin ella no podría entrar. Si quita `tealdeer`, borra
también sus páginas. El historial y las carpetas que aprendió zoxide se quedan.
