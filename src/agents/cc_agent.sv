//=============================================================================
// File   : cc_agent.sv -- Completer Completion (CC) agent, PASSIVE
// Observes completions StreamBridge returns to the host in response to CQ
// requests. This interface is entirely bridge-driven, so the agent carries
// no sequencer/driver; its only "active" behaviour is asserting tready,
// since there is no separate host-receiver component modeled here.
//=============================================================================

class cc_monitor extends uvm_monitor;
  `uvm_component_utils(cc_monitor)

  virtual stream_bridge_if vif;
  uvm_analysis_port #(sb_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual stream_bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for cc_monitor")
  endfunction

  // Layout (cc_tuser[63:0]) -- an original, self-consistent completion
  // descriptor for this environment:
  //   [1:0]   status
  //   [17:2]  byte_count[15:0]
  //   [24:18] lower_addr[6:0]
  //   [32:25] tag[7:0]
  //   [48:33] requester_id[15:0]
  //   [63:49] reserved
  task run_phase(uvm_phase phase);
    vif.cb.cc_tready <= 1'b0;
    wait (vif.rst_n === 1'b1);
    vif.cb.cc_tready <= 1'b1; // always-ready host receiver model

    forever begin
      sb_txn txn;
      bit [63:0] tuser;

      @(vif.cb iff (vif.cb.cc_tvalid === 1'b1 && vif.cb.cc_tready === 1'b1));
      tuser = vif.cb.cc_tuser;

      txn = sb_txn::type_id::create("cc_txn");
      txn.kind         = TXN_CPL_CPL;
      txn.status       = sb_cpl_status_e'(tuser[1:0]);
      txn.byte_count   = tuser[17:2];
      txn.lower_addr   = tuser[24:18];
      txn.tag          = tuser[32:25];
      txn.requester_id = tuser[48:33];

      forever begin
        txn.payload.push_back(vif.cb.cc_tdata[31:0]);
        if (vif.cb.cc_tlast) break;
        @(vif.cb iff vif.cb.cc_tvalid === 1'b1 && vif.cb.cc_tready === 1'b1);
      end

      ap.write(txn);
    end
  endtask
endclass

class cc_agent extends uvm_agent;
  `uvm_component_utils(cc_agent)

  uvm_active_passive_enum is_active = UVM_PASSIVE;
  cc_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = cc_monitor::type_id::create("monitor", this);
  endfunction
endclass
