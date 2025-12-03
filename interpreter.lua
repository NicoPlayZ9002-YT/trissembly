local args = {...}

-- Put your program here!

program = {
    'LIT 0 5',
    'LIT 1 1',
    'WHL 0 ; While loops!',
    'PRN 0 # This is another comment. LIT 0 7',
    'SUB 0 1',
    'ENW',
}

-- Read program from file if provided, else use `program` table if present
local function load_program()
    if args[1] then
        local lines = {}
        local fh = io.open(args[1], "r")
        if not fh then error("Cannot open file: " .. args[1]) end
        for line in fh:lines() do
            line = line:gsub("\r","")

            -- strip comments on file load
            line = line:gsub("%s*;.*$", ""):gsub("%s*#.*$", "")
        
            if line:match("%S") then
                table.insert(lines, line)
            end
        end
        fh:close()
        return lines
    elseif type(program) == "table" then
        return program
    else
        io.write("No file specified and no 'program' table found. Exiting.\n")
        os.exit(1)
    end
end

-- tokenizer that keeps quoted strings together
local function tokenize(line)
    local tokens = {}
    local i = 1
    local n = #line
    while i <= n do
        -- skip spaces
        local s,e = line:find("^%s+", i)
        if s then i = e + 1 end
        if i > n then break end
        local c = line:sub(i,i)
        if c == '"' then
            -- quoted string
            local j = i + 1
            local str = {}
            while j <= n do
                local ch = line:sub(j,j)
                if ch == '"' then break end
                if ch == '\\' and j < n then
                    -- support simple escapes \" \\ \n \t
                    local nextch = line:sub(j+1, j+1)
                    if nextch == 'n' then table.insert(str, '\n'); j = j + 2
                    elseif nextch == 't' then table.insert(str, '\t'); j = j + 2
                    else table.insert(str, nextch); j = j + 2 end
                else
                    table.insert(str, ch); j = j + 1
                end
            end
            if j > n then error("Unterminated string in line: " .. line) end
            table.insert(tokens, table.concat(str))
            i = j + 1
        else
            local s2,e2 = line:find("^[^%s]+", i)
            if s2 then
                table.insert(tokens, line:sub(s2,e2))
                i = e2 + 1
            else
                break
            end
        end
    end
    return tokens
end

-- safe register helpers
local regs = {}            -- registers table (indexed by numbers or names)
local function get_reg(k)
    -- numeric if number string
    if type(k) == "number" then k = tostring(k) end
    local val = regs[k]
    if val == nil then return 0 end
    return val
end
local function set_reg(k, v)
    regs[tostring(k)] = v
end

-- RNG seed for RNM
local seed = os.time() % 65536
local function lcg_next()
    -- classic LCG step
    seed = (seed * 1103515245 + 12345) % 65536
    return seed
end

-- helper to convert token to number if possible
local function maybe_number(tok)
    if type(tok) == "number" then return tok end
    local num = tonumber(tok)
    if num ~= nil then return num end
    return tok
end

-- execution helpers for blocks (FOR/WHL)
local block_stack = {}  -- stores {type="FOR"/"WHL", ip_of_start, ...}

-- operation table
local ops = {
    MOV = function(a, b) set_reg(a, get_reg(tostring(b))) end,
    ADD = function(a, b) set_reg(a, get_reg(a) + get_reg(b)) end,
    SUB = function(a, b) set_reg(a, get_reg(a) - get_reg(b)) end,
    MUL = function(a, b) set_reg(a, get_reg(a) * get_reg(b)) end,
    DIV = function(a, b) set_reg(a, get_reg(a) / get_reg(b)) end, -- float division
    MOD = function(a, b) set_reg(a, get_reg(a) % get_reg(b)) end,
    ASC = function(a, ch) 
        if type(ch) == "string" and #ch > 0 then
            set_reg(a, string.byte(ch:sub(1,1)))
        else
            error("ASC expects a character string")
        end
    end,
    CHR = function(a, b)
        local val = get_reg(b)
        set_reg(a, string.char(math.floor(val % 256)))
    end,
    LIT = function(a, v) 
        -- v might be string or number token
        if type(v) == "string" then
            set_reg(a, v)
        else
            set_reg(a, v)
        end
    end,
    INT = function(a, v) set_reg(a, math.tointeger(tonumber(v) or 0)) end,
    FLT = function(a, v) set_reg(a, tonumber(v) or 0.0) end,
    PRN = function(a) 
        local v = get_reg(a)
        print(v)
    end,
    RNM = function(a, modulus)
        modulus = tonumber(modulus) or 1
        if modulus <= 0 then modulus = 1 end
        local val = lcg_next()
        set_reg(a, val % modulus)
    end,
    RNG = function(a) set_reg(a, lcg_next()) end,
    -- Jumps and conditional helpers will be handled in main loop
}

-- load program and execute
local prog = load_program()

local ip = 1
local max_ip = #prog

-- helper to push/pop block frames
local function push_block(frame) table.insert(block_stack, frame) end
local function pop_block() return table.remove(block_stack) end

-- execute loop
while ip <= max_ip do
    local line = prog[ip]

    -- Strip comments: anything after ';' or '#'
    line = line:gsub("%s*;.*$", ""):gsub("%s*#.*$", "")

    local tokens = tokenize(line)

    if #tokens == 0 then ip = ip + 1 goto continue end
    local op = tokens[1]:upper()
    -- built-in structured ops: FOR, ENF, WHL, ENW, JMP, JEZ, JNZ
    if op == "FOR" then
        -- FOR i start end step
        if #tokens < 5 then error("FOR expects 4 args at line " .. ip) end
        local ireg = tokens[2]
        local start = maybe_number(tokens[3])
        local last = maybe_number(tokens[4])
        local step = maybe_number(tokens[5])
        step = tonumber(step) or 0
        if step == 0 then error("FOR loop step cannot be 0 (infinite loop) at line " .. ip) end
        set_reg(ireg, tonumber(start) or 0)
        -- push frame with the place to return to (ip)
        push_block({type="FOR", ireg=ireg, last=tonumber(last), step=tonumber(step), start_ip=ip+1})
        ip = ip + 1
        goto continue
    elseif op == "ENF" then
        -- end of FOR; check top block
        local top = block_stack[#block_stack]
        if not top or top.type ~= "FOR" then error("ENF without matching FOR at line " .. ip) end
        local cur = get_reg(top.ireg)
        local step = top.step
        local last = top.last
        cur = cur + step
        set_reg(top.ireg, cur)
        -- determine if we continue
        if (step > 0 and cur <= last) or (step < 0 and cur >= last) then
            -- jump back to start of FOR body (after FOR line)
            ip = top.start_ip
        else
            pop_block() -- done with FOR
            ip = ip + 1
        end
        goto continue
    elseif op == "WHL" then
        -- WHL reg  -> loop while regs[reg] ~= 0
        if #tokens < 2 then error("WHL expects 1 arg at line " .. ip) end
        local reg = tokens[2]
        -- push WHL frame and proceed (we check condition at ENW)
        push_block({type="WHL", reg=reg, start_ip=ip+1})
        ip = ip + 1
        goto continue
    elseif op == "ENW" then
        local top = block_stack[#block_stack]
        if not top or top.type ~= "WHL" then error("ENW without matching WHL at line " .. ip) end
        local val = get_reg(top.reg)
        if val ~= 0 then
            ip = top.start_ip
        else
            pop_block()
            ip = ip + 1
        end
        goto continue
    elseif op == "JMP" then
        -- JMP line_number
        if #tokens < 2 then error("JMP expects destination line number") end
        local dest = tonumber(tokens[2])
        if not dest or dest < 1 or dest > max_ip then error("Invalid JMP destination: " .. tostring(tokens[2])) end
        ip = dest
        goto continue
    elseif op == "JEZ" then
        -- JEZ reg dest  -> jump if reg == 0
        if #tokens < 3 then error("JEZ expects reg and dest") end
        local reg = tokens[2]
        local dest = tonumber(tokens[3])
        if get_reg(reg) == 0 then
            if not dest or dest < 1 or dest > max_ip then error("Invalid JEZ dest") end
            ip = dest
        else
            ip = ip + 1
        end
        goto continue
    elseif op == "JNZ" then
        -- JNZ reg dest  -> jump if reg ~= 0
        if #tokens < 3 then error("JNZ expects reg and dest") end
        local reg = tokens[2]
        local dest = tonumber(tokens[3])
        if get_reg(reg) ~= 0 then
            if not dest or dest < 1 or dest > max_ip then error("Invalid JNZ dest") end
            ip = dest
        else
            ip = ip + 1
        end
        goto continue
    end

    -- generic opcode dispatch
    local handler = ops[op]
    if not handler then
        error(("Unknown opcode '%s' at line %d"):format(op, ip))
    end

    -- prepare args for handlers: support form "OP reg value" where value may be string or number or reg name
    -- Many handlers expect (a, b) where a and b are raw tokens or numbers. We convert numeric tokens to numbers.
    local a = tokens[2]
    local b = tokens[3]

    -- For MOV/ADD/etc we often want to treat args as register keys (strings)
    -- But INT/FLT expect a numeric literal in tokens[3]
    local raw_a = a
    local raw_b = b

    -- map numeric-literal-looking args to numbers but keep register names as strings
    if a and tonumber(a) ~= nil then a = tonumber(a) end
    if b and tonumber(b) ~= nil then b = tonumber(b) end

    -- call handler protected
    local ok, err = pcall(function() handler(a, b or raw_b) end)
    if not ok then
        error(("Runtime error at line %d: %s\n>> %s"):format(ip, tostring(err), line))
    end

    ip = ip + 1
    ::continue::
end
