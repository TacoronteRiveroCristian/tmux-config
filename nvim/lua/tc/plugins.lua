-- Plugins, gestionados con lazy.nvim. Cada uno va fijado a un commit (la
-- versión probada): para cambiarla, edita el commit y ejecuta ./install vim.
-- Se descargan en ~/.local/share/nvim/tmux-config/ (lo hace ./install vim).
-- Sin iconos: todo se ve igual con cualquier fuente.

-- netrw (el explorador de ficheros de serie) cede el sitio a nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local datos = vim.fn.stdpath('data') .. '/tmux-config'

local lazypath = datos .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
    local out = vim.fn.system({ 'git', 'clone', '--quiet', '--filter=blob:none',
        'https://github.com/folke/lazy.nvim.git', lazypath })
    if vim.v.shell_error ~= 0 then
        error('no se pudo descargar lazy.nvim:\n' .. out)
    end
    vim.fn.system({ 'git', '-C', lazypath, 'checkout', '--quiet', '85c7ff3711b730b4030d03144f6db6375044ae82' }) -- v11.17.5
end
vim.opt.runtimepath:prepend(lazypath)

-- Raíz del proyecto del fichero abierto: su repo git o su carpeta (en el árbol,
-- la carpeta del árbol). Ahí buscan Ctrl+P y Espacio g.
local function raiz()
    local nombre = vim.api.nvim_buf_get_name(0)
    local dir = (nombre ~= '' and vim.bo.buftype == '') and vim.fs.dirname(nombre) or vim.uv.cwd()
    return vim.fs.root(dir, '.git') or dir
end

local function telescope(picker, opts)
    return function() require('telescope.builtin')[picker](opts and opts() or {}) end
end

require('lazy').setup({
    -- El propio gestor, también fijado (si no, Lazy sync lo actualizaría)
    { 'folke/lazy.nvim', commit = '85c7ff3711b730b4030d03144f6db6375044ae82' }, -- v11.17.5

    -- Tema de colores
    {
        'folke/tokyonight.nvim', commit = '545d72cde6400835d895160ecb5853874fd5156d', -- v4.14.1
        lazy = false, priority = 1000,
        config = function()
            require('tokyonight').setup({ style = 'night' })
            vim.cmd.colorscheme('tokyonight-night')
        end,
    },

    -- Barra de estado: modo, rama git, cambios, errores, fichero, posición
    {
        'nvim-lualine/lualine.nvim', commit = '221ce6b2d999187044529f49da6554a92f740a96',
        opts = {
            options = { theme = 'auto', icons_enabled = false, component_separators = '|', section_separators = '', globalstatus = true },
            sections = { lualine_c = { { 'filename', path = 1 } } },
        },
    },

    -- Menú de atajos: pulsa Espacio y espera
    {
        'folke/which-key.nvim', commit = 'fcbf4eea17cb299c02557d576f0d568878e354a4', -- v3.17.0
        event = 'VeryLazy',
        opts = {
            preset = 'modern',
            delay = 400,
            icons = { mappings = false },
            spec = {
                { '<leader>c', group = 'Código (LSP)' },
                { '<leader>v', group = 'Git (versiones)' },
            },
        },
    },

    -- Árbol de ficheros. Dentro: a crear · r renombrar · d borrar · c copiar ·
    -- p pegar · x cortar · H ocultos · R refrescar · g? ayuda
    {
        'nvim-tree/nvim-tree.lua', commit = '531b807b8f0d6f75016a0ee1e0cd5ce2086e9d95', -- v1.18.0
        lazy = false,
        keys = {
            { '<leader>e', function() require('nvim-tree.api').tree.toggle() end, desc = 'Árbol de ficheros' },
            { '<leader>f', function() require('nvim-tree.api').tree.find_file({ open = true, focus = true }) end, desc = 'Mostrar este fichero en el árbol' },
        },
        config = function()
            require('nvim-tree').setup({
                disable_netrw = true,
                hijack_netrw = false,          -- netrw ya está desactivado arriba
                hijack_directories = { enable = false },
                sync_root_with_cwd = true,   -- la carpeta del árbol es la de trabajo
                view = { width = 32 },
                filters = { dotfiles = false, custom = { '^\\.git$' } },
                git = { ignore = false },
                renderer = {
                    group_empty = true,
                    icons = {
                        show = { file = false, folder = false, folder_arrow = true, git = true, modified = true },
                        glyphs = {
                            folder = { arrow_closed = '+', arrow_open = '-' },
                            git = { unstaged = 'M', staged = 'S', unmerged = 'U', renamed = 'R', untracked = '?', deleted = 'D', ignored = '!' },
                            modified = '*',
                        },
                    },
                },
            })
            -- "nvim carpeta": abrir el árbol en esa carpeta y trabajar en ella
            vim.api.nvim_create_autocmd('VimEnter', {
                callback = function(data)
                    if vim.fn.isdirectory(data.file) == 1 then
                        vim.cmd.enew()
                        vim.cmd.bwipeout(data.buf)
                        vim.cmd.cd(data.file)
                        require('nvim-tree.api').tree.open()
                    end
                end,
            })
            -- Al cerrar el último fichero, cerrar también el árbol (y salir)
            vim.api.nvim_create_autocmd('QuitPre', {
                callback = function()
                    local arbol, flotantes, ventanas = {}, 0, vim.api.nvim_list_wins()
                    for _, w in ipairs(ventanas) do
                        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'NvimTree' then
                            table.insert(arbol, w)
                        elseif vim.api.nvim_win_get_config(w).relative ~= '' then
                            flotantes = flotantes + 1
                        end
                    end
                    if #ventanas - flotantes - #arbol == 1 then
                        for _, w in ipairs(arbol) do vim.api.nvim_win_close(w, true) end
                    end
                end,
            })
        end,
    },

    -- Buscador: ficheros, texto, ficheros abiertos, recientes. Dentro: escribe,
    -- flechas o Ctrl+j/k, Enter abre, Ctrl+v en una división, Esc sale.
    {
        'nvim-telescope/telescope.nvim', commit = '5255aa27c422de944791318024167ad5d40aad20', -- v0.2.2
        dependencies = { { 'nvim-lua/plenary.nvim', commit = '74b06c6c75e4eeb3108ec01852001636d85a932b' } },
        cmd = 'Telescope',
        keys = {
            { '<C-p>', telescope('find_files', function() return { cwd = raiz() } end), desc = 'Buscar fichero' },
            { '<leader>p', telescope('find_files', function() return { cwd = raiz() } end), desc = 'Buscar fichero' },
            { '<leader>g', telescope('live_grep', function() return { cwd = raiz() } end), desc = 'Buscar texto en el proyecto' },
            { '<leader>b', telescope('buffers'), desc = 'Ficheros abiertos' },
            { '<leader>r', telescope('oldfiles'), desc = 'Ficheros recientes' },
            { '<leader>k', telescope('keymaps'), desc = 'Buscar un atajo' },
        },
        config = function()
            local acciones = require('telescope.actions')
            require('telescope').setup({
                defaults = {
                    prompt_prefix = '> ',
                    selection_caret = '> ',
                    path_display = { 'truncate' },
                    file_ignore_patterns = { '^%.git/' },
                    mappings = { i = { ['<C-j>'] = acciones.move_selection_next, ['<C-k>'] = acciones.move_selection_previous } },
                },
                pickers = { find_files = { hidden = true } },
            })
        end,
    },

    -- Git en el margen: líneas añadidas, cambiadas y borradas
    {
        'lewis6991/gitsigns.nvim', commit = 'a462f416e2ce4744531c6256252dee99a7d34a83', -- v2.1.0
        event = { 'BufReadPre', 'BufNewFile' },
        opts = {
            on_attach = function(buf)
                local gs = require('gitsigns')
                local function map(teclas, accion, desc)
                    vim.keymap.set('n', teclas, accion, { buffer = buf, desc = desc })
                end
                map(']c', function() gs.nav_hunk('next') end, 'Siguiente cambio')
                map('[c', function() gs.nav_hunk('prev') end, 'Cambio anterior')
                map('<leader>vp', gs.preview_hunk, 'Ver el cambio')
                map('<leader>vr', gs.reset_hunk, 'Deshacer el cambio')
                map('<leader>vb', gs.blame_line, 'Quién cambió esta línea')
                map('<leader>vd', gs.diffthis, 'Comparar con la última versión')
            end,
        },
    },

    -- LSP: los servidores los instala ./install vim (tc/lsp.lua tiene la lista)
    {
        'mason-org/mason-lspconfig.nvim', commit = 'a5671269a1ddfa7790cdf97c14e600e269da550f', -- v2.3.0
        lazy = false,
        dependencies = {
            {
                'mason-org/mason.nvim', commit = '2a6940af80375532e5e9e7c1f2fc6319a1b7a69d', -- v2.3.1
                opts = { install_root_dir = datos .. '/mason', ui = { border = 'rounded' } },
            },
            { 'neovim/nvim-lspconfig', commit = '4d363f93c3581b9212a24f7a830d7590b3f050af' }, -- v2.12.0
            { 'saghen/blink.cmp', commit = '78336bc89ee5365633bcf754d93df01678b5c08f' },     -- v1.10.2
        },
        config = function()
            vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities() })
            require('tc.lsp').configurar()
            -- activa los servidores instalados; no descarga nada al arrancar
            require('mason-lspconfig').setup({ ensure_installed = {}, automatic_enable = true })
        end,
    },

    -- Autocompletado: Tab acepta, flechas o Ctrl+n/p eligen, Esc cierra
    {
        'saghen/blink.cmp', commit = '78336bc89ee5365633bcf754d93df01678b5c08f', -- v1.10.2
        event = { 'InsertEnter', 'CmdlineEnter' },
        opts = {
            keymap = { preset = 'super-tab' },
            fuzzy = { implementation = 'lua' }, -- sin descargar el binario de Rust
            completion = {
                menu = { border = 'rounded', draw = { columns = { { 'label', 'label_description', gap = 1 }, { 'kind' } } } },
                documentation = { auto_show = true, window = { border = 'rounded' } },
            },
            signature = { enabled = true, window = { border = 'rounded' } },
            sources = { default = { 'lsp', 'path', 'buffer', 'snippets' } },
        },
    },

    -- Cerrar paréntesis, corchetes y comillas solos
    { 'windwp/nvim-autopairs', commit = '23320e75953ac82e559c610bec5a90d9c6dfa743', event = 'InsertEnter', opts = {} }, -- 0.10.0

    -- Guías verticales de sangría (útil en YAML)
    {
        'lukas-reineke/indent-blankline.nvim', commit = 'f1e186e44d3b7f9ae918008e2c28ce37c6023d2d', -- v3.10.1
        main = 'ibl', event = { 'BufReadPost', 'BufNewFile' },
        opts = { indent = { char = '│' }, scope = { enabled = false } },
    },
}, {
    root = datos .. '/lazy',
    lockfile = vim.fn.stdpath('state') .. '/tmux-config-lazy-lock.json',
    install = { missing = true, colorscheme = { 'tokyonight-night', 'habamax' } },
    checker = { enabled = false },
    change_detection = { enabled = false },
    rocks = { enabled = false },
    -- lazy reinicia el runtimepath: que conserve la carpeta nvim/ del repo (tc.*)
    performance = { rtp = { paths = { vim.g.tc_repo .. '/nvim' } } },
    ui = {
        border = 'rounded',
        icons = {
            cmd = 'cmd ', config = 'cfg ', event = 'ev ', ft = 'ft ', init = 'init ', import = 'imp ',
            keys = 'keys ', lazy = 'lazy ', loaded = '+', not_loaded = '-', plugin = 'plug ',
            runtime = 'rt ', require = 'req ', source = 'src ', start = 'start ', task = 'task ',
            list = { '*', '>', '-', '-' },
        },
    },
})
