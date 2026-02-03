Steps to follow: 

1. Clone the neo430 repo from github for example compiled binaries.
3. Add all neo430 files to a package named "neo430" in Vivado Project Manager.
4. Add the wishbone_aes subdirectory under neo430/sw/example/.
5. Download Chipwhisperer package into a virtual environment or available Chipwhisperer Jupyter Server.
6. Download NEO430 toolchain from https://www.ti.com/tool/MSP430-GCC-OPENSOURCE#downloads
7. https://www.youtube.com/watch?v=oC69vlWofJQ for mingw setup 
8. pacman -S mingw-w64-x86_64-make to get gnu make
9. Copy and paste mingw32-make and rename make
10. Add mysys32/ucrt64/bin to path
11. Add the toolchain downloaded to system path (ti msp430 gcc toolchain)
