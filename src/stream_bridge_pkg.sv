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
  // Completer-path agents only — this repo shows one complete vertical
  // slice rather than the full six-agent environment. See the README.
  `include "cq_agent.sv"
  `include "cc_agent.sv"
  `include "arb_agent.sv"

  // ---- reference model + environment --------------------------------------
  `include "scoreboard.sv"
  `include "environment.sv"

  // ---- tests ---------------------------------------------------------------
  `include "base_test.sv"
  `include "test_cpl_write_readback.sv"

endpackage

`endif
