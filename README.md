Steps to follow: 

1. Add all neo430 files to a package named "neo430" in Vivado Project Manager.
2. Download Chipwhisperer package into a virtual environment or available Chipwhisperer Jupyter Server.
3. Download NEO430 toolchain from https://www.ti.com/tool/MSP430-GCC-OPENSOURCE#downloads
4. https://www.youtube.com/watch?v=oC69vlWofJQ for mingw setup 
5. pacman -S mingw-w64-x86_64-make to get gnu make
6. Copy and paste mingw32-make and rename make
7. Add mysys32/ucrt64/bin to path
8. Add the toolchain downloaded to system path (ti msp430 gcc toolchain)
