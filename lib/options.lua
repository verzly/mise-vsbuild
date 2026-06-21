local M = {}

local function safe_index(value, key)
    if value == nil then
        return nil
    end

    local ok, result = pcall(function()
        return value[key]
    end)

    if ok then
        return result
    end

    return nil
end

function M.table(ctx)
    local options = safe_index(ctx, "options")
    if options == nil then
        return {}
    end

    return options
end

function M.get(ctx, key)
    return safe_index(M.table(ctx), key)
end

function M.enabled(value)
    if value == true then
        return true
    end

    if value == nil or value == false then
        return false
    end

    value = tostring(value):lower()
    return value ~= "" and value ~= "0" and value ~= "false" and value ~= "no" and value ~= "off"
end

function M.disabled(value)
    if value == nil then
        return false
    end

    if value == false then
        return true
    end

    value = tostring(value):lower()
    return value == "0" or value == "false" or value == "no" or value == "off"
end

return M
