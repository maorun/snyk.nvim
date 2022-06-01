local rootDir = vim.fn.expand("<sfile>:h:h:h:h")
local snykCommandGlobal = 'snyk'
local snykCommand = rootDir .. "/node_modules/.bin/snyk"
local Job = require('plenary.job')

local namespace = vim.api.nvim_create_namespace('snyk')

local function printWithoutHistory(text)
    text = 'Snyk: ' .. text
    vim.cmd("echo '" .. text .. "'")
end

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
    local fullFile = params.fullFile
    -- @todo extract file and cwd from fullFile
    local file = params.file
    local cwd = params.cwd
    printWithoutHistory('startJob')
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
        on_stderr = function(error, data)
            table.insert(check, data)
        end,
        on_exit = function(signal)
            vim.schedule(function()
                if (check[1] == '{') then
                    local json = vim.fn.json_decode(check)
                    test_code(file, fullFile, json)
                else
                    printWithoutHistory('got an error: "' .. check[1] .. '"')
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
    vim.api.nvim_create_autocmd({"BufReadPost", "BufWritePost" }, {
        group = snykGroup,
        pattern = {
            '*.c', '*.cc', '*.cpp', '*.cxx', '*.h', '*.hpp', '*.hxx', '*.ejs', '*.es', '*.es6', '*.htm', '*.html', '*.js', '*.jsx', '*.ts', '*.tsx', '*.vue', '*.java', '*.erb', '*.haml', '*.rb', '*.rhtml', '*.slim', '*.py', '*.go', '*.ASPX', '*.Aspx', '*.CS', '*.Cs', '*.aspx', '*.cs', '*.php', '*.xml'
        },
        callback = function(params)
            startJob({
                fullFile = vim.fn.expand('<afile>'),
                file = vim.fn.expand('<afile>:t'),
                cwd = vim.fn.expand('<afile>:p:h'),
            })
        end
    })
end

M.auth = auth
M.testCode = startJob

return M
