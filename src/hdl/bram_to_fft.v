`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/18/2015 02:16:55 AM
// Design Name: 
// Module Name: process_fft
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

module bram_to_fft(
    input clk,
    input [11:0] head,
    output reg [11:0] addr,
    input [13:0] data,
    input start,
    input last_missing,
    output reg [31:0] frame_tdata,
    output reg frame_tlast,
    input frame_tready,
    output reg frame_tvalid
    );
    
    // Get a signed version of the sample by subtracting half the max
    wire signed [15:0] data_signed = {data, 2'b0} - (1 << 15);

    // SENDING LOGIC
    // Once our oversampling is done,
    // Start at the frame bram head and send all 4096 buckets of bram.
    // Hopefully every time this happens, the FFT core is ready
    reg sending = 0;
    reg [13:0] send_count = 0;
    // In the last 3/4 of the window of 4*4096 samples, pad the window with zeros
    assign zero_padding = |send_count[13:12]; // last 3/4 is when 2 MSBs are 01, 10, or 11

    always @(posedge clk) begin
        frame_tvalid <= 0; // Normally do not send
        frame_tlast <= 0; // Normally not the end of a frame
        if (!sending) begin
            if (start) begin // When a new sample shifts in
                addr <= head; // Start reading at the new head
                send_count <= 0; // Reset send_count
                sending <= 1; // Advance to next state
            end
        end
        else begin
            if (last_missing) begin
                // If core thought the frame ended
                sending <= 0; // reset to state 0
            end
            else begin
                frame_tdata <= zero_padding ? 32'b0 : {16'b0, data_signed};
                frame_tvalid <= 1; // Signal to fft a sample is ready
                if (frame_tready) begin // If the fft module was ready
                    if (!zero_padding) addr <= addr + 1; // Switch to read next sample
                    send_count <= send_count + 1; // increment send_count 
                end
                if (&send_count) begin
                    // We're at last sample
                    frame_tlast <= 1; // Tell the core
                    if (frame_tready) sending <= 0; // Reset to state 0
                end
            end
        end
    end

endmodule
