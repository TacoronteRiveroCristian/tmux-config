# tmux-config

Mi entorno de terminal, igual en todos los servidores: tmux con un único mapa de
atajos al estilo Kitty (`Alt+tecla` para el día a día, `Ctrl+B` para lo
ocasional) y, si quieres, zsh con sugerencias y búsqueda en el historial, y
neovim con aspecto de IDE.

Todo vive **solo dentro de tmux**. Fuera, el servidor queda como lo trae la
distro: bash y su config no se tocan, `vi` es el de siempre, en el PATH no
aparece nada nuevo y la shell de login no cambia (nada de `chsh`).

¿Primera vez con tmux? [docs/GUIA.md](docs/GUIA.md) lo explica paso a paso, y
[docs/CHEATSHEET.md](docs/CHEATSHEET.md) es el mapa de atajos. Dentro de tmux,
los dos se abren con `Alt+h`.

## Cómo funciona

1. `./install` enlaza la config del repo donde la buscan los programas. Son
   enlaces: editar un fichero del repo es editar la config de esa máquina.
2. `~/.tmux.conf` es la única puerta. Con `./install zsh`, tmux arranca los
   panes en zsh con la config del repo (`ZDOTDIR`), sin tocar `~/.zshrc`.
3. Ese zsh pone en el PATH los comandos del repo (`nvim`, `vi`, `vim`,
   `tmux-guia`) y neovim como editor, con su config aparte (`NVIM_APPNAME`).
4. Fuera de tmux no llega nada de eso: ni el PATH, ni zsh, ni neovim.
5. `./actualizar` es `git pull` y `./install` de lo que tengas instalado.
   Cada `./install` apunta en `~/.local/state/tmux-config/` qué paquetes puso
   él, para que `./uninstall` quite solo esos.

## Estructura del proyecto

| Ruta | Qué es | ¿La editas? |
|---|---|---|
| [`.tmux.conf`](.tmux.conf) | Config de tmux. Está en la raíz porque el `~/.tmux.conf` de cada servidor enlaza aquí; se explica en [`tmux/`](tmux/README.md) | Sí |
| [`zsh/`](zsh/README.md) | Config de zsh (`.zshrc`) y su instalador | Sí, el `.zshrc` |
| [`nvim/`](nvim/README.md) | Config de neovim: opciones, atajos, plugins y LSP | Sí |
| [`docs/`](docs/) | `GUIA.md` (tmux paso a paso) y `CHEATSHEET.md` (mapa de atajos): lo que abren `Alt+h` y `Espacio ?` | Si cambias atajos |
| [`tmux/`](tmux/README.md) | Instalador y desinstalador de tmux | No |
| [`vim/`](vim/README.md) | Instalador y desinstalador de neovim (el componente se llama `vim`; su config está en `nvim/`) | No |
| [`bin/`](bin/) | `tmux-guia` (abre la guía); `view` y `vimdiff`, neovim en solo lectura y comparando (nvim no lo deduce del nombre) | No |
| [`lib/`](lib/comun.sh) | `comun.sh`: lo común a los instaladores (enlaces con backup, estado, avisos, recargar tmux); `paquetes.sh`: el plan de paquetes, a partir de la tabla `paquetes` de cada componente | No |
| [`tests/`](tests/README.md) | Pruebas en Docker que imitan los servidores | Si cambias instaladores |
| [`.github/`](.github/workflows/tests.yml) | CI: pasa esas pruebas en cada push | No |
| `install`, `uninstall`, `actualizar` | Los comandos de [Empezar](#empezar) (`uninstall` es un enlace a `install`) | No |

## Empezar

```bash
git clone https://github.com/TacoronteRiveroCristian/tmux-config.git ~/GitHub/personal/tmux-config
cd ~/GitHub/personal/tmux-config
./install --check tmux zsh vim   # opcional: el plan, sin tocar nada ni usar sudo
./install tmux zsh vim           # o solo los que quieras; ./install sin nada los lista
tmux new -A -s trabajo
```

| Componente | Qué pone | Detalles |
|---|---|---|
| `tmux` | tmux y su config | [tmux/](tmux/README.md) |
| `zsh` | zsh en los panes, con sugerencias, fzf, zoxide y tldr | [zsh/](zsh/README.md) |
| `vim` | neovim 0.12.5 con árbol de ficheros, buscador, LSP y git; también al escribir `vi` o `vim` | [nvim/](nvim/README.md) |

- `./install` enseña primero el plan: lo que ya está, los paquetes que
  instalaría (con cuántos entran contando sus dependencias), las configs tuyas
  que apartaría como `*.bak.<fecha>`, lo que los repos no dan y qué se pierde
  sin ello, con el arreglo sugerido (nunca añade repos por su cuenta). Para
  saber qué dan los repos, si va a instalar algo, antes pone al día los índices
  de apt (`apt-get update`, con sudo; no instala nada). Si va a instalar o
  apartar algo pregunta `[S/n]`; si algo imprescindible falta, o apt tendría
  que quitar un paquete que ya tienes porque choca con uno de estos
  (`BLOQUEA`), no toca nada. Al final, un resumen de lo que quedó sin instalar
  y los avisos.
- `--check` se queda en el plan: ni sudo ni cambios. `-y` sigue sin preguntar;
  sin terminal (scripts, cron) hace falta, o no instala nada.
- `./install` se puede repetir: instala lo que falte (sudo solo entonces) y
  salta lo que ya está. Con `--actualizar`, además actualiza los paquetes.
  Los paquetes de cada componente están en su tabla (`tmux/paquetes`,
  `zsh/paquetes`, `vim/paquetes`), con la versión mínima y qué se pierde sin
  cada uno.
- `./actualizar` trae los cambios del repo (`git pull`) y vuelve a pasar
  `./install` por los componentes que tengas, así que no hace falta saber qué
  cambió. Con `--actualizar`, también los paquetes; con `-y`, sin preguntar si
  el pull trae un paquete nuevo. Si hay cambios locales que chocan con el
  pull, no instala nada.
- `./uninstall <componente>` enseña lo que va a hacer y pide confirmación.
  Solo quita los paquetes que instaló él; los que ya estaban, no.
- Los paquetes de apt/dnf son de todo el sistema. Con apt se instalan sin
  recomendados; con dnf entran sus dependencias débiles, como siempre en Rocky.

## Personalizar

| Quiero cambiar… | Fichero |
|---|---|
| Atajos de tmux, barra de abajo, ratón | [`.tmux.conf`](.tmux.conf) → [cómo](tmux/README.md#cambiar-o-añadir-un-atajo) |
| Alias, teclas de la shell, prompt, variables | [`zsh/.zshrc`](zsh/.zshrc) → [cómo](zsh/README.md#cómo-está-organizado-zshrc) |
| Opciones de neovim (sangría, números…) | [`nvim/lua/tc/opciones.lua`](nvim/lua/tc/opciones.lua) |
| Atajos generales de neovim | [`nvim/lua/tc/atajos.lua`](nvim/lua/tc/atajos.lua) |
| Plugins de neovim y **sus** atajos (árbol, buscador, git) | [`nvim/lua/tc/plugins.lua`](nvim/lua/tc/plugins.lua) |
| Lenguajes con LSP | [`nvim/lua/tc/lsp.lua`](nvim/lua/tc/lsp.lua) → [cómo](nvim/README.md#cambiar-cosas) |
| El mapa que abren `Alt+h` y `Espacio ?` | [`docs/CHEATSHEET.md`](docs/CHEATSHEET.md): si cambias un atajo, cámbialo aquí también |

**Para todos los servidores**, edita esos ficheros. **Solo para una máquina**
(tokens, rutas, alias de ese servidor), usa los ficheros locales, que están
fuera del repo y no los toca ningún script:

| | Fichero local |
|---|---|
| zsh | `~/.zshrc.local` |
| neovim | `~/.config/tmux-config-nvim/local.lua` |
| tmux | No tiene: todo lo de `.tmux.conf` va a todos |

El repo es **público**: un secreto nunca va en el repo, siempre en un fichero local.

### El flujo

1. Edita en tu clon de trabajo, no en un servidor. En los servidores, la config
   es un enlace al repo: si la cambias ahí sin commit, el cambio no llega a los
   demás y `./actualizar` falla en cuanto el repo traiga cambios a ese fichero.
2. Prueba sin instalar, desde la raíz del repo:
   ```bash
   ZDOTDIR="$PWD/zsh" zsh                               # zsh (exit para volver)
   tmux -L prueba -f "$PWD/.tmux.conf" new -s prueba    # tmux, desde una terminal FUERA de tmux
   NVIM_APPNAME=tmux-config-nvim nvim -u nvim/init.lua  # neovim, DENTRO de un pane de tmux
   ```
   tmux, fuera: dentro, el tmux de fuera se queda los `Alt` y `Ctrl+B`.
   neovim, dentro: fuera, `nvim` no es el del repo (o no existe). Si tu clon
   de trabajo es también el instalado en esa máquina, zsh y neovim ya usan el
   cambio en un pane nuevo.
3. Commit y push. GitHub Actions instala todo en contenedores limpios
   ([tests/](tests/README.md)): espera a que salga en verde.
4. En cada servidor: `./actualizar`. El `git pull` cambia los ficheros
   enlazados antes de que `./install` compruebe nada: si la config está rota,
   zsh y neovim la cargan igual. Por eso los pasos 2 y 3.

Tras `./actualizar`, tmux se recarga solo; zsh lo coge en los panes nuevos (o
con `exec zsh`) y neovim al volver a abrirlo.

## Dónde queda cada cosa en el servidor

Lo que pone `./install` en cada máquina. Salvo `~/.tmux.conf`, todo está donde
solo lo usa lo que arranca dentro de tmux:

| Qué | Dónde |
|---|---|
| Config de tmux | `~/.tmux.conf` → repo |
| Config de zsh | `~/.local/opt/tmux-config/zsh/.zshrc` → repo (los panes arrancan zsh con `ZDOTDIR` ahí) |
| Config de neovim | `~/.config/tmux-config-nvim/init.lua` → repo (`NVIM_APPNAME=tmux-config-nvim`) |
| `nvim`, `vi`, `vim`, `view`, `vimdiff`, `tmux-guia` | `~/.local/opt/tmux-config/bin`: en el PATH solo en los panes |
| neovim oficial | `~/.local/opt/tmux-config/nvim-v0.12.5` |
| Plugins y servidores LSP de neovim | `~/.local/share/tmux-config-nvim` |
| Historial | `~/.zsh_history`; deshacer de neovim en `~/.local/state/tmux-config-nvim` |
| Qué paquetes instaló cada componente | `~/.local/state/tmux-config/` |

`~/.zshrc`, `~/.vimrc` y `~/.config/nvim` no se tocan: siguen siendo tuyos.

## Requisitos

- tmux **3.2 o superior**: Ubuntu 22.04+, Debian 12+, RHEL/Rocky 9+. En Ubuntu
  20.04 (3.0a) y Debian 11 (3.1c) la config no carga: `./install tmux` lo
  detecta y no enlaza nada.
- zsh **5.8 o superior**.
- neovim: el oficial v0.12.5, que instala `./install vim` (x86_64 o arm64).

Probado en contenedores limpios con Ubuntu 24.04 (tmux 3.4, zsh 5.9), Ubuntu
22.04 (3.2a, 5.8.1), Debian 12 (3.3a, 5.9) y Rocky 9 (3.2a, 5.8; también sin
EPEL), e imágenes mínimas. La CI repite en cada push Ubuntu 24.04 y 22.04,
Debian trixie y Raspberry Pi OS (trixie y bookworm); Rocky no está en la CI.

## Desde la versión anterior

La que enlazaba `~/.zshrc`, `~/.vimrc`, `~/.config/nvim` y `~/.local/bin`:
`git pull && ./actualizar` (el pull trae `./actualizar`, que aún no existía).
Cada componente quita sus enlaces viejos, devuelve a su sitio tus configs de
antes (si hay un único backup `.bak.<fecha>`; con varios, los lista y no elige)
y pasa `~/.config/nvim/local.lua` a `~/.config/tmux-config-nvim/`. El paquete
vim que instalaba aquella versión no se quita solo, ni el bash-completion que
traía como recomendado (cambia el Tab de bash): lo avisa con el comando para
hacerlo. En los panes ya abiertos `EDITOR` apunta al neovim viejo: abre uno
nuevo.
