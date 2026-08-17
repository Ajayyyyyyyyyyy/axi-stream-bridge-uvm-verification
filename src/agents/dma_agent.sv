//=============================================================================
// File   : dma_agent.sv -- DMA command agent, ACTIVE
// Drives the DMA command sideband to kick off device-initiated transfers,
// and monitors both outgoing commands and incoming completion/retirement
// events (dma_done_*) for the scoreboard.
//=============================================================================

class dma_sequencer extends uvm_sequencer #(sb_txn);
  `uvm_component_utils(dma_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class dma_driver extends uvm_driver #(sb_txn);
  `uvm_component_utils(dma_driver)

  virtual stream_bridge_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual stream_bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for dma_driver")
  endfunction

  task run_phase(uvm_phase phase);
    vif.cb.dma_cmd_valid <= 1'b0;
    wait (vif.rst_n === 1'b1);

    forever begin
      sb_txn req;
      seq_item_port.get_next_item(req);

      @(vif.cb);
      vif.cb.dma_cmd_valid  <= 1'b1;
      vif.cb.dma_cmd_dir    <= req.dma_dir;
      vif.cb.dma_cmd_haddr  <= req.dma_host_addr;
      vif.cb.dma_cmd_laddr  <= req.dma_local_addr;
      vif.cb.dma_cmd_length <= req.length_bytes;
      vif.cb.dma_cmd_tag    <= req.tag;
      @(vif.cb iff vif.cb.dma_cmd_ready === 1'b1);
      vif.cb.dma_cmd_valid <= 1'b0;

      `uvm_info(get_type_name(), $sformatf("issued %s", req.convert2string()), UVM_HIGH)
      seq_item_port.item_done();
    end
  endtask
endclass

class dma_monitor extends uvm_monitor;
  `uvm_component_utils(dma_monitor)

  virtual stream_bridge_if vif;
  uvm_analysis_port #(sb_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual stream_bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for dma_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    fork
      monitor_commands();
      monitor_completions();
    join
  endtask

  task monitor_commands();
    forever begin
      sb_txn txn;
      @(vif.cb iff (vif.cb.dma_cmd_valid === 1'b1 && vif.cb.dma_cmd_ready === 1'b1));
      txn = sb_txn::type_id::create("dma_cmd_txn");
      txn.kind           = vif.cb.dma_cmd_dir ? TXN_DMA_WR_CMD : TXN_DMA_RD_CMD;
      txn.dma_dir        = vif.cb.dma_cmd_dir;
      txn.dma_host_addr  = vif.cb.dma_cmd_haddr;
      txn.dma_local_addr = vif.cb.dma_cmd_laddr;
      txn.length_bytes   = vif.cb.dma_cmd_length;
      txn.tag            = vif.cb.dma_cmd_tag;
      ap.write(txn);
    end
  endtask

  task monitor_completions();
    forever begin
      sb_txn txn;
      @(vif.cb iff vif.cb.dma_done_valid === 1'b1);
      txn = sb_txn::type_id::create("dma_done_txn");
      txn.kind    = TXN_DMA_DONE;
      txn.tag     = vif.cb.dma_done_tag;
      txn.dma_err = vif.cb.dma_done_err;
      ap.write(txn);
    end
  endtask
endclass

class dma_agent extends uvm_agent;
  `uvm_component_utils(dma_agent)

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  dma_sequencer sequencer;
  dma_driver    driver;
  dma_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = dma_monitor::type_id::create("monitor", this);
    if (is_active == UVM_ACTIVE) begin
      sequencer = dma_sequencer::type_id::create("sequencer", this);
      driver    = dma_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
