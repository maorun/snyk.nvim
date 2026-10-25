if not package.loaded['plenary.job'] and not package.preload['plenary.job'] then
    package.preload['plenary.job'] = function()
        local Job = {}
        Job.__index = Job
        function Job:new(opts)
            return setmetatable(opts or {}, Job)
        end
        function Job:start() end
        return Job
    end
end

local core = require('maorun.snyk.core')
core.checkSnykAvailable = function() end

describe('snyk setup and options', function()
    local snyk = require('maorun.snyk')

    it('should use default options when none provided', function()
        snyk.setup()
        assert.is_not_nil(snyk.options)
        assert.is_nil(snyk.options.snyk_command)
        assert.is_true(snyk.options.auto_auth)
        assert.is_true(snyk.options.setup_autocmds)
    end)

    it('should accept and apply custom snyk_command', function()
        snyk.setup({ snyk_command = '/usr/bin/snyk' })
        assert.are.equal('/usr/bin/snyk', snyk.options.snyk_command)
    end)

    it('should accept alternative option keys for snyk command', function()
        snyk.setup({ snykCommand = 'snyk-alt' })
        assert.are.equal('snyk-alt', snyk.options.snykCommand)

        snyk.setup({ command = 'snyk-cmd' })
        assert.are.equal('snyk-cmd', snyk.options.command)
    end)

    it('should accept auto_auth and setup_autocmds options', function()
        snyk.setup({ auto_auth = false, setup_autocmds = false })
        assert.is_false(snyk.options.auto_auth)
        assert.is_false(snyk.options.setup_autocmds)
    end)
end)

describe('snyk utils', function()
    local utils = require('maorun.snyk.utils')

    it('should get filename from path', function()
        assert.are.equal('utils.lua', utils.getFilename('lua/maorun/snyk/utils.lua'))
    end)

    it('should get cwd from path', function()
        assert.are.equal('lua/maorun/snyk/', utils.getCwd('lua/maorun/snyk/utils.lua'))
    end)

    it('should print without history successfully', function()
        local echoed = nil
        local old_echo = vim.api and vim.api.nvim_echo
        vim.api = vim.api or {}
        vim.api.nvim_echo = function(chunks, history, opts)
            echoed = chunks
        end

        utils.printWithoutHistory('test message')
        assert.is_not_nil(echoed)
        assert.are.equal('Snyk: test message', echoed[1][1])

        if old_echo then
            vim.api.nvim_echo = old_echo
        else
            vim.api.nvim_echo = nil
        end
    end)
end)
