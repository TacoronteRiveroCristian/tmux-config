# tests

`tests/run` prueba el repo **con los cambios sin commit** en contenedores Docker
que imitan las máquinas donde se usa, con el clon en
`~/GitHub/personal/tmux-config`.

```bash
tests/run                  # todos, en paralelo
tests/run pi-trixie        # solo uno
tests/run -l               # la lista
```

| Perfil | Qué imita |
|---|---|
| `pi-trixie` | La Raspberry Pi de verdad: Raspberry Pi OS trixie arm64, con el repo de Raspberry Pi, nodejs de NodeSource y la clave caducada de `gh`. Instala lo publicado y actualiza con `git pull && ./actualizar` |
| `pi-bookworm` | Raspberry Pi OS bookworm arm64, instalación nueva |
| `ubuntu-server` | Ubuntu Server 24.04, con tmux, vim y bash-completion de serie (uninstall debe respetarlos) |
| `ubuntu-2204` | Ubuntu 22.04 (node 12, sin tealdeer), en español: apt cambia su salida |
| `migracion` | La versión que enlazaba `~/.zshrc`, y `git pull && ./actualizar` |
| `actualizar` | `./actualizar` con cambios de verdad en upstream, un paquete nuevo en la tabla, y con terminal la pregunta `[S/n]` y la de solo tmux o también fuera |

En cada máquina comprueba que `./install --check` no toca nada, que sin
terminal y sin `-y` no instala, que un paquete tuyo que choca con uno del repo
para el plan (`BLOQUEA`) y no se quita, que install y actualizar terminan bien
(y que repetir no pide sudo), que un pane nuevo de tmux arranca zsh con `vim` =
el neovim del repo y `z`, que fuera de tmux no hay nada del repo, que un `.py`
sale con resaltado y pyright, que los servidores LSP están en la versión del
registro de mason fijado (y que uno en otra versión vuelve a ella), que
`sudoedit` no deja en el HOME el historial de deshacer de la copia, que `tldr`
funciona, que bash no se toca, que `--global` deja zsh de shell de login y
neovim en `~/.bashrc` (fuera de tmux, igual que dentro; `ssh host comando`, sin
ruido; `./actualizar` lo mantiene) y `--solo-tmux` lo deja todo como estaba, y
que uninstall no deja restos, deshace `--global`, respeta lo que ya estaba y no
cierra un tmux abierto.

Necesita Docker y red. En x86 las Raspberry van emuladas
(`docker run --privileged --rm tonistiigi/binfmt --install arm64`); si no se
puede, se saltan. Los logs quedan en `tests/logs/`.

GitHub Actions las pasa en cada push (`.github/workflows/tests.yml`), las
Raspberry en un runner arm64 nativo.

`tests/bashrc.sh` comprueba, sin Docker y en un segundo, el bloque que pone
`./install vim --global` al final de `~/.bashrc`: que quitarlo lo deje byte a
byte como estaba (sin salto de línea al final, vacío, sin existir, con lo que
se añadió detrás, con sus permisos), que no se repita, que el de una versión
anterior se cambie y que uno tocado a mano no se toque. También lo pasa la CI.

`tests/atajos.sh` comprueba, sin Docker y en un segundo, que los atajos
`Espacio`+tecla de neovim son los mismos en `nvim/lua` y en la sección "En
neovim" de [docs/CHEATSHEET.md](../docs/CHEATSHEET.md): avisa de los que faltan
en el mapa y de los que el mapa cita y ya no existen. También lo pasa la CI.

**Cuándo ejecutarlas a mano:** al tocar los instaladores (`install`,
`actualizar`, `*/install.sh`, `*/uninstall.sh`, `lib/`). Para un cambio de config basta con
probarla sin instalar (ver el [README](../README.md#el-flujo)) y dejar que la CI
haga el resto.
