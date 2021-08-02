# High speed behavioural Verilog memory model

The mem_model component is a Verilog simulation test component that allows for a very large memory address space without reserving large amounts of memory, defining large Verilog arrays, or building a truncated memory map into a test bench which could be subject to change in the design. The model uses the Verilog PLI to access a C model, pushing the majority of the functionality away from the simulator, making the test bench lightweight, and the memory accesses very fast in simulation compute time.

A direct access API is also provided to allow any other PLI C/C++ code to transfer data directly, without the overhead of simulating bus transactions.

More details can be found in the manual---doc/mem_model_manual.pdf.
