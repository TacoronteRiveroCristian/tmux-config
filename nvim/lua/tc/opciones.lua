-- Opciones generales.

local o = vim.opt

o.number = true             -- números de línea
o.cursorline = true         -- resaltar la línea del cursor
o.signcolumn = 'yes'        -- columna fija para git y errores: el texto no salta
o.mouse = 'a'               -- clic, rueda y arrastrar, como en tmux
o.termguicolors = true      -- colores reales (tmux los deja pasar: terminal-features RGB)
o.showmode = false          -- el modo ya sale en la barra de estado
o.scrolloff = 5             -- dejar 5 líneas de margen al hacer scroll
o.sidescrolloff = 5
o.linebreak = true          -- las líneas largas se cortan entre palabras
o.splitright = true         -- las divisiones nuevas, a la derecha y abajo
o.splitbelow = true
o.confirm = true            -- al salir con cambios, preguntar si guardar en vez de dar error
o.undofile = true           -- deshacer se conserva al cerrar el fichero
o.ignorecase = true         -- buscar sin distinguir mayúsculas,
o.smartcase = true          -- salvo si escribes alguna
o.expandtab = true          -- sangría: 4 espacios (2 en YAML, JSON...)
o.shiftwidth = 4
o.softtabstop = 4
o.list = true               -- ver tabuladores y espacios al final de línea
o.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- :terminal y :! con la shell de los panes de tmux (zsh con la config del repo,
-- ZDOTDIR) y no con la de login. Solo si se abrió desde uno de esos panes.
if vim.env.ZDOTDIR and vim.uv.fs_realpath(vim.env.ZDOTDIR .. '/.zshrc') == vim.g.tc_repo .. '/zsh/.zshrc' then
    o.shell = 'zsh'
end

vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'yaml', 'json', 'jsonc', 'html', 'xml', 'css', 'javascript', 'typescript', 'lua', 'ruby', 'markdown', 'terraform' },
    callback = function()
        vim.opt_local.shiftwidth = 2
        vim.opt_local.softtabstop = 2
    end,
})

-- Al reabrir un fichero, volver a la línea donde estabas
vim.api.nvim_create_autocmd('BufReadPost', {
    callback = function(ev)
        local marca = vim.api.nvim_buf_get_mark(ev.buf, '"')
        local lineas = vim.api.nvim_buf_line_count(ev.buf)
        if marca[1] > 0 and marca[1] <= lineas and not vim.bo[ev.buf].filetype:match('commit') then
            pcall(vim.api.nvim_win_set_cursor, 0, marca)
        end
    end,
})

-- Resaltar un momento lo que acabas de copiar
vim.api.nvim_create_autocmd('TextYankPost', {
    callback = function() vim.hl.on_yank({ timeout = 200 }) end,
})

-- Errores y avisos del LSP: texto al final de la línea y letras E/W/I/H en el margen
vim.diagnostic.config({
    virtual_text = true,
    severity_sort = true,
    float = { border = 'rounded', source = true },
})
