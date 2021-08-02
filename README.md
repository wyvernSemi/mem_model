# High speed behavioural Verilog memory model

The mem_model component is a Verilog simulation test component that allows for a very large memory address space without reserving large amounts of memory, defining large Verilog arrays, or building a truncated memory map into a test bench which could be subject to change in the design. The model uses the Verilog PLI to access a C model, pushing the majority of the functionality away from the simulator, making the test bench lightweight, and the memory accesses very fast in simulation compute time.

The component is a lightweight behavioural Verilog module, and uses the PLI interface to communicate with a set of C/C++ software to implement the actual memory model. 
