//=============================================================================
// File   : cq_agent.sv -- Completer Request (CQ) agent, ACTIVE
// Drives host-initiated register/BAR read and write requests into the
// StreamBridge CQ AXI4-Stream interface, and monitors what was actually
// driven for the scoreboard.
//=============================================================================

class cq_sequencer extends uvm_sequencer #(sb_txn);
  `uvm_component_utils(cq_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class cq_driver extends uvm_driver #(sb_txn);
  `uvm_component_utils(cq_driver)

  virtual stream_bridge_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual stream_bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for cq_driver")
  endfunction

  task run_phase(uvm_phase phase);
    vif.cb.cq_tvalid <= 1'b0;
    wait (vif.rst_n === 1'b1);

    forever begin
      sb_txn req;
      seq_item_port.get_next_item(req);
      drive_txn(req);
      seq_item_port.item_done();
    end
  endtask

  // Packs address/tag/write-enable into an original sideband descriptor.
  // Layout (cq_tuser[63:0]):
  //   [0]     is_write
  //   [8:1]   tag
  //   [47:9]  addr[38:0]  (local/BAR address space)
  //   [63:48] reserved
  task drive_txn(sb_txn req);
    int unsigned beats;
    bit [63:0] descriptor;

    descriptor        = '0;
    descriptor[0]      = (req.kind == TXN_CPL_WR_REQ);
    descriptor[8:1]    = req.tag;
    descriptor[47:9]   = req.addr[38:0];

    beats = (req.payload.size() == 0) ? 1 : req.payload.size();

    @(vif.cb);
    for (int unsigned b = 0; b < beats; b++) begin
      vif.cb.cq_tvalid <= 1'b1;
      vif.cb.cq_tdata  <= (req.kind == TXN_CPL_WR_REQ && req.payload.size() > b) ?
                           {480'h0, req.payload[b]} : '0;
      vif.cb.cq_tkeep  <= '1;
      vif.cb.cq_tlast  <= (b == beats - 1);
      vif.cb.cq_tuser  <= descriptor;
      @(vif.cb iff vif.cb.cq_tready === 1'b1);
    end
    vif.cb.cq_tvalid <= 1'b0;
    vif.cb.cq_tlast  <= 1'b0;
    `uvm_info(get_type_name(), $sformatf("drove %s", req.convert2string()), UVM_HIGH)
  endtask
endclass

class cq_monitor extends uvm_monitor;
  `uvm_component_utils(cq_monitor)

  virtual stream_bridge_if vif;
  uvm_analysis_port #(sb_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual stream_bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for cq_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      sb_txn txn;
      bit [63:0] descriptor;
      bit        is_write;

      @(vif.cb iff (vif.cb.cq_tvalid === 1'b1 && vif.cb.cq_tready === 1'b1));
      descriptor = vif.cb.cq_tuser;
      is_write   = descriptor[0];

      txn = sb_txn::type_id::create("cq_txn");
      txn.kind = is_write ? TXN_CPL_WR_REQ : TXN_CPL_RD_REQ;
      txn.addr = {25'h0, descriptor[47:9]};
      txn.tag  = descriptor[8:1];

      forever begin
        if (is_write) txn.payload.push_back(vif.cb.cq_tdata[31:0]);
        if (vif.cb.cq_tlast) break;
        @(vif.cb iff vif.cb.cq_tvalid === 1'b1 && vif.cb.cq_tready === 1'b1);
      end
      txn.length_bytes = is_write ? (txn.payload.size() * 4) : 4;

      ap.write(txn);
    end
  endtask
endclass

class cq_agent extends uvm_agent;
  `uvm_component_utils(cq_agent)

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  cq_sequencer sequencer;
  cq_driver    driver;
  cq_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = cq_monitor::type_id::create("monitor", this);
    if (is_active == UVM_ACTIVE) begin
      sequencer = cq_sequencer::type_id::create("sequencer", this);
      driver    = cq_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
