local Pass = {}

local function is_obfuscated(name)
    return name:match("^_0x%x+") or name:match("^[%a]_%x+")
        or name:match("^l_%d+") or name:match("^I+$")
end

local function visit(node, ctx, prefix)
    if type(node) ~= "table" then return node end
    if node.kind == "Local" then
        for i, n in ipairs(node.names) do
            if is_obfuscated(n) then
                ctx.counter = ctx.counter + 1
                local new = prefix .. ctx.counter
                ctx.map[n] = new
                node.names[i] = new
            end
        end
    elseif node.kind == "Name" then
        if ctx.map[node.name] then node.name = ctx.map[node.name] end
    end
    for k, v in pairs(node) do
        if type(v) == "table" and k ~= "map" then
            if v.kind then visit(v, ctx, prefix)
            else for i, x in ipairs(v) do visit(x, ctx, prefix) end end
        end
    end
    return node
end

function Pass.run(ast, opts)
    opts = opts or {}
    local ctx = { counter = 0, map = {} }
    return visit(ast, ctx, opts.prefix or "v")
end

return Pass
