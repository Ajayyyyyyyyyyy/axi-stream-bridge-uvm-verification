//=============================================================================
// File   : tb_top.sv
// Purpose: Testbench top: clock/reset generation, DUT instantiation,
//          waveform dump stub, and the UVM entry point.
//=============================================================================

`timescale 1ns/1ps

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import stream_bridge_pkg::*;

  localparam int CLK_PERIOD_NS = 2; // 500 MHz core clock

  logic clk;
  logic rst_n;

  //---------------------------------------------------------------------
  // Clock / reset generation
  //---------------------------------------------------------------------
  initial clk = 1'b0;
  always #(CLK_PERIOD_NS/2) clk = ~clk;

  initial begin
    rst_n = 1'b0;
    repeat (10) @(posedge clk);
    rst_n = 1'b1;
  end

  //---------------------------------------------------------------------
  // DUT interface
  //---------------------------------------------------------------------
  stream_bridge_if sb_if (
    .clk   (clk),
    .rst_n (rst_n)
  );

  //---------------------------------------------------------------------
  // DUT instance -- proprietary RTL not included, see StreamBridge_stub.sv
  //---------------------------------------------------------------------
  StreamBridge dut (
    .clk            (clk),
    .rst_n          (rst_n),

    .cq_tvalid      (sb_if.cq_tvalid),
    .cq_tready      (sb_if.cq_tready),
    .cq_tdata       (sb_if.cq_tdata),
    .cq_tkeep       (sb_if.cq_tkeep),
    .cq_tlast       (sb_if.cq_tlast),
    .cq_tuser       (sb_if.cq_tuser),

    .cc_tvalid      (sb_if.cc_tvalid),
    .cc_tready      (sb_if.cc_tready),
    .cc_tdata       (sb_if.cc_tdata),
    .cc_tkeep       (sb_if.cc_tkeep),
    .cc_tlast       (sb_if.cc_tlast),
    .cc_tuser       (sb_if.cc_tuser),

    .rq_tvalid      (sb_if.rq_tvalid),
    .rq_tready      (sb_if.rq_tready),
    .rq_tdata       (sb_if.rq_tdata),
    .rq_tkeep       (sb_if.rq_tkeep),
    .rq_tlast       (sb_if.rq_tlast),
    .rq_tuser       (sb_if.rq_tuser),

    .rc_tvalid      (sb_if.rc_tvalid),
    .rc_tready      (sb_if.rc_tready),
    .rc_tdata       (sb_if.rc_tdata),
    .rc_tkeep       (sb_if.rc_tkeep),
    .rc_tlast       (sb_if.rc_tlast),
    .rc_tuser       (sb_if.rc_tuser),

    .fab_req        (sb_if.fab_req),
    .fab_gnt        (sb_if.fab_gnt),
    .fab_wr_en      (sb_if.fab_wr_en),
    .fab_addr       (sb_if.fab_addr),
    .fab_wdata      (sb_if.fab_wdata),
    .fab_wstrb      (sb_if.fab_wstrb),
    .fab_src_id     (sb_if.fab_src_id),
    .fab_rvalid     (sb_if.fab_rvalid),
    .fab_rdata      (sb_if.fab_rdata),
    .fab_rerr       (sb_if.fab_rerr),

    .dma_cmd_valid  (sb_if.dma_cmd_valid),
    .dma_cmd_ready  (sb_if.dma_cmd_ready),
    .dma_cmd_dir    (sb_if.dma_cmd_dir),
    .dma_cmd_haddr  (sb_if.dma_cmd_haddr),
    .dma_cmd_laddr  (sb_if.dma_cmd_laddr),
    .dma_cmd_length (sb_if.dma_cmd_length),
    .dma_cmd_tag    (sb_if.dma_cmd_tag),
    .dma_done_valid (sb_if.dma_done_valid),
    .dma_done_tag   (sb_if.dma_done_tag),
    .dma_done_err   (sb_if.dma_done_err)
  );

  //---------------------------------------------------------------------
  // Waveform dump stub -- enabled via +WAVES on the simulator command line
  //---------------------------------------------------------------------
  initial begin
    if ($test$plusargs("WAVES")) begin
      $shm_open("waves.shm");
      $shm_probe(tb_top, "AS");
      // For simulators without SHM support, swap the two lines above for:
      //   $dumpfile("waves.vcd");
      //   $dumpvars(0, tb_top);
    end
  end

  //---------------------------------------------------------------------
  // UVM entry point
  //---------------------------------------------------------------------
  initial begin
    uvm_config_db#(virtual stream_bridge_if)::set(null, "*", "vif", sb_if);
    run_test();
  end

endmodule
