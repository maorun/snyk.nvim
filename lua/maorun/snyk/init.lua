local rootDir = vim.fn.expand('<sfile>:h:h:h:h')
local snykCommandGlobal = 'snyk'
local snykCommand = rootDir .. '/node_modules/.bin/snyk'
local Job = require('plenary.job')

local function printWithoutHistory(text)
    text = 'Snyk: ' .. text
    -- vim.cmd("echo '" .. text .. "'")
end

-- perform diagnostic
local function performTestCode(currentFile, fullFile, json)
    diagnostics = vim.tbl_map(function(result)
        -- https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Documents/CommitteeSpecifications/2.1.0/sarif-schema-2.1.0.json
        local file = result.locations[1].physicalLocation.artifactLocation.uri
        if file == currentFile then
            local location = result.locations[1].physicalLocation.region
            local warning = result.level
            if warning == 'warning' then
                warning = vim.diagnostic.severity.WARN
            elseif warning == 'error' then
                warning = vim.diagnostic.severity.ERROR
            elseif warning == 'note' then
                warning = vim.diagnostic.severity.INFO
            elseif warning == 'none' then
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
                source = 'snyk',
            }
        end
    end, json.runs[1].results)
    local namespace = vim.api.nvim_create_namespace(currentFile .. 'snyk')
    vim.diagnostic.set(namespace, vim.fn.bufnr(fullFile), diagnostics)
end

-- perform diagnostic for IaC
local function performIaC(fullPath, currentFile, fullFile, json)
    local namespace = vim.api.nvim_create_namespace(currentFile .. 'snyk')
    vim.diagnostic.set(namespace, vim.fn.bufnr(fullFile), {})
    local diagnostics = {}
    local jobs = vim.tbl_map(function(result)
        local warning = result.severity
        if warning == 'medium' then
            warning = vim.diagnostic.severity.WARN
        elseif warning == 'high' then
            warning = vim.diagnostic.severity.ERROR
        elseif warning == 'low' then
            warning = vim.diagnostic.severity.WARN
            -- warning = vim.diagnostic.severity.INFO
        else
            warning = vim.diagnostic.severity.HINT
        end
        local linenumber = 0
        return Job:new({
            command = 'npx',
            cwd = rootDir,
            args = {
                'ts-node',
                'index.ts',
                fullPath,
                result.msg,
            },
            interactive = false,
            on_stdout = function(error, data)
                linenumber = data
            end,
            on_exit = function(signal, ret)
                vim.schedule(function()
                    table.insert(diagnostics, {
                        bufnr = 0,
                        lnum = tonumber(linenumber),
                        end_lnum = tonumber(linenumber),
                        col = 0,
                        -- end_col = 1,
                        severity = warning,
                        message = 'Issue: '
                            .. result.iacDescription.issue
                            .. '\n'
                            .. 'Impact: '
                            .. result.iacDescription.impact
                            .. '\n'
                            .. 'Resolve: '
                            .. result.iacDescription.resolve
                            .. '\n'
                            .. '('
                            .. result.msg
                            .. ')\n'
                            .. 'see also '
                            .. result.documentation,
                        source = 'snyk',
                    })
                    vim.diagnostic.set(namespace, vim.fn.bufnr(fullFile), diagnostics)
                end)
            end,
        }):start()
    end, json.infrastructureAsCodeIssues)
end

-- perform diagnostic for Container
local function performContainer(fullPath, currentFile, fullFile, json)
    local namespace = vim.api.nvim_create_namespace(currentFile .. 'snyk')
    vim.diagnostic.set(namespace, vim.fn.bufnr(fullFile), {})
    local diagnostics = {}
    for _, result in ipairs(json.issues) do
        local warning = result.severity
        if warning == 'medium' then
            warning = vim.diagnostic.severity.WARN
        elseif warning == 'high' then
            warning = vim.diagnostic.severity.ERROR
        elseif warning == 'low' then
            warning = vim.diagnostic.severity.INFO
        else
            warning = vim.diagnostic.severity.HINT
        end
        table.insert(diagnostics, {
            bufnr = 0,
            lnum = 0,
            col = 0,
            severity = warning,
            message = result.title .. '\n' .. result.description,
            source = 'snyk',
        })
    end
    vim.diagnostic.set(namespace, vim.fn.bufnr(fullFile), diagnostics)
end

-- Add a function to perform Snyk Open Source diagnostics
local function performOpenSource(fullPath, currentFile, fullFile, json)
    local namespace = vim.api.nvim_create_namespace(currentFile .. 'snyk')
    vim.diagnostic.set(namespace, vim.fn.bufnr(fullFile), {})
    local diagnostics = {}
    for _, vuln in ipairs(json.vulnerabilities) do
        local warning = vuln.severity
        if warning == 'medium' then
            warning = vim.diagnostic.severity.WARN
        elseif warning == 'high' then
            warning = vim.diagnostic.severity.ERROR
        elseif warning == 'low' then
            warning = vim.diagnostic.severity.INFO
        else
            warning = vim.diagnostic.severity.HINT
        end
        table.insert(diagnostics, {
            bufnr = 0,
            lnum = 0,
            col = 0,
            severity = warning,
            message = vuln.title
                .. '\n'
                .. vuln.description
                .. '\nFix: '
                .. (vuln.fix or 'No fix available'),
            source = 'snyk',
        })
    end
    vim.diagnostic.set(namespace, vim.fn.bufnr(fullFile), diagnostics)
end

-- Add a function to start the Snyk Open Source job
local function startOpenSourceJob(params)
    local check = {}
    local fullFile = params.fullFile
    local file = getFilename(fullFile)
    local cwd = getCwd(fullFile)
    vim.diagnostic.reset()
    Job:new({
        command = snykCommand,
        cwd = cwd,
        args = {
            'test',
            '--json',
        },
        interactive = false,
        on_stdout = function(error, data)
            table.insert(check, data)
        end,
        on_exit = function(signal)
            vim.schedule(function()
                local json = vim.fn.json_decode(check)
                if json.error then
                    printWithoutHistory('got an error: "' .. json.error .. '"')
                else
                    performOpenSource(params.fullPath, file, fullFile, json)
                end
            end)
        end,
    }):start()
end

local function getFilename(fullFile)
    local head = string.find(fullFile, '[^/]+$')
    return string.sub(fullFile, head)
end
local function getCwd(fullFile)
    local head = string.find(fullFile, '[^/]+$')
    if head == 1 then
        return '.'
    end
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
            'code',
            'test',
            '--json',
        },
        interactive = false,
        on_stdout = function(error, data)
            table.insert(check, data)
        end,
        on_exit = function(signal)
            vim.schedule(function()
                if check[1] == '{' then
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
            'iac',
            'test',
            file,
            '--json',
        },
        interactive = false,
        on_stdout = function(error, data)
            table.insert(check, data)
        end,
        on_exit = function(signal)
            vim.schedule(function()
                local json = vim.fn.json_decode(check)
                if json.error then
                    printWithoutHistory('got an error: "' .. json.error .. '"')
                else
                    performIaC(params.fullPath, file, fullFile, json)
                end
            end)
        end,
    }):start()
end

local function startContainerJob(params)
    local check = {}
    local fullFile = params.fullFile
    local file = getFilename(fullFile)
    local cwd = getCwd(fullFile)
    vim.diagnostic.reset()
    Job:new({
        command = snykCommand,
        cwd = cwd,
        args = {
            'container',
            'test',
            file,
            '--json',
        },
        interactive = false,
        on_stdout = function(error, data)
            table.insert(check, data)
        end,
        on_exit = function(signal)
            vim.schedule(function()
                local json = vim.fn.json_decode(check)
                if json.error then
                    printWithoutHistory('got an error: "' .. json.error .. '"')
                else
                    performContainer(params.fullPath, file, fullFile, json)
                end
            end)
        end,
    }):start()
end

local function checkSnykAvailable(afterCheck)
    if vim.fn.executable(snykCommandGlobal) == 0 then
        if vim.fn.executable(snykCommand) == 0 and vim.fn.executable('npm') == 0 then
            printWithoutHistory('Snyk not available')
        elseif vim.fn.executable(snykCommand) == 0 then
            Job:new({
                command = 'npm',
                cwd = rootDir,
                args = {
                    'install',
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
            printWithoutHistory('Snyk available (plugin)')
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
            'config',
            'get',
            'api',
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
                if apiKey == '' then
                    printWithoutHistory('Snyk not yet authenticated')
                    Job
                        :new({
                            command = snykCommand,
                            args = {
                                'auth',
                            },
                            interactive = false,
                            on_exit = function(signal)
                                vim.schedule(function()
                                    printWithoutHistory('Snyk now authenticated')
                                end)
                            end,
                        })
                        :start()
                else
                    printWithoutHistory('Snyk was authenticated')
                end
            end)
        end,
    }):start()
end

local function shouldBeCheck(fullFile)
    local isNoStream = string.find(fullFile, '.*://') == nil
    return isNoStream
end

local M = {}
function M.setup(options)
    checkSnykAvailable(function()
        auth()
    end)

    local snykGroup = vim.api.nvim_create_augroup('snyk', {})
    vim.api.nvim_clear_autocmds({
        event = { 'BufReadPost', 'BufWritePost' },
        group = snykGroup,
    })
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        desc = 'Snyk Code',
        group = snykGroup,
        pattern = {
            '*.c',
            '*.cc',
            '*.cpp',
            '*.cxx',
            '*.h',
            '*.hpp',
            '*.hxx',
            '*.ejs',
            '*.es',
            '*.es6',
            '*.htm',
            '*.html',
            '*.js',
            '*.jsx',
            '*.ts',
            '*.tsx',
            '*.vue',
            '*.java',
            '*.erb',
            '*.haml',
            '*.rb',
            '*.rhtml',
            '*.slim',
            '*.py',
            '*.go',
            '*.ASPX',
            '*.Aspx',
            '*.CS',
            '*.Cs',
            '*.aspx',
            '*.cs',
            '*.php',
            '*.xml',
        },
        callback = function(params)
            local file = vim.fn.expand('<afile>')
            if shouldBeCheck(file) then
                startJob({
                    fullFile = file,
                })
            end
        end,
    })
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        desc = 'Snyk Infrastructure as Code',
        group = snykGroup,
        pattern = {
            '*.yaml',
        },
        callback = function(params)
            local file = vim.fn.expand('<afile>')
            if shouldBeCheck(file) then
                startIaCJob({
                    fullPath = vim.fn.expand('%:p'),
                    fullFile = file,
                })
            end
        end,
    })
    -- Add autocmd for Snyk Container
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        desc = 'Snyk Container',
        group = snykGroup,
        pattern = {
            '*.dockerfile',
            '*.Dockerfile',
            '*.container',
        },
        callback = function(params)
            local file = vim.fn.expand('<afile>')
            if shouldBeCheck(file) then
                startContainerJob({
                    fullPath = vim.fn.expand('%:p'),
                    fullFile = file,
                })
            end
        end,
    })
    -- Add autocmd for Snyk Open Source
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        desc = 'Snyk Open Source',
        group = snykGroup,
        pattern = {
            'package.json',
            'requirements.txt',
            'Gemfile',
            'pom.xml',
            'build.gradle',
            'build.gradle.kts',
            'Pipfile',
            'go.mod',
            'Cargo.toml',
            'composer.json',
        },
        callback = function(params)
            local file = vim.fn.expand('<afile>')
            if shouldBeCheck(file) then
                startOpenSourceJob({
                    fullPath = vim.fn.expand('%:p'),
                    fullFile = file,
                })
            end
        end,
    })
end

M.auth = auth
M.setup()
-- M.testCode({
--     fullFile = vim.fn.expand('%'),
-- })

vim.cmd([[
    augroup snykReload
        autocmd!
        autocmd! BufWritePost */maorun/**.lua so %
    augroup END
]])

return M
