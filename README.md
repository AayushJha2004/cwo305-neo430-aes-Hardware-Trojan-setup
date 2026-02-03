Steps to follow: 

1. Clone the neo430 repo from github for example compiled binaries.
2. Add all neo430 files to a package named "neo430" in Vivado Project Manager.
3. Download Chipwhisperer package into a virtual environment or available Chipwhisperer Jupyter Server.
4. Download NEO430 toolchain from https://www.ti.com/tool/MSP430-GCC-OPENSOURCE#downloads
5. https://www.youtube.com/watch?v=oC69vlWofJQ for mingw setup 
6. pacman -S mingw-w64-x86_64-make to get gnu make
7. Copy and paste mingw32-make and rename make
8. Add mysys32/ucrt64/bin to path
9. Add the toolchain downloaded to system path (ti msp430 gcc toolchain)
