# tmux-config

Configuración personal de tmux, igual en todos los servidores. Un único mapa de
atajos al estilo Kitty: `Alt+tecla` para el día a día y `Ctrl+B` para lo
ocasional. Está en [docs/CHEATSHEET.md](docs/CHEATSHEET.md).

Opcionalmente, zsh dentro de tmux con sugerencias, colores y búsqueda difusa en
el historial (ver [zsh](#zsh)), y neovim con aspecto y funciones de IDE: tema,
árbol de ficheros, buscador, LSP, autocompletado y git (ver
[vim y neovim](#vim-y-neovim)).

¿Primera vez? Lee la guía paso a paso [docs/GUIA.md](docs/GUIA.md). Una vez
instalado, se abre con `tmux-guia` desde la shell o con `Alt+h` dentro de tmux.

## Instalar / actualizar

Cada componente (`tmux`, `zsh`, `vim`) se instala y se quita por separado:

```bash
git clone <este-repo> ~/GitHub/personal/tmux-config
cd ~/GitHub/personal/tmux-config
./install tmux          # o: ./install tmux zsh
./install               # lista los componentes
```

`./install tmux` se puede ejecutar tantas veces como se quiera:

1. Instala tmux (apt o dnf) si falta. Solo en ese caso usa sudo. Con
   `./install tmux --actualizar` también lo actualiza a la última versión de la
   distro.
2. Comprueba que `.tmux.conf` carga sin errores con esa versión, en un servidor
   tmux aislado que no toca las sesiones en marcha.
3. Enlaza `~/.tmux.conf` a este repo. Si ya había una config, la guarda como
   `~/.tmux.conf.bak.<fecha>`.
4. Enlaza el comando `tmux-guia` en `~/.local/bin`.
5. Aplica la config a los tmux que ya estén en marcha, **sin cerrar sesiones**
   (lo mismo que `Ctrl+B R`). Los que se lanzaron con otra config (`-f`) no
   los toca.

Para traer cambios: `git pull && ./install tmux zsh` (los que tengas), y se
aplican solos a los tmux abiertos. Dentro de tmux, `Ctrl+B R` recarga la config.
Si se quita un atajo de la config, sigue activo hasta reiniciar tmux
(`tmux kill-server`, que sí cierra las sesiones).

## Desinstalar

```bash
./uninstall tmux
./uninstall zsh
./uninstall vim
```

`./uninstall tmux` se ejecuta **fuera de tmux**. Enseña la lista de lo que va a
hacer y pide confirmación antes de:

1. Cerrar los servidores tmux de tu usuario, con todas sus sesiones.
2. Quitar `~/.tmux.conf` y `~/.local/bin/tmux-guia`, solo si son enlaces a
   este repo.
3. Desinstalar el paquete tmux. apt/dnf vuelve a confirmar y enseña qué más se
   quita.

En Ubuntu Server, apt quita también el metapaquete `ubuntu-server`, porque
depende de tmux. El script lo avisa. Recupéralo tras `./install tmux` con
`sudo apt install ubuntu-server`.

## zsh

`./install zsh` pone zsh **solo en los panes de tmux**. No cambia la shell de
login: fuera de tmux, en `ssh host comando`, en los scripts, como root y para el
resto de usuarios todo sigue en bash. Instálalo solo en tu propia cuenta, no en
cuentas compartidas (`ubuntu`, `admin`, root).

Qué trae:

| Tecla | Qué hace |
|---|---|
| `→` o `Fin` | acepta la sugerencia en gris (sale de tu historial) |
| `Ctrl+→` | acepta una palabra de la sugerencia |
| `↑` / `↓` | historial filtrado por lo ya escrito (`git` + `↑` = último git) |
| `Ctrl+R` | buscar en el historial con fzf |
| `Ctrl+T` / `Alt+c` | insertar un fichero / cambiar de directorio con fzf |
| `Tab` | completar; repetido, menú con flechas |

- Colores mientras escribes: un comando que no existe sale en rojo.
- El historial se comparte entre panes, y un comando que empieza por espacio
  no se guarda (para tokens y contraseñas).
- Se comporta como bash al pegar: admite `# comentarios` y un `?` o `*` sin
  coincidencias se pasa tal cual.
- El prompt no usa iconos: se ve igual con Nerd Font o sin ella, desde
  cualquier terminal. La fuente es cosa del terminal local, no de los
  servidores.
- Lo propio de cada máquina (alias, variables, PATH) va en `~/.zshrc.local`.

Lo que hace `./install zsh` (también idempotente):

1. Instala `zsh`, `zsh-autosuggestions`, `zsh-syntax-highlighting` y `fzf` si
   faltan. En Rocky/RHEL los tres últimos solo están en EPEL: si no está
   activo, no lo activa por su cuenta; avisa y zsh funciona sin ellos.
2. Apunta en `~/.local/state/tmux-config/zsh.paquetes` qué paquetes ha
   instalado él.
3. Comprueba que `zsh/.zshrc` carga sin errores con esa versión de zsh.
4. Enlaza `~/.zshrc` a este repo (con backup `~/.zshrc.bak.<fecha>`).

Si tmux ya está en marcha, los panes nuevos arrancan en zsh directamente; los
que ya estaban abiertos siguen en su shell. Fuera de tmux todo queda como lo
trae la distro, a propósito: lo configurado vive dentro de tmux y es igual en
todos los servidores. Por eso ningún componente toca la config de bash.

`./uninstall zsh` quita el enlace, devuelve los panes nuevos de los tmux en
marcha a la shell de login y desinstala **solo los paquetes que instaló
`./install zsh`**. Los que ya estaban, no. Y zsh no se desinstala si es la
shell de login de algún usuario, porque entonces no podría entrar.

En imágenes mínimas de Debian/Ubuntu (Docker, cloud minimal) no se instala
`/usr/share/doc`, que es donde Debian deja los atajos de fzf para zsh. En ese
caso `Ctrl+R` es el de zsh, sin fzf, y `./install zsh` lo avisa.

## vim y neovim

`./install vim` deja **neovim como editor de trabajo, con aspecto y funciones de
IDE**, y vim clásico con una config base por si hace falta. Los dos comparten
los mismos atajos (Espacio e, Ctrl+P, Espacio g...): lo aprendido vale en los
dos. Mapa completo: `Espacio ?` dentro de neovim, o `Alt+h` en tmux.

**¿Nunca has usado vim?** Abre `nvim fichero`, pulsa `i` para escribir, `Esc`
para dejar de escribir, `Espacio w` guarda y `Espacio q` cierra. Pulsa `Espacio`
y espera: sale un menú con todo lo que puedes hacer. Para aprender en 30
minutos: `vimtutor es` (en español) o `:Tutor` dentro de neovim.

neovim trae:

| Qué | Cómo |
|---|---|
| Menú de atajos (which-key) | `Espacio` y esperar |
| Árbol de ficheros (crear, renombrar, copiar, borrar) | `Espacio e`; dentro, `g?` ayuda |
| Buscar fichero / texto en el proyecto | `Ctrl+P` / `Espacio g` |
| LSP: errores en vivo, ir a la definición, renombrar | bash (con shellcheck), Python, YAML, JSON, Dockerfile, Lua, Markdown |
| Autocompletado | sale solo; `Tab` acepta |
| Git en el margen | `]c` siguiente cambio, `Espacio vp` verlo |
| Tema tokyonight, barra de estado, guías de sangría, cierre de paréntesis | — |
| Copiar al portapapeles de tu PC, también por SSH | `Espacio y` |

- `nvim carpeta` abre el árbol en esa carpeta y trabaja en ella.
- Deshacer se conserva al cerrar el fichero, y al reabrirlo vuelve a la línea
  donde estabas. Al salir con cambios sin guardar, pregunta en vez de dar error.
- Sin iconos: se ve igual con cualquier fuente.
- Dentro de tmux (con `./install zsh`) es el **editor por defecto**: lo que
  abren `git commit`, `crontab -e`, `sudoedit`, `systemctl edit`... (variables
  `EDITOR` y `VISUAL`, que pone `.zshrc`). Fuera de tmux sigue el de la distro:
  nano (Debian/Ubuntu) o vi (Rocky). Con `sudo` (`sudo crontab -e`, `visudo`)
  también, porque sudo no pasa `EDITOR` y abrir tu neovim como root no es buena
  idea.
- Para ficheros del sistema, en tmux: `sudoedit /etc/fichero`. Edita una copia
  con tu config y la guarda con sudo, sin abrir el editor como root.
- Lo propio de cada máquina: `~/.config/nvim/local.lua` (neovim) y
  `~/.vimrc.local` (vim). Más servidores LSP en una máquina: `:Mason`.

Lo que hace `./install vim` (idempotente):

1. Instala con apt/dnf `vim` y lo que usa neovim: `git`, `curl`, `unzip`,
   `ripgrep`, `shellcheck`, `nodejs` y `npm`. Apunta los que instala él. En
   Rocky/RHEL ripgrep y shellcheck están en EPEL: sin EPEL avisa y sigue.
2. vim: comprueba que `vim/vimrc` carga sin errores y enlaza `~/.vimrc`.
3. Instala el **neovim oficial v0.12.5** en `~/.local/opt` (sin root), comprobando
   su sha256, y lo enlaza en `~/.local/bin/nvim`. Las distros traen de la 0.6 a
   la 0.10, demasiado antiguas para estos plugins. Hay build para x86_64 y arm64.
4. Descarga los plugins (cada uno fijado a un commit, en `nvim/lua/tc/plugins.lua`)
   y los servidores LSP en `~/.local/share/nvim/tmux-config`, comprueba que todo
   carga en su versión y enlaza `~/.config/nvim/init.lua` (con backup de la
   config anterior).
5. No toca la config de bash: neovim es el editor por defecto porque
   `zsh/.zshrc` lo pone si existe `~/.local/bin/nvim`. Sin `./install zsh` lo
   avisa. Para otro editor, `export EDITOR=...` en `~/.zshrc.local`. Si git
   tiene `core.editor`, también lo avisa: git lo usa antes que `EDITOR`.

La primera vez descarga unos cientos de MB (node, plugins, servidores LSP) y
tarda varios minutos; las siguientes no descarga nada. `./uninstall vim` quita
los enlaces, el neovim oficial, los plugins, los servidores y solo los paquetes
que instaló él.

Los servidores LSP de node (bash, Python, YAML, JSON, Dockerfile) necesitan
node 18 o superior: Debian 12/13 y Ubuntu 24.04 sí; en Ubuntu 22.04 (node 12)
quedan Lua y Markdown.

vim usa `vim/vimrc` con tres plugins que van dentro del repo, con versión fija
(`vim/pack/`, listados en `vim/plugins.txt`; para cambiarlos,
`vim/actualizar-plugins.sh`): NERDTree (árbol, menú con `m`), CtrlP (`Ctrl+P`)
y vim-commentary (`gcc`). Un neovim antiguo de la distro también usa esa config.

## Requisitos

tmux **3.2 o superior**: Ubuntu 22.04+, Debian 12+, RHEL/Rocky 9+.

Probado en contenedores limpios con Ubuntu 24.04 (3.4), Ubuntu 22.04 (3.2a),
Debian 12 (3.3a) y Rocky 9 (3.2a). En Ubuntu 20.04 (3.0a) y Debian 11 (3.1c) la
config no carga: `./install tmux` lo detecta y no enlaza nada.

neovim: el oficial v0.12.5, que instala `./install vim` (x86_64 o arm64). vim
**8.2 o superior** (probada la config base con vim 8.2, 9.0 y 9.1, y con los
neovim de las distros, 0.6 a 0.10).

zsh **5.8 o superior** (5.8.1 en Ubuntu 22.04, 5.9 en Ubuntu 24.04 y Debian 12,
5.8 en Rocky 9). Probado en los mismos contenedores, también con Rocky sin EPEL
y con imágenes mínimas.

## Probar cambios sin instalar

```bash
tmux -L prueba -f "$PWD/.tmux.conf" new -s prueba
ZDOTDIR="$PWD/zsh" zsh
nvim -u nvim/init.lua
vim -u vim/vimrc
```

## Archivos

| Archivo | Qué es |
|---|---|
| `.tmux.conf` | La configuración, comentada |
| `docs/CHEATSHEET.md` | El mapa de atajos |
| `docs/GUIA.md` | Guía de uso paso a paso |
| `bin/tmux-guia` | Abre el mapa y la guía en la terminal |
| `zsh/.zshrc` | La configuración de zsh, comentada |
| `nvim/init.lua`, `nvim/lua/tc/` | La configuración de neovim: opciones, atajos, plugins, LSP |
| `vim/vimrc` | La configuración de vim (y de un neovim antiguo), comentada |
| `vim/pack/`, `vim/plugins.txt` | Los plugins de vim, con su versión |
| `vim/actualizar-plugins.sh` | Vuelve a copiar los plugins de `vim/plugins.txt` |
| `install`, `uninstall` | Instalar / quitar componentes (`uninstall` es un enlace a `install`) |
| `tmux/`, `zsh/`, `vim/` | `install.sh` y `uninstall.sh` de cada componente |
| `lib/comun.sh` | Funciones compartidas por los scripts de los componentes |
