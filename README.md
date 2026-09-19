# Universal Lua Deobfuscator

A multi-file, extensible Lua deobfuscator written in pure Lua. It parses Lua source into an AST, runs a pipeline of transformation passes, and re-serializes clean source code.

> **Disclaimer:** There is no such thing as a truly "universal" deobfuscator. Each obfuscator (Luraph, IronBrew, MoonSec, Prometheus, etc.) uses different techniques. This project handles the most common patterns found in *source-level* obfuscation. VM-based / bytecode obfuscators require a different approach.

---

## Table of Contents

- [Features](#features)
- [Project structure](#project-structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [How it works](#how-it-works)
- [Adding a new pass](#adding-a-new-pass)
- [Supported transformations](#supported-transformations)
- [Limitations](#limitations)
- [Roadmap](#roadmap)
- [License](#license)
- [Contributing](#contributing)

---

## Features

- **Lexer** — tokenizes Lua 5.x source (strings, long strings, numbers, keywords, symbols).
- **Parser** — builds an AST for the essential Lua grammar (locals, assignments, expressions, calls, conditionals, loops, functions, tables).
- **Pass pipeline** — modular transformations applied in order:
  - `unhex` — decodes `\xNN`, `\NN`, and raw hex strings.
  - `constant_folding` — folds `"a".."b"`, `1+2`, `3*4`, etc.
  - `string_decoder` — resolves `string.char(...)` calls into string literals.
  - `variable_renamer` — renames obfuscated locals (`_0x1a2b`, `l_1`, `III`) to `v1`, `v2`, ...
  - `dead_code` — removes `if false then ... end`, `while false`, and unreachable branches.
- **Serializer** — writes the transformed AST back to readable Lua source.
- **CLI** — simple `main.lua` entry point.

---

## Project structure

```
deobfuscator/
├── main.lua                  # CLI entry point
├── deobfuscator.lua          # pipeline + AST serializer
├── lexer.lua                 # tokenizer
├── parser.lua                # recursive-descent parser
├── ast.lua                   # AST node helpers
├── utils.lua                 # I/O + string utilities
└── passes/
    ├── unhex.lua
    ├── constant_folding.lua
    ├── string_decoder.lua
    ├── variable_renamer.lua
    └── dead_code.lua
```

---

## Requirements

- **Lua 5.3+** or **LuaJIT 2.1+**
- No external dependencies.

---

## Installation

Clone or copy the files into a folder:

```bash
git clone https://github.com/your-user/lua-deobfuscator.git
cd lua-deobfuscator
```

---

## Usage

```bash
lua main.lua <input.lua> [output.lua]
```

If `output.lua` is omitted, results are written to `deobfuscated.lua`.

### Example

**Input** (`sample.lua`):

```lua
local _0x1a2b = string.char(72,101,108,108,111)
local _0x3c4d = "776f726c64"
print(_0x1a2b .. " " .. "48 65 6c 6c 6f")
if false then print("dead code") end
```

**Command**:

```bash
lua main.lua sample.lua clean.lua
```

**Output** (`clean.lua`):

```lua
local v1 = "Hello"
local v2 = "world"
print(v1 .. " " .. "Hello")
```

---

## How it works

1. **Tokenize** — `lexer.lua` splits the source into tokens.
2. **Parse** — `parser.lua` builds an AST from the token stream.
3. **Transform** — each pass in `deobfuscator.lua` walks the AST and rewrites nodes.
4. **Serialize** — the AST is printed back as Lua source.

---

## Adding a new pass

Create a file in `passes/` exposing a `run(ast, opts)` function:

```lua
-- passes/my_pass.lua
local Pass = {}

local function visit(node)
    if type(node) ~= "table" then return node end
    for k, v in pairs(node) do
        if type(v) == "table" then
            if v.kind then node[k] = visit(v)
            else for i, x in ipairs(v) do v[i] = visit(x) end end
        end
    end
    -- your transformation here
    return node
end

function Pass.run(ast) return visit(ast) end
return Pass
```

Then register it in `deobfuscator.lua`:

```lua
local passes = {
    require("passes.unhex"),
    require("passes.constant_folding"),
    require("passes.my_pass"),   -- add here
    require("passes.string_decoder"),
    require("passes.variable_renamer"),
    require("passes.dead_code"),
}
```

---

## Supported transformations

| Pass                | What it does                                                        |
|---------------------|---------------------------------------------------------------------|
| `unhex`             | `"\x48\x65"` → `"He"`, `"48656c6c6f"` → `"Hello"`                   |
| `constant_folding`  | `"a".."b"` → `"ab"`, `2+3` → `5`, `4*5` → `20`                      |
| `string_decoder`    | `string.char(72,105)` → `"Hi"`, `"\72\105"` → `"Hi"`                |
| `variable_renamer`  | `_0x1a2b`, `l_5`, `III` → `v1`, `v2`, `v3`                          |
| `dead_code`         | `if false then ... end` removed, `while false do ... end` removed  |

---

## Limitations

- **No VM emulation** — obfuscators like Luraph, IronBrew 2, MoonSec V3 compile Lua to custom bytecode. This tool does **not** execute or decompile that bytecode.
- **No dynamic resolution** — calls to `load`, `loadstring`, `getfenv`, `_ENV`, `setmetatable` tricks, and `debug.*` are not resolved.
- **Parser coverage** — the parser covers the common Lua grammar but not 100% of Lua 5.4 (e.g., `goto`/labels, complex method chains inside expressions). If a file fails to parse, the error message reports the offending token and position.
- **Renamer scope** — only renames locals whose names match known obfuscation patterns; it will not touch globals (which could break semantics).

---

## Roadmap

- [ ] AST interpreter for `string.char`, `table.concat`, `base64`, XOR with literal keys
- [ ] `load("...")()` inlining pass
- [ ] VM pattern detector (Luraph / MoonSec signatures)
- [ ] Comment-preserving printer
- [ ] Full Lua 5.4 grammar (goto, labels, generic for, etc.)
- [ ] Unit test suite

---

## License

MIT. Do whatever you want, no warranty.

---

## Contributing

Pull requests are welcome. If you're adding a pass:

1. Keep it self-contained in `passes/`.
2. Export `run(ast, opts)`.
3. Add it to the pipeline in `deobfuscator.lua`.
4. Add a test case in the README or a `tests/` folder.

---

## Acknowledgements

Inspired by the broader Lua reverse-engineering community. Not affiliated with any obfuscator vendor.
