//=============================================================================
// File   : base_test.sv
// Purpose: Common base for every StreamBridge test. Selects and builds
//          either the completer-path environment or the requester/DMA-path
//          environment, and prints the topology once elaboration is done.
//          Concrete tests set use_dma_env before calling super.build_phase()
//          and implement run_phase() to start their own sequences.
//=============================================================================

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  stream_bridge_env     cpl_env;
  stream_bridge_dma_env dma_env;

  bit use_dma_env = 1'b0;

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (use_dma_env)
      dma_env = stream_bridge_dma_env::type_id::create("dma_env", this);
    else
      cpl_env = stream_bridge_env::type_id::create("cpl_env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

endclass
