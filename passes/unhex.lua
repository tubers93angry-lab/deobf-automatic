local Utils = require("utils")
local Pass = {}

local function try_hex(s)
    if #s >= 4 and #s % 2 == 0 and s:match("^%x+$") then
        return Utils.hex_to_string(s)
    end
    return nil
end

local function visit(node)
    if type(node) ~= "table" then return node end
    for k, v in pairs(node) do
        if type(v) == "table" then
            if v.kind then node[k] = visit(v)
            else for i, x in ipairs(v) do v[i] = visit(x) end end
        end
    end
    if node.kind == "String" then
        local val = node.value
        if val:find("\\x%x%x") then
            val = val:gsub("\\x(%x%x)", function(h)
                return string.char(tonumber(h, 16))
            end)
        end
        local h = try_hex(val)
        if h and h:match("%g") then val = h end
        node.value = val
    end
    return node
end

function Pass.run(ast) return visit(ast) end

return Pass
