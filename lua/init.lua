local Job = require('plenary.job')

local namespace = vim.api.nvim_create_namespace('snyk')

-- perform diagnostic
local function test_code(currentFile, fullFile, json)
    diagnostics = vim.tbl_map(function(result)

        -- https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Documents/CommitteeSpecifications/2.1.0/sarif-schema-2.1.0.json
        local file = result.locations[1].physicalLocation.artifactLocation.uri
        if (file == currentFile) then
            local location = result.locations[1].physicalLocation.region
            local warning = result.level
            if (warning == "warning") then
                warning = vim.diagnostic.severity.WARN
            elseif (warning == "error") then
                warning = vim.diagnostic.severity.ERROR
            elseif (warning == "note") then
                warning = vim.diagnostic.severity.INFO
            elseif (warning == "none") then
                warning = vim.diagnostic.severity.HINT
            end
            return {
                bufnr = 0,
                lnum = location.startLine - 1,
                end_lnum = location.endLine - 1,
                col = location.startColumn - 1,
                end_col = location.endColumn,
                severity = warning,
                message = result.message.text,
                source = "snyk",
            };
        end
    end, json.runs[1].results)

    vim.diagnostic.set(namespace, vim.fn.bufnr(fullFile), diagnostics)
end


local function startJob(params)
    local cmd = "snyk code test --json"
    local check = {}
    local fullFile = vim.fn.expand('<afile>')
    local file = vim.fn.expand('<afile>:t')
    Job:new({
        command = "snyk",
        cwd = vim.fn.expand('<afile>:p:h'),
        args = {
            "code",
            "test",
            "--json",
        },
        interactive = false,
        on_stdout = function(error, data)
            table.insert(check, data)
        end,
        on_stderr = function(error, data)
            table.insert(check, data)
        end,
        on_exit = function(signal)
            vim.schedule(function()
                local json = vim.fn.json_decode(check)
                test_code(file, fullFile, json)
            end)
        end,
    }):start()
end

local M = {}
function M.setup(options)
    local snykGroup = vim.api.nvim_create_augroup('snyk', {})

    vim.api.nvim_create_autocmd({"BufReadPost", "BufWritePost" }, {
        group = snykGroup,
        pattern = "*",
        callback = function(params)
            if (vim.bo.filetype ~= "typescriptreact") then
                return
            end
            startJob(params)
        end
    })
end

return M
