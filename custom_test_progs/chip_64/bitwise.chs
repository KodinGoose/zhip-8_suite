resolution 64 32
jump :shift_left


shift_left:
	shift_left 9 :to_shift_left 1
	sub 9 :shift_left_call :to_shift_left
	shift_left_call: call :wrong_shift_left
jump :shift_left_saturate

to_shift_left: create 9 15

correct_shift_left:
	draw 9 9 :shift_left_x :shift_left_y :star
ret

wrong_shift_left:
ret

shift_left_x: create 4 08
shift_left_y: create 4 7


shift_left_saturate:
	shift_left 9 :shift_left_saturate_with 0 saturate
	sub 9 :shift_left_saturate_call :shift_left_saturate_with
	shift_left_saturate_call: call :wrong_shift_left_saturate
jump :shift_right

# Whether the values of the operation are correct are checked by a different test
shift_left_saturate_with: create 9 30

correct_shift_left_saturate:
	draw 9 9 :shift_left_saturate_x :shift_left_saturate_y :star
ret

wrong_shift_left_saturate:
ret

shift_left_saturate_x: create 4 08
shift_left_saturate_y: create 4 17


shift_right:
	shift_right 9 :shift_right_with 1
	sub 9 :shift_right_call :shift_right_with
	shift_right_call: call :wrong_shift_right
jump :shift_right_saturate

shift_right_with: create 9 60

correct_shift_right:
	draw 9 9 :shift_right_x :shift_right_y :star
ret

wrong_shift_right:
ret

shift_right_x: create 4 18
shift_right_y: create 4 7


shift_right_saturate:
	shift_right 9 :shift_right_saturate_with 0 saturate
	sub 9 :shift_right_saturate_call :shift_right_saturate_with
	shift_right_saturate_call: call :wrong_shift_right_saturate
jump :shift_right

# Whether the values of the operation are correct are checked by a different test
shift_right_saturate_with: create 9 30

correct_shift_right_saturate:
	draw 9 9 :shift_right_saturate_x :shift_right_saturate_y :star
ret

wrong_shift_right_saturate:
ret

shift_right_saturate_x: create 4 18
shift_right_saturate_y: create 4 17


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
