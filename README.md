# tmux-config

Configuración personal de tmux, igual en todos los servidores. Un único mapa de
atajos al estilo Kitty: `Alt+tecla` para el día a día y `Ctrl+B` para lo
ocasional. Está en [docs/CHEATSHEET.md](docs/CHEATSHEET.md).

Opcionalmente, zsh dentro de tmux con sugerencias, colores y búsqueda difusa en
el historial (ver [zsh](#zsh)).

¿Primera vez? Lee la guía paso a paso [docs/GUIA.md](docs/GUIA.md). Una vez
instalado, se abre con `tmux-guia` desde la shell o con `Alt+h` dentro de tmux.

## Instalar / actualizar

Cada componente (`tmux`, `zsh`) se instala y se quita por separado:

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

Para traer cambios: `git pull && ./install tmux zsh` (los que tengas). Dentro de
tmux, `Ctrl+B R` recarga la config.

## Desinstalar

```bash
./uninstall tmux
./uninstall zsh
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

Tras instalarlo con tmux en marcha: `Ctrl+B R` y los panes nuevos arrancan en
zsh. Para usarlo también fuera de tmux, en tu propia máquina:
`chsh -s "$(command -v zsh)"`.

`./uninstall zsh` quita el enlace, devuelve los panes nuevos de los tmux en
marcha a la shell de login y desinstala **solo los paquetes que instaló
`./install zsh`**. Los que ya estaban, no. Y zsh no se desinstala si es la
shell de login de algún usuario, porque entonces no podría entrar.

En imágenes mínimas de Debian/Ubuntu (Docker, cloud minimal) no se instala
`/usr/share/doc`, que es donde Debian deja los atajos de fzf para zsh. En ese
caso `Ctrl+R` es el de zsh, sin fzf, y `./install zsh` lo avisa.

## Requisitos

tmux **3.2 o superior**: Ubuntu 22.04+, Debian 12+, RHEL/Rocky 9+.

Probado en contenedores limpios con Ubuntu 24.04 (3.4), Ubuntu 22.04 (3.2a),
Debian 12 (3.3a) y Rocky 9 (3.2a). En Ubuntu 20.04 (3.0a) y Debian 11 (3.1c) la
config no carga: `./install tmux` lo detecta y no enlaza nada.

zsh **5.8 o superior** (5.8.1 en Ubuntu 22.04, 5.9 en Ubuntu 24.04 y Debian 12,
5.8 en Rocky 9). Probado en los mismos contenedores, también con Rocky sin EPEL
y con imágenes mínimas.

## Probar cambios sin instalar

```bash
tmux -L prueba -f "$PWD/.tmux.conf" new -s prueba
ZDOTDIR="$PWD/zsh" zsh
```

## Archivos

| Archivo | Qué es |
|---|---|
| `.tmux.conf` | La configuración, comentada |
| `docs/CHEATSHEET.md` | El mapa de atajos |
| `docs/GUIA.md` | Guía de uso paso a paso |
| `bin/tmux-guia` | Abre el mapa y la guía en la terminal |
| `zsh/.zshrc` | La configuración de zsh, comentada |
| `install`, `uninstall` | Instalar / quitar componentes (`uninstall` es un enlace a `install`) |
| `tmux/`, `zsh/` | `install.sh` y `uninstall.sh` de cada componente |
| `lib/comun.sh` | Funciones compartidas por los scripts de los componentes |
