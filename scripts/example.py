import chipwhisperer as cw

bitstream_path = "C:\\Users\\jhaaa\\Desktop\\test\\soc\\soc.runs\\impl_1\\cw305_top.bit"
scope = cw.scope()
target = cw.target(scope, cw.targets.CW305, bsfile=bitstream_path)
# This returns True if the FPGA 'DONE' pin is high
print(f"FPGA Programmed: {target.is_programmed()}")
# The reference design stores the build timestamp in a register
try:
    print(f"FPGA Build Time: {target.get_fpga_buildtime()}")
except:
    print("Could not read build time. Check if your design includes the standard registers.")
target.vccint_set(1.0) #set VCC-INT to 1V
target.pll.pll_outfreq_set(50e6, 1)
target.pll.pll_outfreq_get(0)
# Configure the Scope for capture
scope.gain.db = 40        # Adjust based on signal strength
scope.adc.samples = 5000  # Number of points to capture
scope.adc.offset = 0
scope.adc.basic_mode = "rising_edge"
scope.io.trigger_source = "tio4"
scope.clock.adc_src = "extclk_x4"
target.fpga_write(0x0d, [0x01]) # Mode 0: Encrypt

# 1. Input data as standard NIST order (No manual reversal)
key_hex = "000102030405060700010203040506ff"
pt_hex  = "11112233445566778899aabbccddeed8"

# Convert to list without [::-1]
key = list(bytes.fromhex(key_hex))[::-1]
plaintext = list(bytes.fromhex(pt_hex))[::-1]

print(f"Original PT: {bytes(plaintext).hex(' ')}")
# 2. Encryption
target.fpga_write(0x0d, [0x00]) # Mode 0: Encrypt
target.fpga_write(0x0a, key)    # Key
target.fpga_write(0x06, plaintext) # TextIn 
target.fpga_write(0x05, [0x01]) # Trigger

ciphertext = target.fpga_read(0x09, 16) # CipherOut
print(f"Ciphertext:  {ciphertext.hex(' ')}")

# 3. Decryption Loopback
target.fpga_write(0x0d, [0x01]) # Mode 1: Decrypt

target.fpga_write(0x07, list(ciphertext)) 
target.fpga_write(0x05, [0x01]) # Trigger

# Based on your Verilog: crypt_textin = aes_mode ? aes_out : 128'b0
# The result should be in REG_CRYPT_TEXTOUT
decrypted_pt = target.fpga_read(0x08, 16)
print(f"Decrypted:   {decrypted_pt.hex(' ')}")