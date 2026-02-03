// #################################################################################################
// #  < Blinking LED example program >                                                             #
// # ********************************************************************************************* #
// #  Displays an 8-bit counter on the high-active LEDs connected to the parallel output port.     #
// # ********************************************************************************************* #
// # BSD 3-Clause License                                                                          #
// #                                                                                               #
// # Copyright (c) 2020, Stephan Nolting. All rights reserved.                                     #
// #                                                                                               #
// # Redistribution and use in source and binary forms, with or without modification, are          #
// # permitted provided that the following conditions are met:                                     #
// #                                                                                               #
// # 1. Redistributions of source code must retain the above copyright notice, this list of        #
// #    conditions and the following disclaimer.                                                   #
// #                                                                                               #
// # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
// #    conditions and the following disclaimer in the documentation and/or other materials        #
// #    provided with the distribution.                                                            #
// #                                                                                               #
// # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
// #    endorse or promote products derived from this software without specific prior written      #
// #    permission.                                                                                #
// #                                                                                               #
// # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
// # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
// # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
// # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
// # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
// # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
// # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
// # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
// # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
// # ********************************************************************************************* #
// # The NEO430 Processor - https://github.com/stnolting/neo430                                    #
// #################################################################################################


// Libraries
#include <stdint.h>
#include <neo430.h>
#include <cw305_aes_defines.h>

// Configuration
#define BAUD_RATE 19200

void aes_write_data(uint8_t reg_offset, uint8_t* data, uint8_t len) {
    for (uint8_t i = 0; i < len; i++) {
        // Address = Base + (RegisterID << 7) + ByteIndex
        uint32_t addr = AES_WB_BASE | (reg_offset << 7) | (15-i);
        neo430_wishbone8_write(addr, data[i]);
    }
}

void aes_read_data(uint8_t reg_offset, uint8_t* buffer, uint8_t len) {
    for (uint8_t i = 0; i < len; i++) {
        uint32_t addr = AES_WB_BASE | (reg_offset << 7) | (15-i);
        buffer[i] = neo430_wishbone8_read(addr);
    }
}

void aes_trigger(void) {
    uint32_t addr = AES_WB_BASE | (REG_CRYPT_GO << 7);
    neo430_wishbone8_write(addr, 0x01);
}

void aes_mode(uint8_t mode) {
    uint32_t addr = AES_WB_BASE | (REG_CRYPT_MODE << 7);
    neo430_wishbone8_write(addr, mode);
}

void ro_enable(void) {
    uint32_t addr = AES_WB_BASE | (REG_RO_ENABLE << 7);
    neo430_wishbone8_write(addr, 0x01);
}

void ro_disable(void) {
    uint32_t addr = AES_WB_BASE | (REG_RO_ENABLE << 7);
    neo430_wishbone8_write(addr, 0x00);
}

void print_data(char *s, uint8_t* byte_array, uint8_t len) {
  neo430_uart_br_print(s);
  for (int i=0; i<len; i++) {
    neo430_uart_print_hex_byte(byte_array[i]);  
  }
  neo430_printf("\n");
}

/* ------------------------------------------------------------
 * INFO Main function
 * ------------------------------------------------------------ */
int main(void) {

  // setup UART
  neo430_uart_setup(BAUD_RATE);

  // intro text
  neo430_uart_br_print("\nAES x Wishbone test\n");

  // A sample 128-bit key (16 bytes)
  uint8_t key[16] = {
      0x2B, 0x7E, 0x15, 0x16, 0x28, 0xAE, 0xD2, 0xA6, 
      0xAB, 0xF7, 0x15, 0x88, 0x09, 0xCF, 0x4F, 0x3C
  };

  // A sample 128-bit plaintext (16 bytes)
  uint8_t pt[16]  = {
      0x6B, 0xC1, 0xBE, 0xE2, 0x2E, 0x40, 0x9F, 0x96, 
      0xE9, 0x3D, 0x7E, 0x11, 0x73, 0x93, 0x17, 0x2A
  };

  uint8_t ct[16];
  uint8_t to[16];

  // Set AES in encryption mode
  aes_mode(0);

  // Write Key
  aes_write_data(REG_CRYPT_KEY, key, 16);
  print_data("Key: ", key, 16);

  // Write Plaintext
  aes_write_data(REG_CRYPT_TEXTIN, pt, 16);
  print_data("Plaintext: ", pt, 16);

  // Trigger
  aes_trigger();

  // Wait for hardware to finish (poll busy flag)
  while(neo430_wishbone8_read(AES_WB_BASE | (REG_CRYPT_GO << 7)) != 0);

  // Read Cipherout
  aes_read_data(REG_CRYPT_CIPHEROUT, ct, 16);
  print_data("Cipher: ", ct, 16);

  // Set AES in decryption mode
  aes_mode(1);

  // Write Same Key
  aes_write_data(REG_CRYPT_KEY, key, 16);

  // Write Cipher output
  aes_write_data(REG_CRYPT_CIPHERIN, ct, 16);
  
  // Trigger
  aes_trigger();

  // Wait for hardware to finish (poll busy flag)
  while(neo430_wishbone8_read(AES_WB_BASE | (REG_CRYPT_GO << 7)) != 0);
  
  // Read Textout
  aes_read_data(REG_CRYPT_TEXTOUT, to, 16);
  print_data("Decrypt: ", to, 16);

  return 0;
}
