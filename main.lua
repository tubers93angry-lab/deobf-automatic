local Deobf = require("deobfuscator")
local Utils = require("utils")

local input = arg[1]
local output = arg[2] or "deobfuscated.lua"

if not input then
    print("usage: lua main.lua <input.lua> [output.lua]")
    os.exit(1)
end

local code, err = Utils.read_file(input)
if not code then
    print("error: " .. err)
    os.exit(1)
end

local ok, result = pcall(Deobf.process, code)
if not ok then
    print("deobfuscation failed: " .. tostring(result))
    os.exit(1)
end

Utils.write_file(output, result)
print("ok -> " .. output)
