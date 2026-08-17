//=============================================================================
// File   : stream_bridge_if.sv
// Purpose: Testbench-side interface for the StreamBridge DUT.
//
// Exposes the four industry-standard AXI4-Stream interface roles used by
// Xilinx-style PCIe integrated blocks (Completer Request/CQ, Completer
// Completion/CC, Requester Request/RQ, Requester Completion/RC -- see
// Xilinx PG156 for the public definition of these roles), plus an original,
// wholly independent internal fabric bus and DMA command/data path that
// StreamBridge itself defines. All internal signal names, encodings, and
// widths below are invented for this project.
//=============================================================================

interface stream_bridge_if #(
  parameter int AXIS_DATA_W = 512,
  parameter int AXIS_KEEP_W = AXIS_DATA_W / 32,
  parameter int FAB_DATA_W  = 256,
  parameter int FAB_ADDR_W  = 39,
  parameter int FAB_STRB_W  = FAB_DATA_W / 8,
  parameter int TAG_W       = 8,
  parameter int REQID_W     = 16
)(
  input logic clk,
  input logic rst_n
);

  //---------------------------------------------------------------------
  // Completer Request (CQ) -- host-initiated register/BAR access,
  // host -> StreamBridge. Standard AXI4-Stream handshake.
  //---------------------------------------------------------------------
  logic                   cq_tvalid;
  logic                   cq_tready;
  logic [AXIS_DATA_W-1:0] cq_tdata;
  logic [AXIS_KEEP_W-1:0] cq_tkeep;
  logic                   cq_tlast;
  logic [63:0]            cq_tuser; // sideband descriptor, see cq_agent.sv

  //---------------------------------------------------------------------
  // Completer Completion (CC) -- StreamBridge -> host, completion for CQ.
  //---------------------------------------------------------------------
  logic                   cc_tvalid;
  logic                   cc_tready;
  logic [AXIS_DATA_W-1:0] cc_tdata;
  logic [AXIS_KEEP_W-1:0] cc_tkeep;
  logic                   cc_tlast;
  logic [63:0]            cc_tuser; // sideband descriptor, see cc_agent.sv

  //---------------------------------------------------------------------
  // Requester Request (RQ) -- StreamBridge -> host, DMA-engine-issued
  // request (device-initiated read/write of host memory).
  //---------------------------------------------------------------------
  logic                   rq_tvalid;
  logic                   rq_tready;
  logic [AXIS_DATA_W-1:0] rq_tdata;
  logic [AXIS_KEEP_W-1:0] rq_tkeep;
  logic                   rq_tlast;
  logic [63:0]            rq_tuser; // sideband descriptor, see rq_agent.sv

  //---------------------------------------------------------------------
  // Requester Completion (RC) -- host -> StreamBridge, completion data
  // for a device-initiated (DMA) read request.
  //---------------------------------------------------------------------
  logic                   rc_tvalid;
  logic                   rc_tready;
  logic [AXIS_DATA_W-1:0] rc_tdata;
  logic [AXIS_KEEP_W-1:0] rc_tkeep;
  logic                   rc_tlast;
  logic [63:0]            rc_tuser; // sideband descriptor, see rc_agent.sv

  //---------------------------------------------------------------------
  // Internal arbitrated fabric bus (wide read/write bus behind the
  // bridge). StreamBridge is the sole requester on this bus in this
  // environment; the arbiter agent models the shared memory/fabric side.
  //---------------------------------------------------------------------
  logic                   fab_req;
  logic                   fab_gnt;
  logic                   fab_wr_en;
  logic [FAB_ADDR_W-1:0]  fab_addr;
  logic [FAB_DATA_W-1:0]  fab_wdata;
  logic [FAB_STRB_W-1:0]  fab_wstrb;
  logic [3:0]             fab_src_id;
  logic                   fab_rvalid;
  logic [FAB_DATA_W-1:0]  fab_rdata;
  logic                   fab_rerr;

  //---------------------------------------------------------------------
  // DMA command / completion path -- a lightweight sideband used to kick
  // off device-initiated DMA transfers and report their retirement.
  //---------------------------------------------------------------------
  logic                   dma_cmd_valid;
  logic                   dma_cmd_ready;
  logic                   dma_cmd_dir;      // 0 = device->host, 1 = host->device
  logic [63:0]            dma_cmd_haddr;    // host-side (system) address
  logic [FAB_ADDR_W-1:0]  dma_cmd_laddr;    // local fabric-side address
  logic [19:0]            dma_cmd_length;   // transfer length, bytes
  logic [TAG_W-1:0]       dma_cmd_tag;
  logic                   dma_done_valid;
  logic [TAG_W-1:0]       dma_done_tag;
  logic                   dma_done_err;

  //---------------------------------------------------------------------
  // Testbench clocking block -- every agent's driver/monitor samples and
  // drives through this block to keep timing centralized and unambiguous.
  //---------------------------------------------------------------------
  clocking cb @(posedge clk);
    default input #1step output #1step;

    output cq_tvalid, cq_tdata, cq_tkeep, cq_tlast, cq_tuser;
    input  cq_tready;

    input  cc_tvalid, cc_tdata, cc_tkeep, cc_tlast, cc_tuser;
    output cc_tready;

    input  rq_tvalid, rq_tdata, rq_tkeep, rq_tlast, rq_tuser;
    output rq_tready;

    output rc_tvalid, rc_tdata, rc_tkeep, rc_tlast, rc_tuser;
    input  rc_tready;

    input  fab_req, fab_wr_en, fab_addr, fab_wdata, fab_wstrb, fab_src_id;
    output fab_gnt;
    output fab_rvalid, fab_rdata, fab_rerr;

    output dma_cmd_valid, dma_cmd_dir, dma_cmd_haddr, dma_cmd_laddr,
           dma_cmd_length, dma_cmd_tag;
    input  dma_cmd_ready;
    input  dma_done_valid, dma_done_tag, dma_done_err;
  endclocking

  modport TB (clocking cb, input clk, input rst_n);

  modport DUT (
    input  cq_tvalid, cq_tdata, cq_tkeep, cq_tlast, cq_tuser,
    output cq_tready,

    output cc_tvalid, cc_tdata, cc_tkeep, cc_tlast, cc_tuser,
    input  cc_tready,

    output rq_tvalid, rq_tdata, rq_tkeep, rq_tlast, rq_tuser,
    input  rq_tready,

    input  rc_tvalid, rc_tdata, rc_tkeep, rc_tlast, rc_tuser,
    output rc_tready,

    output fab_req, fab_wr_en, fab_addr, fab_wdata, fab_wstrb, fab_src_id,
    input  fab_gnt,
    input  fab_rvalid, fab_rdata, fab_rerr,

    input  dma_cmd_valid, dma_cmd_dir, dma_cmd_haddr, dma_cmd_laddr,
           dma_cmd_length, dma_cmd_tag,
    output dma_cmd_ready,
    output dma_done_valid, dma_done_tag, dma_done_err,

    input  clk, input rst_n
  );

endinterface
