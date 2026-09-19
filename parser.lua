local Parser = {}
Parser.__index = Parser

local function new(tokens)
    return setmetatable({ tokens = tokens, pos = 1 }, Parser)
end

function Parser:peek(n)
    return self.tokens[self.pos + (n or 0)]
end

function Parser:next()
    local t = self.tokens[self.pos]
    self.pos = self.pos + 1
    return t
end

function Parser:check(type, value)
    local t = self:peek()
    if not t or t.type ~= type then return false end
    if value and t.value ~= value then return false end
    return true
end

function Parser:accept(type, value)
    if self:check(type, value) then return self:next() end
    return nil
end

function Parser:expect(type, value)
    local t = self:accept(type, value)
    if not t then
        error(("expected %s %s, got %s '%s' at pos %d")
            :format(type, value or "", self:peek().type,
                    self:peek().value, self:peek().pos))
    end
    return t
end

function Parser:parse_block()
    local stmts = {}
    while true do
        local t = self:peek()
        if t.type == "eof" then break end
        if t.type == "keyword" and (t.value == "end" or t.value == "else"
            or t.value == "elseif" or t.value == "until") then break end
        if self:check("symbol", ";") then
            self:next()
        else
            local s = self:parse_statement()
            if s then table.insert(stmts, s) end
        end
    end
    return stmts
end

function Parser:parse_statement()
    local t = self:peek()
    if t.type == "keyword" then
        if t.value == "local" then
            self:next()
            local names = {}
            repeat
                local n = self:expect("name")
                table.insert(names, n.value)
            until not self:accept("symbol", ",")
            local expr = nil
            if self:accept("symbol", "=") then expr = self:parse_exprlist() end
            return { kind = "Local", names = names, exprs = expr }
        elseif t.value == "return" then
            self:next()
            local exprs = self:parse_exprlist()
            return { kind = "Return", exprs = exprs }
        elseif t.value == "if" then
            self:next()
            local cond = self:parse_expr()
            self:expect("keyword", "then")
            local body = self:parse_block()
            local orelse = {}
            if self:accept("keyword", "else") then
                orelse = self:parse_block()
            end
            self:expect("keyword", "end")
            return { kind = "If", cond = cond, body = body, orelse = orelse }
        elseif t.value == "while" then
            self:next()
            local cond = self:parse_expr()
            self:expect("keyword", "do")
            local body = self:parse_block()
            self:expect("keyword", "end")
            return { kind = "While", cond = cond, body = body }
        elseif t.value == "function" then
            self:next()
            local name = self:parse_prefix()
            local params, body = self:parse_funcbody()
            return { kind = "Function", name = name, params = params, body = body }
        elseif t.value == "do" then
            self:next()
            local body = self:parse_block()
            self:expect("keyword", "end")
            return { kind = "Do", body = body }
        end
    end
    local expr = self:parse_expr()
    if self:accept("symbol", "=") then
        local rhs = self:parse_exprlist()
        return { kind = "Assign", target = expr, exprs = rhs }
    end
    return { kind = "ExprStmt", expr = expr }
end

function Parser:parse_exprlist()
    local exprs = { self:parse_expr() }
    while self:accept("symbol", ",") do
        table.insert(exprs, self:parse_expr())
    end
    return exprs
end

local BINOP_PREC = {
    ["or"]=1, ["and"]=2,
    ["<"]=3,[">"]=3,["<="]=3,[">="]=3,["~="]=3,["=="]=3,
    [".."]=4,
    ["+"]=5,["-"]=5,
    ["*"]=6,["/"]=6,["%"]=6,
    ["^"]=7,
}

function Parser:parse_expr(min_prec)
    min_prec = min_prec or 1
    local left = self:parse_unary()
    while true do
        local t = self:peek()
        local op, prec
        if t.type == "symbol" or t.type == "keyword" then
            op = t.value
            prec = BINOP_PREC[op]
        end
        if not prec or prec < min_prec then break end
        self:next()
        local right = self:parse_expr(prec + 1)
        left = { kind = "Binary", op = op, left = left, right = right }
    end
    return left
end

function Parser:parse_unary()
    local t = self:peek()
    if t.value == "-" or t.value == "not" or t.value == "#" then
        self:next()
        local operand = self:parse_unary()
        return { kind = "Unary", op = t.value, operand = operand }
    end
    return self:parse_suffixed()
end

function Parser:parse_suffixed()
    local expr = self:parse_primary()
    while true do
        local t = self:peek()
        if t.type == "symbol" and (t.value == "." or t.value == ":") then
            self:next()
            local name = self:expect("name").value
            expr = { kind = "Index", obj = expr,
                     key = { kind = "String", value = name },
                     is_method = (t.value == ":") }
        elseif t.type == "symbol" and t.value == "[" then
            self:next()
            local key = self:parse_expr()
            self:expect("symbol", "]")
            expr = { kind = "Index", obj = expr, key = key }
        elseif t.type == "symbol" and t.value == "(" then
            self:next()
            local args = {}
            if not self:check("symbol", ")") then
                args = self:parse_exprlist()
            end
            self:expect("symbol", ")")
            expr = { kind = "Call", func = expr, args = args }
        elseif t.type == "string" then
            self:next()
            expr = { kind = "Call", func = expr,
                     args = { { kind = "String", value = t.value } } }
        else
            break
        end
    end
    return expr
end

function Parser:parse_prefix()
    local t = self:peek()
    if t.type == "name" then
        self:next()
        return { kind = "Name", name = t.value }
    end
    error("expected name, got " .. t.type .. " '" .. t.value .. "'")
end

function Parser:parse_primary()
    local t = self:next()
    if t.type == "number" then
        return { kind = "Number", value = t.value }
    elseif t.type == "string" then
        return { kind = "String", value = t.value }
    elseif t.type == "name" then
        return { kind = "Name", name = t.value }
    elseif t.type == "keyword" and (t.value == "true" or t.value == "false") then
        return { kind = "Boolean", value = (t.value == "true") }
    elseif t.type == "keyword" and t.value == "nil" then
        return { kind = "Nil" }
    elseif t.type == "keyword" and t.value == "function" then
        local params, body = self:parse_funcbody()
        return { kind = "FunctionExpr", params = params, body = body }
    elseif t.type == "symbol" and t.value == "(" then
        local e = self:parse_expr()
        self:expect("symbol", ")")
        return e
    elseif t.type == "symbol" and t.value == "{" then
        local fields = {}
        if not self:check("symbol", "}") then
            repeat
                local k, v
                if self:check("name") and self:peek(1).value == "=" then
                    k = { kind = "String", value = self:next().value }
                    self:next()
                    v = self:parse_expr()
                elseif self:check("symbol", "[") then
                    self:next()
                    k = self:parse_expr()
                    self:expect("symbol", "]")
                    self:expect("symbol", "=")
                    v = self:parse_expr()
                else
                    v = self:parse_expr()
                end
                table.insert(fields, { key = k, value = v })
            until not self:accept("symbol", ",")
        end
        self:expect("symbol", "}")
        return { kind = "Table", fields = fields }
    end
    error("unexpected token " .. t.type .. " '" .. tostring(t.value) .. "'")
end

function Parser:parse_funcbody()
    self:expect("symbol", "(")
    local params = {}
    if not self:check("symbol", ")") then
        repeat
            local p = self:expect("name")
            table.insert(params, p.value)
        until not self:accept("symbol", ",")
    end
    self:expect("symbol", ")")
    local body = self:parse_block()
    self:expect("keyword", "end")
    return params, body
end

function Parser.parse(tokens)
    local p = new(tokens)
    local ast = { kind = "Chunk", body = p:parse_block() }
    return ast
end

return Parser
