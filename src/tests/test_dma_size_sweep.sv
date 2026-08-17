//=============================================================================
// File   : test_dma_size_sweep.sv
// Purpose: Sweeps DMA write-then-read-back transfer size from 4 bytes up to
//          a full 4KB page, stressing length/last-beat handling and the
//          scoreboard's DWORD-count checking across a range of sizes.
//=============================================================================

class test_dma_size_sweep extends base_test;
  `uvm_component_utils(test_dma_size_sweep)

  function new(string name = "test_dma_size_sweep", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    use_dma_env = 1'b1;
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    dma_size_sweep_seq seq;
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

    seq = dma_size_sweep_seq::type_id::create("seq");
    seq.start(dma_env.dma.sequencer);

    #1000ns;
    phase.drop_objection(this);
  endtask

endclass
