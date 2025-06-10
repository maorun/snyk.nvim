local M = {}

function M.printWithoutHistory(text)
    text = 'Snyk: ' .. text
    -- vim.cmd("echo '" .. text .. "'")
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
