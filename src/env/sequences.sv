//=============================================================================
// File   : sequences.sv
// Purpose: Stimulus sequences for the StreamBridge completer path.
//
// This is a curated excerpt of the full sequence library. Sequences for the
// requester/DMA path (dma_write_readback_seq, dma_single_cmd_seq,
// dma_size_sweep_seq, rc_responder_seq) and additional completer-path
// stimulus (cpl_continuous_burst_seq) are omitted here — see the README for
// what they covered.
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
