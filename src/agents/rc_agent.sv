//=============================================================================
// File   : rc_agent.sv -- Requester Completion (RC) agent, ACTIVE
// Models the host's completion behaviour for device-initiated DMA reads:
// reacts to RQ read requests captured directly off the bus (there is no
// separate "host memory" component in this environment) and returns
// deterministic, address-derived completion data on RC.
//=============================================================================

class rc_sequencer extends uvm_sequencer #(sb_txn);
  `uvm_component_utils(rc_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class rc_driver extends uvm_driver #(sb_txn);
  `uvm_component_utils(rc_driver)

  virtual stream_bridge_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual stream_bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for rc_driver")
  endfunction

  // Sequence items pulled from the sequencer act as a timing/behaviour
  // policy rather than payload content -- matching the reactive nature of
  // a completion responder (see rc_responder_seq in sequences.sv).
  //
  // Layout driven on rc_tuser[63:0]:
  //   [1:0]   status
  //   [17:2]  byte_count[15:0]
  //   [25:18] tag[7:0]
  //   [63:26] reserved
  task run_phase(uvm_phase phase);
    vif.cb.rc_tvalid <= 1'b0;
    wait (vif.rst_n === 1'b1);

    forever begin
      sb_txn policy;
      bit [7:0]    tag;
      bit [38:0]   haddr;
      bit [19:0]   len;
      int unsigned dwords;

      seq_item_port.get_next_item(policy);

      @(vif.cb iff (vif.cb.rq_tvalid === 1'b1 && vif.cb.rq_tready === 1'b1 &&
                    !vif.cb.rq_tuser[0]));
      tag    = vif.cb.rq_tuser[8:1];
      haddr  = vif.cb.rq_tuser[47:9];
      len    = vif.cb.rq_tdata[19:0];
      dwords = (len == 0) ? 1 : (len / 4);

      @(vif.cb);
      for (int unsigned d = 0; d < dwords; d++) begin
        vif.cb.rc_tvalid      <= 1'b1;
        vif.cb.rc_tdata[31:0] <= {haddr[28:0], 3'h0} + (d * 4); // deterministic host pattern
        vif.cb.rc_tlast       <= (d == dwords - 1);
        vif.cb.rc_tuser       <= {38'h0, tag, len[15:0], 2'b00}; // status = OK
        @(vif.cb iff vif.cb.rc_tready === 1'b1);
      end
      vif.cb.rc_tvalid <= 1'b0;
      vif.cb.rc_tlast  <= 1'b0;

      seq_item_port.item_done();
    end
  endtask
endclass

class rc_monitor extends uvm_monitor;
  `uvm_component_utils(rc_monitor)

  virtual stream_bridge_if vif;
  uvm_analysis_port #(sb_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual stream_bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for rc_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      sb_txn txn;
      bit [1:0]  status;
      bit [15:0] byte_count;
      bit [7:0]  tag;

      @(vif.cb iff (vif.cb.rc_tvalid === 1'b1 && vif.cb.rc_tready === 1'b1));
      status     = vif.cb.rc_tuser[1:0];
      byte_count = vif.cb.rc_tuser[17:2];
      tag        = vif.cb.rc_tuser[25:18];

      txn = sb_txn::type_id::create("rc_txn");
      txn.kind         = TXN_REQ_CPL;
      txn.status       = sb_cpl_status_e'(status);
      txn.byte_count   = byte_count;
      txn.tag          = tag;
      txn.requester_id = 16'hDA00;

      forever begin
        txn.payload.push_back(vif.cb.rc_tdata[31:0]);
        if (vif.cb.rc_tlast) break;
        @(vif.cb iff vif.cb.rc_tvalid === 1'b1 && vif.cb.rc_tready === 1'b1);
      end

      ap.write(txn);
    end
  endtask
endclass

class rc_agent extends uvm_agent;
  `uvm_component_utils(rc_agent)

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  rc_sequencer sequencer;
  rc_driver    driver;
  rc_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = rc_monitor::type_id::create("monitor", this);
    if (is_active == UVM_ACTIVE) begin
      sequencer = rc_sequencer::type_id::create("sequencer", this);
      driver    = rc_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
