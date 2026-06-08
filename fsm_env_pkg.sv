//======================================================================
// File   : fsm_env_pkg.sv
// Mô tả  : Driver, Monitor, Coverage, Scoreboard, Agent, Env cho FSM TB
//======================================================================
package fsm_env_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fsm_seq_pkg::*;

    // Mã trạng thái dùng chung cho ref model & coverage
    localparam logic [1:0] IDLE=2'b00, S1=2'b01, S10=2'b10, S101=2'b11;

    //==================================================================
    // DRIVER: lấy item, lái din lên interface mỗi chu kỳ clock
    //==================================================================
    class fsm_driver extends uvm_driver #(fsm_item);
        `uvm_component_utils(fsm_driver)
        virtual fsm_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual fsm_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF","Driver không lấy được virtual interface")
        endfunction

        task run_phase(uvm_phase phase);
            vif.drv_cb.din <= 0;
            forever begin
                fsm_item it;
                seq_item_port.get_next_item(it);
                @(vif.drv_cb);
                vif.drv_cb.din <= it.din;   // lái 1 bit mỗi chu kỳ
                seq_item_port.item_done();
            end
        endtask
    endclass

    //==================================================================
    // MONITOR: quan sát din/state_o/detected, phát qua analysis port
    //==================================================================
    class fsm_monitor extends uvm_monitor;
        `uvm_component_utils(fsm_monitor)
        virtual fsm_if vif;
        uvm_analysis_port #(fsm_item) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual fsm_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF","Monitor không lấy được virtual interface")
        endfunction

        task run_phase(uvm_phase phase);
            forever begin
                @(vif.mon_cb);
                if (vif.mon_cb.rst_n) begin   // chỉ thu khi đã thoát reset
                    fsm_item it = fsm_item::type_id::create("mon_it");
                    it.din      = vif.mon_cb.din;
                    it.detected = vif.mon_cb.detected;
                    it.state_o  = vif.mon_cb.state_o;
                    ap.write(it);
                end
            end
        endtask
    endclass

    //==================================================================
    // COVERAGE: subscriber thu thập functional coverage
    //   - cp_state : phủ đủ 4 trạng thái
    //   - cp_din   : phủ cả 0 và 1
    //   - cp_trans : phủ các chuyển trạng thái (state transition bins)
    //   - cross    : trạng thái x đầu vào
    //==================================================================
    class fsm_coverage extends uvm_subscriber #(fsm_item);
        `uvm_component_utils(fsm_coverage)
        fsm_item tr;
        real cov_state, cov_trans, cov_total;

        covergroup cg;
            option.per_instance = 1;

            cp_state: coverpoint tr.state_o {
                bins idle = {IDLE};
                bins s1   = {S1};
                bins s10  = {S10};
                bins s101 = {S101};
            }
            cp_din: coverpoint tr.din {
                bins zero = {0};
                bins one  = {1};
            }
            cp_detect: coverpoint tr.detected {
                bins no  = {0};
                bins yes = {1};
            }
            // Chuyển trạng thái hợp lệ của FSM (state transition coverage)
            cp_trans: coverpoint tr.state_o {
                bins t_idle_s1   = (IDLE => S1);
                bins t_idle_idle = (IDLE => IDLE);
                bins t_s1_s1     = (S1   => S1);
                bins t_s1_s10    = (S1   => S10);
                bins t_s10_s101  = (S10  => S101);
                bins t_s10_idle  = (S10  => IDLE);
                bins t_s101_s1   = (S101 => S1);
                bins t_s101_s10  = (S101 => S10);
            }
            // Cross: mỗi trạng thái được kích bởi cả 0 và 1
            cx_state_din: cross cp_state, cp_din;
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            cg = new();
        endfunction

        // Hàm bắt buộc của uvm_subscriber
        function void write(fsm_item t);
            tr = t;
            cg.sample();
        endfunction

        function void report_phase(uvm_phase phase);
            cov_state = cg.cp_state.get_coverage();
            cov_trans = cg.cp_trans.get_coverage();
            cov_total = cg.get_coverage();
            `uvm_info("COV", "================ ĐỘ PHỦ (COVERAGE) ================", UVM_LOW)
            `uvm_info("COV", $sformatf("State coverage      : %0.2f%%", cov_state), UVM_LOW)
            `uvm_info("COV", $sformatf("Transition coverage : %0.2f%%", cov_trans), UVM_LOW)
            `uvm_info("COV", $sformatf("Tổng coverage       : %0.2f%%", cov_total), UVM_LOW)
        endfunction
    endclass

    //==================================================================
    // SCOREBOARD: mô hình tham chiếu FSM độc lập, so sánh với DUT
    //==================================================================
    class fsm_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(fsm_scoreboard)
        uvm_analysis_imp #(fsm_item, fsm_scoreboard) imp;

        logic [1:0] ref_state;   // trạng thái mô hình tham chiếu
        bit         primed;      // đã có mẫu đầu tiên để đồng bộ chưa
        int         n_check, n_pass, n_fail, n_detect;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            imp = new("imp", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ref_state = IDLE;
            primed    = 0;
        endfunction

        // Hàm chuyển trạng thái của mô hình tham chiếu (giống DUT)
        function logic [1:0] next_state(logic [1:0] s, bit d);
            case (s)
                IDLE: return d ? S1   : IDLE;
                S1  : return d ? S1   : S10;
                S10 : return d ? S101 : IDLE;
                S101: return d ? S1   : S10;
                default: return IDLE;
            endcase
        endfunction

        // Nhận transaction từ monitor (state_o là trạng thái HIỆN TẠI của DUT
        // ứng với din vừa lấy mẫu; nxt sẽ được kiểm ở mẫu kế tiếp)
        function void write(fsm_item it);
            logic [1:0] exp_detect_state;
            // Đồng bộ mô hình với DUT ở mẫu đầu tiên
            if (!primed) begin
                ref_state = it.state_o;
                primed = 1;
            end

            // 1) Kiểm tra trạng thái DUT khớp mô hình tham chiếu
            n_check++;
            if (it.state_o === ref_state) begin
                n_pass++;
                `uvm_info("SCB", $sformatf("PASS state: ref=%0d dut=%0d din=%0b",
                          ref_state, it.state_o, it.din), UVM_HIGH)
            end else begin
                n_fail++;
                `uvm_error("SCB", $sformatf("FAIL state: ref=%0d dut=%0d din=%0b",
                           ref_state, it.state_o, it.din))
            end

            // 2) Kiểm tra ngõ ra detected (Moore: detected khi state==S101)
            if ((it.state_o == S101) !== it.detected) begin
                n_fail++;
                `uvm_error("SCB", $sformatf("FAIL detected: state=%0d detected=%0b",
                           it.state_o, it.detected))
            end
            if (it.detected) n_detect++;

            // 3) Cập nhật mô hình tham chiếu cho mẫu kế tiếp
            ref_state = next_state(ref_state, it.din);
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SCB", "================ KẾT QUẢ SCOREBOARD ================", UVM_LOW)
            `uvm_info("SCB", $sformatf("Số lần kiểm tra=%0d  PASS=%0d  FAIL=%0d",
                      n_check, n_pass, n_fail), UVM_LOW)
            `uvm_info("SCB", $sformatf("Số lần phát hiện '101' = %0d", n_detect), UVM_LOW)
            if (n_fail == 0) `uvm_info("SCB","*** TEST PASSED ***", UVM_LOW)
            else             `uvm_error("SCB","*** TEST FAILED ***")
        endfunction
    endclass

    //==================================================================
    // AGENT: sequencer + driver + monitor
    //==================================================================
    class fsm_agent extends uvm_agent;
        `uvm_component_utils(fsm_agent)
        fsm_sequencer sqr;
        fsm_driver    drv;
        fsm_monitor   mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon = fsm_monitor::type_id::create("mon", this);
            if (get_is_active() == UVM_ACTIVE) begin
                sqr = fsm_sequencer::type_id::create("sqr", this);
                drv = fsm_driver::type_id::create("drv", this);
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            if (get_is_active() == UVM_ACTIVE)
                drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    //==================================================================
    // ENVIRONMENT: agent + scoreboard + coverage
    //   Analysis port của monitor phát tới CẢ scoreboard VÀ coverage
    //==================================================================
    class fsm_env extends uvm_env;
        `uvm_component_utils(fsm_env)
        fsm_agent      agt;
        fsm_scoreboard scb;
        fsm_coverage   cov;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agt = fsm_agent::type_id::create("agt", this);
            scb = fsm_scoreboard::type_id::create("scb", this);
            cov = fsm_coverage::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            agt.mon.ap.connect(scb.imp);   // tới scoreboard
            agt.mon.ap.connect(cov.analysis_export); // tới coverage
        endfunction
    endclass

endpackage