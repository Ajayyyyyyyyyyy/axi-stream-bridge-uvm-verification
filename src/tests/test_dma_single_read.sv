//=============================================================================
// File   : test_dma_single_read.sv
// Purpose: A single device-initiated DMA read of host memory, exercising
//          the RQ/RC completion path and the [requester_id][tag] tracking
//          for the DMA engine's fixed internal identity.
//=============================================================================

class test_dma_single_read extends base_test;
  `uvm_component_utils(test_dma_single_read)

  function new(string name = "test_dma_single_read", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    use_dma_env = 1'b1;
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    dma_single_cmd_seq cmd_seq;
    arb_responder_seq   arb_seq;
    rc_responder_seq    rc_seq;

    phase.raise_objection(this);

    fork
      begin
        arb_seq = arb_responder_seq::type_id::create("arb_seq");
        arb_seq.start(dma_env.arb.sequencer);
      end
      begin
        rc_seq = rc_responder_seq::type_id::create("rc_seq");
        rc_seq.start(dma_env.rc.sequencer);
      end
    join_none

    cmd_seq = dma_single_cmd_seq::type_id::create("cmd_seq");
    if (!cmd_seq.randomize() with { dir == 1'b0; length_bytes == 256; })
      `uvm_error(get_type_name(), "sequence randomization failed")
    cmd_seq.start(dma_env.dma.sequencer);

    #500ns; // allow the completion to drain through RC before ending
    phase.drop_objection(this);
  endtask

endclass
