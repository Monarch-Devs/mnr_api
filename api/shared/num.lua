local num = {}

function num.clamp(value, min, max)
    if type(value) ~= 'number' then return error(('value must be a number, received "%s"'):format(type(value)), 2) end
    if type(min) ~= 'number' then return error(('min must be a number, received "%s"'):format(type(min)), 2) end
    if type(max) ~= 'number' then return error(('max must be a number, received "%s"'):format(type(max)), 2) end
    if min > max then return error(('min (%d) cannot be greater than max (%d)'):format(min, max), 2) end

    return math.max(min, math.min(value, max))
end

return num