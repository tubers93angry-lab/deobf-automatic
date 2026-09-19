local Pass = {}

local function const_value(e)
    if e.kind == "String" then return e.value end
    if e.kind == "Number" then return tonumber(e.value) end
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
    if node.kind == "Binary" then
        local a = const_value(node.left)
        local b = const_value(node.right)
        if node.op == ".." and type(a) == "string" and type(b) == "string" then
            return { kind = "String", value = a .. b }
        end
        if node.op == "+" and type(a) == "number" and type(b) == "number" then
            return { kind = "Number", value = tostring(a + b) }
        end
        if node.op == "-" and type(a) == "number" and type(b) == "number" then
            return { kind = "Number", value = tostring(a - b) }
        end
        if node.op == "*" and type(a) == "number" and type(b) == "number" then
            return { kind = "Number", value = tostring(a * b) }
        end
    end
    return node
end

function Pass.run(ast) return visit(ast) end

return Pass
