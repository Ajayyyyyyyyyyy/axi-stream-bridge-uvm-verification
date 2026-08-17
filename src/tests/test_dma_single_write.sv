//=============================================================================
// File   : test_dma_single_write.sv
// Purpose: A single device-initiated DMA write to host memory. Writes are
//          posted in this environment (no RC completion expected), so only
//          the arbiter responder is needed alongside the DMA command driver.
//=============================================================================

class test_dma_single_write extends base_test;
  `uvm_component_utils(test_dma_single_write)

  function new(string name = "test_dma_single_write", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    use_dma_env = 1'b1;
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    dma_single_cmd_seq cmd_seq;
    arb_responder_seq   arb_seq;

    phase.raise_objection(this);

    fork
      begin
        arb_seq = arb_responder_seq::type_id::create("arb_seq");
        arb_seq.start(dma_env.arb.sequencer);
      end
    join_none

    cmd_seq = dma_single_cmd_seq::type_id::create("cmd_seq");
    if (!cmd_seq.randomize() with { dir == 1'b1; length_bytes == 256; })
      `uvm_error(get_type_name(), "sequence randomization failed")
    cmd_seq.start(dma_env.dma.sequencer);

    #300ns;
    phase.drop_objection(this);
  endtask

endclass
