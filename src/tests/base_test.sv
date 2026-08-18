//=============================================================================
// File   : base_test.sv
// Purpose: Common base for every StreamBridge completer-path test. Builds
//          the completer environment and prints the topology once
//          elaboration is done. This repo shows the completer path only —
//          see the README for the (omitted) requester/DMA-path tests.
//=============================================================================

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  stream_bridge_env cpl_env;

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cpl_env = stream_bridge_env::type_id::create("cpl_env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

endclass
