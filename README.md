# High speed C/C++ based behavioural Verilog an VHDL co-simulation memory model 

<p align="center">
<img src="https://github.com/wyvernSemi/mem_model/assets/21970031/fd04c5c5-dd53-4381-851e-ccb9a362fcef" width=700>
</p>

The mem_model component is a Verilog/VHDL simulation test component that allows for a very large memory address space without reserving large amounts of memory, defining large HDL arrays, or building a truncated memory map into a test bench which could be subject to change in the design. The model uses the simulators' programming interfaces to access a C model, pushing the majority of the functionality away from the simulator, making the test bench lightweight, and the memory accesses very fast in simulation compute time.

A direct access API is also provided to allow any other PLI C/C++ code to transfer data directly, without the overhead of simulating bus transactions (see <tt>src/mem.h</tt>). Wrapper HDL is also provided to map the ports to an AXI subordinate interface (<tt>mem_model_axi.v</tt> and <tt>mem_model_axi.vhd</tt>). The default memory mapped slave port and burst ports are Altera Avalon bus compatible.

By default memory is uninitialised but, if compiled with <tt>MEM_ZERO_NEW PAGES</tt> defined, memory will be initialised with zeros. By default, the model is big endian, but this can be overridden by defining <tt>MEM_MODEL_DEFAULT_ENDIAN=1</tt>.

More details can be found in the manual&mdash;<tt>doc/mem_model_manual.pdf</tt>.
