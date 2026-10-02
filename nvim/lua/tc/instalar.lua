-- Instalación sin pantalla, la que lanza ./install vim:
--   nvim --headless -u nvim/init.lua -c 'lua require("tc.instalar").lsp()'
-- Instala los servidores LSP que falten y espera a que acaben. Sale con error
-- (cquit) si alguno falla, para que ./install vim lo diga.

local M = {}

local function decir(texto)
    io.stdout:write('==> ' .. texto .. '\n')
    io.stdout:flush()
end

function M.lsp()
    local lsp = require('tc.lsp')
    if not lsp.hay_node() then
        decir('AVISO: sin node >= 18 y npm: solo los servidores que no lo necesitan (Lua, Markdown)')
    end
    local registry = require('mason-registry')
    registry.refresh()

    local pendientes, resultado = {}, {}
    for _, s in ipairs(lsp.activos()) do
        local pkg = registry.get_package(s.paquete)
        if pkg:is_installed() then
            decir('servidor LSP ya instalado: ' .. s.paquete)
        else
            decir('instalando servidor LSP: ' .. s.paquete)
            table.insert(pendientes, s.paquete)
            pkg:install({}, function(ok, err)
                resultado[s.paquete] = ok and true or tostring(err)
            end)
        end
    end

    vim.wait(20 * 60 * 1000, function()
        return vim.tbl_count(resultado) == #pendientes
    end, 500)

    local fallos = 0
    for _, nombre in ipairs(pendientes) do
        if resultado[nombre] == true then
            decir('servidor LSP instalado: ' .. nombre)
        else
            fallos = fallos + 1
            decir('ERROR instalando ' .. nombre .. ': ' .. (resultado[nombre] or 'no terminó a tiempo'))
        end
    end
    vim.cmd(fallos == 0 and 'qall!' or 'cquit 1')
end

-- Comprueba que la config carga entera: tema, plugins en su commit y sin
-- errores. Imprime "tc-ok" si todo está bien; si no, sale con error.
function M.comprobar()
    local fallos = {}
    local function falla(texto) table.insert(fallos, texto) end

    if vim.g.colors_name ~= 'tokyonight-night' then
        falla('tema: ' .. tostring(vim.g.colors_name))
    end
    for _, modulo in ipairs({ 'lualine', 'which-key', 'nvim-tree', 'telescope', 'gitsigns', 'blink.cmp', 'mason', 'nvim-autopairs', 'ibl' }) do
        local ok, err = pcall(require, modulo)
        if not ok then falla('plugin ' .. modulo .. ': ' .. tostring(err)) end
    end
    for _, plugin in pairs(require('lazy.core.config').plugins) do
        local commit = plugin.commit
        if commit then
            local actual = vim.trim(vim.fn.system({ 'git', '-C', plugin.dir, 'rev-parse', 'HEAD' }))
            if actual ~= commit then
                falla(plugin.name .. ' está en ' .. actual:sub(1, 12) .. ', no en ' .. commit:sub(1, 12))
            end
        end
    end
    -- errores visibles al arrancar (los silenciados con silent! no cuentan)
    for linea in vim.gsplit(vim.api.nvim_exec2('messages', { output = true }).output, '\n') do
        if linea:match('^E%d+:') or linea:match('^Error') then falla('al arrancar: ' .. linea) end
    end

    if #fallos == 0 then
        decir('config de neovim: tema, plugins y versiones bien')
        io.stdout:write('tc-ok\n')
        vim.cmd('qall!')
    else
        for _, f in ipairs(fallos) do decir('ERROR ' .. f) end
        vim.cmd('cquit 1')
    end
end

return M
