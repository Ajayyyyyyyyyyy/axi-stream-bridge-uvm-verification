//=============================================================================
// File   : test_cpl_continuous_burst.sv
// Purpose: A long run of back-to-back completer write-then-readback pairs,
//          pipelined with no forced idle gaps, to stress tag reuse timing
//          and outstanding-transaction tracking in the scoreboard.
//=============================================================================

class test_cpl_continuous_burst extends base_test;
  `uvm_component_utils(test_cpl_continuous_burst)

  function new(string name = "test_cpl_continuous_burst", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    use_dma_env = 1'b0;
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    cpl_continuous_burst_seq seq;
    arb_responder_seq        arb_seq;

    phase.raise_objection(this);

    fork
      begin
        arb_seq = arb_responder_seq::type_id::create("arb_seq");
        arb_seq.start(cpl_env.arb.sequencer);
      end
    join_none

    seq = cpl_continuous_burst_seq::type_id::create("seq");
    if (!seq.randomize() with { num_pairs == 32; })
      `uvm_error(get_type_name(), "sequence randomization failed")
    seq.start(cpl_env.cq.sequencer);

    #500ns;
    phase.drop_objection(this);
  endtask

endclass
