local Utils = {}

function Utils.read_file(path)
    local ok, f = pcall(io.open, path, "rb")
    if not ok or not f then return nil, "file not found" end
    local content = f:read("*a")
    f:close()
    return content
end

function Utils.write_file(path, content)
    local ok, f = pcall(io.open, path, "wb")
    if not ok or not f then return nil, "could not write file" end
    f:write(content)
    f:close()
    return true
end

-- resto igual...
