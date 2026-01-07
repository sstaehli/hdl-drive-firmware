onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /spiadc_tb/Rst
add wave -noupdate /spiadc_tb/Clk
add wave -noupdate /spiadc_tb/Trigger
add wave -noupdate /spiadc_tb/CS_N
add wave -noupdate /spiadc_tb/SCLK
add wave -noupdate /spiadc_tb/MISO
add wave -noupdate /spiadc_tb/Valid
add wave -noupdate /spiadc_tb/U
add wave -noupdate /spiadc_tb/V
add wave -noupdate /spiadc_tb/W
add wave -noupdate /spiadc_tb/VBus
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