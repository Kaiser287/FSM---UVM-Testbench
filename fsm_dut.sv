//======================================================================
// File   : fsm_dut.sv
// Mô tả  : FSM phát hiện chuỗi bit "101" (overlapping) - mô hình Moore
//          Trạng thái: IDLE -> S1 -> S10 -> S101(detect)
//======================================================================
module seq_detector_101 (
    input  logic       clk,
    input  logic       rst_n,    // reset đồng bộ, tích cực thấp
    input  logic       din,      // chuỗi bit nối tiếp đầu vào
    output logic       detected, // =1 khi vừa phát hiện "101"
    output logic [1:0] state_o   // trạng thái hiện tại (cho verification)
);

    // Mã hóa trạng thái
    typedef enum logic [1:0] {
        IDLE = 2'b00,  // chưa khớp gì
        S1   = 2'b01,  // đã thấy "1"
        S10  = 2'b10,  // đã thấy "10"
        S101 = 2'b11   // đã thấy "101" -> phát hiện
    } state_e;

    state_e cur_state, nxt_state;

    // Thanh ghi trạng thái (sequential)
    always_ff @(posedge clk) begin
        if (!rst_n) cur_state <= IDLE;
        else        cur_state <= nxt_state;
    end

    // Logic trạng thái kế tiếp (combinational) - cho phép chồng lấp
    always_comb begin
        nxt_state = cur_state;
        unique case (cur_state)
            IDLE: nxt_state = din ? S1   : IDLE;
            S1  : nxt_state = din ? S1   : S10;   // "11"->S1, "10"->S10
            S10 : nxt_state = din ? S101 : IDLE;  // "101"->detect, "100"->IDLE
            S101: nxt_state = din ? S1   : S10;   // chồng lấp: "1011"->S1, "1010"->S10
        endcase
    end

    // Đầu ra Moore: chỉ phụ thuộc trạng thái hiện tại
    assign detected = (cur_state == S101);
    assign state_o  = cur_state;

endmodule