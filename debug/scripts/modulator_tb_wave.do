onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /modulator_tb/Clk
add wave -noupdate -format Analog-Step -height 84 -max 4096.0 -min 0.0 -radix unsigned /modulator_tb/Angle
add wave -noupdate -format Analog-Step -height 205 -max 2047.0 -min -2048.0 -radix decimal /modulator_tb/Sine
add wave -noupdate -format Analog-Step -height 50 -max 1.0 -min -1.0 -radix sfixed /modulator_tb/RealSine
add wave -noupdate -format Analog-Step -height 84 -max 2047.0 -min -2048.0 -radix decimal /modulator_tb/Cosine
add wave -noupdate -format Analog-Step -height 50 -max 1.0 -min -1.0 -radix sfixed /modulator_tb/RealCosine
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {38920185 ps} 0}
quietly wave cursor active 1
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
WaveRestoreZoom {0 ps} {250 us}

run -all
