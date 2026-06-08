//======================================================================
// File   : fsm_if.sv
// Mô tả  : Interface kết nối DUT FSM với UVM testbench
//======================================================================
interface fsm_if (input logic clk);

    logic       rst_n;
    logic       din;
    logic       detected;
    logic [1:0] state_o;

    // Clocking block cho Driver: lái din, đọc kết quả
    clocking drv_cb @(posedge clk);
        default input #1step output #1ns;
        output din;
        input  detected, state_o;
    endclocking

    // Clocking block cho Monitor: chỉ quan sát
    clocking mon_cb @(posedge clk);
        default input #1step;
        input din, detected, state_o, rst_n;
    endclocking

    modport DRV (clocking drv_cb, output rst_n, input clk);
    modport MON (clocking mon_cb, input clk);

endinterface