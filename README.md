Prerequisites:

1. Clone this repo: git clone https://github.com/AayushJha2004/cwo305-neo430-aes-Hardware-Trojan-setup/edit/main/README.md
2. Clone NEO430 repo: git clone https://github.com/stnolting/neo430
3. Copy the wishbone_aes subdirectory under neo430/sw/example/.

Bitstream Generation: 

4. Create a blank Vivado project named "soc"
5. Select part xc7a100tftg256-1 as part
6. Add files under RTL and constraint cw305.xdc to the project
7. Go to Vivado project manager and select all files prefixed neo430 and add them to new package named "neo430"
8. Generate bitstream with this setup
9. The provided cw305_top.bit can also be used as a convenience

Chipwhisperer API Setup + Programming bitfile

10. python -m venv venv
11. Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
12. .\venv\Scripts\activate.ps1
13. pip install chipshisperer
14. open aes_bitstream.py and set bitfile path to point to your bitfile created/cloned locally
15. make sure chipshisperer is connected before programming
16. run the script to program the FPGA
    
    Aside: if numpy fails run these commands:  1. pip uninstall numpy -y
                                               2. pip install numpy --force-reinstall --no-cache-dir

Getting command line for NE0430

17. Install terraterm: https://teratermproject.github.io/index-en.html
18. Open device manager and check with COM port chipwhisper is connected to
19. Open a serial connection and press reset button on chipwhisperer
20. An autoboot prompt should appear, press any key within 4 seconds to cancel

Compiling executable binaries

21. 
