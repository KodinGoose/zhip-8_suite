execute 0xEEE
clear
ret: ret
exit
jump jump_to: :0xEEE
jump :ret
jump :jump_to
jump :seq_arg
call :0xEEE
call :ret
seq r13 seq_arg: 0xEE
sne r13 0xEE
seq r13 r13
set r13 0xEE
add r13 0xEE
set r13 r13
set r13 r13 or
set r13 r13 and
set r13 r13 xor
add r13 r13
sub r13 r13
rsh r13 r13
sub r13 r13 wtf
lsh r13 r13
sne r13 r13
sar 0xEEE
sar :ret
regJump 0xEEE
regJump :ret
rand r13 0xEE
draw r13 r13 0xE
spr r13
snp r13
gdt r13
wkr r13
sdt r13
sst r13
aar r13
saf r13
bcd r13
srg r13
lrg r13
srg r13 storage
lrg r13 storage
create 0xEE 0xEE *ret
