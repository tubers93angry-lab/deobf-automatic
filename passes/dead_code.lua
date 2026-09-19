local Pass = {}

local function visit_block(stmts)
    local out = {}
    for _, s in ipairs(stmts) do
        if s.kind == "If" then
            visit_node(s)
            if s.cond.kind == "Boolean" then
                local branch = s.cond.value and s.body or (s.orelse or {})
                for _, x in ipairs(branch) do out[#out+1] = x end
            else
                out[#out+1] = s
            end
        elseif s.kind == "While" then
            visit_node(s)
            if not (s.cond.kind == "Boolean" and s.cond.value == false) then
                out[#out+1] = s
            end
        else
            visit_node(s)
            out[#out+1] = s
        end
    end
    return out
end

function visit_node(n)
    if type(n) ~= "table" then return end
    for k, v in pairs(n) do
        if type(v) == "table" then
            if v.kind then visit_node(v)
            else for i, x in ipairs(v) do if x.kind then visit_node(x) end end end
        end
    end
    if n.body then n.body = visit_block(n.body) end
    if n.orelse then n.orelse = visit_block(n.orelse) end
end

function Pass.run(ast)
    visit_node(ast)
    return ast
end

return Pass
