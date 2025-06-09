local Job = require('plenary.job')
local utils = require('maorun.snyk.utils')

local M = {}

-- rootDir, snykCommandGlobal, and snykCommand are passed in or set during init
-- For now, snykCommand will be a return value from checkSnykAvailable
-- and then passed to auth.

function M.checkSnykAvailable(rootDir, snykCommandGlobal, initialSnykCommand, afterCheck)
    local currentSnykCommand = initialSnykCommand
    if vim.fn.executable(snykCommandGlobal) == 0 then
        if vim.fn.executable(currentSnykCommand) == 0 and vim.fn.executable('npm') == 0 then
            utils.printWithoutHistory('Snyk not available')
            -- Consider how to handle this case - maybe afterCheck should receive an error?
            afterCheck(nil) -- Indicate Snyk is not available
        elseif vim.fn.executable(currentSnykCommand) == 0 then
            utils.printWithoutHistory('Snyk not found, attempting to install via npm...')
            Job:new({
                command = 'npm',
                cwd = rootDir,
                args = { 'install' },
                interactive = false,
                on_exit = function(job, exit_code)
                    vim.schedule(function()
                        if exit_code == 0 then
                            utils.printWithoutHistory('Snyk installed via npm')
                            afterCheck(currentSnykCommand)
                        else
                            utils.printWithoutHistory(
                                'Snyk npm install failed. Exit code: ' .. exit_code
                            )
                            afterCheck(nil) -- Indicate Snyk is not available
                        end
                    end)
                end,
            }):start()
        else
            utils.printWithoutHistory('Snyk available (plugin at ' .. currentSnykCommand .. ')')
            afterCheck(currentSnykCommand)
        end
    else
        currentSnykCommand = snykCommandGlobal
        utils.printWithoutHistory('Snyk available (global at ' .. currentSnykCommand .. ')')
        afterCheck(currentSnykCommand)
    end
end

function M.auth(rootDir, snykCommand)
    if not snykCommand then
        utils.printWithoutHistory('Snyk command not available, skipping auth.')
        return
    end

    local apiKey = ''
    Job
        :new({
            command = snykCommand,
            cwd = rootDir,
            args = { 'config', 'get', 'api' },
            interactive = false,
            on_stdout = function(_, data) -- Ignoring error argument as it's often nil for on_stdout
                if data then
                    apiKey = data
                end
            end,
            on_stderr = function(_, data)
                -- utils.printWithoutHistory('Auth stderr: ' .. data) -- For debugging if needed
            end,
            on_exit = function(_, exit_code) -- Ignoring signal argument
                vim.schedule(function()
                    apiKey = vim.fn.trim(apiKey) -- Trim whitespace
                    if apiKey == '' or apiKey == 'null' or exit_code ~= 0 then -- Also check for 'null' string
                        utils.printWithoutHistory(
                            'Snyk not yet authenticated (API key is empty or error). Attempting auth...'
                        )
                        Job
                            :new({
                                command = snykCommand,
                                args = { 'auth' },
                                interactive = false, -- Keep false unless direct interaction is needed
                                on_exit = function(_, auth_exit_code)
                                    vim.schedule(function()
                                        if auth_exit_code == 0 then
                                            utils.printWithoutHistory(
                                                'Snyk auth process initiated. Please check your browser.'
                                            )
                                        else
                                            utils.printWithoutHistory(
                                                'Snyk auth command failed. Exit code: '
                                                    .. auth_exit_code
                                            )
                                        end
                                    end)
                                end,
                            })
                            :start()
                    else
                        utils.printWithoutHistory('Snyk already authenticated.')
                    end
                end)
            end,
        })
        :start()
end

return M
