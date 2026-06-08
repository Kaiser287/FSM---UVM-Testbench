//======================================================================
// File   : fsm_run.f  (file list - thứ tự biên dịch quan trọng)
//======================================================================
fsm_dut.sv
fsm_if.sv
fsm_seq_pkg.sv
fsm_env_pkg.sv
fsm_test_pkg.sv
fsm_tb_top.sv

//======================================================================
// LỆNH CHẠY MÔ PHỎNG (kèm thu thập coverage)
//======================================================================
// --- Synopsys VCS ---
//   vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
//        -cm line+cond+fsm+tgl -f fsm_run.f -l comp.log
//   ./simv +UVM_TESTNAME=fsm_regression_test +UVM_VERBOSITY=UVM_LOW -cm line+cond+fsm+tgl
//   urg -dir simv.vdb -report cov_report     // sinh báo cáo coverage HTML
//
// --- Mentor Questa ---
//   vlib work
//   vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv -f fsm_run.f
//   vsim -c fsm_tb_top -coverage +UVM_TESTNAME=fsm_regression_test \
//        -do "run -all; coverage report -details; quit"
//
// --- Cadence Xcelium ---
//   xrun -uvm -sv -coverage all -f fsm_run.f +UVM_TESTNAME=fsm_regression_test
//   imc -load cov_work    // xem coverage
//
// --- Danh sách test ---
//   fsm_pattern_test     : directed - ép phát hiện "101" (chức năng)
//   fsm_random_test      : 500 bit ngẫu nhiên (coverage + hiệu năng)
//   fsm_overlap_test     : chuỗi 10101... (phát hiện chồng lấp)
//   fsm_zeros_test       : toàn 0 (trường hợp biên)
//   fsm_regression_test  : chạy tất cả -> đạt coverage cao nhất