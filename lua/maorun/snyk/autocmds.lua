local utils = require('maorun.snyk.utils')
local jobs = require('maorun.snyk.jobs')

local M = {}

-- snykCommand and rootDir will be passed from init.lua during setup
function M.setup_autocmds(snykCommand, rootDir)
    local snykGroup = vim.api.nvim_create_augroup('snyk', { clear = true }) -- Added clear = true

    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        desc = 'Snyk Code',
        group = snykGroup,
        pattern = {
            '*.c', '*.cc', '*.cpp', '*.cxx', '*.h', '*.hpp', '*.hxx',
            '*.ejs', '*.es', '*.es6', '*.htm', '*.html', '*.js', '*.jsx',
            '*.ts', '*.tsx', '*.vue', '*.java', '*.erb', '*.haml', '*.rb',
            '*.rhtml', '*.slim', '*.py', '*.go', '*.ASPX', '*.Aspx',
            '*.CS', '*.Cs', '*.aspx', '*.cs', '*.php', '*.xml',
        },
        callback = function(params)
            local file = vim.fn.expand('<afile>')
            if utils.shouldBeCheck(file) then -- Use utils.shouldBeCheck
                jobs.startJob({ fullFile = file }, snykCommand)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        desc = 'Snyk Infrastructure as Code',
        group = snykGroup,
        pattern = { '*.yaml', '*.yml' }, -- Added *.yml as it's a common extension for YAML
        callback = function(params)
            local file = vim.fn.expand('<afile>')
            if utils.shouldBeCheck(file) then -- Use utils.shouldBeCheck
                jobs.startIaCJob({
                    fullPath = vim.fn.expand('%:p'),
                    fullFile = file,
                }, snykCommand, rootDir)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        desc = 'Snyk Container',
        group = snykGroup,
        pattern = { '*.dockerfile', '*.Dockerfile', '*.container' },
        callback = function(params)
            local file = vim.fn.expand('<afile>')
            if utils.shouldBeCheck(file) then -- Use utils.shouldBeCheck
                jobs.startContainerJob({
                    fullPath = vim.fn.expand('%:p'),
                    fullFile = file,
                }, snykCommand)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        desc = 'Snyk Open Source',
        group = snykGroup,
        pattern = {
            'package.json', 'requirements.txt', 'Gemfile', 'pom.xml',
            'build.gradle', 'build.gradle.kts', 'Pipfile', 'go.mod',
            'Cargo.toml', 'composer.json',
        },
        callback = function(params)
            local file = vim.fn.expand('<afile>')
            if utils.shouldBeCheck(file) then -- Use utils.shouldBeCheck
                jobs.startOpenSourceJob({
                    fullPath = vim.fn.expand('%:p'),
                    fullFile = file,
                }, snykCommand)
            end
        end,
    })
end

return M
