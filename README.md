# chip-8 assembler in zig

This is an assemler/de_assembler for chip-8 and schip-8 written in Zig.

The text below is documentation and may look funky in browser. Download the file to view properly.

The language supports labels with the following syntax:
[label_name]: This is for declaring a label, this can be on it's own line or before an opcode
:[label_name] This is for using an label as an argument for an opcode that asks for an address (Including the chip-8 variant of the "sjp" opcode)

You can write comments with the following syntax:
#This is a comment
or after an opcode:
cal :draw # This calls the draw "function"

(To be implemented as of date 2025.03.20)
The language supports decimal, hexadecimal (0xN), octal (0oN) and binary (0bN) format for numbers.
The assembler defaults to decimal unless otherwise specified.

This is a list of all the commands that are supported, their assembly like equivalent, what they assemble to and their description
Each opcode and number is 4 bits and represented in hexadecimal (In the following "table")
N: A 4 bit number (NN for 8 bit and NNN for 12 bit addresses)
rx, ry: A register (x and y values are 0-15)
Language                          | Assembly like | Opcode | Description
----------------------------------+---------------+--------+-------------------------------------------------------------------------
execute NNN                       | exe NNN       |  0NNN  | Execute an instruction at NNN (The interpreter doesn't support this one)
clear                             | clr           |  00E0  | Clears the screen
return                            | ret           |  00EE  | Returns from a subroutine (uses the (presumably) address on the "stack")
exit                              | ext           |  00FD  | Exit the interpreter (Not chip-8 compatible but supported by the interpreter nonetheless)
jump NNN                          | jmp NNN       |  1NNN  | Jumps to address
call NNN                          | cal NNN       |  2NNN  | Calls subroutine at address (pushes the current address onto the "stack")
skipEqual rx NN                   | seq rx NN     |  3xNN  | Skip next opcode if rx == NN
skipNotEqual rx NN                | sne rx NN     |  4xNN  | Skip next opcode if rx != NN
skipEqual rx ry                   | seq rx ry     |  5xy0  | Skip next opcode if rx == ry
set rx NN                         | set rx NN     |  6xNN  | Set rx to NN
add rx NN                         | add rx NN     |  7xNN  | Add NN to rx
set rx ry                         | set rx ry     |  8xy0  | Set rx to ry
set rx ry or                      | set rx ry or  |  8xy1  | Set rx to rx or ry (bitwise or)
set rx ry and                     | set rx ry and |  8xy2  | Set rx to rx and ry (bitwise and)
set rx ry xor                     | set rx ry xor |  8xy3  | Set rx to rx xor ry (bitwise xor)
add rx ry                         | add rx ry     |  8xy4  | Add ry to rx, rF is set to 1 on overflow and 0 otherwise (even if rx and rF is the same register)
subtract rx ry                    | sub rx ry     |  8xy5  | Subtract ry from rx, rF is set to 0 underflow and 1 otherwise (even if rx and rF is the same register)
rightShift rx ry                  | rsh rx ry     |  8xy6  | Set rx to ry and shift one bit to the right, sets rF to the shifted out bit (even if rx and rF is the same register)
subtract rx ry wtf                | sub rx ry wtf |  8xy7  | Set rx to ry - rx, rF is set to 1 on underflow and 0 otherwise (even if rx and rF is the same register)
leftShift rx ry                   | lsh rx ry     |  8xyE  | Set rx to ry and shift one bit to the left, sets rF to the shifted out bit (even if rx and rF is the same register)
skipNotEqual rx ry                | sne rx ry     |  9xy0  | Skip next opcode if rx != ry
setAddressRegister NNN            | sar NNN       |  ANNN  | Set the address register to NNN
registerJump NNN                  | rjp NNN       |  BNNN  | Jump to the address NNN + r0 (Incompatible with superchip)
registerJump rx NN                | rjp rx NN     |  BxNN  | Jump to address xNN + rx (what the fuck is this shit?) (Incompatible with chip-8 (thank god))
random rx NN                      | rnd rx NN     |  CxNN  | Set rx to a random value bitwise and-ed with NN
draw rx ry N                      | drw rx ry N   |  DxyN  | Draw 8xN pixel sprite at position rX, rY with data starting at the address in the address register (Having N equal to 0 makes the sprite 16 by 16 in the interpreter)
skipPressed rx                    | spr rx        |  Ex9E  | Skip the following instruction if the key corresponding to the hex value currently stored in rX is pressed
skipNotPressed rx                 | snp rx        |  ExA1  | Skip the following instruction if the key corresponding to the hex value currently stored in rX is not pressed
getDelayTimer rx                  | gdt rx        |  Fx07  | Set rx to the delay timer
waitKeyReleased                   | wkr rx        |  Fx0A  | Wait for a key release and set rX to it's corresponding hex code
setDelayTimer rx                  | sdt rx        |  Fx15  | Set delay timer to rx
setSoundTimer rx                  | sst rx        |  Fx18  | Set sound timer to rx
addAddressRegister rx             | aar rx        |  Fx1E  | Add rx to the address register
setAddressRegisterToFont rx       | saf rx        |  Fx29  | Set the address register to the 5 line high hex sprite (font) corresponding to the lowest nibble in rX
setAddressRegisterToFont rx schip | saf rx schip  |  Fx30  | Set the address register to the 10 line high hex sprite (font) corresponding to the lowest nibble in rX (Incompatible with chip-8)
binaryCodedDecimal rx             | bcd rx        |  Fx33  | Write the value of rX as BCD value at the address of the address pointer and the next two bytes
saveRegisters rx                  | wrg rx        |  Fx55  | Write the content of r0-rX at the memory pointed to by the address register, the address register is incremented by x+1 (x or 0 if ran in schip1.0 or schip1.1 modes respectively)
loadRegisters rx                  | rrg rx        |  Fx65  | Read the bytes from memory pointed to by I into the registers r0 to rX, the address register is incremented by X+1 (x or 0 if ran in schip1.0 or schip1.1 modes respectively)
saveRegistersStorage rx           | wrs rx        |  Fx75  | Store the content of the registers r0 to rX into flags storage (outside of the addressable ram) (Not compatible with chip-8 but supported by the interpreter nonetheless)
loadRegistersStorage rx           | rrs rx        |  Fx85  | Load the registers v0 to vX from flags storage (outside the addressable ram) (Not compatible with chip-8 but supported by the interpreter )
rawData N N N N                   | raw N N N N   |  NNNN  | Raw data, this can be code not supported by the assembler/de_assembler
