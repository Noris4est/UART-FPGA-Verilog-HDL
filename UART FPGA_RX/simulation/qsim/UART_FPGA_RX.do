onerror {exit -code 1}
vlib work
vlog -work work UART_FPGA_RX.vo
vlog -work work Waveform8.vwf.vt
vsim -novopt -c -t 1ps -L maxii_ver -L altera_ver -L altera_mf_ver -L 220model_ver -L sgate_ver -L altera_lnsim_ver work.UART_FPGA_RX_vlg_vec_tst
vcd file -direction UART_FPGA_RX.msim.vcd
vcd add -internal UART_FPGA_RX_vlg_vec_tst/*
vcd add -internal UART_FPGA_RX_vlg_vec_tst/i1/*
proc simTimestamp {} {
    echo "Simulation time: $::now ps"
    if { [string equal running [runStatus]] } {
        after 2500 simTimestamp
    }
}
after 2500 simTimestamp
run -all
quit -f
