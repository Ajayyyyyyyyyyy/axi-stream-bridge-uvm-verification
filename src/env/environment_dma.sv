//=============================================================================
// File   : environment_dma.sv
// Purpose: Requester/DMA-path environment configuration -- exercises
//          device-initiated DMA transfers to/from host memory. Active RC
//          driver, passive RQ monitor, active DMA command sequencer, and
//          active arbiter agent, all wired into the reference-model
//          scoreboard via analysis ports.
//=============================================================================

class stream_bridge_dma_env extends uvm_env;
  `uvm_component_utils(stream_bridge_dma_env)

  rc_agent                 rc;
  rq_agent                 rq;
  dma_agent                dma;
  arb_agent                arb;
  stream_bridge_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    rc  = rc_agent::type_id::create("rc", this);
    rq  = rq_agent::type_id::create("rq", this);
    dma = dma_agent::type_id::create("dma", this);
    arb = arb_agent::type_id::create("arb", this);
    scoreboard = stream_bridge_scoreboard::type_id::create("scoreboard", this);

    rc.is_active  = UVM_ACTIVE;
    rq.is_active  = UVM_PASSIVE;
    dma.is_active = UVM_ACTIVE;
    arb.is_active = UVM_ACTIVE;
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    rc.monitor.ap.connect(scoreboard.rc_export);
    rq.monitor.ap.connect(scoreboard.rq_export);
    dma.monitor.ap.connect(scoreboard.dma_export);
    arb.monitor.ap.connect(scoreboard.fab_export);
  endfunction

endclass
