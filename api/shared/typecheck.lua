---@class MnrTypecheckAPI
local typecheck = {}

function typecheck.single(value, definition)
    if value == nil then
        if definition.defaults ~= nil then
            return definition.defaults
        end

        if definition.required then
            return nil, 'value is required'
        end

        return nil
    end

    if type(value) ~= definition.expected then
        return nil, ('expected %s (received %s)'):format(definition.expected, type(value))
    end

    return value
end

function typecheck.schema(input, schema, output)
    if type(input) ~= 'table' then
        return nil, ('expected table (received %s)'):format(type(input))
    end

    output = output or {}

    for key, definition in pairs(schema) do
        local normalized, err = typecheck.single(input[key], definition)

        if err then
            return nil, ('%s: %s'):format(key, err)
        end

        if normalized ~= nil then
            output[key] = normalized
        end
    end

    return output
end

return typecheck