# TODO: expand to mul, div and mod

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
ret

add_x2: create 4 8
add_y2: create 4 17

sub:
	sub 9 :sub_call1 30
	sub_call1: call :wrong_sub1
	sub 9 :sub_call2 :to_sub
	sub_call2: call :wrong_sub2
	halt
jump :sub

to_sub: create 9 30

correct_sub1:
	draw 9 9 :sub_x1 :sub_y1 :star
ret

wrong_sub1:
ret

sub_x1: create 4 18
sub_y1: create 4 7

correct_sub2:
	draw 9 9 :sub_x2 :sub_y2 :star
ret

wrong_sub2:
ret

sub_x2: create 4 18
sub_y2: create 4 17

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
