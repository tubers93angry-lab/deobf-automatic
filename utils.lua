local Utils = {}

function Utils.read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil, "file not found" end
    local content = f:read("*a")
    f:close()
    return content
end

function Utils.write_file(path, content)
    local f = io.open(path, "wb")
    if not f then return nil, "could not write file" end
    f:write(content)
    f:close()
    return true
end

-- converts hex string "48656c6c6f" -> "Hello"
function Utils.hex_to_string(hex)
    hex = hex:gsub("%s+", "")
    return (hex:gsub("%x%x", function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

-- converts "72 101 108" or "\72\101\108" -> text
function Utils.dec_to_string(dec)
    return (dec:gsub("\\?(%d+)", function(n)
        return string.char(tonumber(n))
    end))
end

function Utils.strip_comments(code)
    code = code:gsub("%-%-%[%[.-%]%]", "")
    code = code:gsub("%-%-[^\n]*", "")
    return code
end

return Utils
