-- Servidores LSP: errores en vivo, autocompletado, ir a la definición...
-- Los instala ./install vim con mason (en ~/.local/share/nvim/tmux-config/mason).
-- Para añadir más en una máquina: :Mason (i instala, X desinstala).

local M = {}

-- servidor (nombre de nvim-lspconfig) · paquete (nombre de mason) · necesita node
M.servidores = {
    { lsp = 'bashls',   paquete = 'bash-language-server',       node = true }, -- bash, sh (con shellcheck)
    { lsp = 'pyright',  paquete = 'pyright',                    node = true }, -- Python
    { lsp = 'yamlls',   paquete = 'yaml-language-server',       node = true }, -- YAML: compose, ansible, k8s
    { lsp = 'jsonls',   paquete = 'json-lsp',                   node = true }, -- JSON
    { lsp = 'dockerls', paquete = 'dockerfile-language-server', node = true }, -- Dockerfile
    { lsp = 'lua_ls',   paquete = 'lua-language-server' },                     -- Lua (esta config)
    { lsp = 'marksman', paquete = 'marksman' },                                -- Markdown
}

-- Los servidores de node necesitan node >= 18 con npm (Ubuntu 22.04 trae el 12)
function M.hay_node()
    if vim.fn.executable('node') == 0 or vim.fn.executable('npm') == 0 then
        return false
    end
    local mayor = tonumber(vim.fn.system({ 'node', '--version' }):match('^v(%d+)'))
    return mayor ~= nil and mayor >= 18
end

function M.activos()
    local node, lista = M.hay_node(), {}
    for _, s in ipairs(M.servidores) do
        if node or not s.node then
            table.insert(lista, s)
        end
    end
    return lista
end

-- Ajustes de servidores concretos (el resto, los de nvim-lspconfig)
function M.configurar()
    vim.lsp.config('lua_ls', {
        settings = { Lua = { workspace = { library = { vim.env.VIMRUNTIME } } } },
    })
end

return M
