import chipwhisperer as cw
import time

scope = cw.scope()
bitstream_path = "C:\\Users\\jhaaa\\Desktop\\cw305_research\\soc_pwa\\soc_pwa.runs\\impl_1\\cw305_top.bit"
target = cw.target(scope, cw.targets.CW305, bsfile=bitstream_path)
# This returns True if the FPGA 'DONE' pin is high
print(f"FPGA Programmed: {target.is_programmed()}")
# The reference design stores the build timestamp in a register
try:
    print(f"FPGA Build Time: {target.get_fpga_buildtime()}")
except:
    print("Could not read build time. Check if your design includes the standard registers.")
    
target.vccint_set(1.0) #set VCC-INT to 1V
target.pll.pll_outfreq_set(10e6, 1)

# Configure the Scope for capture
scope.gain.db = 40        # Adjust based on signal strength
scope.adc.samples = 5000  # Number of points to capture
scope.adc.offset = 0
scope.adc.basic_mode = "rising_edge"
scope.io.trigger_source = "tio4"
scope.clock.adc_src = "extclk_x4"

# Define a simple capture function
def capture_trace(ro_on=False):
    if ro_on:
        target.fpga_write(0x0c, [0x01]) # Enable ROs
    else:
        target.fpga_write(0x0c, [0x00]) # Disable ROs
        
    scope.arm()
    
    # Trigger the AES encryption (example command)
    # This depends on the specific AES implementation/firmware
    target.simpleserial_write('p', bytearray([0]*16)) 
    
    ret = scope.capture()
    if ret:
        print("Target timed out!")
        return None
        
    trace = scope.get_last_trace()
    
    # Always turn off ROs after capture to prevent overheating
    target.fpga_write(0x0c, [0x00])
    time.sleep(3)
    return trace

# Map the TIO pins to the UART functions
scope.io.tio1 = "serial_rx" # From Target's TX (R16)
scope.io.tio3 = "serial_tx" # From Target's RX (M16)

response = target.simpleserial_read('r', 16)
print(response)

import matplotlib.pyplot as plt

trace_clean = capture_trace(ro_on=False)
trace_noisy = capture_trace(ro_on=True)

plt.figure(figsize=(12, 6))
plt.plot(trace_clean, label="Clean (RO Off)")
plt.plot(trace_noisy, label="Noisy (RO On)", alpha=0.7)
plt.title("Impact of Ring Oscillators on Power Trace")
plt.legend()
plt.show()