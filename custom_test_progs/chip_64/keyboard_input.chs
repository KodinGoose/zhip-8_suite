resolution 64 32
jump :loop_1

# Set loop_back_arg before calling using jump
# Loops while key is pressed
loop_back:
	key_pressed 44 :loop_back jump
jump loop_back_arg: *0

loop_1:
	key_pressed 44 :draw_1 jump
jump :loop_1

x_1: create 4 12
y_1: create 4 7

draw_1:
	draw 9 9 :x_1 :y_1 :star
	present
	# 0x78 == loop_2:
	set 8 :loop_back_arg 0x78
	jump :loop_back

loop_2:
	key_pressed 44 :draw_2 call
	jump :loop_3 1 if :done_2 == :done_2_correct_val
jump :loop_2

done_2: create 1 0
done_2_correct_val: create 1 1

x_2: create 4 12
y_2: create 4 17
draw_2:
	draw 9 9 :x_2 :y_2 :star
	present
	set 1 :done_2 1
	# 0xf8 == loop_3:
	set 8 :loop_back_arg 0xf8
	jump :loop_back
ret


loop_3:
	key_pressed 44 :draw_3 jump wait

x_3: create 4 22
y_3: create 4 7

draw_3:
	draw 9 9 :x_3 :y_3 :star
	present
	# 0x145 == loop_4:
	set 8 :loop_back_arg 0x145
	jump :loop_back

loop_4:
	key_pressed 44 :draw_4 call wait
jump :loop_5

x_4: create 4 22
y_4: create 4 17
draw_4:
	draw 9 9 :x_4 :y_4 :star
	present
	# 0x1B0 == loop_5_start:
	set 8 :loop_back_arg 0x1B0
	jump :loop_back
ret


loop_back_released:
	key_released 44 :loop_back_released jump
jump loop_back_released_arg: *0


do_loop_5:
# 0x1CC == loop_5:
set 8 :loop_back_released_arg 0x1CC
jump :loop_back_released
loop_5:
	key_released 44 :draw_5 jump
jump :loop_5

x_5: create 4 32
y_5: create 4 7
draw_5:
	draw 9 9 :x_5 :y_5 :star
	present
	# 0x222 == loop_6:
	set 8 :loop_back_released_arg 0x222
	jump :loop_back_released

loop_6:
	key_released 44 :draw_6 call
	jump :loop_7 1 if :done_6 == :done_6_correct_val
jump :loop_6

done_6: create 1 0
done_6_correct_val: create 1 1

x_6: create 4 32
y_6: create 4 17
draw_6:
	draw 9 9 :x_6 :y_6 :star
	present
	set 1 :done_6 1
	# 0x2A2 == loop_7:
	set 8 :loop_back_released_arg 0x2A2
	jump :loop_back_released
ret


loop_7:
	key_released 44 :draw_7 jump wait

x_7: create 4 42
y_7: create 4 7
draw_7:
	draw 9 9 :x_7 :y_7 :star
	present
	# 0x2EF == loop_8:
	set 8 :loop_back_released_arg 0x2EF
	jump :loop_back_released

loop_8:
	key_released 44 :draw_8 call wait
jump :halt

x_8: create 4 42
y_8: create 4 17
draw_8:
	draw 9 9 :x_8 :y_8 :star
	present
ret


halt: halt


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
