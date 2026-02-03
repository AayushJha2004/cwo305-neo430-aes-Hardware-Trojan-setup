/* 
ChipWhisperer Artix Target - Example of connections between example registers
and rest of system.

Copyright (c) 2016-2020, NewAE Technology Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted without restriction. Note that modules within
the project may have additional restrictions, please carefully inspect
additional licenses.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of NewAE Technology Inc.
*/

`timescale 1ns / 1ps
`default_nettype none 

module cw305_top #(
    parameter pBYTECNT_SIZE = 7,
    parameter pADDR_WIDTH = 21,
    parameter pPT_WIDTH = 128,
    parameter pCT_WIDTH = 128,
    parameter pKEY_WIDTH = 128,
    // MODIFICATION: parameter to change the number of RO instances
    parameter NO_RO = 500, // number of ros per bank
    parameter NO_BANK = 1 // number of ro banks
)(
    // USB Interface
    input wire                          usb_clk,        // Clock
`ifdef SS2_WRAPPER
    output wire                         usb_clk_buf,    // if needed by parent module
    input  wire [7:0]                   usb_data,
    output wire [7:0]                   usb_dout,
`else
    inout wire [7:0]                    usb_data,       // Data for write/read
`endif
    input wire [pADDR_WIDTH-1:0]        usb_addr,       // Address
    input wire                          usb_rdn,        // !RD, low when addr valid for read
    input wire                          usb_wrn,        // !WR, low when data+addr valid for write
    input wire                          usb_cen,        // !CE, active low chip enable
    input wire                          usb_trigger,    // High when trigger requested

    // Buttons/LEDs on Board
    input wire                          j16_sel,        // DIP switch J16
    input wire                          k16_sel,        // DIP switch K16
    input wire                          k15_sel,        // DIP switch K15
    input wire                          l14_sel,        // DIP Switch L14
    input wire                          pushbutton,     // Pushbutton SW4, connected to R1, used here as reset
    output wire                         led1,           // red LED
    output wire                         led2,           // green LED
    output wire                         led3,           // blue LED

    // PLL
    input wire                          pll_clk1,       //PLL Clock Channel #1
    //input wire                        pll_clk2,       //PLL Clock Channel #2 (unused in this example)

    // 20-Pin Connector Stuff
    output wire                         tio_trigger,
    output wire                         tio_clkout,
    input  wire                         tio_clkin

    // Block Interface to Crypto Core
`ifdef USE_BLOCK_INTERFACE
   ,output wire                         crypto_clk,
    output wire                         crypto_rst,
    output wire [pPT_WIDTH-1:0]         crypto_textout,
    output wire [pKEY_WIDTH-1:0]        crypto_keyout,
    input  wire [pCT_WIDTH-1:0]         crypto_cipherin,
    output wire                         crypto_start,
    input wire                          crypto_ready,
    input wire                          crypto_done,
    input wire                          crypto_busy,
    input wire                          crypto_idle
`endif

    // MODIFICATION: ports of neo430 microcontroller
    , input  wire uart_rxd_i,
    output wire uart_txd_o

    // MODIFICATION: ring oscillator enable signal and bank output
    , output wire ro_enable_out,
    output wire bank0_out

    // MODIFICATION:: bootloader led status
    , output wire bootloader
    );

`ifndef SS2_WRAPPER
    wire usb_clk_buf;
    wire [7:0] usb_dout;
    assign usb_data = isout? usb_dout : 8'bZ;
`endif

    wire [pKEY_WIDTH-1:0] crypt_key;
    wire [pPT_WIDTH-1:0] crypt_textout;
    wire [pPT_WIDTH-1:0] crypt_textin;
    wire [pCT_WIDTH-1:0] crypt_cipherout;
    wire [pCT_WIDTH-1:0] crypt_cipherin;
    wire crypt_init;
    wire crypt_ready;
    wire crypt_start;
    wire crypt_done;
    wire crypt_busy;

    wire isout;
    wire [pADDR_WIDTH-pBYTECNT_SIZE-1:0] reg_address;
    wire [pBYTECNT_SIZE-1:0] reg_bytecnt;
    wire reg_addrvalid;
    wire [7:0] write_data;
    wire [7:0] read_data;
    wire reg_read;
    wire reg_write;
    wire [4:0] clk_settings;
    wire crypt_clk;    

    // MODIFICATION: write ro_enable to take register value of new enable register
    wire ro_enable;
    wire [NO_BANK-1:0] bank_out;

    // MODIFICATION: aes_mode wire (0: encryption, 1: decryption)
    wire aes_mode;

    wire resetn = pushbutton;
    wire reset = !resetn;

    // MODIFICATION: neo430 microcontroller io signals for gpio
    wire [7:0] gpio_o;
    // MODIFICATION: led3 for aed_reg read write status is removed from output ports as we need to see the neo430 bootloader status (higher priority)
    wire O_user_led; // replacement wire for previously aes_reg read write status led routed to output
    assign bootloader = gpio_o[0];
    assign led3 = O_user_led;

    // USB CLK Heartbeat
    reg [24:0] usb_timer_heartbeat;
    always @(posedge usb_clk_buf) usb_timer_heartbeat <= usb_timer_heartbeat +  25'd1;
    assign led1 = usb_timer_heartbeat[24];

    // CRYPT CLK Heartbeat
    reg [22:0] crypt_clk_heartbeat;
    always @(posedge crypt_clk) crypt_clk_heartbeat <= crypt_clk_heartbeat +  23'd1;
    assign led2 = crypt_clk_heartbeat[22];


    cw305_usb_reg_fe #(
       .pBYTECNT_SIZE           (pBYTECNT_SIZE),
       .pADDR_WIDTH             (pADDR_WIDTH)
    ) U_usb_reg_fe (
       .rst                     (reset),
       .usb_clk                 (usb_clk_buf), 
       .usb_din                 (usb_data), 
       .usb_dout                (usb_dout), 
       .usb_rdn                 (usb_rdn), 
       .usb_wrn                 (usb_wrn),
       .usb_cen                 (usb_cen),
       .usb_alen                (1'b0),                 // unused
       .usb_addr                (usb_addr),
       .usb_isout               (isout), 
       .reg_address             (reg_address), 
       .reg_bytecnt             (reg_bytecnt), 
       .reg_datao               (write_data), 
       .reg_datai               (read_data),
       .reg_read                (reg_read), 
       .reg_write               (reg_write), 
       .reg_addrvalid           (reg_addrvalid)
    );


cw305_reg_aes #(
       .pBYTECNT_SIZE           (pBYTECNT_SIZE),
       .pADDR_WIDTH             (pADDR_WIDTH),
       .pPT_WIDTH               (pPT_WIDTH),
       .pCT_WIDTH               (pCT_WIDTH),
       .pKEY_WIDTH              (pKEY_WIDTH)
    ) U_reg_aes (
       .reset_i                 (reset), 
       .crypto_clk              (crypt_clk),
       .usb_clk                 (usb_clk_buf), 

       // MODIFIED: Connecting the Multiplexed Bus signals
       .reg_address             (mux_address), 
       .reg_bytecnt             (mux_bytecnt), 
       .reg_read                (mux_reg_read), 
       .reg_write               (mux_reg_write), 
       .write_data              (mux_write_data),

       .read_data               (read_data),
       .reg_addrvalid           (reg_addrvalid), 

       .exttrigger_in           (usb_trigger),

       .I_textout               (crypt_textin),
       .I_cipherout             (crypt_cipherin),
       .I_ready                 (crypt_ready), 
       .I_done                  (crypt_done), 
       .I_busy                  (crypt_busy), 

       .O_clksettings           (clk_settings),
       .O_user_led              (O_user_led), 
       .O_key                   (crypt_key), 
       .O_textin                (crypt_textout),
       .O_cipherin              (crypt_cipherout), 
       .O_start                 (crypt_start), 
       
       // MODIFICATION: new O_ro_enable output
       .O_ro_enable             (ro_enable),
       // MODIFICATION: aes mode 
       .O_crypt_mode            (aes_mode)
    );


`ifdef ICE40
    assign usb_clk_buf = usb_clk;
    assign crypt_clk = usb_clk;
    assign tio_clkout = usb_clk;
`else
    clocks U_clocks (
       .usb_clk                 (usb_clk),
       .usb_clk_buf             (usb_clk_buf),
       .I_j16_sel               (j16_sel),
       .I_k16_sel               (k16_sel),
       .I_clock_reg             (clk_settings),
       .I_cw_clkin              (tio_clkin),
       .I_pll_clk1              (pll_clk1),
       .O_cw_clkout             (tio_clkout),
       .O_cryptoclk             (crypt_clk)
    );
`endif



  // Block interface is used by the IP Catalog. If you are using block-based
  // design define USE_BLOCK_INTERFACE.
`ifdef USE_BLOCK_INTERFACE
    assign crypto_clk = crypt_clk;
    assign crypto_rst = crypt_init;
    assign crypto_keyout = crypt_key;
    assign crypto_textout = crypt_textout;
    assign crypt_cipherin = crypto_cipherin;
    assign crypto_start = crypt_start;
    assign crypt_ready = crypto_ready;
    assign crypt_done = crypto_done;
    assign crypt_busy = crypto_busy;
    assign tio_trigger = ~crypto_idle;
`endif

  // START CRYPTO MODULE CONNECTIONS
  // The following can have your crypto module inserted.
  // This is an example of the Google Vault AES module.
  // You can use the ILA to view waveforms if needed, which
  // requires an external USB-JTAG adapter (such as Xilinx Platform
  // Cable USB).

// MODIFICATION: define google vault aes for instantiation
`define GOOGLE_VAULT_AES
`ifdef GOOGLE_VAULT_AES
   wire aes_clk;
   wire [127:0] aes_key;
   wire [127:0] aes_in;
   wire [127:0] aes_out;
   wire aes_load;
   wire aes_busy;

   assign aes_clk = crypt_clk;
   assign aes_load = crypt_start;
   assign aes_key = crypt_key;
   assign aes_in = aes_mode? crypt_cipherout : crypt_textout;
   assign crypt_ready = 1'b1;
   assign crypt_cipherin = aes_mode ? 128'b0 : aes_out;
   assign crypt_textin = aes_mode ? aes_out : 128'b0;
   assign crypt_done = ~aes_busy;
   assign crypt_busy = aes_busy;

   // Example AES Core
   aes_core aes_core (
       .clk             (aes_clk),
       .load_i          (aes_load),
       .key_i           ({aes_key, 128'h0}),
       .data_i          (aes_in),
       .size_i          (2'd0), //AES128
       .dec_i           (aes_mode),//0: encryption, 1: decryption
       .data_o          (aes_out),
       .busy_o          (aes_busy)
   );
   assign tio_trigger = aes_busy;
`endif

// MODIFICATION: new instances of 4 ro_banks with NO_RO/4 ros each
(* DONT_TOUCH = "yes" *)
genvar i;
generate 
    for (i=0; i<NO_BANK; i = i + 1) begin: generate_RO_Bank
        ro_bank #(.RO_COUNT(NO_RO)) ro_bank_inst (
            .ro_enable(ro_enable),
            .bank_out(bank_out[i])
        );
    end
endgenerate

assign ro_enable_out = ro_enable;
assign bank0_out = bank_out[0];

// --- 1. Wishbone Wire Declarations ---
wire [31:0] wb_adr_o;
wire [31:0] wb_dat_o; // Data from NEO430
wire [31:0] wb_dat_i; // Data to NEO430
wire [3:0]  wb_sel_o; // Byte selects
wire        wb_we_o;
wire        wb_stb_o;
wire        wb_cyc_o;
wire        wb_ack_i;

// --- 2. Address Decoding & Multiplexer Logic ---
// We map AES registers to the NEO430 address space (e.g., 0xFF90 range)
// Match whatever address your NEO430 C-code writes into the WB32 registers
wire neo_access_aes = (wb_adr_o[31:20] == 12'hFF0);

// Intermediate "Muxed" signals for the AES Register Module
wire [pADDR_WIDTH-pBYTECNT_SIZE-1:0] mux_address;
wire [pBYTECNT_SIZE-1:0]             mux_bytecnt;
wire                                 mux_reg_read;
wire                                 mux_reg_write;
wire [7:0]                           mux_write_data;

// Selection Logic: If NEO430 is active in the AES range, it takes control.
// Otherwise, the USB interface (reg_fe) has control.
// Match the slicing used by the USB frontend (U_usb_reg_fe)
assign mux_address    = neo_access_aes ? wb_adr_o[20:pBYTECNT_SIZE] : reg_address;
assign mux_bytecnt    = neo_access_aes ? wb_adr_o[pBYTECNT_SIZE-1:0] : reg_bytecnt;
assign mux_reg_write  = neo_access_aes ? (wb_stb_o && wb_we_o && wb_sel_o[0]) : reg_write;
assign mux_reg_read   = neo_access_aes ? (wb_stb_o && !wb_we_o) : reg_read;
assign mux_write_data = neo_access_aes ? wb_dat_o[7:0] : write_data;

// Return data to NEO430
assign wb_dat_i = {24'b0, read_data}; // AES read_data is 8-bit, mapped to low byte [cite: 154]
assign wb_ack_i = wb_stb_o;           // Immediate ACK for register-style access

// MODIFICATION: neo430 microcontroller instantiation
neo430_top_wrapper neo430_top_wrapper_inst (
    .clk_i      (crypt_clk),
    .rst_i      (resetn),
    .gpio_o     (gpio_o),
    .uart_txd_o (uart_txd_o),
    .uart_rxd_i (uart_rxd_i),
    // Wishbone Connections
    .wb_adr_o    (wb_adr_o),
    .wb_dat_o    (wb_dat_o),
    .wb_dat_i    (wb_dat_i),
    .wb_sel_o    (wb_sel_o),
    .wb_we_o     (wb_we_o),
    .wb_stb_o     (wb_stb_o),
    .wb_cyc_o    (wb_cyc_o),
    .wb_ack_i    (wb_ack_i)
);

endmodule

`default_nettype wire

