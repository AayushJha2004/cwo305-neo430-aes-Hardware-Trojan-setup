import chipwhisperer as cw

bitstream_path = "C:\\Users\\jhaaa\\Desktop\\cw305_research\\vivado\\neo430\\neo430.runs\\impl_1\\cw305_top.bit"
scope = cw.scope()
target = cw.target(scope, cw.targets.CW305, bsfile=bitstream_path)
# This returns True if the FPGA 'DONE' pin is high
print(f"FPGA Programmed: {target.is_programmed()}")
# The reference design stores the build timestamp in a register
try:
    print(f"FPGA Build Time: {target.get_fpga_buildtime()}")
except:
    print("Could not read build time. Check if your design includes the standard registers.")