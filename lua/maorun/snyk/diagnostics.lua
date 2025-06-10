local Job = require('plenary.job') -- Assuming Job is used by one of the functions, if not remove.
-- If utils.lua is needed by these functions, add:
-- local utils = require('maorun.snyk.utils')

local M = {}

-- perform diagnostic
function M.performTestCode(currentFile, fullFile, json)
    local diagnostics = vim.tbl_map(function(result)
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
function M.performIaC(fullPath, currentFile, fullFile, json, rootDir) -- Added rootDir
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
            cwd = rootDir, -- Used rootDir
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
function M.performContainer(fullPath, currentFile, fullFile, json)
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
function M.performOpenSource(fullPath, currentFile, fullFile, json)
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

return M
