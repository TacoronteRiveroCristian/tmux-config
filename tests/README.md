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
| `ubuntu-2204` | Ubuntu 22.04 (node 12, sin tealdeer) |
| `migracion` | La versión que enlazaba `~/.zshrc`, y `git pull && ./actualizar` |
| `actualizar` | `./actualizar` con cambios de verdad en upstream |

En cada máquina comprueba que install y actualizar terminan bien, que un pane
nuevo de tmux arranca zsh con `vim` = el neovim del repo y `z`, que fuera de
tmux no hay nada del repo, que un `.py` sale con resaltado y pyright, que `tldr`
funciona, que bash no se toca, y que uninstall no deja restos y respeta lo que
ya estaba.

Necesita Docker y red. En x86 las Raspberry van emuladas
(`docker run --privileged --rm tonistiigi/binfmt --install arm64`); si no se
puede, se saltan. Los logs quedan en `tests/logs/`.

GitHub Actions las pasa en cada push (`.github/workflows/tests.yml`), las
Raspberry en un runner arm64 nativo.

**Cuándo ejecutarlas a mano:** al tocar los instaladores (`install`,
`actualizar`, `*/install.sh`, `*/uninstall.sh`, `lib/`). Para un cambio de config basta con
probarla sin instalar (ver el [README](../README.md#el-flujo)) y dejar que la CI
haga el resto.
