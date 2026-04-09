onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /bitfilter_tb/Rst
add wave -noupdate /bitfilter_tb/Clk
add wave -noupdate /bitfilter_tb/BitIn
add wave -noupdate /bitfilter_tb/BitCheckValue
add wave -noupdate /bitfilter_tb/BitOutExpected
add wave -noupdate /bitfilter_tb/BitOut
add wave -noupdate /bitfilter_tb/ReadyExpected
add wave -noupdate /bitfilter_tb/Ready
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {94500 ps}

run -all
