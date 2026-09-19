local Utils = require("utils")
local Pass = {}

local function eval_number(e)
    if e.kind == "Number" then return tonumber(e.value) end
    return nil
end

local function try_string_char(call)
    if call.kind ~= "Call" then return nil end
    local f = call.func
    if f.kind == "Index" and f.obj.kind == "Name" and f.obj.name == "string"
       and f.key.kind == "String" and f.key.value == "char" then
        local buf = {}
        for _, a in ipairs(call.args) do
            local v = eval_number(a)
            if type(v) ~= "number" then return nil end
            buf[#buf+1] = string.char(v)
        end
        return table.concat(buf)
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
    if node.kind == "Call" then
        local s = try_string_char(node)
        if s then return { kind = "String", value = s } end
    end
    if node.kind == "String" and node.value:find("\\%d") then
        return { kind = "String", value = Utils.dec_to_string(node.value) }
    end
    return node
end

function Pass.run(ast) return visit(ast) end

return Pass
