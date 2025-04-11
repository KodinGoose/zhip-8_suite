# chip-8 assembler in zig  

This is an assemler/de_assembler for chip-8 and schip-8 written in Zig (version 0.14.0).  

You can write comments with the following syntax:  
```
#This is a comment
```
or after an opcode:  
```
exe 0xE0 # This is the same as cls  
```

The language supports labels with the following syntax:  
[label_name]: This is for declaring a label, this can be on it's own line or before an opcode  
:[label_name] This is how to specify which label to jump to.  
Labels can be used as an arguemnt for any opcode that asks for an address(Including the chip-8 variant of the "rjp" opcode)  
Example:  
```
clear: clr  
# An example of a "function"  
# The only restriction on a label is that it can only consist of letters, it can have the same name as an opcode  
ext:  
  ext  
  ret  
jmp :clear  
cal :ext  
```

The language supports decimal, hexadecimal (0xN), octal (0oN) and binary (0bN) format for numbers.  
The assembler defaults to hexadecimal unless otherwise specified.  

This is a list of all the commands that are supported, their assembly like equivalent, what they assemble to and their description  
Each opcode and number is 4 bits and represented in hexadecimal (In the following "table")  
N: A 4 bit number (NN for 8 bit and NNN for 12 bit addresses)  
rx, ry: A register (x and y values are 0-15)  
<table>
  <tr>
    <th>Alternative</th>
    <th>Assembly</th>
    <th>Opcode</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>execute NNN</td>
    <td>exe NNN</td>
    <td>0NNN</td>
    <td>Execute an instruction at NNN (The interpreter doesn't support this one)</td>
  </tr>
  <tr>
    <td>clear</td>
    <td>cls</td>
    <td>00E0</td>
    <td>Clears the screen</td>
  </tr>
  <tr>
    <td>return</td>
    <td>ret</td>
    <td>00EE</td>
    <td>Returns from a subroutine (uses the (presumably) address on the "stack")</td>
  </tr>
  <tr>
    <td>exit</td>
    <td>ext</td>
    <td>00FD</td>
    <td>Exit the interpreter (Not chip-8 compatible but supported by the interpreter nonetheless)</td>
  </tr>
  <tr>
    <td>jump NNN</td>
    <td>jmp NNN</td>
    <td>1NNN</td>
    <td>Jumps to address</td>
  </tr>
  <tr>
    <td>call NNN</td>
    <td>cal NNN</td>
    <td>2NNN</td>
    <td>Calls subroutine at address (pushes the current address onto the "stack")</td>
  </tr>
  <tr>
    <td>skipEqual rx NN</td>
    <td>seq rx NN</td>
    <td>3xNN</td>
    <td>Skip next opcode if rx == NN</td>
  </tr>
  <tr>
    <td>skipNotEqual rx NN</td>
    <td>sne rx NN</td>
    <td>4xNN</td>
    <td>Skip next opcode if rx != NN</td>
  </tr>
  <tr>
    <td>skipEqual rx ry</td>
    <td>seq rx ry</td>
    <td>5xy0</td>
    <td>Skip next opcode if rx == ry</td>
  </tr>
  <tr>
    <td>set rx NN</td>
    <td>set rx NN</td>
    <td>6xNN</td>
    <td>Set rx to NN</td>
  </tr>
  <tr>
    <td>add rx NN</td>
    <td>add rx NN</td>
    <td>7xNN</td>
    <td>Add NN to rx</td>
  </tr>
  <tr>
    <td>set rx ry</td>
    <td>set rx ry</td>
    <td>8xy0</td>
    <td>Set rx to ry</td>
  </tr>
  <tr>
    <td>set rx ry or</td>
    <td>set rx ry or</td>
    <td>8xy1</td>
    <td>Set rx to rx or ry (bitwise or)</td>
  </tr>
  <tr>
    <td>set rx ry and</td>
    <td>set rx ry and</td>
    <td>8xy2</td>
    <td>Set rx to rx and ry (bitwise and)</td>
  </tr>
  <tr>
    <td>set rx ry xor</td>
    <td>set rx ry xor</td>
    <td>8xy3</td>
    <td>Set rx to rx xor ry (bitwise xor)</td>
  </tr>
  <tr>
    <td>add rx ry</td>
    <td>add rx ry</td>
    <td>8xy4</td>
    <td>Add ry to rx, rF is set to 1 on overflow and 0 otherwise (even if rx and rF is the same register)</td>
  </tr>
  <tr>
    <td>subtract rx ry</td>
    <td>sub rx ry</td>
    <td>8xy5</td>
    <td>Subtract ry from rx, rF is set to 0 underflow and 1 otherwise (even if rx and rF is the same register)</td>
  </tr>
  <tr>
    <td>rightShift rx ry</td>
    <td>rsh rx ry</td>
    <td>8xy6</td>
    <td>Set rx to ry and shift one bit to the right, sets rF to the shifted out bit (even if rx and rF is the same register)</td>
  </tr>
  <tr>
    <td>subtract rx ry wtf</td>
    <td>sub rx ry wtf</td>
    <td>8xy7</td>
    <td>Set rx to ry - rx, rF is set to 1 on underflow and 0 otherwise (even if rx and rF is the same register)</td>
  </tr>
  <tr>
    <td>leftShift rx ry</td>
    <td>lsh rx ry</td>
    <td>8xyE</td>
    <td>Set rx to ry and shift one bit to the left, sets rF to the shifted out bit (even if rx and rF is the same register)</td>
  </tr>
  <tr>
    <td>skipNotEqual rx ry</td>
    <td>sne rx ry</td>
    <td>9xy0</td>
    <td>Skip next opcode if rx != ry</td>
  </tr>
  <tr>
    <td>skipNotEqual rx ry</td>
    <td>sne rx ry</td>
    <td>9xy0</td>
    <td>Skip next opcode if rx != ry</td>
  </tr>
  <tr>
    <td>setAddressRegister NNN</td>
    <td>sar NNN</td>
    <td>ANNN</td>
    <td>Set the address register to NNN</td>
  </tr>
  <tr>
    <td>registerJump NNN</td>
    <td>rjp NNN</td>
    <td>BNNN</td>
    <td>Jump to the address NNN + r0 (Incompatible with superchip)</td>
  </tr>
  <tr>
    <td>registerJump rx NN</td>
    <td>rjp rx NN</td>
    <td>BxNN</td>
    <td>Jump to address xNN + rx (what the fuck is this shit?) (Incompatible with chip-8 (thank god))</td>
  </tr>
  <tr>
    <td>random rx NN</td>
    <td>rnd rx NN</td>
    <td>CxNN</td>
    <td>Set rx to a random value bitwise and-ed with NN</td>
  </tr>
  <tr>
    <td>draw rx ry N</td>
    <td>drw rx ry N</td>
    <td>DxyN</td>
    <td>Draw 8xN pixel sprite at position rX, rY with data starting at the address in the address register (Having N equal to 0 makes the sprite 16 by 16 in the interpreter)</td>
  </tr>
  <tr>
    <td>skipPressed rx</td>
    <td>spr rx</td>
    <td>Ex9E</td>
    <td>Skip the following instruction if the key corresponding to the hex value currently stored in rX is pressed</td>
  </tr>
  <tr>
    <td>skipNotPressed rx</td>
    <td>snp rx</td>
    <td>ExA1</td>
    <td>Skip the following instruction if the key corresponding to the hex value currently stored in rX is not pressed</td>
  </tr>
  <tr>
    <td>getDelayTimer rx</td>
    <td>gdt rx</td>
    <td>Fx07</td>
    <td>Set rx to the delay timer</td>
  </tr>
  <tr>
    <td>waitKeyReleased</td>
    <td>wkr rx</td>
    <td>Fx0A</td>
    <td>Wait for a key release and set rX to it's corresponding hex code</td>
  </tr>
  <tr>
    <td>setDelayTimer rx</td>
    <td>sdt rx</td>
    <td>Fx15</td>
    <td>Set delay timer to rx</td>
  </tr>
  <tr>
    <td>setSoundTimer rx</td>
    <td>sst rx</td>
    <td>Fx18</td>
    <td>Set sound timer to rx</td>
  </tr>
  <tr>
    <td>addAddressRegister rx</td>
    <td>aar rx</td>
    <td>Fx1E</td>
    <td>Add rx to the address register</td>
  </tr>
  <tr>
    <td>setAddressRegisterToFont rx</td>
    <td>saf rx</td>
    <td>Fx29</td>
    <td>Set the address register to the 5 line high hex sprite (font) corresponding to the lowest nibble in rX</td>
  </tr>
  <tr>
    <td>setAddressRegisterToFont rx schip</td>
    <td>saf rx schip</td>
    <td>Fx30</td>
    <td>Set the address register to the 10 line high hex sprite (font) corresponding to the lowest nibble in rX (Incompatible with chip-8)</td>
  </tr>
  <tr>
    <td>binaryCodedDecimal rx</td>
    <td>bcd rx</td>
    <td>Fx33</td>
    <td>Write the value of rX as BCD value at the address of the address pointer and the next two bytes</td>
  </tr>
  <tr>
    <td>saveRegisters rx</td>
    <td>wrg rx</td>
    <td>Fx55</td>
    <td>Write the content of r0-rX at the memory pointed to by the address register, the address register is incremented by x+1 (x or 0 if ran in schip1.0 or schip1.1 modes respectively)</td>
  </tr>
  <tr>
    <td>loadRegisters rx</td>
    <td>rrg rx</td>
    <td>Fx65</td>
    <td>Read the bytes from memory pointed to by I into the registers r0 to rX, the address register is incremented by X+1 (x or 0 if ran in schip1.0 or schip1.1 modes respectively)</td>
  </tr>
  <tr>
    <td>saveRegistersStorage rx</td>
    <td>wrs rx</td>
    <td>Fx75</td>
    <td>Store the content of the registers r0 to rX into flags storage (outside of the addressable ram) (Not compatible with chip-8 but supported by the interpreter nonetheless)</td>
  </tr>
  <tr>
    <td>loadRegistersStorage rx</td>
    <td>rrs rx</td>
    <td>Fx85</td>
    <td>Load the registers v0 to vX from flags storage (outside the addressable ram) (Not compatible with chip-8 but supported by the interpreter)</td>
  </tr>
  <tr>
    <td>rawData N N N N</td>
    <td>raw N N N N</td>
    <td>NNNN</td>
    <td>Raw data, this can be code not supported by the assembler/de_assembler</td>
  </tr>
</table> 
