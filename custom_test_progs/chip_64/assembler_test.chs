# This file is meant to test whether all the instructions assemble to their correct opcodes with their correct arguments

halt
exit
clear
# Can have multiple aliases before an opcode
ret: return: ret
resolution 0xFEDC 0xCDEF

scroll up 0xFFFF
scroll right 0xFFFF
scroll down 0xFFFF
scroll left 0xFFFF

jump *3
jump :ret

jump *3 4 if *3 < *4
jump *3 4 if *3 <= *4
jump *3 4 if *3 > *4
jump *3 4 if *3 >= *4
jump *3 4 if *3 == *4
jump *3 4 if *3 != *4

jump *3 4 if *3 < :ret
jump *3 4 if *3 <= :ret
jump *3 4 if *3 > :ret
jump *3 4 if *3 >= :ret
jump *3 4 if *3 == :ret
jump *3 4 if *3 != :ret

jump *3 4 if :ret < :ret
jump *3 4 if :ret <= :ret
jump *3 4 if :ret > :ret
jump *3 4 if :ret >= :ret
jump *3 4 if :ret == :ret
jump *3 4 if :ret != :ret

jump :ret 4 if :ret < :ret
jump :ret 4 if :ret <= :ret
jump :ret 4 if :ret > :ret
jump :ret 4 if :ret >= :ret
jump :ret 4 if :ret == :ret
jump :ret 4 if :ret != :ret

call *3
call :ret

reserve 3
reserve 4 3

create 4 0xFFFFFFFF 0xFFFFFFFF 0xFFFFFFFF 0xFFFFFFFF

alloc *3 4
alloc :ret 4

alloc *3 *3
alloc *3 :return
alloc :ret :return

create 11 0xFFFFFFFFFFFFFFFFFFFFFF

set 3 *3 0xEEEEEE
set 3 :ret 0xEEEEEE
set 3 *3 *3
set 3 *3 :ret
set 3 :ret :ret

add 3 *3 0xEEEEEE
add 3 :ret 0xEEEEEE
add 3 *3 *3
add 3 *3 :ret
add 3 :ret :ret

sub 3 *3 0xEEEEEE
sub 3 :ret 0xEEEEEE
sub 3 *3 *3
sub 3 *3 :ret
sub 3 :ret :ret

mul 3 *3 0xEEEEEE
mul 3 :ret 0xEEEEEE
mul 3 *3 *3
mul 3 *3 :ret
mul 3 :ret :ret

div 3 *3 0xEEEEEE
div 3 :ret 0xEEEEEE
div 3 *3 *3
div 3 *3 :ret
div 3 :ret :ret

mod 3 *3 0xEEEEEE
mod 3 :ret 0xEEEEEE
mod 3 *3 *3
mod 3 *3 :ret
mod 3 :ret :ret

create 18 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

shift_left 2 *3 0xFFFFFF
shift_left 2 *3 0xFFFFFF saturate
shift_left 2 :ret 0xFFFFFF
shift_left 2 :ret 0xFFFFFF saturate
shift_right 2 *3 0xFFFFFF
shift_right 2 *3 0xFFFFFF saturate
shift_right 2 :ret 0xFFFFFF
shift_right 2 :ret 0xFFFFFF saturate

and 3 *3 0xAAAAAA
and 3 :ret 0xAAAAAA
and 3 :ret *3
and 3 :ret :ret

or 3 *3 0xAAAAAA
or 3 :ret 0xAAAAAA
or 3 :ret *3
or 3 :ret :ret

xor 3 *3 0xAAAAAA
xor 3 :ret 0xAAAAAA
xor 3 :ret *3
xor 3 :ret :ret

not 3 *3
not 3 :ret
not 3 :ret
not 3 :ret

rand 4 *3
rand 4 :return

create 18 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

key_pressed 0xAAAA *3 jump
key_pressed 0xAAAA :ret call
key_pressed 0xAAAA *3 jump wait
key_pressed 0xAAAA :ret call wait

key_released 0xAAAA *3 jump
key_released 0xAAAA :ret call
key_released 0xAAAA *3 jump wait
key_released 0xAAAA :ret call wait

create 24 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

present
draw 0xBBBB 0xCCCC *3 *4 *5
draw 0xBBBB 0xCCCC :ret :ret :ret

create 17 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

time *3
time :ret
auto_sleep off
auto_sleep on
sleep 3
sleep *3
sleep :ret

create 16 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
create 9 0xFFFFFFFFFFFFFFFFFF

jump :jump_to
jump jump_to: *0xEE
create 14 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF

jump :jump_to_2
create 8 jump_to_2: 0xEE
create 15 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
