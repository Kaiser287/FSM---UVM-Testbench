//======================================================================
// File   : fsm_seq_pkg.sv
// Mô tả  : Sequence item + Sequences cho FSM UVM Testbench
//======================================================================
package fsm_seq_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    //==================================================================
    // Transaction item: một bit đầu vào din tại một chu kỳ clock
    //==================================================================
    class fsm_item extends uvm_sequence_item;
        rand bit din;          // bit đầu vào (do sequence điều khiển)
        // các trường quan sát (do monitor điền)
        bit       detected;
        bit [1:0] state_o;

        `uvm_object_utils_begin(fsm_item)
            `uvm_field_int(din,      UVM_ALL_ON)
            `uvm_field_int(detected, UVM_ALL_ON)
            `uvm_field_int(state_o,  UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "fsm_item");
            super.new(name);
        endfunction
    endclass

    //==================================================================
    // Sequencer
    //==================================================================
    typedef uvm_sequencer #(fsm_item) fsm_sequencer;

    //==================================================================
    // Base sequence
    //==================================================================
    class fsm_base_seq extends uvm_sequence #(fsm_item);
        `uvm_object_utils(fsm_base_seq)
        int num = 50;
        function new(string name = "fsm_base_seq"); super.new(name); endfunction
    endclass

    //==================================================================
    // Random sequence: bit din ngẫu nhiên (kiểm thử rộng, dồn coverage)
    //==================================================================
    class fsm_random_seq extends fsm_base_seq;
        `uvm_object_utils(fsm_random_seq)
        function new(string name = "fsm_random_seq"); super.new(name); endfunction
        task body();
            repeat (num) begin
                fsm_item it = fsm_item::type_id::create("it");
                start_item(it);
                if (!it.randomize()) `uvm_error("RAND","randomize failed")
                finish_item(it);
            end
        endtask
    endclass

    //==================================================================
    // Directed sequence: phát chuỗi mẫu cố định để ép phát hiện "101"
    //==================================================================
    class fsm_pattern_seq extends fsm_base_seq;
        `uvm_object_utils(fsm_pattern_seq)
        bit pattern[] = '{1,0,1, 0,0, 1,0,1, 1,0,1,0,1};  // chứa nhiều "101" chồng lấp
        function new(string name = "fsm_pattern_seq"); super.new(name); endfunction
        task body();
            foreach (pattern[i]) begin
                fsm_item it = fsm_item::type_id::create("it");
                start_item(it);
                if (!it.randomize() with { din == pattern[i]; })
                    `uvm_error("RAND","randomize failed")
                finish_item(it);
            end
        endtask
    endclass

    //==================================================================
    // All-zeros sequence: kiểm thử FSM ở trạng thái không khớp
    //==================================================================
    class fsm_zeros_seq extends fsm_base_seq;
        `uvm_object_utils(fsm_zeros_seq)
        function new(string name = "fsm_zeros_seq"); super.new(name); endfunction
        task body();
            repeat (num) begin
                fsm_item it = fsm_item::type_id::create("it");
                start_item(it);
                if (!it.randomize() with { din == 0; }) `uvm_error("RAND","fail")
                finish_item(it);
            end
        endtask
    endclass

    //==================================================================
    // Overlapping sequence: chuỗi "1010101..." kiểm thử phát hiện chồng lấp
    //==================================================================
    class fsm_overlap_seq extends fsm_base_seq;
        `uvm_object_utils(fsm_overlap_seq)
        function new(string name = "fsm_overlap_seq"); super.new(name); endfunction
        task body();
            for (int i = 0; i < num; i++) begin
                fsm_item it = fsm_item::type_id::create("it");
                start_item(it);
                if (!it.randomize() with { din == (i % 2 == 0); }) // 1,0,1,0,...
                    `uvm_error("RAND","fail")
                finish_item(it);
            end
        endtask
    endclass

endpackage