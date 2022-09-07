local rootDir = vim.fn.expand("<sfile>:h:h:h:h")
local snykCommandGlobal = 'snyk'
local snykCommand = rootDir .. "/node_modules/.bin/snyk"
local Job = require('plenary.job')

local namespace = vim.api.nvim_create_namespace('snyk')

local function printWithoutHistory(text)
    text = 'Snyk: ' .. text
    -- vim.cmd("echo '" .. text .. "'")
end

-- perform diagnostic
local function performTestCode(currentFile, fullFile, json)
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

-- perform diagnostic for IaC
-- todo: extract getColAndLineNumber from path
local function performIaC(currentFile, fullFile, json)
    diagnostics = vim.tbl_map(function(result)

        local warning = result.severity
        if (warning == "medium") then
            warning = vim.diagnostic.severity.WARN
        elseif (warning == "high") then
            warning = vim.diagnostic.severity.ERROR
        elseif (warning == "low") then
            warning = vim.diagnostic.severity.WARN
            -- warning = vim.diagnostic.severity.INFO
        else
            warning = vim.diagnostic.severity.HINT
        end

        return {
            bufnr = 0,
            lnum = result.lineNumber,
            end_lnum = result.lineNumber,
            col = 0,
            -- end_col = 1,
            severity = warning,
            message =
                'Issue: ' .. result.iacDescription.issue .. '\n' ..
                'Impact: ' .. result.iacDescription.impact .. '\n' .. 
                'Resolve: ' .. result.iacDescription.resolve .. '\n' ..
                '(' .. result.msg .. ')\n' ..
                'see also ' .. result.documentation,
            source = "snyk",
        };
    end, json.infrastructureAsCodeIssues)

    vim.diagnostic.set(namespace, vim.fn.bufnr(fullFile), diagnostics)
end

-- WIP for performIaC
local function getColAndLineNumber(pathByResult)
    local i = 0
    table.remove(pathByResult, 1)
    table.remove(pathByResult)
    local last = table.remove(pathByResult)
    local fullPath = table.concat(vim.tbl_map(function(path)
        i = i + 1
        local pos = string.find(path, "%[")
        if (pos) then
            local name = string.sub(path, pos + 1, string.find(path, "%]") - 1)
            path = string.sub(path, 1, pos - 1)
            i = i + 1
            return 
                string.rep('  ', i - 3) .. path .. '.*\n'
                .. string.rep('  ', i - 2) .. 'name: ' .. name .. '\n'
        end
        return string.rep('  ', i - 2) .. path  .. '.*\n' 
    end, pathByResult), '')
    fullPath = fullPath .. string.rep('  ', i - 1) .. last .. '.*'
end


local function getFilename(fullFile)
    local head = string.find(fullFile, '[^/]+$')
    return string.sub(fullFile, head)
end
local function getCwd(fullFile)
    local head = string.find(fullFile, '[^/]+$')
    return string.sub(fullFile, 1, head - 1)
end

local function startJob(params)
    local check = {}
    local fullFile = params.fullFile
    local file = getFilename(fullFile)
    local cwd = getCwd(fullFile)
    Job:new({
        command = snykCommand,
        cwd = cwd,
        args = {
            "code",
            "test",
            "--json",
        },
        interactive = false,
        on_stdout = function(error, data)
            table.insert(check, data)
        end,
        on_exit = function(signal)
            vim.schedule(function()
                if (check[1] == '{') then
                    local json = vim.fn.json_decode(check)
                    performTestCode(file, fullFile, json)
                else
                    printWithoutHistory('got an error: "' .. check[1] .. '"')
                end
            end)
        end,
    }):start()
end

local function startIaCJob(params)
    local check = {}
    local fullFile = params.fullFile
    local file = getFilename(fullFile)
    local cwd = getCwd(fullFile)
    vim.diagnostic.reset()
    Job:new({
        command = snykCommand,
        cwd = cwd,
        args = {
            "iac",
            "test",
            file,
            "--json",
        },
        interactive = false,
        on_stdout = function(error, data)
            table.insert(check, data)
        end,
        on_exit = function(signal)
            vim.schedule(function()
                local json = vim.fn.json_decode(check)
                if (json.error) then
                    printWithoutHistory('got an error: "' .. json.error .. '"')
                else
                    performIaC(file, fullFile, json)
                end
            end)
        end,
    }):start()
end


local function checkSnykAvailable(afterCheck)
    if (vim.fn.executable(snykCommandGlobal) == 0) then
        if (vim.fn.executable(snykCommand) == 0 and vim.fn.executable('npm') == 0) then
            printWithoutHistory("Snyk not available")
        elseif (vim.fn.executable(snykCommand) == 0) then
            Job:new({
                command = 'npm',
                cwd = rootDir,
                args = {
                    "install",
                },
                interactive = false,
                on_exit = function(signal)
                    vim.schedule(function()
                        afterCheck()
                    end)
                end,
            }):start()
            printWithoutHistory('Snyk installed')
        else
            printWithoutHistory("Snyk available (plugin)")
            afterCheck()
        end
    else
        snykCommand = snykCommandGlobal
        printWithoutHistory('Snyk available')
        afterCheck()
    end
end

local function auth()
    local apiKey = ''
    Job:new({
        command = snykCommand,
        cwd = rootDir,
        args = {
            "config",
            "get",
            "api",
        },
        interactive = false,
        on_stdout = function(error, data)
            apiKey = data
        end,
        on_stderr = function(error, data)
            -- table.insert(check, data)
        end,
        on_exit = function(signal)
            vim.schedule(function()
                if (apiKey == '') then
                    printWithoutHistory('Snyk not yet authenticated')
                    Job:new({
                        command = snykCommand,
                        args = {
                            "auth",
                        },
                        interactive = false,
                        on_exit = function(signal)
                            vim.schedule(function()
                                printWithoutHistory('Snyk now authenticated')
                            end)
                        end
                    }):start()
                else
                    printWithoutHistory('Snyk was authenticated')
                end
            end)
        end,
    }):start()
end

local M = {}
function M.setup(options)
    checkSnykAvailable(function()
        auth()
    end)

    local snykGroup = vim.api.nvim_create_augroup('snyk', {})
    vim.api.nvim_clear_autocmds({
        event={"BufReadPost", "BufWritePost" },
        group = snykGroup,
    })
    vim.api.nvim_create_autocmd({"BufReadPost", "BufWritePost" }, {
        desc = 'Snyk Code',
        group = snykGroup,
        pattern = {
            '*.c', '*.cc', '*.cpp', '*.cxx', '*.h', '*.hpp', '*.hxx', '*.ejs', '*.es', '*.es6', '*.htm', '*.html', '*.js', '*.jsx', '*.ts', '*.tsx', '*.vue', '*.java', '*.erb', '*.haml', '*.rb', '*.rhtml', '*.slim', '*.py', '*.go', '*.ASPX', '*.Aspx', '*.CS', '*.Cs', '*.aspx', '*.cs', '*.php', '*.xml'
        },
        callback = function(params)
            startJob({
                fullFile = vim.fn.expand('<afile>'),
            })
        end
    })
    vim.api.nvim_create_autocmd({"BufReadPost", "BufWritePost" }, {
        desc = 'Snyk Infrastructure as Code',
        group = snykGroup,
        pattern = {
            '*.yaml',
        },
        callback = function(params)
            startIaCJob({
                fullFile = vim.fn.expand('<afile>'),
            })
        end
    })
end

M.auth = auth
M.setup()
-- M.testCode({
--     fullFile = vim.fn.expand('%'),
-- })

vim.cmd [[
    augroup snykReload
        autocmd!
        autocmd! BufWritePost */maorun/**.lua so %
    augroup END
]]


return M
