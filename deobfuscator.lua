local Lexer = require("lexer")
local Parser = require("parser")

local passes = {
    require("passes.unhex"),
    require("passes.constant_folding"),
    require("passes.string_decoder"),
    require("passes.variable_renamer"),
    require("passes.dead_code"),
}

local Deobf = {}

local function serialize(node, indent)
    indent = indent or ""

    local function ser(e, ind)
        if type(e) ~= "table" then return tostring(e) end
        if e.kind == "Number" then return e.value end
        if e.kind == "String" then return string.format("%q", e.value) end
        if e.kind == "Boolean" then return tostring(e.value) end
        if e.kind == "Nil" then return "nil" end
        if e.kind == "Name" then return e.name end
        if e.kind == "Binary" then
            return ser(e.left, ind) .. " " .. e.op .. " " .. ser(e.right, ind)
        end
        if e.kind == "Unary" then
            return e.op .. " " .. ser(e.operand, ind)
        end
        if e.kind == "Index" then
            if e.is_method then
                return ser(e.obj, ind) .. ":" .. e.key.value
            end
            if e.key.kind == "String" and e.key.value:match("^[%a_][%w_]*$") then
                return ser(e.obj, ind) .. "." .. e.key.value
            end
            return ser(e.obj, ind) .. "[" .. ser(e.key, ind) .. "]"
        end
        if e.kind == "Call" then
            local args = {}
            for _, a in ipairs(e.args) do args[#args+1] = ser(a, ind) end
            return ser(e.func, ind) .. "(" .. table.concat(args, ", ") .. ")"
        end
        if e.kind == "Table" then
            local parts = {}
            for _, f in ipairs(e.fields) do
                if f.key then
                    parts[#parts+1] = ser(f.key, ind) .. " = " .. ser(f.value, ind)
                else
                    parts[#parts+1] = ser(f.value, ind)
                end
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        end
        if e.kind == "FunctionExpr" then
            return "function(" .. table.concat(e.params, ", ") .. ") ... end"
        end
        return "--[[ expr " .. tostring(e.kind) .. " ]]"
    end

    local out = {}
    local function emit(line) out[#out+1] = indent .. line end

    local function stmt(s, ind)
        if s.kind == "Local" then
            local names = table.concat(s.names, ", ")
            if s.exprs and #s.exprs > 0 then
                local exprs = {}
                for _, e in ipairs(s.exprs) do exprs[#exprs+1] = ser(e, ind) end
                emit("local " .. names .. " = " .. table.concat(exprs, ", "))
            else
                emit("local " .. names)
            end
        elseif s.kind == "Assign" then
            local exprs = {}
            for _, e in ipairs(s.exprs) do exprs[#exprs+1] = ser(e, ind) end
            emit(ser(s.target, ind) .. " = " .. table.concat(exprs, ", "))
        elseif s.kind == "Return" then
            if #s.exprs == 0 then
                emit("return")
            else
                local exprs = {}
                for _, e in ipairs(s.exprs) do exprs[#exprs+1] = ser(e, ind) end
                emit("return " .. table.concat(exprs, ", "))
            end
        elseif s.kind == "ExprStmt" then
            emit(ser(s.expr, ind))
        elseif s.kind == "If" then
            emit("if " .. ser(s.cond, ind) .. " then")
            for _, x in ipairs(s.body) do stmt(x, ind .. "  ") end
            if s.orelse and #s.orelse > 0 then
                emit("else")
                for _, x in ipairs(s.orelse) do stmt(x, ind .. "  ") end
            end
            emit("end")
        elseif s.kind == "While" then
            emit("while " .. ser(s.cond, ind) .. " do")
            for _, x in ipairs(s.body) do stmt(x, ind .. "  ") end
            emit("end")
        elseif s.kind == "Do" then
            emit("do")
            for _, x in ipairs(s.body) do stmt(x, ind .. "  ") end
            emit("end")
        elseif s.kind == "Function" then
            emit("function " .. ser(s.name, ind) .. "(" ..
                 table.concat(s.params, ", ") .. ")")
            for _, x in ipairs(s.body) do stmt(x, ind .. "  ") end
            emit("end")
        else
            emit("--[[ stmt " .. tostring(s.kind) .. " ]]")
        end
    end

    for _, s in ipairs(node.body) do stmt(s, indent) end
    return table.concat(out, "\n")
end

function Deobf.process(source, opts)
    opts = opts or {}
    local tokens = Lexer.new(source):tokenize()
    local ast = Parser.parse(tokens)
    for _, pass in ipairs(passes) do
        ast = pass.run(ast, opts)
    end
    return serialize(ast), ast
end

return Deobf
