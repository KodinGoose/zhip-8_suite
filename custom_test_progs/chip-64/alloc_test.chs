alloc :address 4
free  :address 4
alloc :address :to_alloc
free  :address :to_alloc
alloc :address 8
free :to_free1 4
free :to_free2 2
free :to_free3 2

to_alloc: create 8 0x200

address: reserve 8

to_free1: create 8 0xB2
to_free2: create 8 0xB0
to_free3: create 8 0xB6
