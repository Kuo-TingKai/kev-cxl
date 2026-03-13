# gem5 config: CXL/PCIe 7.0 style bus and memory (conceptual).
# Run from gem5 root: ./build/X86/gem5.opt <path>/cxl_config.py
# Requires: gem5 built for X86 (e.g. scons build/X86/gem5.opt).

import m5
from m5.objects import *

# 1. System and clock
system = System()
system.clk_domain = SrcClockDomain(clock="3GHz", voltage_domain=VoltageDomain())
system.mem_mode = "timing"

# 2. CPU
system.cpu = X86TimingSimpleCPU()

# 3. CXL-style bus (high width / latency params for PCIe 7.0 / CXL 3.0)
system.cxl_bus = SystemXBar(width=64)
system.cxl_bus.frontend_latency = 10
system.cxl_bus.forward_latency = 20

# 4. Memory: use SimpleMemory for portability; replace with MemCtrl+DDR5 if available
system.mem_ranges = [AddrRange("2GB")]
system.cxl_mem = SimpleMemory(latency="50ns", bandwidth="64GB/s")
system.cxl_mem.port = system.cxl_bus.mem_side_ports

# 5. Connect CPU to bus
system.cpu.icache_port = system.cxl_bus.cpu_side_ports
system.cpu.dcache_port = system.cxl_bus.cpu_side_ports

# Run (SE mode: no binary by default; use -c <binary> when invoking gem5)
root = Root(full_system=False, system=system)
m5.instantiate()
print("Starting simulation...")
exit_event = m5.simulate()
print(f"Exited at tick {m5.curTick()} cause: {exit_event.getCause()}")
