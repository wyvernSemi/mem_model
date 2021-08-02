onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group tb /tb/clk
add wave -noupdate -expand -group tb /tb/reset_n
add wave -noupdate -expand -group tb -radix unsigned /tb/count
add wave -noupdate -expand -group tb -radix hexadecimal /tb/address
add wave -noupdate -expand -group tb /tb/write
add wave -noupdate -expand -group tb /tb/byteenable
add wave -noupdate -expand -group tb -radix hexadecimal /tb/writedata
add wave -noupdate -expand -group tb /tb/read
add wave -noupdate -expand -group tb -radix hexadecimal /tb/readdata
add wave -noupdate -expand -group tb /tb/readdatavalid
add wave -noupdate -group cpu /tb/cpu/clk
add wave -noupdate -group cpu /tb/cpu/BE_ADDR
add wave -noupdate -group cpu /tb/cpu/NODE
add wave -noupdate -group cpu /tb/cpu/nodenum
add wave -noupdate -group cpu /tb/cpu/Update
add wave -noupdate -group cpu /tb/cpu/UpdateResponse
add wave -noupdate -group cpu /tb/cpu/WE
add wave -noupdate -group cpu -radix hexadecimal /tb/cpu/address
add wave -noupdate -group cpu /tb/cpu/byteenable
add wave -noupdate -group cpu /tb/cpu/read
add wave -noupdate -group cpu /tb/cpu/readdata
add wave -noupdate -group cpu /tb/cpu/readdatavalid
add wave -noupdate -group cpu /tb/cpu/write
add wave -noupdate -group cpu -radix hexadecimal /tb/cpu/writedata
add wave -noupdate -group cpu /tb/cpu/irq
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {75000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {214500 ps} {300100 ps}
