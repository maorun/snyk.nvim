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

local default_options = {
    snyk_command = nil,
    auto_auth = true,
    setup_autocmds = true,
}

function M.setup(options)
    M.options = vim.tbl_deep_extend('force', default_options, options or {})

    local custom_snyk_command = M.options.snyk_command or M.options.snykCommand or M.options.command
    local check_global = custom_snyk_command or snykCommandGlobal
    local check_plugin = custom_snyk_command or initialSnykPluginCommand

    -- Initialize current_snyk_command with the plugin-specific path first
    current_snyk_command = check_plugin

    core.checkSnykAvailable(rootDir, check_global, check_plugin, function(snyk_command_path)
        if snyk_command_path then
            current_snyk_command = snyk_command_path -- Update with the actually found command
            utils.printWithoutHistory('Snyk command set to: ' .. current_snyk_command)

            if M.options.auto_auth then
                -- Authenticate Snyk
                core.auth(rootDir, current_snyk_command)
            end

            if M.options.setup_autocmds then
                -- Setup autocommands, passing the determined snyk command and rootDir
                autocmds.setup_autocmds(current_snyk_command, rootDir)
            end

            utils.printWithoutHistory('Snyk setup complete.')
        else
            -- Keep current_snyk_command as nil or its initial value if check failed
            current_snyk_command = nil
            utils.printWithoutHistory(
                'Snyk initialization failed: Snyk command not found or installation failed.'
            )
        end
    end)
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
