window lock
resolution 1280 720
window match
resolution 64 32
call :main
halt

main:
	draw 5 5 :x1 :y1 :pixels
	draw 5 5 :x2 :y2 :pixels
	draw 5 5 :x3 :y3 :pixels
	draw 5 5 :x4 :y4 :pixels
ret

x1: create 4 30
y1: create 4 15

x2: create 4 5
y2: create 4 5

x3: create 4 59
y3: create 4 27

x4: create 4 0
y4: create 4 0

pixels:
create 4 0x000000FF 0x000000FF 0x0000FFFF 0x000000FF 0x000000FF
create 4 0x000000FF 0x0000FFFF 0x0000FFFF 0x0000FFFF 0x000000FF
create 4 0x0000FFFF 0x0000FFFF 0x0000FFFF 0x0000FFFF 0x0000FFFF
create 4 0x000000FF 0x0000FFFF 0x0000FFFF 0x0000FFFF 0x000000FF
create 4 0x000000FF 0x000000FF 0x0000FFFF 0x000000FF 0x000000FF
