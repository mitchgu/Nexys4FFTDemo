//////////////////////////////////////////////////////////////////////////////////
// Company: 
// 
// Create Date: 11/12/2015 V1.0
// Design Name: Guitar Hero: Fast Fourier Edition
// Module Name: ghffe_nexys4
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module nexys4_fft_demo (
    input CLK100MHZ,
    input[15:0] SW, 
    input BTNC, BTNU, BTNL, BTNR, BTND,
    input AD3P, AD3N,
    output[3:0] VGA_R, 
    output[3:0] VGA_B, 
    output[3:0] VGA_G,
    output VGA_HS, 
    output VGA_VS, 
    output AUD_PWM, AUD_SD,
    output LED16_B, LED16_G, LED16_R,
    output LED17_B, LED17_G, LED17_R,
    output[15:0] LED, // LEDs above switches
    output[7:0] SEG,  // segments A-G (0-6), DP (7)
    output[7:0] AN    // Display 0-7
    );

    wire clk_104mhz;
    wire clk_65mhz;

    // SETUP CLOCKS
    // 104Mhz clock for XADC
    // It divides by 4 and runs the ADC clock at 26Mhz
    // And the ADC can do one conversion in 26 clock cycles
    // So the sample rate is 1Msps (not posssible w/ 100Mhz)
    clk_wiz_0 clockgen(
        .clk_in1(CLK100MHZ),
        .clk_out1(clk_104mhz),
        .clk_out2(clk_65mhz));

// **************** BEGIN BASIC IO SETUP *******************************//

    // INSTANTIATE SEVEN SEGMENT DISPLAY
    wire [31:0] seg_data;
    wire [6:0] segments;
    wire [7:0] strobe;
    display_8hex display(
        .clk(clk_65mhz),
        .data(seg_data),
        .seg(segments),
        .strobe(strobe)); 

    // SYNCHRONIZE SWITCHES
    wire [15:0] SWS;
    genvar i;
    generate for(i=0; i<15; i=i+1)
        begin:
            sync_gen_1 synchronize s65(clk_65mhz, SW[i], SWS[i]);
        end
    endgenerate

// **************** END BASIC IO SETUP *******************************//

    wire [15:0] sample_reg;
    wire eoc, xadc_reset;
    // INSTANTIATE XADC INPUT
    xadc_guitar xadc_guitar_1 (
        .dclk_in(clk_104mhz),  // Master clock for DRP and XADC. 
        .di_in(0),             // DRP input info (0 becuase we don't need to write)
        .daddr_in(6'h13),      // The DRP register address for the third analog aux
        .den_in(1),            // DRP enable line high (we want to read)
        .dwe_in(0),            // DRP write enable low (never write)
        .drdy_out(),           // DRP ready signal (unused)
        .do_out(sample_reg),   // DRP output from register (the ADC data)
        .reset_in(xadc_reset), // reset line
        .vp_in(0),             // dedicated/built in analog channel on bank 0
        .vn_in(0),             // can't use this analog channel b/c of nexys 4 setup
        .vauxp3(input_p),     // The third analog auxiliary input channel
        .vauxn3(input_n),     // Choose this one b/c it's on JXADC header 1
        .channel_out(),        // Not useful in sngle channel mode
        .eoc_out(eoc),         // Pulses high on end of ADC conversion
        .alarm_out(),          // Not useful
        .eos_out(),            // End of sequence pulse, not useful
        .busy_out()            // High when conversion is in progress. unused.
    );
    assign xadc_reset = 0; // Ignore reset for this example. Might want to assign to button for actual application

    // INSTANTIATE SAMPLE FRAME BLOCK RAM 
    // This 14x4096 bram stores the frame of samples
    // The write port is written by osample16.
    // The read port is read by process_fft.
    wire fwe;
    reg [11:0] fhead = 0;
    wire [11:0] faddr;
    wire [13:0] fsample, fdata;
    bram_frame bram1 (
        .clka(clk_104mhz),   // input wire clka
        .wea(fwe),           // input wire [0 : 0] wea
        .addra(fhead),     // input wire [11 : 0] addra
        .dina(fsample),      // input wire [15 : 0] dina
        .clkb(clk_104mhz),   // input wire clkb
        .addrb(faddr),     // input wire [11 : 0] addrb
        .doutb(fdata)      // output wire [15 : 0] doutb
    );

    // INSTANTIATE 16x OVERSAMPLING
    // This outputs 14-bit samples at a 62.5kHz sample rate
    // with lower noise than raw ADC output
    // Useful for outputting to PWM audio
    wire [13:0] osample16;
    wire done_osample16;
    oversample16 osamp16_1 (
        .clk(clk_104mhz),
        .sample(sample_reg[15:4]),
        .eoc(eoc),
        .oversample(osample16),
        .done(done_osample16));

    always @(posedge clk_104mhz) begin
        if (done_osample16) fhead <= fhead + 1;
    end
    assign fsample = osample16;
    assign fwe = done_osample16;

    // INSTANTIATE PWM AUDIO OUT MODULE
    // This is a PWM frequency of around 51kHz.
    wire [10:0] pwm_sample;
    pwm11 guitar_pwm(
        .clk(clk_104mhz),
        .PWM_in(pwm_sample),
        .PWM_out(output_audio_pwm),
        .PWM_sd(output_audio_sd)
        );

    // INSTANTIATE FFT PROCESSING MODULE
    wire last_missing;
    wire [31:0] frame_tdata;
    wire frame_tlast, frame_tready, frame_tvalid;
    bram_to_fft bram_to_fft_0(
        .clk(clk_104mhz),
        .head(fhead),
        .addr(faddr),
        .data(fdata),
        .start(done_osample16),
        .last_missing(last_missing),
        .frame_tdata(frame_tdata),
        .frame_tlast(frame_tlast),
        .frame_tready(frame_tready),
        .frame_tvalid(frame_tvalid)
    );

    wire [23:0] magnitude_tdata;
    wire [13:0] magnitude_tuser;
    wire magnitude_tlast, magnitude_tvalid;
    fft_mag fft_mag_i(
        .clk(clk_104mhz),
        .event_tlast_missing(last_missing),
        .frame_tdata(frame_tdata),
        .frame_tlast(frame_tlast),
        .frame_tready(frame_tready),
        .frame_tvalid(frame_tvalid),
        .magnitude_tdata(magnitude_tdata),
        .magnitude_tlast(magnitude_tlast),
        .magnitude_tuser(magnitude_tuser),
        .magnitude_tvalid(magnitude_tvalid));

    wire in_range;
    assign in_range = ~|magnitude_tuser[13:12]; // When 13 and 12 are 0, we get the 0 to 15.6kHz buckets

    // INSTANTIATE HISTOGRAM BLOCK RAM 
    // This 16x4096 bram stores the histogram data.
    // The write port is written by process_fft.
    // The read port is read by the video outputter or the SD care saver
    // Assign histogram bram read address to histogram module unless saving
    wire [11:0] haddr;
    wire [15:0] hdata;
    bram_fft bram2 (
        .clka(clk_104mhz), // input wire clka
        .wea(in_range & magnitude_tvalid),  // input wire [0 : 0] wea
        .addra(magnitude_tuser[11:0]),     // input wire [9 : 0] addra
        .dina(magnitude_tdata[15:0]),      // input wire [15 : 0] dina
        .clkb(clk_65mhz),  // input wire clkb
        .addrb(haddr),     // input wire [9 : 0] addrb
        .doutb(hdata)      // output wire [15 : 0] doutb
    );

    // INSTANTIATE XVGA SIGNALS
    wire [10:0] hcount;
    wire [9:0] vcount;
    wire hsync, vsync, blank;
    xvga xvga1(
        .vclock(clk_65mhz),
        .hcount(hcount),
        .vcount(vcount),
        .vsync(vsync),
        .hsync(hsync),
        .blank(blank));

    // INSTANTIATE HISTOGRAM VIDEO
    wire [2:0] hist_pixel;
    wire [2:0] hist_range;
    histogram fft_histogram(
        .clk(clk_65mhz),
        .hcount(hcount),
        .vcount(vcount),
        .blank(blank),
        .range(hist_range),
        .vaddr(haddr),
        .vdata(hdata),
        .pixel(hist_pixel));

//////////////////////////////////////////////////////////////////////////////////
//  
    // Connect the analog header pin to the xadc input
    assign input_p = AD3P;
    assign input_n = AD3N;

    // PWM input is 16x oversampled
    assign pwm_sample = osample16[13:3];
    // Connect the guitar pwm audio to Nexys's PWM out
    assign AUD_PWM = output_audio_pwm;
    assign AUD_SD = output_audio_sd;

    // VGA OUTPUT
    // Histogram has two pipeline stages so we'll pipeline the hs and vs equally
    reg [1:0] hsync_delay;
    reg [1:0] vsync_delay;
    reg hsync_out, vsync_out;
    always @(posedge clk_65mhz) begin
        {hsync_out,hsync_delay} <= {hsync_delay,hsync};
        {vsync_out,vsync_delay} <= {vsync_delay,vsync};
    end
    assign VGA_R = {4{hist_pixel[0]}};
    assign VGA_G = {4{hist_pixel[1]}};
    assign VGA_B = {4{hist_pixel[2]}};
    assign VGA_HS = hsync_out;
    assign VGA_VS = vsync_out;
    
    // Map histogram range to 3 switches
    assign hist_range = SW[2:0];

    // Assign RGB LEDs
    assign {LED16_R, LED16_G, LED16_B} = 3'b000;
    assign {LED17_R, LED17_G, LED17_B} = 3'b000;
    
    // Assign switch LEDs to switch states
    assign LED = SW;
    
    // Display 01234567 then fsm state and timer time left
    assign seg_data = 32'hDEADBEEF; 

    // Link segments module output to segments
    assign AN = strobe;  
    assign SEG[6:0] = segments;
    assign SEG[7] = 1'b1;

//
//////////////////////////////////////////////////////////////////////////////////
 
endmodule