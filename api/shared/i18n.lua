local language = GetConvar('mnr:locale', 'en')
local _locales = {}

local _keysBuffer = {}

---@param data table
---@param lvl number
local function flatKeys(data, lvl)
    for key, value in pairs(data) do
        _keysBuffer[lvl] = key
        if type(value) == 'table' then
            flatKeys(value, lvl + 1)
        else
            _locales[table.concat(_keysBuffer, '.', 1, lvl)] = value
        end
    end
end

---@param lang string
local function loadLocales(lang)
    local path = ('locales/%s.json'):format(lang)
    local file = LoadResourceFile(mnrEnv.resource, path)
    if not file then
        error(('unable to load "%s"'):format(path), 2)
    end

    local data = json.decode(file)
    if type(data) ~= 'table' then
        error(('invalid locale file "%s"'):format(path), 2)
    end

    flatKeys(data, 1)
end

loadLocales('en')

if language ~= 'en' then
    loadLocales(language)
end

---@type MnrI18NAPI
local function i18n(key, ...)
    local locale = _locales[key]

    if type(locale) == 'string' and select('#', ...) > 0 then
        return locale:format(...)
    end

    return locale or key
end

return i18n