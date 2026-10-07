# neovim

La config de neovim que instala `./install vim`. El instalador está en
[`../vim/`](../vim/): el componente se llama `vim` porque, dentro de tmux, `vi`
y `vim` abren este neovim. Fuera de tmux, `vi` sigue siendo el de la distro,
salvo con [`./install vim --global`](#también-fuera-de-tmux---global). vim
clásico no se instala.

| Fichero | Qué cambias ahí |
|---|---|
| `init.lua` | Nada: solo carga los módulos de abajo y tu `local.lua` |
| `lua/tc/opciones.lua` | Opciones: números de línea, sangría, ratón, búsqueda… |
| `lua/tc/atajos.lua` | Atajos generales: guardar, cerrar, copiar, los del LSP |
| `lua/tc/plugins.lua` | Los plugins, su configuración **y sus atajos** |
| `lua/tc/lsp.lua` | Qué lenguajes tienen servidor LSP |
| `lua/tc/instalar.lua` | Nada: lo usa `./install vim` |

## Qué trae

**¿Nunca has usado vim?** Abre `vi fichero`, pulsa `i` para escribir y `Esc`
para dejar de escribir. `Espacio w` guarda y `Espacio q` cierra. Pulsa
`Espacio` y espera: sale un menú con todo lo que puedes hacer. Para aprender en
30 minutos: `:Tutor` (en inglés).

Trae menú de atajos (which-key), árbol de ficheros, buscador de ficheros y de
texto, LSP (errores en vivo, ir a la definición, renombrar) para bash con
shellcheck, Python, YAML, JSON, Dockerfile, Lua y Markdown, autocompletado, git
en el margen, rodear texto con comillas o paréntesis (nvim-surround), markdown
con formato (render-markdown), copiar al portapapeles de tu PC también por SSH,
y el tema tokyonight con barra de estado y guías de sangría. Sin iconos: se ve
igual con cualquier fuente. Las teclas: `Espacio ?` dentro de neovim, o la
sección "En neovim" de [docs/CHEATSHEET.md](../docs/CHEATSHEET.md#en-neovim-si-instalaste-install-vim).

- `nvim carpeta` abre el árbol en esa carpeta y trabaja en ella.
- Si Claude (u otro programa, desde otro pane) cambia un fichero que tienes
  abierto, neovim lo relee solo; si tú también lo habías cambiado, pregunta.
- Deshacer se conserva al cerrar el fichero, y al reabrirlo vuelve a la línea
  donde estabas; salvo en `/tmp`, `/var/tmp` y `/dev/shm`, donde `sudoedit` deja
  la copia del fichero de root (su historial guardaría el contenido en tu HOME).
  Al salir con cambios sin guardar, pregunta en vez de dar error.
- Dentro de tmux (con `./install zsh`) es el **editor por defecto**: lo que
  abren `git commit`, `crontab -e`, `sudoedit`, `systemctl edit`… Fuera de
  tmux sigue el de la distro, nano (Debian/Ubuntu) o vi (Rocky), salvo con
  `--global`. Con `sudo`
  (`sudo crontab -e`, `visudo`), también el de la distro, porque sudo no pasa
  `EDITOR` y abrir tu neovim como root no es buena idea. Para ficheros del sistema:
  `sudoedit /etc/fichero`, que edita una copia con tu config y la guarda con sudo.
- `:terminal` y `:!` usan el zsh de los panes.
- Su config va aparte (`NVIM_APPNAME=tmux-config-nvim`): si tienes tu propio
  `~/.config/nvim`, no se mezclan.

## Cambiar cosas

**Una opción**, en `opciones.lua`. Por ejemplo, `o.relativenumber = true`
(números de línea relativos). La sangría (4 espacios; 2 en YAML, JSON…) está
en el mismo fichero: `shiftwidth`, `softtabstop` y el `FileType`.

**Un atajo general**, en `atajos.lua`:

```lua
map('n', '<leader>x', '<cmd>comando<cr>', { desc = 'Qué hace' })
```

`<leader>` es Espacio. Ponle siempre `desc`: es lo que sale en el menú de
Espacio. Los atajos de código van dentro del `LspAttach`, para que solo existan
en ficheros con LSP.

**Un atajo de un plugin**, en `plugins.lua`, junto a ese plugin: en su
`keys = { … }` el árbol (nvim-tree) y el buscador (telescope); los de git, en
el `on_attach` de gitsigns.

**Un plugin nuevo**, en `plugins.lua`, fijado a un commit (la versión probada):

```lua
{ 'autor/plugin.nvim', commit = '<sha completo, 40 caracteres>', opts = {} },
```

`./install vim` comprueba que cada plugin está justo en ese commit: con un sha
corto, falla. Nada se actualiza solo: para cambiar la versión de un plugin,
cambia su `commit` y ejecuta `./install vim`.

**Un lenguaje**: añade su servidor a `M.servidores` en `lsp.lua`, con su nombre
en nvim-lspconfig y en mason (`:Mason` los lista), y `node = true` si lo
necesita. `./install vim` lo instala.

**Las versiones de los servidores LSP** salen del registro de mason fijado en
`plugins.lua` (`registries`, una etiqueta de
[mason-registry](https://github.com/mason-org/mason-registry/releases)): son las
mismas en todas las máquinas. Para subirlas, cambia la etiqueta y ejecuta
`./install vim`, que deja cada servidor en la versión de ese registro.

Si cambias un atajo, apúntalo en la sección "En neovim" de
[docs/CHEATSHEET.md](../docs/CHEATSHEET.md): es lo que abre `Espacio ?`. Con
los de `Espacio`, `tests/atajos.sh` (y la CI) avisa si se te olvida.

## Solo en esta máquina

- `~/.config/tmux-config-nvim/local.lua`: se carga al final y no está en el
  repo. Lua normal: opciones, atajos, lo que quieras. Ahí no existen los
  nombres cortos `o` y `map` de los módulos: escribe `vim.opt.relativenumber = true` y
  `vim.keymap.set(...)`.
- `:Mason` instala más servidores LSP solo en esa máquina (`i` instala, `X`
  desinstala).

## Probar y aplicar

Dentro de un pane de tmux (fuera, `nvim` no es el del repo), en la raíz del repo:

```bash
NVIM_APPNAME=tmux-config-nvim nvim -u nvim/init.lua
```

Usa los plugins ya instalados; uno nuevo lo descarga al abrir. Un cambio de
`commit`, no: ese necesita `./install vim`.

Tras `./actualizar` (que vuelve a pasar `./install vim` y descarga los plugins
y servidores que falten), cierra y vuelve a abrir neovim.

## Lo que hace `./install vim`

Se puede ejecutar tantas veces como se quiera:

1. Instala con apt/dnf lo que usa neovim: `git`, `curl`, `unzip`, `ripgrep`,
   `shellcheck`, `nodejs` y `npm` (tabla `vim/paquetes`; lo hace `./install`
   tras enseñar el plan). Apunta los que instala él. En Rocky/RHEL, ripgrep y
   shellcheck están en EPEL: sin EPEL el plan dice qué se pierde y sigue.
   nodejs y npm, solo si los repos ofrecen node 18 o superior (o ya lo tienes).
2. Instala el **neovim oficial v0.12.5** en `~/.local/opt/tmux-config` (sin
   root), comprobando su sha256, y enlaza `nvim`, `vi`, `vim`, `view` y
   `vimdiff` en `~/.local/opt/tmux-config/bin`. Las distros traen de la 0.6 a
   la 0.10, demasiado antiguas para estos plugins. Hay build para x86_64 y arm64.
3. Descarga los plugins y los servidores LSP en `~/.local/share/tmux-config-nvim`,
   cada uno en su versión fijada (un servidor que ya estaba en otra, lo cambia),
   comprueba que todo carga y enlaza `~/.config/tmux-config-nvim/init.lua`.
4. No toca la config de bash: neovim es el editor por defecto porque
   `zsh/.zshrc` lo pone. Sin `./install zsh`, lo avisa. Para otro editor,
   `export EDITOR=...` en `~/.zshrc.local`. Si git tiene un `core.editor` que no
   es vi ni vim, el plan lo avisa: git lo usa antes que `EDITOR`.

La primera vez descarga unos cientos de MB (node, plugins, servidores LSP) y
tarda varios minutos; las siguientes no descarga nada, salvo lo que cambie de
versión (el commit de un plugin o el registro de mason).

Los servidores LSP de node (bash, Python, YAML, JSON, Dockerfile) necesitan
node 18 o superior: Debian 12/13 y Ubuntu 24.04 sí. Ubuntu 22.04 trae el 12 y
Rocky 9 por defecto el 16: `./install vim` no instala ni nodejs ni npm (solo
serían peso), quedan Lua y Markdown, y el plan sugiere el arreglo: en Ubuntu,
el repo de NodeSource (`curl -fsSL https://deb.nodesource.com/setup_22.x |
sudo -E bash - && ./install vim`); en Rocky, `sudo dnf module enable nodejs:20
&& ./install vim`.

En un Debian/Ubuntu sin python3 (imágenes mínimas), el `npm` de la distro lo
necesita, y con él llega `/etc/inputrc`, que cambia algunas teclas de bash. Los
servidores normales ya traen python3.

## También fuera de tmux: `--global`

```bash
./install vim --global      # nvim, vi, vim y EDITOR también fuera de tmux
./install vim --solo-tmux   # volver a solo dentro de tmux
```

La primera vez, con terminal, `./install vim` lo pregunta; luego se queda
apuntado (`~/.local/state/tmux-config/vim.global`) y `./actualizar` lo mantiene.
Con `--global`, un bloque al final de `~/.bashrc`, entre
`# >>> tmux-config >>>` y `# <<< tmux-config <<<`, pone en bash interactivo el PATH
con `nvim`, `vi`, `vim`, `view` y `vimdiff`, `NVIM_APPNAME` y `EDITOR`/`VISUAL`.
Si zsh también es global, `.zshrc` hace lo mismo en el zsh de fuera. `ssh host
comando` y los scripts no lo ven, y se nota en las sesiones nuevas.

`--solo-tmux` y `./uninstall vim` quitan el bloque y dejan `~/.bashrc` byte a
byte como estaba. Si `~/.bashrc` es un enlace (un gestor de dotfiles), no se
toca y lo avisa; también si el bloque está tocado a mano (sin una de esas dos
líneas, o repetido): lo de debajo nunca se pierde.

## Lo que hace `./uninstall vim`

Quita los enlaces, el neovim oficial, los plugins, los servidores, el bloque de
`~/.bashrc` (con `--global`) y solo los paquetes que instaló él. Tu `local.lua`
y el historial de deshacer se quedan.
