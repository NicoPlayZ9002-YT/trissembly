-- Trissembly interpreter (reconstructed)
-- Lua 5.3+ recommended
-- Usage: lua main.lua program.trs
-- Or edit this file and set `program = { ... }` for inline testing.

local args = {...}

-- Optional inline program for quick testing (uncomment to use)
-- 99bottles.trs, program-table-fied
program = {
    'LIT A "Hello, Trissembly!"',
    'PRN A'
}
-- read program from file or inline table
local function load_raw_lines()
    if args[1] then
        local fh = io.open(args[1], "r")
        if not fh then error("Cannot open file: " .. args[1]) end
        local lines = {}
        for line in fh:lines() do
            -- normalize endings
            line = line:gsub("\r","")
            table.insert(lines, line)
        end
        fh:close()
        return lines
    elseif type(program) == "table" then
        local copy = {}
        for _,ln in ipairs(program) do table.insert(copy, ln) end
        return copy
    else
        io.write("No file specified and no 'program' table found. Exiting.\n")
        os.exit(1)
    end
end

-- tokenizer: splits into tokens while keeping quoted strings, removes comments
local function tokenize_raw(line)
    -- remove comments starting with ; or #
    local cleaned = line
    -- handle inline comments: find first unquoted ; or #
    local inquote = false
    local res_chars = {}
    for i = 1, #cleaned do
        local ch = cleaned:sub(i,i)
        if ch == '"' then
            inquote = not inquote
            table.insert(res_chars, ch)
        elseif (ch == ';' or ch == '#') and not inquote then
            break -- strip rest
        else
            table.insert(res_chars, ch)
        end
    end
    cleaned = table.concat(res_chars)
    -- trim
    cleaned = cleaned:match("^%s*(.-)%s*$")
    if cleaned == "" then return {} end

    -- support label forms: "name:" -> treat as LBL name
    local colon_label = cleaned:match("^([A-Za-z_][%w_]*)%s*:%s*(.*)")
    if colon_label then
        local lbl = cleaned:match("^([A-Za-z_][%w_]*)%s*:")
        local rest = cleaned:sub(#lbl+2)
        if rest:match("%S") then
            -- produce a LBL token then continue tokenizing the rest
            local t = {"LBL", lbl}
            for _,tok in ipairs(tokenize_raw(rest)) do table.insert(t, tok) end
            return t
        else
            return {"LBL", lbl}
        end
    end

    local tokens = {}
    local i = 1
    local n = #cleaned
    while i <= n do
        -- skip spaces
        local s,e = cleaned:find("^%s+", i)
        if s then i = e + 1 end
        if i > n then break end
        local c = cleaned:sub(i,i)
        if c == '"' then
            -- quoted string
            local j = i + 1
            local str = {}
            while j <= n do
                local ch = cleaned:sub(j,j)
                if ch == '"' then break end
                if ch == '\\' and j < n then
                    local nextch = cleaned:sub(j+1, j+1)
                    if nextch == 'n' then table.insert(str, '\n'); j = j + 2
                    elseif nextch == 't' then table.insert(str, '\t'); j = j + 2
                    elseif nextch == '"' then table.insert(str, '"'); j = j + 2
                    elseif nextch == '\\' then table.insert(str, '\\'); j = j + 2
                    else table.insert(str, nextch); j = j + 2 end
                else
                    table.insert(str, ch); j = j + 1
                end
            end
            if j > n then error("Unterminated string in line: " .. line) end
            table.insert(tokens, table.concat(str))
            i = j + 1
        else
            local s2,e2 = cleaned:find("^[^%s]+", i)
            if s2 then
                table.insert(tokens, cleaned:sub(s2,e2))
                i = e2 + 1
            else
                break
            end
        end
    end
    return tokens
end

-- safe register helpers (named registers allowed)
local regs = {}            -- key: string (numbers also stored as strings)
local function get_reg(key)
    if key == nil then return 0 end
    local k = tostring(key)
    local v = regs[k]
    if v == nil then
        -- default numeric registers to 0, strings to ""
        return 0
    end
    return v
end
local function set_reg(key, val)
    regs[tostring(key)] = val
end

-- LCG RNG seed (16-bit like before)
local seed = os.time() % 65536
local function lcg_next()
    seed = (seed * 1103515245 + 12345) % 65536
    return seed
end

-- program loading + label prepass
local raw_lines = load_raw_lines()
local instrs = {}     -- filtered instruction lines (strings)
local labels = {}     -- map label -> instr index (1-based)
for idx,line in ipairs(raw_lines) do
    local toks = tokenize_raw(line)
    if #toks > 0 then
        -- if first token is LBL, consume and record
        if toks[1]:upper() == "LBL" then
            if not toks[2] then error("LBL with no name at source line " .. idx) end
            local name = toks[2]
            labels[name] = #instrs + 1
            -- if there are tokens after the LBL name, turn them into a new instruction
            if #toks > 2 then
                local rest = {}
                for i=3,#toks do table.insert(rest, toks[i]) end
                table.insert(instrs, table.concat(rest, " "))
            end
        else
            table.insert(instrs, line)
        end
    end
end

-- helper: resolve destination which can be a number string or label
local function resolve_dest(tok)
    if not tok then return nil end
    local n = tonumber(tok)
    if n then return n end
    -- assume label
    local dest = labels[tok]
    return dest
end

-- operation table (3-letter names)
local ops = {
    MOV = function(a, b) set_reg(a, get_reg(b)) end,
    ADD = function(a, b) set_reg(a, (get_reg(a) or 0) + (get_reg(b) or 0)) end,
    SUB = function(a, b) set_reg(a, (get_reg(a) or 0) - (get_reg(b) or 0)) end,
    MUL = function(a, b) set_reg(a, (get_reg(a) or 0) * (get_reg(b) or 0)) end,
    DIV = function(a, b) 
        local bv = get_reg(b)
        if bv == 0 then error("DIV by zero") end
        set_reg(a, (get_reg(a) or 0) / bv)
    end,
    MOD = function(a, b)
        local bv = get_reg(b)
        if bv == 0 then error("MOD by zero") end
        set_reg(a, (get_reg(a) or 0) % bv)
    end,
    ASC = function(a, ch)
        if type(ch) ~= "string" or #ch == 0 then error("ASC expects a character string") end
        set_reg(a, string.byte(ch:sub(1,1)))
    end,
    CHR = function(a, b)
        local val = get_reg(b)
        set_reg(a, string.char(math.floor(val % 256)))
    end,
    LIT = function(a, v)
        -- store literal (string or number token)
        set_reg(a, v)
    end,
    INT = function(a, v)
        set_reg(a, math.tointeger(tonumber(v) or 0))
    end,
    FLT = function(a, v)
        set_reg(a, tonumber(v) or 0.0)
    end,
    PRN = function(a)
        local v = get_reg(a)
        io.write(tostring(v) .. "\n")
    end,
    RNG = function(a) set_reg(a, lcg_next()) end,
    RNM = function(a, modulus)
        local m = tonumber(modulus) or 1
        if m <= 0 then m = 1 end
        set_reg(a, lcg_next() % m)
    end,
    CCT = function(a, b)
        local av = get_reg(a)
        local bv = get_reg(b)
        set_reg(a, tostring(av) .. tostring(bv))
    end,
    STR = function(a) set_reg(a, tostring(get_reg(a))) end,
    -- a few helpers you might want:
    NOP = function() end,
}

-- Execution state for blocks
local block_stack = {}  -- frames for FOR and WHL

local function push_block(frame) table.insert(block_stack, frame) end
local function pop_block() return table.remove(block_stack) end

-- Execution loop
local ip = 1
local max_ip = #instrs

local function maybe_number(tok)
    if tok == nil then return nil end
    local n = tonumber(tok)
    if n ~= nil then return n end
    return tok
end

while ip <= max_ip do
    local raw_line = instrs[ip]
    local tokens = tokenize_raw(raw_line)
    if #tokens == 0 then ip = ip + 1 goto continue end
    local op = tokens[1]:upper()

    -- structured control
    if op == "FOR" then
        -- FOR i start end step
        if #tokens < 5 then error("FOR expects: FOR var start end step (line " .. ip .. ")") end
        local ireg = tokens[2]
        local start = maybe_number(tokens[3])
        local last = maybe_number(tokens[4])
        local step = maybe_number(tokens[5])
        step = tonumber(step) or 0
        if step == 0 then error("FOR step cannot be 0 (infinite loop) at instr " .. ip) end
        set_reg(ireg, tonumber(start) or 0)
        push_block({type="FOR", ireg=ireg, last=tonumber(last), step=tonumber(step), start_ip=ip+1})
        ip = ip + 1
        goto continue
    elseif op == "ENF" then
        local top = block_stack[#block_stack]
        if not top or top.type ~= "FOR" then error("ENF without matching FOR at instr " .. ip) end
        local cur = get_reg(top.ireg)
        local step = top.step
        local last = top.last
        cur = cur + step
        set_reg(top.ireg, cur)
        if (step > 0 and cur <= last) or (step < 0 and cur >= last) then
            ip = top.start_ip
        else
            pop_block()
            ip = ip + 1
        end
        goto continue
    elseif op == "WHL" then
        -- WHL reg  -> loop while regs[reg] ~= 0
        if #tokens < 2 then error("WHL expects 1 arg at instr " .. ip) end
        local reg = tokens[2]
        -- push WHL frame; we will check at ENW whether to loop again
        push_block({type="WHL", reg=reg, start_ip=ip+1})
        ip = ip + 1
        goto continue
    elseif op == "ENW" then
        local top = block_stack[#block_stack]
        if not top or top.type ~= "WHL" then error("ENW without matching WHL at instr " .. ip) end
        local val = get_reg(top.reg)
        if val ~= 0 then
            ip = top.start_ip
        else
            pop_block()
            ip = ip + 1
        end
        goto continue
    end

    -- jumps (accept numeric dest or label)
    if op == "JMP" then
        if #tokens < 2 then error("JMP expects a destination (number or label) at instr " .. ip) end
        local dest = resolve_dest(tokens[2])
        if not dest or dest < 1 or dest > max_ip then error("Invalid JMP destination " .. tostring(tokens[2]) .. " at instr " .. ip) end
        ip = dest
        goto continue
    elseif op == "JEZ" then
        if #tokens < 3 then error("JEZ expects reg and dest at instr " .. ip) end
        local reg = tokens[2]
        local dest = resolve_dest(tokens[3])
        if get_reg(reg) == 0 then
            if not dest or dest < 1 or dest > max_ip then error("Invalid JEZ destination " .. tostring(tokens[3]) .. " at instr " .. ip) end
            ip = dest
        else
            ip = ip + 1
        end
        goto continue
    elseif op == "JNZ" then
        if #tokens < 3 then error("JNZ expects reg and dest at instr " .. ip) end
        local reg = tokens[2]
        local dest = resolve_dest(tokens[3])
        if get_reg(reg) ~= 0 then
            if not dest or dest < 1 or dest > max_ip then error("Invalid JNZ destination " .. tostring(tokens[3]) .. " at instr " .. ip) end
            ip = dest
        else
            ip = ip + 1
        end
        goto continue
    end

    -- generic op dispatch
    local handler = ops[op]
    if not handler then
        error(("Unknown opcode '%s' at instr %d -> %s"):format(op, ip, tostring(raw_line)))
    end

    -- prepare arguments:
    -- many ops treat arguments as register keys (strings) except INT/FLT/LIT which expect literal in token[3]
    local a_token = tokens[2]
    local b_token = tokens[3]
    -- convert numeric literal-looking register indices to strings (we store all regs by string keys)
    -- but keep tokens as-is for INT/FLT/LIT where handler expects the literal
    local call_a = a_token
    local call_b = b_token

    -- If a_token is numeric, keep as string key (so registers "0","1" etc.)
    if a_token and tonumber(a_token) ~= nil then call_a = tostring(a_token) end
    if b_token and tonumber(b_token) ~= nil then call_b = tostring(b_token) end

    -- call handler in pcall for clearer error messages
    local ok, err = pcall(function() handler(call_a, (b_token ~= nil) and ( (op == "INT" or op == "FLT" or op == "LIT" or op == "ASC") and b_token or call_b ) or nil) end)
    if not ok then
        error(("Runtime error at instr %d: %s\n>> %s"):format(ip, tostring(err), raw_line))
    end

    ip = ip + 1
    ::continue::
end

-- end of interpreter
