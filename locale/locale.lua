function Locale(key, ...)
    local lang = Config.Locale or 'en'
    local langData = Locales[lang]
    if not langData then
        return '[LANG_ERR: ' .. tostring(key) .. ']'
    end
    local str = langData[key]
    if not str then
        return '[MISSING: ' .. tostring(key) .. ']'
    end
    if ... then
        local success, result = pcall(string.format, str, ...)
        if success then return result else return str end
    end
    return str
end


