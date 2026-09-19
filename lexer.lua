local Lexer = {}
Lexer.__index = Lexer

local KEYWORDS = {
    ["and"]=true,["break"]=true,["do"]=true,["else"]=true,["elseif"]=true,
    ["end"]=true,["false"]=true,["for"]=true,["function"]=true,["if"]=true,
    ["in"]=true,["local"]=true,["nil"]=true,["not"]=true,["or"]=true,
    ["repeat"]=true,["return"]=true,["then"]=true,["true"]=true,
    ["until"]=true,["while"]=true,["goto"]=true
}

function Lexer.new(src)
    return setmetatable({ src = src, pos = 1, len = #src, tokens = {} }, Lexer)
end

function Lexer:peek(n)
    n = n or 1
    return self.src:sub(self.pos, self.pos + n - 1)
end

function Lexer:advance(n)
    self.pos = self.pos + (n or 1)
end

function Lexer:add(type, value)
    table.insert(self.tokens, { type = type, value = value, pos = self.pos })
end

function Lexer:tokenize()
    while self.pos <= self.len do
        local c = self:peek()
        if c:match("%s") then
            self:advance()
        elseif self:peek(2) == "--" then
            if self:peek(4) == "--[[" then
                local _, e = self.src:find("%]%]", self.pos)
                self.pos = (e or self.len) + 1
            else
                local _, e = self.src:find("\n", self.pos)
                self.pos = e or self.len + 1
            end
        elseif c == '"' or c == "'" then
            local quote = c
            self:advance()
            local buf = {}
            while self.pos <= self.len and self:peek() ~= quote do
                local ch = self:peek()
                if ch == "\\" then
                    table.insert(buf, self:peek(2))
                    self:advance(2)
                else
                    table.insert(buf, ch)
                    self:advance()
                end
            end
            self:advance()
            self:add("string", table.concat(buf))
        elseif self:peek(2) == "[[" then
            local _, e = self.src:find("%]%]", self.pos + 2)
            local content = self.src:sub(self.pos + 2, (e or self.len) - 2)
            self.pos = (e or self.len) + 1
            self:add("string", content)
        elseif c:match("%d") or (c == "." and self:peek(2):match("%d")) then
            local num = self.src:match("^%d*%.?%d+[eE]?[%+%-]?%d*", self.pos)
            self:advance(#num)
            self:add("number", num)
        elseif c:match("[%a_]") then
            local id = self.src:match("^[%w_]+", self.pos)
            self:advance(#id)
            if KEYWORDS[id] then
                self:add("keyword", id)
            else
                self:add("name", id)
            end
        else
            local three = self:peek(3)
            local two = self:peek(2)
            if three == "..." then
                self:advance(3); self:add("symbol", "...")
            elseif two:match("^==$") or two:match("^~=$") or two:match("^<=$")
                or two:match("^>=$") or two:match("^%.%.$") or two:match("^::") then
                self:advance(2); self:add("symbol", two)
            else
                self:advance(); self:add("symbol", c)
            end
        end
    end
    self:add("eof", "<eof>")
    return self.tokens
end

return Lexer
