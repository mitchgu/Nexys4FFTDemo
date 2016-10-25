# Nexys 4 FFT Demo
A simple Verilog example of a 4096pt FFT on analog input from a Nexys 4 XADC. The input is sampled at 1MSPS, oversampled to produce 14-bit samples at 62.5kHz, then sent to the FFT processing modules and passed through to PWM Audio out. The FFT outputs the magnitude for each frequency bin and a histogram of the frequency spectrum is output over VGA video

## Requirements

### Hardware
*  A Nexys 4 FPGA
* Assorted resistors to attenuate and bias the analog input properly before going into the JXADC header on the Nexys 4. (+0.5V bias, 1Vpp)

### Software
* Vivado 2016.2 or later for Nexys 4 development.

### Peripherals
* A VGA monitor to display the FFT results

## Organization
There are 3 folders
* `bin` contains the latest working bitstream file that can be directly programmed onto a Nexys 4
* `proj` is intended to contain the Vivado project files, to keep them separate from the source.
* `src` contains the actual sources in several folders for constraints, hdl, ip configuration, and block designs. These are fairly self-explanatory and are the core of the project.

## Setting up the project
The procedure is roughly as follows:

1. Create a new Vivado project in the proj directory. 
2. In the new project dialog:  
	1. Add all the hdl in src/hdl to the project
	2. Add all the ips in src/ip to the project
	3. Add the .xdc constraints file to the project
5. Once in the full IDE, click Add Sources again, specify Block Design, and add the fft_mag.bd block design in `src/bd`
8. Cross your fingers and synthesize/implement/write bitstream

## Shortcut
1. If you just want to see it working, just program from the saved bitfile in the `bin` folder