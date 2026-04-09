onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /abzdecoder_tb/Rst
add wave -noupdate /abzdecoder_tb/Clk
add wave -noupdate /abzdecoder_tb/A
add wave -noupdate /abzdecoder_tb/B
add wave -noupdate /abzdecoder_tb/Z
add wave -noupdate /abzdecoder_tb/Valid
add wave -noupdate /abzdecoder_tb/Referenced
add wave -noupdate /abzdecoder_tb/Ready
add wave -noupdate -format Analog-Step -height 30 -max 4000 -min 0 /abzdecoder_tb/Position
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
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {1 ns}

run -all