local _entries = {}

local grid = {}

function grid.addEntry(data)
    local id, err = exports.mnr_api:AddEntry({ coords = data.coords })
    if not id then
        error(err, 2)
    end

    _entries[id] = data.metadata

    return id
end

function grid.removeEntry(id)
    local success, err = exports.mnr_api:RemoveEntry(id)
    if not success then
        error(err, 2)
    end

    _entries[id] = nil

    return success
end

function grid.getEntries(coords, mode, radius)
    local result, err = exports.mnr_api:GetEntries(coords, mode, radius)
    if not result then
        error(err, 2)
    end

    if mode == 'single' then
        result.metadata = _entries[result.id]
    else
        for i = 1, #result do
            result[i].metadata = _entries[result[i].id]
        end
    end

    return result
end

return grid