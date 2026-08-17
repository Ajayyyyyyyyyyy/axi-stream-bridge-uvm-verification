//=============================================================================
// File   : rq_agent.sv -- Requester Request (RQ) agent, PASSIVE
// Observes device-initiated (DMA-engine-issued) requests StreamBridge sends
// toward host memory. Bridge-driven interface, so no sequencer/driver; the
// monitor asserts tready as an always-ready host model, mirroring cc_agent.
//=============================================================================

class rq_monitor extends uvm_monitor;
  `uvm_component_utils(rq_monitor)

  virtual stream_bridge_if vif;
  uvm_analysis_port #(sb_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual stream_bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for rq_monitor")
  endfunction

  // Layout (rq_tuser[63:0]):
  //   [0]     is_write
  //   [8:1]   tag[7:0]
  //   [47:9]  host_addr[38:0]
  //   [63:48] reserved
  // For reads, the length is not needed on tuser -- it rides in the first
  // beat's tdata[19:0] as a lightweight read-descriptor (no payload).
  task run_phase(uvm_phase phase);
    vif.cb.rq_tready <= 1'b0;
    wait (vif.rst_n === 1'b1);
    vif.cb.rq_tready <= 1'b1; // always-ready host receiver model

    forever begin
      sb_txn txn;
      bit        is_write;
      bit [7:0]  tag;
      bit [38:0] haddr;

      @(vif.cb iff (vif.cb.rq_tvalid === 1'b1 && vif.cb.rq_tready === 1'b1));
      is_write = vif.cb.rq_tuser[0];
      tag      = vif.cb.rq_tuser[8:1];
      haddr    = vif.cb.rq_tuser[47:9];

      txn = sb_txn::type_id::create("rq_txn");
      txn.kind          = is_write ? TXN_REQ_WR_REQ : TXN_REQ_RD_REQ;
      txn.tag           = tag;
      txn.dma_host_addr = {25'h0, haddr};
      txn.requester_id  = 16'hDA00; // fixed identity for the internal DMA engine

      forever begin
        if (is_write) txn.payload.push_back(vif.cb.rq_tdata[31:0]);
        if (vif.cb.rq_tlast) break;
        @(vif.cb iff vif.cb.rq_tvalid === 1'b1 && vif.cb.rq_tready === 1'b1);
      end
      txn.length_bytes = is_write ? (txn.payload.size() * 4) : vif.cb.rq_tdata[19:0];

      ap.write(txn);
    end
  endtask
endclass

class rq_agent extends uvm_agent;
  `uvm_component_utils(rq_agent)

  uvm_active_passive_enum is_active = UVM_PASSIVE;
  rq_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = rq_monitor::type_id::create("monitor", this);
  endfunction
endclass
