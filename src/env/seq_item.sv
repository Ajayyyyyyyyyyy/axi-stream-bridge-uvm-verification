//=============================================================================
// File   : seq_item.sv
// Purpose: Unified transaction object for the StreamBridge UVM environment.
//          A single sequence-item type is shared by every agent so the
//          scoreboard can consume one polymorphic stream of transactions on
//          each analysis export instead of a family of near-duplicate item
//          classes. All fields/encodings below are original to this project.
//=============================================================================

typedef enum int unsigned {
  TXN_CPL_RD_REQ,   // CQ: host register/BAR read request
  TXN_CPL_WR_REQ,   // CQ: host register/BAR write request
  TXN_CPL_CPL,      // CC: completion returned to host
  TXN_REQ_RD_REQ,   // RQ: DMA-engine-issued read request to host memory
  TXN_REQ_WR_REQ,   // RQ: DMA-engine-issued write request to host memory
  TXN_REQ_CPL,      // RC: host completion returned for a DMA read
  TXN_DMA_RD_CMD,   // DMA command sequencer: device -> host read
  TXN_DMA_WR_CMD,   // DMA command sequencer: device -> host write
  TXN_DMA_DONE,     // DMA engine: command retirement
  TXN_FAB_RD_REQ,   // internal fabric bus read request phase (reserved trace point)
  TXN_FAB_WR_REQ,   // internal fabric bus write request (bridge -> arbiter)
  TXN_FAB_RD_DATA   // internal fabric bus read data return (arbiter -> bridge)
} sb_txn_kind_e;

typedef enum bit [1:0] {
  CPL_STATUS_OK     = 2'b00,
  CPL_STATUS_UR      = 2'b01, // unsupported request
  CPL_STATUS_CA      = 2'b10, // completer abort
  CPL_STATUS_RETRY   = 2'b11
} sb_cpl_status_e;

// One 32-byte fabric-bus line, expressed as 8 x 32-bit lanes (matches
// FAB_DATA_W = 256 in stream_bridge_if). Shared by the scoreboard's shadow
// memory model and the arbiter agent's backing-store model.
typedef bit [31:0] fab_line_data_t [8];
typedef bit        fab_line_valid_t [8];

class sb_txn extends uvm_sequence_item;

  rand sb_txn_kind_e      kind;

  // ---- addressing / identification --------------------------------------
  rand bit [63:0]         addr;          // byte address (host or local)
  rand bit [7:0]          tag;           // outstanding-transaction tag
  rand bit [15:0]         requester_id;  // requester/completer identity
  rand int unsigned       length_bytes;  // transfer length in bytes
  rand bit [3:0]          first_be;
  rand bit [3:0]          last_be;

  // ---- payload ------------------------------------------------------------
  rand bit [31:0]         payload[$];    // DWORD-granular payload queue

  // ---- completion-specific fields ------------------------------------------
  rand sb_cpl_status_e    status;
  rand int unsigned       byte_count;    // remaining byte count (RC/CC)
  rand bit [6:0]          lower_addr;    // low address bits echoed in CC

  // ---- fabric-bus-specific fields --------------------------------------------
  rand bit [3:0]          fab_src_id;    // which agent won arbitration
  rand bit                fab_wr_en;
  rand bit [31:0]         fab_wstrb;

  // ---- DMA-specific fields -----------------------------------------------------
  rand bit                dma_dir;       // 0 = device->host, 1 = host->device
  rand bit [63:0]         dma_host_addr;
  rand bit [38:0]         dma_local_addr;
  rand bit                dma_err;

  `uvm_object_utils_begin(sb_txn)
    `uvm_field_enum(sb_txn_kind_e, kind, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(tag, UVM_ALL_ON)
    `uvm_field_int(requester_id, UVM_ALL_ON)
    `uvm_field_int(length_bytes, UVM_ALL_ON)
    `uvm_field_int(first_be, UVM_ALL_ON)
    `uvm_field_int(last_be, UVM_ALL_ON)
    `uvm_field_queue_int(payload, UVM_ALL_ON)
    `uvm_field_enum(sb_cpl_status_e, status, UVM_ALL_ON)
    `uvm_field_int(byte_count, UVM_ALL_ON)
    `uvm_field_int(lower_addr, UVM_ALL_ON)
    `uvm_field_int(fab_src_id, UVM_ALL_ON)
    `uvm_field_int(fab_wr_en, UVM_ALL_ON)
    `uvm_field_int(fab_wstrb, UVM_ALL_ON)
    `uvm_field_int(dma_dir, UVM_ALL_ON)
    `uvm_field_int(dma_host_addr, UVM_ALL_ON)
    `uvm_field_int(dma_local_addr, UVM_ALL_ON)
    `uvm_field_int(dma_err, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "sb_txn");
    super.new(name);
  endfunction

  constraint c_length_reasonable {
    length_bytes inside {[4:4096]};
    length_bytes % 4 == 0;
  }

  function int unsigned dword_count();
    return length_bytes / 4;
  endfunction

  function string convert2string();
    return $sformatf(
      "kind=%s addr=0x%0h tag=0x%0h rid=0x%0h len=%0d status=%s payload_size=%0d",
      kind.name(), addr, tag, requester_id, length_bytes, status.name(), payload.size());
  endfunction

endclass

// Outstanding-transaction tracking row: one tag-indexed associative array
// per requester_id, used by the scoreboard's [requester_id][tag] structure.
typedef sb_txn sb_txn_by_tag_t [bit [7:0]];
