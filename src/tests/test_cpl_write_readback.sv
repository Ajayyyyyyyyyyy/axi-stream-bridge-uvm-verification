//=============================================================================
// File   : test_cpl_write_readback.sv
// Purpose: Single completer write followed by a read-back to the same
//          address, proving CQ/CC/fabric-bus coherency for one transaction.
//=============================================================================

class test_cpl_write_readback extends base_test;
  `uvm_component_utils(test_cpl_write_readback)

  function new(string name = "test_cpl_write_readback", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    use_dma_env = 1'b0;
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    cpl_write_readback_seq seq;
    arb_responder_seq      arb_seq;

    phase.raise_objection(this);

    fork
      begin
        arb_seq = arb_responder_seq::type_id::create("arb_seq");
        arb_seq.start(cpl_env.arb.sequencer);
      end
    join_none

    seq = cpl_write_readback_seq::type_id::create("seq");
    if (!seq.randomize() with { length_bytes == 32; })
      `uvm_error(get_type_name(), "sequence randomization failed")
    seq.start(cpl_env.cq.sequencer);

    #200ns;
    phase.drop_objection(this);
  endtask

endclass
