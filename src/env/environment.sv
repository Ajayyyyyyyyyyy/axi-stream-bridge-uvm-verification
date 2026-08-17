//=============================================================================
// File   : environment.sv
// Purpose: Completer-path environment configuration -- exercises
//          host-initiated register/BAR reads and writes into StreamBridge.
//          Active CQ driver, passive CC monitor, active arbiter agent, all
//          wired into the reference-model scoreboard via analysis ports.
//=============================================================================

class stream_bridge_env extends uvm_env;
  `uvm_component_utils(stream_bridge_env)

  cq_agent                 cq;
  cc_agent                 cc;
  arb_agent                arb;
  stream_bridge_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cq  = cq_agent::type_id::create("cq", this);
    cc  = cc_agent::type_id::create("cc", this);
    arb = arb_agent::type_id::create("arb", this);
    scoreboard = stream_bridge_scoreboard::type_id::create("scoreboard", this);

    cq.is_active  = UVM_ACTIVE;
    cc.is_active  = UVM_PASSIVE;
    arb.is_active = UVM_ACTIVE;
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    cq.monitor.ap.connect(scoreboard.cq_export);
    cc.monitor.ap.connect(scoreboard.cc_export);
    arb.monitor.ap.connect(scoreboard.fab_export);
  endfunction

endclass
