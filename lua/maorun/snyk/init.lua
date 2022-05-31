local rootDir = vim.fn.expand("<sfile>:h:h:h:h")
local snykCommandGlobal = 'snyk'
local snykCommand = rootDir .. "/node_modules/.bin/snyk"
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
        command = snykCommand,
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

local function printWithoutHistory(text)
    vim.cmd("echo '" .. text .. "'")
end

local function checkSnykAvailable()
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
            }):start()
            printWithoutHistory('Snyk installed')
        else
            printWithoutHistory("Snyk available (plugin)")
        end
    else
        snykCommand = snykCommandGlobal
        printWithoutHistory('Snyk available')
    end
end

local M = {}
function M.setup(options)
    checkSnykAvailable()

    local snykGroup = vim.api.nvim_create_augroup('snyk', {})
    vim.api.nvim_create_autocmd({"BufReadPost", "BufWritePost" }, {
        group = snykGroup,
        pattern = {
            '*.c', '*.cc', '*.cpp', '*.cxx', '*.h', '*.hpp', '*.hxx', '*.ejs', '*.es', '*.es6', '*.htm', '*.html', '*.js', '*.jsx', '*.ts', '*.tsx', '*.vue', '*.java', '*.erb', '*.haml', '*.rb', '*.rhtml', '*.slim', '*.py', '*.go', '*.ASPX', '*.Aspx', '*.CS', '*.Cs', '*.aspx', '*.cs', '*.php', '*.xml'
        },
        callback = function(params)
            startJob(params)
        end
    })
end

return M
