local Job = require('plenary.job')
local utils = require('maorun.snyk.utils')
local diagnostics = require('maorun.snyk.diagnostics')

local M = {}

-- Added snykCommand and rootDir as parameters for now
function M.startOpenSourceJob(params, snykCommand)
    local check = {}
    local fullFile = params.fullFile
    local file = utils.getFilename(fullFile)
    local cwd = utils.getCwd(fullFile)
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
                local json_string = table.concat(check)
                local success, json = pcall(vim.fn.json_decode, json_string)
                if not success or not json then
                    utils.printWithoutHistory('Failed to decode JSON for Open Source: ' .. (json_string or 'empty response'))
                    if json and json.error then
                         utils.printWithoutHistory('Error from Snyk: ' .. json.error)
                    end
                    return
                end

                if json.error then
                    utils.printWithoutHistory('got an error: "' .. json.error .. '"')
                else
                    diagnostics.performOpenSource(params.fullPath, file, fullFile, json)
                end
            end)
        end,
    }):start()
end

-- Added snykCommand as a parameter for now
function M.startJob(params, snykCommand)
    local check = {}
    local fullFile = params.fullFile
    local file = utils.getFilename(fullFile)
    local cwd = utils.getCwd(fullFile)
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
                local json_string = table.concat(check)
                if json_string:sub(1,1) == '{' then -- Basic check if it looks like JSON
                    local success, json = pcall(vim.fn.json_decode, json_string)
                    if not success or not json then
                        utils.printWithoutHistory('Failed to decode JSON for Code Test: ' .. (json_string or 'empty response'))
                        return
                    end
                    diagnostics.performTestCode(file, fullFile, json)
                else
                    utils.printWithoutHistory('got an error: "' .. (json_string or 'empty response') .. '"')
                end
            end)
        end,
    }):start()
end

-- Added snykCommand and rootDir as parameters for now
function M.startIaCJob(params, snykCommand, rootDir)
    local check = {}
    local fullFile = params.fullFile
    local file = utils.getFilename(fullFile)
    local cwd = utils.getCwd(fullFile)
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
                local json_string = table.concat(check)
                local success, json = pcall(vim.fn.json_decode, json_string)
                if not success or not json then
                    utils.printWithoutHistory('Failed to decode JSON for IaC: ' .. (json_string or 'empty response'))
                     if json and json.error then
                         utils.printWithoutHistory('Error from Snyk: ' .. json.error)
                    end
                    return
                end

                if json.error then
                    utils.printWithoutHistory('got an error: "' .. json.error .. '"')
                else
                    diagnostics.performIaC(params.fullPath, file, fullFile, json, rootDir) -- Pass rootDir here
                end
            end)
        end,
    }):start()
end

-- Added snykCommand as a parameter for now
function M.startContainerJob(params, snykCommand)
    local check = {}
    local fullFile = params.fullFile
    local file = utils.getFilename(fullFile)
    local cwd = utils.getCwd(fullFile)
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
                local json_string = table.concat(check)
                local success, json = pcall(vim.fn.json_decode, json_string)
                if not success or not json then
                    utils.printWithoutHistory('Failed to decode JSON for Container: ' .. (json_string or 'empty response'))
                     if json and json.error then
                         utils.printWithoutHistory('Error from Snyk: ' .. json.error)
                    end
                    return
                end

                if json.error then
                    utils.printWithoutHistory('got an error: "' .. json.error .. '"')
                else
                    diagnostics.performContainer(params.fullPath, file, fullFile, json)
                end
            end)
        end,
    }):start()
end

return M
