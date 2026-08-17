//=============================================================================
// File   : StreamBridge_stub.sv
//
// NOTE: This module is an intentionally empty placeholder. The real
// StreamBridge RTL is proprietary and is NOT included in this portfolio
// repository. This stub exists purely so the testbench elaborates as a
// complete, structurally-connected environment against a black-box DUT
// with the right port list -- it ties every output off to a safe default
// and implements no bridge functionality whatsoever.
//
// Port list matches stream_bridge_if.sv's DUT modport exactly.
//=============================================================================

module StreamBridge #(
  parameter int AXIS_DATA_W = 512,
  parameter int AXIS_KEEP_W = AXIS_DATA_W / 32,
  parameter int FAB_DATA_W  = 256,
  parameter int FAB_ADDR_W  = 39,
  parameter int FAB_STRB_W  = FAB_DATA_W / 8,
  parameter int TAG_W       = 8
)(
  input  logic clk,
  input  logic rst_n,

  // Completer Request (CQ) -- host -> bridge
  input  logic                   cq_tvalid,
  output logic                   cq_tready,
  input  logic [AXIS_DATA_W-1:0] cq_tdata,
  input  logic [AXIS_KEEP_W-1:0] cq_tkeep,
  input  logic                   cq_tlast,
  input  logic [63:0]            cq_tuser,

  // Completer Completion (CC) -- bridge -> host
  output logic                   cc_tvalid,
  input  logic                   cc_tready,
  output logic [AXIS_DATA_W-1:0] cc_tdata,
  output logic [AXIS_KEEP_W-1:0] cc_tkeep,
  output logic                   cc_tlast,
  output logic [63:0]            cc_tuser,

  // Requester Request (RQ) -- bridge -> host
  output logic                   rq_tvalid,
  input  logic                   rq_tready,
  output logic [AXIS_DATA_W-1:0] rq_tdata,
  output logic [AXIS_KEEP_W-1:0] rq_tkeep,
  output logic                   rq_tlast,
  output logic [63:0]            rq_tuser,

  // Requester Completion (RC) -- host -> bridge
  input  logic                   rc_tvalid,
  output logic                   rc_tready,
  input  logic [AXIS_DATA_W-1:0] rc_tdata,
  input  logic [AXIS_KEEP_W-1:0] rc_tkeep,
  input  logic                   rc_tlast,
  input  logic [63:0]            rc_tuser,

  // Internal arbitrated fabric bus
  output logic                   fab_req,
  input  logic                   fab_gnt,
  output logic                   fab_wr_en,
  output logic [FAB_ADDR_W-1:0]  fab_addr,
  output logic [FAB_DATA_W-1:0]  fab_wdata,
  output logic [FAB_STRB_W-1:0]  fab_wstrb,
  output logic [3:0]             fab_src_id,
  input  logic                   fab_rvalid,
  input  logic [FAB_DATA_W-1:0]  fab_rdata,
  input  logic                   fab_rerr,

  // DMA command / completion path
  input  logic                   dma_cmd_valid,
  output logic                   dma_cmd_ready,
  input  logic                   dma_cmd_dir,
  input  logic [63:0]            dma_cmd_haddr,
  input  logic [FAB_ADDR_W-1:0]  dma_cmd_laddr,
  input  logic [19:0]            dma_cmd_length,
  input  logic [TAG_W-1:0]       dma_cmd_tag,
  output logic                   dma_done_valid,
  output logic [TAG_W-1:0]       dma_done_tag,
  output logic                   dma_done_err
);

  // Safe, inert tie-offs so the environment elaborates cleanly against
  // this placeholder. No functional behaviour is modeled here -- the real
  // bridge, register map, arbiter client, and DMA engine are proprietary
  // and belong to the author's employer, not to this repository.
  assign cq_tready      = 1'b0;

  assign cc_tvalid      = 1'b0;
  assign cc_tdata       = '0;
  assign cc_tkeep       = '0;
  assign cc_tlast       = 1'b0;
  assign cc_tuser       = '0;

  assign rq_tvalid      = 1'b0;
  assign rq_tdata       = '0;
  assign rq_tkeep       = '0;
  assign rq_tlast       = 1'b0;
  assign rq_tuser       = '0;

  assign rc_tready      = 1'b0;

  assign fab_req         = 1'b0;
  assign fab_wr_en       = 1'b0;
  assign fab_addr        = '0;
  assign fab_wdata       = '0;
  assign fab_wstrb       = '0;
  assign fab_src_id      = '0;

  assign dma_cmd_ready   = 1'b0;
  assign dma_done_valid  = 1'b0;
  assign dma_done_tag    = '0;
  assign dma_done_err    = 1'b0;

endmodule
