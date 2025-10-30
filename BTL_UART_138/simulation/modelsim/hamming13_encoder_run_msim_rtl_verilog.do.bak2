transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138 {C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138/hamming13_encoder.v}

vlog -vlog01compat -work work +incdir+C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138 {C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138/tb_full_system_13.v}
vlog -vlog01compat -work work +incdir+C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138 {C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138/hamming13_encoder.v}
vlog -vlog01compat -work work +incdir+C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138 {C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138/hamming13_decoder.v}
vlog -vlog01compat -work work +incdir+C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138 {C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138/uart_tx_hamming13.v}
vlog -vlog01compat -work work +incdir+C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138 {C:/Users/tad29/OneDrive/Desktop/ThietKeLogicSo/BTL_UART_138/uart_rx_hamming13.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L fiftyfivenm_ver -L rtl_work -L work -voptargs="+acc"  tb_full_system_13

add wave *
view structure
view signals
run -all
