//=============================================================================
// File   : scoreboard.sv
// Purpose: Reference-model scoreboard for the StreamBridge environment.
//
// Two independent checking strategies live here, mirroring the two things
// that actually matter about a bridge like this:
//
//   1. Outstanding-transaction tracking, keyed by [requester_id][tag].
//      Completer (CQ/CC) and requester/DMA (RQ/RC) traffic share one
//      tracking structure: DMA-issued requests use a fixed internal
//      requester_id so they land in the same associative-array shape as
//      host-issued completer requests. Completions are checked against
//      the DWORD count implied by the original request's length.
//
//   2. A shadow-memory model of the internal 256-bit fabric bus, checked
//      write-by-write: every write is decomposed into its 8 x 32-bit
//      lanes using the write-strobe, every subsequent read at that same
//      32-byte line is checked lane-by-lane against what was last
//      written there. Misaligned fabric accesses are flagged directly.
//=============================================================================

`uvm_analysis_imp_decl(_cq)
`uvm_analysis_imp_decl(_cc)
`uvm_analysis_imp_decl(_rq)
`uvm_analysis_imp_decl(_rc)
`uvm_analysis_imp_decl(_dma)
`uvm_analysis_imp_decl(_fab)

class stream_bridge_scoreboard extends uvm_component;
  `uvm_component_utils(stream_bridge_scoreboard)

  uvm_analysis_imp_cq  #(sb_txn, stream_bridge_scoreboard) cq_export;
  uvm_analysis_imp_cc  #(sb_txn, stream_bridge_scoreboard) cc_export;
  uvm_analysis_imp_rq  #(sb_txn, stream_bridge_scoreboard) rq_export;
  uvm_analysis_imp_rc  #(sb_txn, stream_bridge_scoreboard) rc_export;
  uvm_analysis_imp_dma #(sb_txn, stream_bridge_scoreboard) dma_export;
  uvm_analysis_imp_fab #(sb_txn, stream_bridge_scoreboard) fab_export;

  // ---------------------------------------------------------------------
  // Outstanding-transaction tracking, keyed by [requester_id][tag].
  // ---------------------------------------------------------------------
  local sb_txn_by_tag_t outstanding[bit [15:0]];

  local const bit [15:0] DMA_ENGINE_RID = 16'hDA00;

  // ---------------------------------------------------------------------
  // Shadow memory model of the internal fabric bus: one fab_line_data_t
  // per 32-byte line, plus a per-lane valid bit so reads to never-written
  // lanes aren't flagged as mismatches.
  // ---------------------------------------------------------------------
  local fab_line_data_t  shadow_line[bit [38:5]];
  local fab_line_valid_t shadow_line_valid[bit [38:5]];

  // ---------------------------------------------------------------------
  // Statistics
  // ---------------------------------------------------------------------
  int unsigned num_cpl_checked;
  int unsigned num_dma_rd_checked;
  int unsigned num_fab_writes_checked;
  int unsigned num_fab_reads_checked;
  int unsigned num_errors;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cq_export  = new("cq_export", this);
    cc_export  = new("cc_export", this);
    rq_export  = new("rq_export", this);
    rc_export  = new("rc_export", this);
    dma_export = new("dma_export", this);
    fab_export = new("fab_export", this);
  endfunction

  //=========================================================================
  // Completer path: CQ opens an outstanding entry, CC must close it.
  //=========================================================================

  function void write_cq(sb_txn t);
    if (outstanding.exists(t.requester_id) && outstanding[t.requester_id].exists(t.tag))
      flag_error($sformatf("CQ tag reuse before completion: rid=0x%0h tag=0x%0h",
                            t.requester_id, t.tag));
    outstanding[t.requester_id][t.tag] = t;
  endfunction

  function void write_cc(sb_txn t);
    sb_txn       req;
    int unsigned expected_dwords;

    if (!outstanding.exists(t.requester_id) || !outstanding[t.requester_id].exists(t.tag)) begin
      flag_error($sformatf("CC seen with no matching outstanding CQ request: rid=0x%0h tag=0x%0h",
                            t.requester_id, t.tag));
      return;
    end

    req             = outstanding[t.requester_id][t.tag];
    expected_dwords = req.dword_count();

    if (req.kind == TXN_CPL_RD_REQ) begin
      if (t.payload.size() != expected_dwords)
        flag_error($sformatf(
          "CC DWORD count mismatch: rid=0x%0h tag=0x%0h expected=%0d actual=%0d",
          t.requester_id, t.tag, expected_dwords, t.payload.size()));
      if (t.byte_count != expected_dwords * 4)
        flag_error($sformatf(
          "CC byte_count field mismatch: rid=0x%0h tag=0x%0h expected=%0d actual=%0d",
          t.requester_id, t.tag, expected_dwords * 4, t.byte_count));
    end
    else if (req.kind == TXN_CPL_WR_REQ) begin
      if (t.payload.size() != 0)
        flag_error($sformatf(
          "CC for a write request carried unexpected payload: rid=0x%0h tag=0x%0h size=%0d",
          t.requester_id, t.tag, t.payload.size()));
    end

    if (t.status != CPL_STATUS_OK)
      flag_error($sformatf("CC returned non-OK status %s for rid=0x%0h tag=0x%0h",
                            t.status.name(), t.requester_id, t.tag));

    outstanding[t.requester_id].delete(t.tag);
    num_cpl_checked++;
  endfunction

  //=========================================================================
  // Requester/DMA path: RQ opens an outstanding entry under the fixed DMA
  // engine requester_id, RC must close it. Only reads carry a completion
  // in this environment (writes are posted).
  //=========================================================================

  function void write_rq(sb_txn t);
    if (t.kind != TXN_REQ_RD_REQ) return; // writes are posted, nothing to track

    if (outstanding.exists(DMA_ENGINE_RID) && outstanding[DMA_ENGINE_RID].exists(t.tag))
      flag_error($sformatf("RQ tag reuse before completion: tag=0x%0h", t.tag));
    outstanding[DMA_ENGINE_RID][t.tag] = t;
  endfunction

  function void write_rc(sb_txn t);
    sb_txn       req;
    int unsigned expected_dwords;

    if (!outstanding.exists(DMA_ENGINE_RID) || !outstanding[DMA_ENGINE_RID].exists(t.tag)) begin
      flag_error($sformatf("RC seen with no matching outstanding RQ request: tag=0x%0h", t.tag));
      return;
    end

    req             = outstanding[DMA_ENGINE_RID][t.tag];
    expected_dwords = req.dword_count();

    if (t.payload.size() != expected_dwords)
      flag_error($sformatf(
        "RC DWORD count mismatch: tag=0x%0h expected=%0d actual=%0d",
        t.tag, expected_dwords, t.payload.size()));

    if (t.byte_count != expected_dwords * 4)
      flag_error($sformatf(
        "RC byte_count field mismatch: tag=0x%0h expected=%0d actual=%0d",
        t.tag, expected_dwords * 4, t.byte_count));

    if (t.status != CPL_STATUS_OK)
      flag_error($sformatf("RC returned non-OK status %s for tag=0x%0h",
                            t.status.name(), t.tag));

    outstanding[DMA_ENGINE_RID].delete(t.tag);
    num_dma_rd_checked++;
  endfunction

  //=========================================================================
  // DMA command sequencer traffic: informational only in this scoreboard;
  // the correctness contract for DMA reads is already covered by RQ/RC.
  //=========================================================================

  function void write_dma(sb_txn t);
    `uvm_info(get_type_name(), $sformatf("DMA command observed: %s", t.convert2string()),
              UVM_HIGH)
  endfunction

  //=========================================================================
  // Internal fabric bus: shadow-memory write-by-write verification.
  //=========================================================================

  function void write_fab(sb_txn t);
    bit [38:5] line = t.addr[38:5];

    if (t.addr[4:0] != 5'b0) begin
      flag_error($sformatf("Fabric bus access is not 32-byte aligned: addr=0x%0h", t.addr));
      return;
    end

    if (t.kind == TXN_FAB_WR_REQ) begin
      for (int lane = 0; lane < 8; lane++) begin
        if (t.fab_wstrb[lane*4 +: 4] != 4'h0) begin
          shadow_line[line][lane]       = t.payload[lane];
          shadow_line_valid[line][lane] = 1'b1;
        end
      end
      num_fab_writes_checked++;
    end
    else if (t.kind == TXN_FAB_RD_DATA) begin
      for (int lane = 0; lane < 8; lane++) begin
        if (!shadow_line_valid.exists(line) || !shadow_line_valid[line][lane]) continue;
        if (t.payload[lane] !== shadow_line[line][lane])
          flag_error($sformatf(
            "Fabric bus read data mismatch: addr=0x%0h lane=%0d expected=0x%08h actual=0x%08h",
            t.addr, lane, shadow_line[line][lane], t.payload[lane]));
      end
      num_fab_reads_checked++;
    end
  endfunction

  //=========================================================================

  local function void flag_error(string msg);
    num_errors++;
    `uvm_error(get_type_name(), msg)
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(), $sformatf(
      "Scoreboard summary: completions=%0d dma_reads=%0d fab_writes=%0d fab_reads=%0d errors=%0d",
      num_cpl_checked, num_dma_rd_checked, num_fab_writes_checked, num_fab_reads_checked,
      num_errors), UVM_LOW)

    foreach (outstanding[rid])
      foreach (outstanding[rid][tag])
        `uvm_warning(get_type_name(),
          $sformatf("Outstanding transaction never completed: rid=0x%0h tag=0x%0h", rid, tag))
  endfunction

endclass
