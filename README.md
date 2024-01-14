# High speed C/C++ based behavioural Verilog memory model 

<p align="center">
<img src="https://github.com/wyvernSemi/mem_model/assets/21970031/fd04c5c5-dd53-4381-851e-ccb9a362fcef" width=700>
</p>

The mem_model component is a Verilog simulation test component that allows for a very large memory address space without reserving large amounts of memory, defining large Verilog arrays, or building a truncated memory map into a test bench which could be subject to change in the design. The model uses the Verilog PLI to access a C model, pushing the majority of the functionality away from the simulator, making the test bench lightweight, and the memory accesses very fast in simulation compute time.

A direct access API is also provided to allow any other PLI C/C++ code to transfer data directly, without the overhead of simulating bus transactions.

More details can be found in the manual&mdash;<tt>doc/mem_model_manual.pdf</tt>.
