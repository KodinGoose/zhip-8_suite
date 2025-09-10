# Also tests rand opcode

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

shift_left_x: create 4 04
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

shift_left_saturate_x: create 4 04
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

shift_right_x: create 4 14
shift_right_y: create 4 7


shift_right_saturate:
	shift_right 9 :shift_right_saturate_with 0 saturate
	sub 9 :shift_right_saturate_call :shift_right_saturate_with
	shift_right_saturate_call: call :wrong_shift_right_saturate
jump :and1

# Whether the values of the operation are correct are checked by a different test
shift_right_saturate_with: create 9 30

correct_shift_right_saturate:
	draw 9 9 :shift_right_saturate_x :shift_right_saturate_y :star
ret

wrong_shift_right_saturate:
ret

shift_right_saturate_x: create 4 14
shift_right_saturate_y: create 4 17


and1:
	and 9 :to_and1 1
	add 9 :and1_call :to_and1
	and1_call: call :wrong_and1
jump :and2

to_and1: create 3 0xFFFFFF 0xFFFFFF 0xFFFFFF

wrong_and1:
ret

correct_and1:
	draw 9 9 :and1_x :and1_y :star
ret

and1_x: create 4 24
and1_y: create 4 7


and2:
	and 9 :to_and2 :and_with
	add 9 :and2_call :to_and2
	and2_call: call :wrong_and2
jump :or1

to_and2: create 3 0xFFFFFF 0xFFFFFF 0xFFFFFF
and_with: create 9 1

wrong_and2:
ret

correct_and2:
	draw 9 9 :and2_x :and2_y :star
ret

and2_x: create 4 24
and2_y: create 4 17


or1:
	or 9 :to_or1 1
	add 9 :or1_call :to_or1
	or1_call: call :wrong_or1
jump :or2

to_or1: create 9 1

wrong_or1:
ret

correct_or1:
	draw 9 9 :or1_x :or1_y :star
ret

or1_x: create 4 34
or1_y: create 4 7


or2:
	or 9 :to_or2 :and_with
	add 9 :or2_call :to_or2
	or2_call: call :wrong_or2
jump :xor1

to_or2: create 9 1
or_with: create 9 1

wrong_or2:
ret

correct_or2:
	draw 9 9 :or2_x :or2_y :star
ret

or2_x: create 4 34
or2_y: create 4 17


xor1:
	xor 9 :to_xor1 1
	add 9 :xor1_call :to_xor1
	xor1_call: call :wrong_xor1
jump :xor2

to_xor1: create 9 0

wrong_xor1:
ret

cxorrect_xor1:
	draw 9 9 :xor1_x :xor1_y :star
ret

xor1_x: create 4 44
xor1_y: create 4 7


xor2:
	xor 9 :to_xor2 :xor_with
	add 9 :xor2_call :to_xor2
	xor2_call: call :wrong_xor2
jump :not1

to_xor2: create 9 0
xor_with: create 9 1

wrong_xor2:
ret

correct_xor2:
	draw 9 9 :xor2_x :xor2_y :star
ret

xor2_x: create 4 44
xor2_y: create 4 17


not1:
	not 9 :to_not1
	add 9 :not1_call :to_not1
	not1_call: call :wrong_not1
jump :rand

to_not1: create 3 0xFFFFFF 0xFFFFFF 0xFFFFFE

wrong_not1:
ret

correct_not1:
	draw 9 9 :not1_x :not1_y :star
ret

not1_x: create 4 54
not1_y: create 4 7


rand:
	rand 9 :to_rand_1
	rand 9 :to_rand_2
	# Two random values right after each other cannot be the same since	the rng is only pseudo random
	# Even if the implementation of the rng allows two equal values in sequence the probability is so small that I don't care
	jump :rand_add 9 if :to_rand_1 != :to_rand_2
	jump :rand_call
	rand_add: add 9 :rand_call 1
	rand_call: call :wrong_rand
halt

to_rand_1: create 9 0
to_rand_2: create 9 0

wrong_rand:
ret

correct_rand:
	draw 9 9 :rand_x :rand_y :star
ret

rand_x: create 4 54
rand_y: create 4 17


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
