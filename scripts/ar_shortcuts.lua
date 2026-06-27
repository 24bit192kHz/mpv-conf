local key_mapping = {
    ["ض"] = "q", ["ص"] = "w", ["ث"] = "e", ["ق"] = "r", ["ف"] = "t",
    ["غ"] = "y", ["ع"] = "u", ["ه"] = "i", ["خ"] = "o", ["ح"] = "p",
    ["ج"] = "[", ["د"] = "]", ["\\"] = "\\", ["ش"] = "a", ["س"] = "s",
    ["ي"] = "d", ["ب"] = "f", ["ل"] = "g", ["ا"] = "h", ["ت"] = "j",
    ["ن"] = "k", ["م"] = "l", ["ك"] = ";", ["ط"] = "'", ["ئ"] = "z",
    ["ء"] = "x", ["ؤ"] = "c", ["ر"] = "v", ["ﻻ"] = "b", ["ى"] = "n",
    ["ة"] = "m", ["و"] = ",", ["ز"] = ".", ["ظ"] = "/", ["َ"] = "Q",
    ["ً"] = "W", ["ُ"] = "E", ["ٌ"] = "R", ["ﻹ"] = "T", ["إ"] = "Y",
    ["`"] = "U", ["÷"] = "I", ["×"] = "O", ["؛"] = "P", ["<"] = "{",
    [">"] = "}", ["|"] = "|", ["ِ"] = "A", ["ٍ"] = "S", ["]"] = "D",
    ["["] = "F", ["ﻷ"] = "G", ["أ"] = "H", ["ـ"] = "J", ["،"] = "K",
    ["/"] = "L", [":"] = ":", ["\""] = "\"", ["~"] = "Z", ["ْ"] = "X",
    ["}"] = "C", ["{"] = "V", ["ﻵ"] = "B", ["آ"] = "N", ["'"] = "M",
    [","] = "<", ["."] = ">", ["؟"] = "?", ["ذ"] = "`"
}

local function handle_key(name, modifiers)
    local key = key_mapping[name]
    if key then
        if modifiers and #modifiers > 0 then
            for _, mod in ipairs(modifiers) do
                key = mod .. "+" .. key
            end
        end
        mp.commandv("keypress", key)
        return true
    end
    return false
end

-- Bind the keys without modifiers
for original_key, _ in pairs(key_mapping) do
    mp.add_forced_key_binding(original_key, "handle_" .. original_key, function() handle_key(original_key, nil) end, {complex = false, repeatable = false})
end

-- Handle modifier keys
local modifiers = {"ctrl", "alt"}
for _, mod in ipairs(modifiers) do
    for original_key, _ in pairs(key_mapping) do
        local binding_name = mod .. "+" .. original_key
        mp.add_forced_key_binding(binding_name, "handle_" .. mod .. "_" .. original_key, function() 
            handle_key(original_key, {mod}) 
        end, {complex = false, repeatable = false})
    end
end
