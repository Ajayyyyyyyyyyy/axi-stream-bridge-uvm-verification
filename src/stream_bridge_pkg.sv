//=============================================================================
// File   : stream_bridge_pkg.sv
// Purpose: Top-level package for the StreamBridge UVM verification
//          environment. Pulls in every class file in dependency order.
//          The stream_bridge_if interface is compiled separately (see
//          sim/Makefile) since it is a module-like construct, not a class.
//=============================================================================

`ifndef STREAM_BRIDGE_PKG_SV
`define STREAM_BRIDGE_PKG_SV

package stream_bridge_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---- transaction + stimulus -------------------------------------------
  `include "seq_item.sv"
  `include "sequences.sv"

  // ---- agents (sequencer + driver + monitor + container per file) -------
  `include "cq_agent.sv"
  `include "cc_agent.sv"
  `include "rq_agent.sv"
  `include "rc_agent.sv"
  `include "dma_agent.sv"
  `include "arb_agent.sv"

  // ---- reference model + environments ------------------------------------
  `include "scoreboard.sv"
  `include "environment.sv"
  `include "environment_dma.sv"

  // ---- tests ---------------------------------------------------------------
  `include "base_test.sv"
  `include "test_cpl_write_readback.sv"
  `include "test_cpl_continuous_burst.sv"
  `include "test_dma_single_read.sv"
  `include "test_dma_single_write.sv"
  `include "test_dma_size_sweep.sv"

endpackage

`endif
