# gem5 Ruby memory system template: multi-core + MESI_Two_Level for CXL/LLM.
# Build gem5 with: scons build/X86/gem5.opt PROTOCOL=MESI_Two_Level
# Run: ./build/X86/gem5.opt <path>/ruby_cxl_config.py
#
# This is a structural template; actual Ruby setup in gem5 is usually done
# via configs/common/ scripts or Ruby.create_system(). Adjust for your gem5 version.

import m5
from m5.objects import *

# 1. System and clock
system = System()
system.clk_domain = SrcClockDomain(clock="3.2GHz", voltage_domain=VoltageDomain())

# 2. Multi-core CPU (4 cores)
system.cpu = [X86TimingSimpleCPU(cpu_id=i) for i in range(4)]

# 3. Ruby memory system (requires gem5 built with MESI_Two_Level)
system.ruby = RubySystem()

# 4. Cache sizes (LLM-friendly: larger L3, high associativity)
l1_isize = "32kB"
l1_dsize = "32kB"
l2_size = "256kB"
l3_size = "16MB"

# 5. Network topology (for CXL Fabric style)
# Actual Ruby network is typically created by Ruby.setup_system() or protocol scripts.
# Example only:
# system.ruby.network = SimpleNetwork(
#     ruby_system=system.ruby,
#     topology='Crossbar',
#     buffer_size=64
# )
#
# Then define L1/L2/Directory controllers and connect to CPUs and memory.
# See configs/common/ and configs/topologies/ in gem5 source.

# Placeholder: minimal runnable setup often uses a simple memory bus instead of Ruby
# if Ruby is not fully configured in this file.
system.mem_ranges = [AddrRange("2GB")]
root = Root(full_system=False, system=system)
m5.instantiate()
print("Ruby CXL template: run with full Ruby setup (see gem5 configs).")
exit_event = m5.simulate()
print(f"Exited at tick {m5.curTick()} cause: {exit_event.getCause()}")
