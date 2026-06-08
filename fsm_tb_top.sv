//======================================================================
// File   : fsm_tb_top.sv
// Mô tả  : Top-level testbench module - kết nối DUT FSM với UVM
//======================================================================
`timescale 1ns/1ps
module fsm_tb_top;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fsm_test_pkg::*;

    // Clock 100MHz
    logic clk = 0;
    always #5 clk = ~clk;

    // Interface
    fsm_if intf (clk);

    // DUT
    seq_detector_101 dut (
        .clk      (clk),
        .rst_n    (intf.rst_n),
        .din      (intf.din),
        .detected (intf.detected),
        .state_o  (intf.state_o)
    );

    // Reset ban đầu (đồng bộ)
    initial begin
        intf.rst_n = 0;
        repeat (3) @(posedge clk);
        intf.rst_n = 1;
    end

    // Đăng ký interface và chạy test
    initial begin
        uvm_config_db#(virtual fsm_if)::set(null, "*", "vif", intf);
      run_test("fsm_base_test");   // chọn test qua +UVM_TESTNAME
    end

    // Dump waveform
    initial begin
        $dumpfile("fsm_tb.vcd");
        $dumpvars(0, fsm_tb_top);
    end

    // Timeout an toàn
    initial begin
        #100000;
        `uvm_fatal("TIMEOUT","Mô phỏng quá thời gian cho phép")
    end
endmodule