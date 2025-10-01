resolution 64 32
call :jump_<
halt

correct_val_jump_<: create 2 20
wrong_val_jump_<: create 2 15
val_jump_<: create 2 15
jump_<:
	jump :wrong_jump_< 2 if :val_jump_< < :wrong_val_jump_<
	jump :call_jump_< 2 if :val_jump_< < :correct_val_jump_< 
	halt
	call_jump_<: call :draw_jump_<
jump :jump_<=

wrong_jump_<: halt

draw_jump_<:
	draw 9 9 :draw_x_jump_< :draw_y_jump_< :star
	present
ret

draw_x_jump_<: create 4 18
draw_y_jump_<: create 4 7


correct_val_jump_<=: create 2 15
wrong_val_jump_<=: create 2 14
val_jump_<=: create 2 15
jump_<=:
	jump :wrong_jump_<= 2 if :val_jump_<= <= :wrong_val_jump_<=
	jump :call_jump_<= 2 if :val_jump_<= <= :correct_val_jump_<= 
	halt
	call_jump_<=: call :draw_jump_<=
jump :jump_>

wrong_jump_<=: halt

draw_jump_<=:
	draw 9 9 :draw_x_jump_<= :draw_y_jump_<= :star
	present
ret

draw_x_jump_<=: create 4 18
draw_y_jump_<=: create 4 17


correct_val_jump_>: create 2 10
wrong_val_jump_>: create 2 15
val_jump_>: create 2 15
jump_>:
	jump :wrong_jump_> 2 if :val_jump_> > :wrong_val_jump_>
	jump :call_jump_> 2 if :val_jump_> > :correct_val_jump_> 
	halt
	call_jump_>: call :draw_jump_>
jump :jump_>=

wrong_jump_>: halt

draw_jump_>:
	draw 9 9 :draw_x_jump_> :draw_y_jump_> :star
	present
ret

draw_x_jump_>: create 4 28
draw_y_jump_>: create 4 7


correct_val_jump_>=: create 2 15
wrong_val_jump_>=: create 2 16
val_jump_>=: create 2 15
jump_>=:
	jump :wrong_jump_>= 2 if :val_jump_>= >= :wrong_val_jump_>=
	jump :call_jump_>= 2 if :val_jump_>= >= :correct_val_jump_>= 
	halt
	call_jump_>=: call :draw_jump_>=
jump :jump_==

wrong_jump_>=: halt

draw_jump_>=:
	draw 9 9 :draw_x_jump_>= :draw_y_jump_>= :star
	present
ret

draw_x_jump_>=: create 4 28
draw_y_jump_>=: create 4 17


correct_val_jump_==: create 2 15
wrong_val_jump_==: create 2 10
val_jump_==: create 2 15
jump_==:
	jump :wrong_jump_== 2 if :val_jump_== == :wrong_val_jump_==
	jump :call_jump_== 2 if :val_jump_== == :correct_val_jump_== 
	halt
	call_jump_==: call :draw_jump_==
jump :jump_!=

wrong_jump_==: halt

draw_jump_==:
	draw 9 9 :draw_x_jump_== :draw_y_jump_== :star
	present
ret

draw_x_jump_==: create 4 38
draw_y_jump_==: create 4 7


correct_val_jump_!=: create 2 10
wrong_val_jump_!=: create 2 15
val_jump_!=: create 2 15
jump_!=:
	jump :wrong_jump_!= 2 if :val_jump_!= != :wrong_val_jump_!=
	jump :call_jump_!= 2 if :val_jump_!= != :correct_val_jump_!= 
	halt
	call_jump_!=: call :draw_jump_!=
ret

wrong_jump_!=: halt

draw_jump_!=:
	draw 9 9 :draw_x_jump_!= :draw_y_jump_!= :star
	present
ret

draw_x_jump_!=: create 4 38
draw_y_jump_!=: create 4 17


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
