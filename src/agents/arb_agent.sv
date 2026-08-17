//=============================================================================
// File   : arb_agent.sv -- Internal fabric-bus arbiter agent, ACTIVE
// Models the shared memory/fabric side of the internal 256-bit arbitrated
// bus: grants StreamBridge's requests and serves reads/writes against a
// simple backing-store model (organized as 32-byte lines / 8 x 32-bit
// lanes), so reads reflect prior writes for real rather than a synthetic
// pattern. This gives the scoreboard's independent shadow-memory check
// (see scoreboard.sv) something genuine to catch if either side's
// write-strobe/lane-extraction logic disagrees.
//=============================================================================

class arb_sequencer extends uvm_sequencer #(sb_txn);
  `uvm_component_utils(arb_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class arb_driver extends uvm_driver #(sb_txn);
  `uvm_component_utils(arb_driver)

  virtual stream_bridge_if vif;
  rand int unsigned grant_latency = 1;

  local fab_line_data_t mem_line[bit [38:5]];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual stream_bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for arb_driver")
  endfunction

  task run_phase(uvm_phase phase);
    vif.cb.fab_gnt    <= 1'b0;
    vif.cb.fab_rvalid <= 1'b0;
    vif.cb.fab_rdata  <= '0;
    vif.cb.fab_rerr   <= 1'b0;
    wait (vif.rst_n === 1'b1);

    forever begin
      sb_txn policy;
      bit [38:5] line;

      seq_item_port.get_next_item(policy); // consumes latency/behaviour policy

      @(vif.cb iff vif.cb.fab_req === 1'b1);
      repeat (grant_latency) @(vif.cb);
      vif.cb.fab_gnt <= 1'b1;

      line = vif.cb.fab_addr[38:5];

      if (vif.cb.fab_wr_en) begin
        for (int lane = 0; lane < 8; lane++)
          if (vif.cb.fab_wstrb[lane*4 +: 4] != 4'h0)
            mem_line[line][lane] = vif.cb.fab_wdata[lane*32 +: 32];
        @(vif.cb);
        vif.cb.fab_gnt <= 1'b0;
      end
      else begin
        @(vif.cb);
        vif.cb.fab_gnt <= 1'b0;
        for (int lane = 0; lane < 8; lane++)
          vif.cb.fab_rdata[lane*32 +: 32] <= mem_line[line][lane];
        vif.cb.fab_rvalid <= 1'b1;
        @(vif.cb);
        vif.cb.fab_rvalid <= 1'b0;
      end

      seq_item_port.item_done();
    end
  endtask
endclass

class arb_monitor extends uvm_monitor;
  `uvm_component_utils(arb_monitor)

  virtual stream_bridge_if vif;
  uvm_analysis_port #(sb_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual stream_bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for arb_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      bit [38:0]  addr;
      bit         wr_en;
      bit [255:0] wdata;
      bit [31:0]  wstrb;

      @(vif.cb iff (vif.cb.fab_req === 1'b1 && vif.cb.fab_gnt === 1'b1));
      addr  = vif.cb.fab_addr;
      wr_en = vif.cb.fab_wr_en;
      wdata = vif.cb.fab_wdata;
      wstrb = vif.cb.fab_wstrb;

      if (wr_en) begin
        sb_txn txn = sb_txn::type_id::create("fab_wr_txn");
        txn.kind      = TXN_FAB_WR_REQ;
        txn.addr      = addr;
        txn.fab_wr_en = 1'b1;
        txn.fab_wstrb = wstrb;
        for (int lane = 0; lane < 8; lane++)
          txn.payload.push_back(wdata[lane*32 +: 32]);
        ap.write(txn);
      end
      else begin
        sb_txn txn;
        @(vif.cb iff vif.cb.fab_rvalid === 1'b1);
        txn = sb_txn::type_id::create("fab_rd_txn");
        txn.kind = TXN_FAB_RD_DATA;
        txn.addr = addr;
        for (int lane = 0; lane < 8; lane++)
          txn.payload.push_back(vif.cb.fab_rdata[lane*32 +: 32]);
        ap.write(txn);
      end
    end
  endtask
endclass

class arb_agent extends uvm_agent;
  `uvm_component_utils(arb_agent)

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  arb_sequencer sequencer;
  arb_driver    driver;
  arb_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = arb_monitor::type_id::create("monitor", this);
    if (is_active == UVM_ACTIVE) begin
      sequencer = arb_sequencer::type_id::create("sequencer", this);
      driver    = arb_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
