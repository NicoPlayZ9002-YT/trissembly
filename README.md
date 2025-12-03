# Trissembly

Trissembly is an open-source, register-based programming language based on assembly languages interpreted in Lua.

## Running Trissembly (Lua 5.3+)

**Option 1 — Run a .trs file**
```
lua main.lua program.trs
```
Where `program.trs` contains instructions like:
```
LIT 0 "Hello, world!"
PRN 0
```

**Option 2 — Embed program directly in `main.lua`**  
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
- Strings must be surrounded with `"double quotes"`.
- Semicolons or hashtags are comments.

---

Trissembly will continue to update over time — redownload the interpreter to stay current.

# To-do list
