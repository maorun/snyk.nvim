local M = {}

function M.printWithoutHistory(text)
    local msg = 'Snyk: ' .. tostring(text)
    if vim.api and vim.api.nvim_echo then
        vim.api.nvim_echo({ { msg, '' } }, false, {})
    elseif vim.fn and vim.fn.execute then
        vim.cmd('echo ' .. vim.fn.string(msg))
    end
end

function M.getFilename(fullFile)
    local head = string.find(fullFile, '[^/]+$')
    return string.sub(fullFile, head)
end

function M.getCwd(fullFile)
    local head = string.find(fullFile, '[^/]+$')
    if head == 1 then
        return '.'
    end
    return string.sub(fullFile, 1, head - 1)
end

return M
