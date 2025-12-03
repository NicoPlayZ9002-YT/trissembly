# Trissembly v1.1

Trissembly is an open-source, register-based programming language based on assembly languages interpreted in Lua.

(NOTE: FILE SUPPORT MAY NOT WORK CURRENTLY)

## Running Trissembly (Lua 5.3+)

**Option 1 : Run a .trs file**
```
lua interpreter.lua program.trs
```
Where `program.trs` contains instructions like:
```
LIT 0 "Hello, world!"
PRN 0
```

**Option 2 : Embed program directly in `main.lua`**  
Useful for iPad/mobile environments lacking file access.
```
program = {
  'LIT 0 "Hello, world!"',
  'PRN 0'
}
```

---

# Instruction Format
- All opcodes are **three letters**.
- Arguments are separated by spaces.
- Strings must use **double quotes**.

Example:
```
LIT 0 "Hello!"
ADD 1 2
PRN 0
```

---

# Opcode List

### **Pointer Movement**
```
JMP L    ; Jump to line L
JEZ A L    ; Jump to line L if A is 0
JNZ A L   ; Jump to line L if A is NOT 0
```

### **Data Movement**
```
LIT A value     ; Load literal (string/number) into register A
INT A number    ; Load integer literal into register A
FLT A number    ; Load float literal into register A
MOV A B         ; Copy value from register B into register A
```

### **Math**
```
ADD A B         ; A = A + B
SUB A B         ; A = A - B
MUL A B         ; A = A * B
DIV A B         ; A = A / B
MOD A B         ; A = A % B
RNG A           ; RNG function from 0-65535
RNM A B         ; RNG with modulus B (random % B)
```

### **Character / ASCII**
```
ASC A "c"       ; A = ASCII code of character c
CHR A B         ; A = character represented by ASCII value in B
STR A           ; Converts A to a string, regardless of what it was before.
CCT A B         ; Concatenates A and B together, and changes A to be the result.
```

### **I/O**
```
PRN A           ; Print register A
```

### **Loops**
```
FOR R S E I     ; For-loop: R = start S, to end E, step I
  ...instructions...
ENF
```

```
WHL R           ; While-loop: runs while register R is nonzero
  ...instructions...
ENW
```

---

# Notes
- Trissembly uses 256 integer-indexed registers: `0` through `255`.
- FOR loops error if the step value is **0** (to prevent infinite loops).
- Strings must be surrounded with `"double quotes"`, and if using the lua program = {} feature, you must have them be `\"`. `'Unless your lines are in single quotes'`.
- Semicolons or hashtags are comments.

---

Trissembly will continue to update over time, so you'll need to redownload the interpreter to keep the most recent version.

# To-do List (Potential improvements)

### **Language Features**
- [ ] Add comparisons (`EQL`, `NEQ`, `LTH`, `GTH`, etc.)
- [ ] Add boolean logic ops (`AND`, `OR`, `NOT`)
- [ ] Add memory arrays (`STO`, `LOD`)
- [ ] Add function calls (`CAL`, `RET`)
- [ ] Add labels + `JMP label` support
- [ ] Add `HLT` (HALT) instruction

### **Interpreter Improvements**
- [ ] Add proper error messages (with context, like `line X: invalid value`)
- [ ] Add debug mode (`--debug`) that prints registers per step
- [ ] Add warning for infinite WHL loops
- [ ] Add file I/O ops (`RDF`, `WRF`)
- [ ] Add command-line arguments passthrough
- [ ] Add unit tests for each opcode using Lua or Python

### **Developer Tools**
- [ ] Create a VSCode syntax highlighting extension
- [ ] Add launch configs so you can F5-run `.trs` files
- [ ] Add Trissembly examples folder (loops, math, ASCII, etc.)
- [ ] Add automated GitHub Actions test runner
- [ ] Add formatter (pretty-print `.trs` code)
- [ ] Add linter (warn on unused registers, dead code, etc.)

### **Documentation**
- [ ] Add a full reference manual for every opcode
- [ ] Add beginner tutorial: "Trissembly in 10 minutes"
- [ ] Add specification for interpreter behavior
- [ ] Add changelog

### **Future / Ambitious**
- [ ] Make a Python version of the interpreter
- [ ] Make a C version (super fast)
- [ ] Make an online playground where `.trs` code runs in browser
- [ ] Write a Trissembly → Lua transpiler
- [ ] Write a bytecode compiler
