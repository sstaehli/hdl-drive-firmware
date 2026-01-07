onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /dq2abc_tb/Rst
add wave -noupdate /dq2abc_tb/Clk
add wave -noupdate /dq2abc_tb/Strobe
add wave -noupdate /dq2abc_tb/Valid
add wave -noupdate /dq2abc_tb/A
add wave -noupdate /dq2abc_tb/B
add wave -noupdate /dq2abc_tb/C
add wave -noupdate /dq2abc_tb/RealA
add wave -noupdate /dq2abc_tb/RealB
add wave -noupdate /dq2abc_tb/RealC
add wave -noupdate /dq2abc_tb/ExpectA
add wave -noupdate /dq2abc_tb/ExpectB
add wave -noupdate /dq2abc_tb/ExpectC
add wave -noupdate -format Analog-Step -height 30 -max 1.0 -min -1.0 /dq2abc_tb/RealA
add wave -noupdate -format Analog-Step -height 30 -max 1.0 -min -1.0 /dq2abc_tb/RealB
add wave -noupdate -format Analog-Step -height 30 -max 1.0 -min -1.0 /dq2abc_tb/RealC
add wave -noupdate -format Analog-Step -height 30 -max 1.0 -min -1.0 /dq2abc_tb/ExpectA
add wave -noupdate -format Analog-Step -height 30 -max 1.0 -min -1.0 /dq2abc_tb/ExpectB
add wave -noupdate -format Analog-Step -height 30 -max 1.0 -min -1.0 /dq2abc_tb/ExpectC
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