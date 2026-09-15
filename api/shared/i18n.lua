local lang = GetConvar('mnr:locale', 'en')
local _loaded = false
local _locales = {}

local _keysBuffer = {}

---@param data table
---@param lvl number
local function _flatKeys(data, lvl)
    for key, value in pairs(data) do
        _keysBuffer[lvl] = key
        if type(value) == 'table' then
            _flatKeys(value, lvl + 1)
        else
            _locales[table.concat(_keysBuffer, '.', 1, lvl)] = value
        end
    end
end

---@param language string
local function _loadLocales(language)
    local data = mnr.import(('locales/%s'):format(language), 'json')
    if not data then
        error(('unable to load "locales/%s.json"'):format(language), 3)
    end

    _flatKeys(data, 1)
end

---@type MnrI18NAPI
local function i18n(key, ...)
    if not _loaded then
        _loadLocales('en')

        if lang ~= 'en' then
            _loadLocales(lang)
        end

        _loaded = true
    end

    local locale = _locales[key]

    if type(locale) ~= 'string' then
        error(('the requested "%s" locale key does not exist or has the wrong type'):format(key), 2)
    end

    if ... then
        return locale:format(...)
    end

    return locale
end

return i18n