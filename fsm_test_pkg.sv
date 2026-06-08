//======================================================================
// File   : fsm_test_pkg.sv
// Mô tả  : Base test + các testcase kiểm chứng FSM
//======================================================================
package fsm_test_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fsm_seq_pkg::*;
    import fsm_env_pkg::*;

    //==================================================================
    // BASE TEST
    //==================================================================
    class fsm_base_test extends uvm_test;
        `uvm_component_utils(fsm_base_test)
        fsm_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = fsm_env::type_id::create("env", this);
        endfunction

        function void end_of_elaboration_phase(uvm_phase phase);
            uvm_top.print_topology();
        endfunction
    endclass

    //==================================================================
    // TC1: Directed pattern test - ép phát hiện "101" (chức năng)
    //==================================================================
    class fsm_pattern_test extends fsm_base_test;
        `uvm_component_utils(fsm_pattern_test)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            fsm_pattern_seq seq;
            phase.raise_objection(this);
            seq = fsm_pattern_seq::type_id::create("seq");
            seq.start(env.agt.sqr);
            #50;
            phase.drop_objection(this);
        endtask
    endclass

    //==================================================================
    // TC2: Random test - bit ngẫu nhiên (dồn coverage + hiệu năng)
    //==================================================================
    class fsm_random_test extends fsm_base_test;
        `uvm_component_utils(fsm_random_test)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            fsm_random_seq seq;
            phase.raise_objection(this);
            seq = fsm_random_seq::type_id::create("seq"); seq.num = 500;
            seq.start(env.agt.sqr);
            #50;
            phase.drop_objection(this);
        endtask
    endclass

    //==================================================================
    // TC3: Overlap test - chuỗi "10101..." kiểm thử phát hiện chồng lấp
    //==================================================================
    class fsm_overlap_test extends fsm_base_test;
        `uvm_component_utils(fsm_overlap_test)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            fsm_overlap_seq seq;
            phase.raise_objection(this);
            seq = fsm_overlap_seq::type_id::create("seq"); seq.num = 40;
            seq.start(env.agt.sqr);
            #50;
            phase.drop_objection(this);
        endtask
    endclass

    //==================================================================
    // TC4: All-zeros test - trường hợp biên không có phát hiện nào
    //==================================================================
    class fsm_zeros_test extends fsm_base_test;
        `uvm_component_utils(fsm_zeros_test)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            fsm_zeros_seq seq;
            phase.raise_objection(this);
            seq = fsm_zeros_seq::type_id::create("seq"); seq.num = 30;
            seq.start(env.agt.sqr);
            #50;
            phase.drop_objection(this);
        endtask
    endclass

    //==================================================================
    // TC5: Regression test - chạy nhiều sequence liên tiếp (full coverage)
    //==================================================================
    class fsm_regression_test extends fsm_base_test;
        `uvm_component_utils(fsm_regression_test)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            fsm_pattern_seq pseq;
            fsm_overlap_seq oseq;
            fsm_random_seq  rseq;
            phase.raise_objection(this);
            pseq = fsm_pattern_seq::type_id::create("pseq");
            oseq = fsm_overlap_seq::type_id::create("oseq"); oseq.num = 40;
            rseq = fsm_random_seq::type_id::create("rseq");  rseq.num = 500;
            pseq.start(env.agt.sqr);
            oseq.start(env.agt.sqr);
            rseq.start(env.agt.sqr);
            #50;
            phase.drop_objection(this);
        endtask
    endclass

endpackage