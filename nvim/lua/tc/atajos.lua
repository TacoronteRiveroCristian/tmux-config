-- Atajos generales. Los de cada plugin están en tc/plugins.lua, junto al plugin.
-- Cada atajo lleva descripción: es lo que enseña el menú de Espacio.

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local map = vim.keymap.set

map('n', '<leader>w', '<cmd>update<cr>', { desc = 'Guardar' })
map('n', '<leader>q', '<cmd>quit<cr>', { desc = 'Cerrar la ventana' })
map('n', '<leader>h', '<cmd>nohlsearch<cr>', { desc = 'Quitar el resaltado de la búsqueda' })
map({ 'n', 'v' }, '<leader>y', '"+y', { desc = 'Copiar al portapapeles (también por SSH)' })

-- Moverse entre divisiones (árbol y fichero)
map('n', '<C-h>', '<C-w>h', { desc = 'Ir a la ventana de la izquierda' })
map('n', '<C-j>', '<C-w>j', { desc = 'Ir a la ventana de abajo' })
map('n', '<C-k>', '<C-w>k', { desc = 'Ir a la ventana de arriba' })
map('n', '<C-l>', '<C-w>l', { desc = 'Ir a la ventana de la derecha' })

-- Indentar en modo visual sin perder la selección
map('v', '<', '<gv', { desc = 'Quitar sangría' })
map('v', '>', '>gv', { desc = 'Añadir sangría' })

-- El mapa de atajos del repo (docs/CHEATSHEET.md), en una división de solo lectura
map('n', '<leader>?', function()
    vim.cmd('botright split +/^##\\ En\\ neovim ' .. vim.fn.fnameescape(vim.g.tc_repo .. '/docs/CHEATSHEET.md'))
    vim.bo.readonly = true
    vim.bo.modifiable = false
end, { desc = 'Mapa de atajos' })

-- Errores del LSP
map('n', '<leader>cd', vim.diagnostic.open_float, { desc = 'Ver el error de esta línea' })
map('n', '<leader>cl', vim.diagnostic.setloclist, { desc = 'Lista de errores del fichero' })

-- Atajos de código, solo en ficheros con servidor LSP. Neovim ya trae K (info),
-- grn (renombrar), gra (acciones), grr (referencias) y ]d / [d (siguiente error).
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
        local function lsp(teclas, accion, desc)
            map('n', teclas, accion, { buffer = ev.buf, desc = desc })
        end
        lsp('gd', vim.lsp.buf.definition, 'Ir a la definición')
        lsp('<leader>ca', vim.lsp.buf.code_action, 'Acciones (arreglos rápidos)')
        lsp('<leader>cr', vim.lsp.buf.rename, 'Renombrar en todo el proyecto')
        lsp('<leader>cf', function() vim.lsp.buf.format({ async = true }) end, 'Formatear el fichero')
        lsp('<leader>ci', vim.lsp.buf.hover, 'Información de lo que hay bajo el cursor')
    end,
})
