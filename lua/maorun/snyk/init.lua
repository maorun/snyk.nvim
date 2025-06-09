-- Module-level state for snyk command path
local current_snyk_command = nil

-- Original global-like variables
local rootDir = vim.fn.expand('<sfile>:h:h:h:h')
local snykCommandGlobal = 'snyk' -- Global snyk command name
local initialSnykPluginCommand = rootDir .. '/node_modules/.bin/snyk' -- Snyk command specific to the plugin

-- Require necessary modules
local utils = require('maorun.snyk.utils')
local core = require('maorun.snyk.core')
local autocmds = require('maorun.snyk.autocmds')
-- Job, diagnostics, and jobs are dependencies of core and autocmds

local M = {}

function M.setup(options) -- options are not currently used, but good to keep for future
    -- Initialize current_snyk_command with the plugin-specific path first
    current_snyk_command = initialSnykPluginCommand

    core.checkSnykAvailable(
        rootDir,
        snykCommandGlobal,
        initialSnykPluginCommand,
        function(snyk_command_path)
            if snyk_command_path then
                current_snyk_command = snyk_command_path -- Update with the actually found command
                utils.printWithoutHistory('Snyk command set to: ' .. current_snyk_command)

                -- Authenticate Snyk
                core.auth(rootDir, current_snyk_command)

                -- Setup autocommands, passing the determined snyk command and rootDir
                autocmds.setup_autocmds(current_snyk_command, rootDir)

                utils.printWithoutHistory('Snyk setup complete.')
            else
                -- Keep current_snyk_command as nil or its initial value if check failed
                current_snyk_command = nil
                utils.printWithoutHistory(
                    'Snyk initialization failed: Snyk command not found or installation failed.'
                )
            end
        end
    )
end

-- Public function to trigger authentication manually if needed
function M.auth()
    if current_snyk_command then
        core.auth(rootDir, current_snyk_command)
    else
        utils.printWithoutHistory(
            'Snyk command not yet determined or not found. Cannot authenticate. Run setup or check Snyk installation.'
        )
    end
end

-- Initial setup call
M.setup()

-- Autoreload on change
vim.cmd([[
    augroup snykReload
        autocmd!
        autocmd! BufWritePost */maorun/**.lua so %
    augroup END
]])

return M
