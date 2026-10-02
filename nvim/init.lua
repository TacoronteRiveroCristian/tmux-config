-- =============================================================================
-- neovim — configuración personal (neovim >= 0.11; ./install vim instala la 0.12.5)
--
-- ./install vim enlaza aquí ~/.config/nvim/init.lua. Los módulos están en
-- nvim/lua/tc/: opciones, atajos, plugins y servidores LSP.
-- Probar cambios sin instalar:  nvim -u nvim/init.lua
--
-- Tecla líder: Espacio (espera un momento y sale el menú de atajos).
-- Espacio ? abre el mapa completo. Lo propio de cada máquina: ~/.config/nvim/local.lua
-- =============================================================================

-- Directorio de este repo (init.lua es un enlace hasta aquí)
local este = vim.uv.fs_realpath(debug.getinfo(1, 'S').source:sub(2))
local repo = vim.fs.dirname(vim.fs.dirname(este))
vim.g.tc_repo = repo

-- Un neovim antiguo (el de la distro) usa la config de vim, que funciona en todos
if vim.fn.has('nvim-0.11') == 0 then
    vim.cmd.source(vim.fn.fnameescape(repo .. '/vim/vimrc'))
    return
end

vim.opt.runtimepath:prepend(repo .. '/nvim')

require('tc.opciones')
require('tc.atajos')
require('tc.plugins')

local local_lua = vim.fn.stdpath('config') .. '/local.lua'
if vim.uv.fs_stat(local_lua) then
    dofile(local_lua)
end
