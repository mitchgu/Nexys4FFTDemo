# Nexys 4 FFT Demo
A simple Verilog example of a 4096pt FFT on analog input from a Nexys 4 XADC. The spectrum is output over vga video, and an oversampled and filtered version of the signal is output over PWM audio.

## Requirements

### Hardware
*  A Nexys 4 FPGA
* Assorted resistors and a headphone jack to setup a 0.5V bias for the guitar's pickup signal to be input into the XADC Header

### Software
* Vivado 2016.2 or later for Nexys 4 development.

### Peripherals
* A VGA monitor to display the game

## Organization
There are 3 folders
* `bin` contains the latest working bitstream file that can be directly programmed onto a Nexys 4
* `proj` is intended to contain the Vivado project files, to keep them separate from the source.
* `src` contains the actual sources in several folders for constraints, hdl, ip configuration, and block designs. These are fairly self-explanatory and are the core of the project.

## Setting up the project
The procedure is roughly as follows:

1. Create a new Vivado project in the proj directory.  
2. Add all the hdl in src/hdl to the project
4. Add all the ips in src/ip to the project
4. Add the .xdc constraints file to the project
5. Once in the full IDE, click Add Sources again, specify Block Design, and add the fft_mag.bd block design in `src/bd`
6. One-time only: Fix the things in the "Important Notes" section below
8. Cross your fingers and synthesize/implement/write bitstream

### Important Notes

* The fft_mag.bd block design won't validate correctly right after import. First one has to change the addsub to asynchronous mode (latency 0) and validate, then wire the axi register slice's tlast to the CORDIC's tlast. After that, the block design should be configured correctly.
* Upon synthesis for the first time, Vivado will likely complain that "Complex defparams are not supported." In that case, entering the following in the TCL console will allow complex defparams: `set_param synth.elaboration.rodinMoreOptions "rt::set_parameter allowIndexedDefparam true"`
