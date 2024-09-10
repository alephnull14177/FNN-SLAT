`define newtaps

module filter_top
    #(
    `ifdef newtaps
    parameter WHOLE_BITS=10, FRAC_BITS=32,
    `else
    parameter WHOLE_BITS=10, FRAC_BITS=54,
    `endif
    parameter WIDTH = WHOLE_BITS + FRAC_BITS // Localparam
    )

    (
    input logic[9:0] x_adc,
    input logic clk, coefficients_ready, sample_ready, reset,
    output logic[9:0] y_n,
    output logic valid_out
    );

    logic[WIDTH-1:0] b0, b1, b2, b3, b4, b5, b6, a3, a6;
    `ifdef newtaps
    assign b0 = 42'b000000000011111111111111101110001110101001;
    assign b1 = 42'b111111111111111111111111011100011101010100;
    assign b2 = 42'b111111111111111111111111011100011101011001;
    assign b3 = 42'b111111111000000000000001101010101011001010;
    assign b4 = 42'b000000000000000000000000100011100010101100;
    assign b5 = 42'b000000000000000000000000100011100010100111;
    assign b6 = 42'b000000000011111111111110100111001001010111;
    assign a3 = 42'b111111111000000000000001101010101011000101;
    assign a6 = 42'b000000000011111111111110010101011000000100;
    `else
    assign b0 = 64'b0000000000111111111111111011100011101010000000000000000000000000;
    assign b1 = 64'b1111111111111111111111110111000111010100100111011110111111011000;
    assign b2 = 64'b1111111111111111111111110111000111010101110110011101010000111000;
    assign b3 = 64'b1111111110000000000000011010101010110011000001111110110001100000;
    assign b4 = 64'b0000000000000000000000001000111000101011011000011111110111010000;
    assign b5 = 64'b0000000000000000000000001000111000101010001001100011111010011100;
    assign b6 = 64'b0000000000111111111111101001110010010100011101111010010100110000;
    assign a3 = 64'b1111111110000000000000011010101010110001110011000001101001101000;
    assign a6 = 64'b0000000000111111111111100101010101111111101100110111011110000100;
    `endif 

    lookahead_behavioral#(
            .WHOLE_BITS(WHOLE_BITS), 
            .FRAC_BITS(FRAC_BITS)
        ) dut (
            .x_adc(x_adc),
            .b0(b0),
            .b1(b1),
            .b2(b2),
            .b3(b3),
            .b4(b4),
            .b5(b5),
            .b6(b6),
            .a3(a3),
            .a6(a6),
            .clk(clk),
            .coefficients_ready(coefficients_ready),
            .sample_ready(sample_ready),
            .reset(reset),
            .y_n(y_n),
            .valid_out(valid_out)
        );

endmodule