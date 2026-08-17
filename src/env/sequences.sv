//=============================================================================
// File   : sequences.sv
// Purpose: Stimulus sequences for the StreamBridge environment.
//=============================================================================

class cpl_base_seq extends uvm_sequence #(sb_txn);
  `uvm_object_utils(cpl_base_seq)
  function new(string name = "cpl_base_seq");
    super.new(name);
  endfunction
endclass

//-----------------------------------------------------------------------------
// Single completer write followed by a completer read-back to the same
// address. Proves that host-visible register/BAR state is coherent through
// the CQ/CC path and the internal fabric bus.
//-----------------------------------------------------------------------------
class cpl_write_readback_seq extends cpl_base_seq;
  `uvm_object_utils(cpl_write_readback_seq)

  rand bit [63:0]   addr;
  rand int unsigned length_bytes;
  rand bit [7:0]    tag;

  constraint c_default {
    length_bytes inside {4, 8, 16, 32, 64};
    addr[1:0] == 2'b00;
  }

  function new(string name = "cpl_write_readback_seq");
    super.new(name);
  endfunction

  task body();
    sb_txn wr, rd;

    wr = sb_txn::type_id::create("wr");
    start_item(wr);
    if (!wr.randomize() with {
          kind           == TXN_CPL_WR_REQ;
          addr           == local::addr;
          length_bytes   == local::length_bytes;
          tag            == local::tag;
          payload.size() == local::length_bytes / 4;
        })
      `uvm_error(get_type_name(), "randomization failed for completer write")
    finish_item(wr);

    rd = sb_txn::type_id::create("rd");
    start_item(rd);
    if (!rd.randomize() with {
          kind         == TXN_CPL_RD_REQ;
          addr         == local::addr;
          length_bytes == local::length_bytes;
          tag          == local::tag + 1;
        })
      `uvm_error(get_type_name(), "randomization failed for completer read")
    finish_item(rd);
  endtask
endclass

//-----------------------------------------------------------------------------
// Continuous burst: N back-to-back write-then-readback pairs at increasing
// addresses. The driver is free to pipeline these -- no idle gap is forced.
//-----------------------------------------------------------------------------
class cpl_continuous_burst_seq extends cpl_base_seq;
  `uvm_object_utils(cpl_continuous_burst_seq)

  rand int unsigned num_pairs = 16;
  rand bit [63:0]   base_addr = 64'h0000_0000_1000_0000;

  function new(string name = "cpl_continuous_burst_seq");
    super.new(name);
  endfunction

  task body();
    cpl_write_readback_seq sub;
    for (int unsigned i = 0; i < num_pairs; i++) begin
      sub = cpl_write_readback_seq::type_id::create($sformatf("sub_%0d", i));
      if (!sub.randomize() with {
            addr         == base_addr + (i * 64);
            length_bytes == 32;
            tag          == (i % 8'hFE);
          })
        `uvm_error(get_type_name(), "randomization failed for burst element")
      sub.start(m_sequencer, this);
    end
  endtask
endclass

//-----------------------------------------------------------------------------
// DMA write to host memory followed by a DMA read-back of the same region,
// driven through the DMA command sequencer (dma_agent's active sequencer).
//-----------------------------------------------------------------------------
class dma_write_readback_seq extends uvm_sequence #(sb_txn);
  `uvm_object_utils(dma_write_readback_seq)

  rand bit [63:0]   host_addr;
  rand bit [38:0]   local_addr;
  rand int unsigned length_bytes;
  rand bit [7:0]    tag;

  constraint c_default {
    length_bytes inside {64, 128, 256, 512, 1024};
    host_addr[5:0]  == 6'b0;
    local_addr[5:0] == 6'b0;
  }

  function new(string name = "dma_write_readback_seq");
    super.new(name);
  endfunction

  task body();
    sb_txn wr_cmd, rd_cmd;

    wr_cmd = sb_txn::type_id::create("wr_cmd");
    start_item(wr_cmd);
    if (!wr_cmd.randomize() with {
          kind           == TXN_DMA_WR_CMD;
          dma_dir        == 1'b1;
          dma_host_addr  == local::host_addr;
          dma_local_addr == local::local_addr;
          length_bytes   == local::length_bytes;
          tag            == local::tag;
        })
      `uvm_error(get_type_name(), "randomization failed for DMA write command")
    finish_item(wr_cmd);

    rd_cmd = sb_txn::type_id::create("rd_cmd");
    start_item(rd_cmd);
    if (!rd_cmd.randomize() with {
          kind           == TXN_DMA_RD_CMD;
          dma_dir        == 1'b0;
          dma_host_addr  == local::host_addr;
          dma_local_addr == local::local_addr;
          length_bytes   == local::length_bytes;
          tag            == local::tag + 1;
        })
      `uvm_error(get_type_name(), "randomization failed for DMA read command")
    finish_item(rd_cmd);
  endtask
endclass

//-----------------------------------------------------------------------------
// A single DMA command (read or write), used directly by the single-read
// and single-write focused tests.
//-----------------------------------------------------------------------------
class dma_single_cmd_seq extends uvm_sequence #(sb_txn);
  `uvm_object_utils(dma_single_cmd_seq)

  rand bit          dir; // 0 = read (device<-host), 1 = write (device->host)
  rand bit [63:0]   host_addr    = 64'h0000_0000_3000_0000;
  rand bit [38:0]   local_addr   = 39'h0;
  rand int unsigned length_bytes = 256;
  rand bit [7:0]    tag          = 8'h10;

  function new(string name = "dma_single_cmd_seq");
    super.new(name);
  endfunction

  task body();
    sb_txn cmd = sb_txn::type_id::create("cmd");
    start_item(cmd);
    if (!cmd.randomize() with {
          kind           == (dir ? TXN_DMA_WR_CMD : TXN_DMA_RD_CMD);
          dma_dir        == dir;
          dma_host_addr  == local::host_addr;
          dma_local_addr == local::local_addr;
          length_bytes   == local::length_bytes;
          tag            == local::tag;
        })
      `uvm_error(get_type_name(), "randomization failed for single DMA command")
    finish_item(cmd);
  endtask
endclass

//-----------------------------------------------------------------------------
// Sweeps DMA transfer size across a representative range (small transfers
// through a full 4KB page) to stress length/last-beat handling.
//-----------------------------------------------------------------------------
class dma_size_sweep_seq extends uvm_sequence #(sb_txn);
  `uvm_object_utils(dma_size_sweep_seq)

  int unsigned sizes[] = '{4, 16, 64, 128, 256, 512, 1024, 2048, 4096};

  function new(string name = "dma_size_sweep_seq");
    super.new(name);
  endfunction

  task body();
    dma_write_readback_seq sub;
    bit [63:0] host_addr = 64'h0000_0000_2000_0000;

    foreach (sizes[i]) begin
      sub = dma_write_readback_seq::type_id::create($sformatf("sweep_%0d", sizes[i]));
      if (!sub.randomize() with {
            length_bytes == sizes[i];
            host_addr    == local::host_addr;
            local_addr   == 39'h0;
            tag          == (i * 2);
          })
        `uvm_error(get_type_name(), "randomization failed for sweep element")
      sub.start(m_sequencer, this);
      host_addr += 64'h0001_0000; // keep regions from overlapping
    end
  endtask
endclass

//-----------------------------------------------------------------------------
// Arbiter responder policy sequence. The arb_driver is reactive: it grants
// whatever the DUT requests on the fabric bus and derives the actual
// address/data directly from the interface. This sequence only supplies a
// stream of generic policy items (controls things like grant latency),
// keeping the driver's reactive loop fed forever.
//-----------------------------------------------------------------------------
class arb_responder_seq extends uvm_sequence #(sb_txn);
  `uvm_object_utils(arb_responder_seq)

  function new(string name = "arb_responder_seq");
    super.new(name);
  endfunction

  task body();
    forever begin
      sb_txn item = sb_txn::type_id::create("arb_rsp");
      start_item(item);
      if (!item.randomize() with { kind == TXN_FAB_RD_DATA; })
        `uvm_error(get_type_name(), "randomization failed for arbiter responder item")
      finish_item(item);
    end
  endtask
endclass

//-----------------------------------------------------------------------------
// RC responder policy sequence, analogous to arb_responder_seq: keeps
// rc_driver's reactive loop fed so it can respond to RQ read requests as
// they appear on the bus.
//-----------------------------------------------------------------------------
class rc_responder_seq extends uvm_sequence #(sb_txn);
  `uvm_object_utils(rc_responder_seq)

  function new(string name = "rc_responder_seq");
    super.new(name);
  endfunction

  task body();
    forever begin
      sb_txn item = sb_txn::type_id::create("rc_rsp");
      start_item(item);
      if (!item.randomize() with { kind == TXN_REQ_CPL; })
        `uvm_error(get_type_name(), "randomization failed for RC responder item")
      finish_item(item);
    end
  endtask
endclass
