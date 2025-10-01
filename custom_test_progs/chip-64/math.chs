# Tests add, sub, mul, div and mod opcodes

resolution 64 32


add:
	add 9 :add_call1 1
	add_call1: call :wrong_add1
	add 9 :add_call2 :to_add
	add_call2: call :wrong_add2
jump :sub

to_add: create 9 1

wrong_add1:
ret

correct_add1:
	draw 9 9 :add_x1 :add_y1 :star
ret

add_x1: create 4 8
add_y1: create 4 7

wrong_add2:
ret

correct_add2:
	draw 9 9 :add_x2 :add_y2 :star
	present
ret

add_x2: create 4 8
add_y2: create 4 17


sub:
	sub 9 :sub_call1 31
	sub_call1: call :wrong_sub1
	sub 9 :sub_call2 :to_sub
	sub_call2: call :wrong_sub2
jump :mul

to_sub: create 9 31

correct_sub1:
	draw 9 9 :sub_x1 :sub_y1 :star
	present
ret

wrong_sub1:
ret

sub_x1: create 4 18
sub_y1: create 4 7

correct_sub2:
	draw 9 9 :sub_x2 :sub_y2 :star
	present
ret

wrong_sub2:
ret

sub_x2: create 4 18
sub_y2: create 4 17


mul:
	mul 9 :to_mul1 2
	add 9 :to_mul1 1
	sub 9 :mul_call1 :to_mul1
	mul_call1: call :wrong_mul1
	mul 9 :to_mul2 :mul_with
	add 9 :to_mul2 1
	sub 9 :mul_call2 :to_mul2
	mul_call2: call :wrong_mul2
jump :div

to_mul1: create 9 15
to_mul2: create 9 15
mul_with: create 9 2

correct_mul1:
	draw 9 9 :mul_x1 :mul_y1 :star
	present
ret

wrong_mul1:
ret

mul_x1: create 4 28
mul_y1: create 4 7

correct_mul2:
	draw 9 9 :mul_x2 :mul_y2 :star
	present
ret

wrong_mul2:
ret

mul_x2: create 4 28
mul_y2: create 4 17


div:
	div 9 :to_div1 2
	sub 9 :div_call1 :to_div1
	div_call1: call :wrong_div1
	div 9 :to_div2 :div_with
	sub 9 :div_call2 :to_div2
	div_call2: call :wrong_div2
jump :mod

to_div1: create 9 63
to_div2: create 9 63
div_with: create 9 2

correct_div1:
	draw 9 9 :div_x1 :div_y1 :star
	present
ret

wrong_div1:
ret

div_x1: create 4 38
div_y1: create 4 7

correct_div2:
	draw 9 9 :div_x2 :div_y2 :star
	present
ret

wrong_div2:
ret

div_x2: create 4 38
div_y2: create 4 17


mod:
	mod 9 :to_mod1 32
	sub 9 :mod_call1 :to_mod1
	mod_call1: call :wrong_mod1
	mod 9 :to_mod2 :mod_with
	sub 9 :mod_call2 :to_mod2
	mod_call2: call :wrong_mod2
halt

to_mod1: create 9 63
to_mod2: create 9 63
mod_with: create 9 32

correct_mod1:
	draw 9 9 :mod_x1 :mod_y1 :star
	present
ret

wrong_mod1:
ret

mod_x1: create 4 48
mod_y1: create 4 7

correct_mod2:
	draw 9 9 :mod_x2 :mod_y2 :star
	present
ret

wrong_mod2:
ret

mod_x2: create 4 48
mod_y2: create 4 17


star:
create 4 0x000000FF 0x000000FF 0x000000FF 0x000000FF 0xFFFF00FF 0x000000FF 0x000000FF 0x000000FF 0x000000FF
create 4 0x000000FF 0x000000FF 0x000000FF 0xFFFF00FF 0xE8E800FF 0xFFFF00FF 0x000000FF 0x000000FF 0x000000FF
create 4 0x000000FF 0x000000FF 0x000000FF 0xFFFF00FF 0xE8E800FF 0xFFFF00FF 0x000000FF 0x000000FF 0x000000FF
create 4 0x000000FF 0xFFFF00FF 0xFFFF00FF 0xE8E800FF 0xE8E800FF 0xE8E800FF 0xFFFF00FF 0xFFFF00FF 0x000000FF
create 4 0xFFFF00FF 0xE8E800FF 0xE8E800FF 0xE8E800FF 0xE8E800FF 0xE8E800FF 0xE8E800FF 0xE8E800FF 0xFFFF00FF
create 4 0x000000FF 0xFFFF00FF 0xFFFF00FF 0xE8E800FF 0xE8E800FF 0xE8E800FF 0xFFFF00FF 0xFFFF00FF 0x000000FF
create 4 0x000000FF 0x000000FF 0x000000FF 0xFFFF00FF 0xE8E800FF 0xFFFF00FF 0x000000FF 0x000000FF 0x000000FF
create 4 0x000000FF 0x000000FF 0x000000FF 0xFFFF00FF 0xE8E800FF 0xFFFF00FF 0x000000FF 0x000000FF 0x000000FF
create 4 0x000000FF 0x000000FF 0x000000FF 0x000000FF 0xFFFF00FF 0x000000FF 0x000000FF 0x000000FF 0x000000FF
