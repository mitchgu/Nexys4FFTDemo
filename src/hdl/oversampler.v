`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Mitchell Gu
// Project Name: Nexys4 FFT Demo
//////////////////////////////////////////////////////////////////////////////////

module oversample16(
    input wire clk,
    input wire [11:0] sample,
    input wire eoc,
    output reg [13:0] oversample,
    output reg done
    );

    reg [3:0] counter = 0;
    reg [15:0] accumulator = 0;

    always @(posedge clk) begin
        done <= 0;
        if (eoc) begin
            // Conversion has ended and we can read a new sample
            if (&counter) begin // If counter is full (16 accumulated)
                // Get final total, divide by 4 with (very limited) rounding.
                oversample <= (accumulator + sample + 2'b10) >> 2;
                done <= 1;
                // Reset accumulator
                accumulator <= 0;
            end
            else begin
                // Else add to accumulator as usual
                accumulator <= accumulator + sample;
                done <= 0;
            end
            counter <= counter + 1;
        end
    end
endmodule

module oversample256(
    input wire clk,
    input wire [11:0] sample,
    input wire eoc,
    output reg [15:0] oversample,
    output reg done
    );

    reg [7:0] counter = 0;
    reg [19:0] accumulator = 0;

    always @(posedge clk) begin
        done <= 0;
        if (eoc) begin
            // Conversion has ended and we can read a new sample
            if (&counter) begin // If counter is full (256 accumulated)
                // Get final total, divide by 16 with rounding.
                oversample <= (accumulator + sample + 4'b0111) >> 4;
                done <= 1;
                // Reset accumulator
                accumulator <= 0;
            end
            else begin
                // Else add to accumulator as usual
                accumulator <= accumulator + sample;
            end
            counter <= counter + 1;
        end
    end
endmodule
