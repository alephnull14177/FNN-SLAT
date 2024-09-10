//Changes to be made: Enable thats fed into the filter that is then fed into the registers
//Valid output signal
//Pad front and back of 10 bit input to make it WIDTH wide
//To do: adjust bits of multiplication and y_n/x_adc, add two more bits to take into account that the parameters can be up to 2/-2
//Make sure that the intermediate truncation is two extra bits


// Filter will ignore any samples before LAT_coefficients_ready is asserted
module filter #(
    parameter ADC_BITS=10,
    parameter WHOLE_BITS=10, FRAC_BITS=54,
    parameter WIDTH = WHOLE_BITS + FRAC_BITS // Localparam
) (
    input logic[ADC_BITS-1:0] x_adc,
    input logic[WIDTH-1:0] b0, b1, b2, a1, a2,
    input logic clk, coefficients_ready, sample_ready, reset,
    output logic[ADC_BITS-1:0] y_n,
    output logic valid_out
);

    logic rst;

    logic signed[WIDTH-1:0] a_c1, a_c2;

    assign a_c1 = ~a1+1; // two's complement
    assign a_c2 = ~a2+1; // two's complement

    logic signed[ADC_BITS-1:0] y_n_i;
    logic signed[WIDTH+3-1:0] y_3, y_4;

    logic signed[WIDTH-1:0] x_i, x_n;
    assign x_i = {{WHOLE_BITS-ADC_BITS{x_adc[ADC_BITS-1]}},{x_adc[ADC_BITS-1:0]},{FRAC_BITS{1'b0}}};

    // Look-ahead transformed filter taps from doi.org/10.1049/iet-com.2018.0085
    logic signed[WIDTH-1:0] b0_lat, b1_lat, b2_lat, b3_lat, b4_lat, a1_lat, a2_lat;

    logic signed[WIDTH*2-1:0] xb0_i, xb1_i, xb2_i, xb3_i, xb4_i;
    logic signed[(WIDTH+3)*2-1:0] y3a1_i, y4a2_i;
    // +3 because it's 5 additions/subtractions: 2^n + 2^n + 2^n + 2^n + 2^n: 5*2^n: 2^3*2^n
    // -1 because index starting at 0
    logic signed[WIDTH-1+3:0] xb0_i_truncated, xb1_i_truncated, xb2_i_truncated, xb3_i_truncated, xb4_i_truncated, y3a1_i_truncated, y4a2_i_truncated;
    logic signed[WIDTH-1+3:0] xb4_ii;
    logic signed[WIDTH-1+3:0] xb0, xb1, xb2, xb3, xb4, y3a1, y4a2;
    logic signed[WIDTH-1+3:0] sum_b, sum_b1234, sum_b234, sum_b34, sum_a, sum_ab;
    logic signed[WIDTH-1+3:0] sum_b1234_i, sum_b234_i, sum_b34_i, sum_a_i, sum_ab_i;

    //truncate outputs of multipliers
    assign xb0_i_truncated = xb0_i[FRAC_BITS +: WIDTH+3];
    assign xb1_i_truncated = xb1_i[FRAC_BITS +: WIDTH+3];
    assign xb2_i_truncated = xb2_i[FRAC_BITS +: WIDTH+3];
    assign xb3_i_truncated = xb3_i[FRAC_BITS +: WIDTH+3];
    assign xb4_i_truncated = xb4_i[FRAC_BITS +: WIDTH+3];
    assign y3a1_i_truncated = y3a1_i[FRAC_BITS +: WIDTH+3];
    assign y4a2_i_truncated = y4a2_i[FRAC_BITS +: WIDTH+3];
    //active high reset and rst, active low coeff_ready
    assign rst = (~coefficients_ready) | reset;

    // Look-Ahead Transformed Filter Taps {{{

    // LAT_coefficients_ready {{{
    // 4 FPGA cycles of latency from coefficients_ready until LAT coefficients ready
    //     100 MHz FPGA clock, 5 MHz sampling frequency -> safe
    logic LAT_coefficients_ready, lat_q1, lat_q2, lat_q3;
    // D=1
    register #(.WIDTH(1)) R_lat_q1(.clk(clk), .rst(rst), .in( 1'b1 ), .out(lat_q1), .en(1'b1));
    // D=2
    register #(.WIDTH(1)) R_lat_q2(.clk(clk), .rst(rst), .in(lat_q1), .out(lat_q2), .en(1'b1));
    // D=3
    register #(.WIDTH(1)) R_lat_q3(.clk(clk), .rst(rst), .in(lat_q2), .out(lat_q3), .en(1'b1));
    // D=4
    register #(.WIDTH(1)) R_lat_q4(.clk(clk), .rst(rst), .in(lat_q3), .out(LAT_coefficients_ready), .en(1'b1));
    // }}}

    // TODO: may need to add 3 extra bits since b2 has 4 expressions added
    // B0 {{{
    logic signed[WIDTH-1:0] b0_1, b0_2, b0_3;
    // D=1
    register #(.WIDTH(WIDTH)) R_b0_1(.clk(clk), .rst(rst), .in(b0  ), .out(b0_1), .en(1'b1));
    // D=2
    register #(.WIDTH(WIDTH)) R_b0_2(.clk(clk), .rst(rst), .in(b0_1), .out(b0_2), .en(1'b1));
    // D=3
    register #(.WIDTH(WIDTH)) R_b0_3(.clk(clk), .rst(rst), .in(b0_2), .out(b0_3), .en(1'b1));
    // D=4
    register #(.WIDTH(WIDTH)) R_b0_lat(.clk(clk), .rst(rst), .in(b0_3), .out(b0_lat), .en(1'b1));
    // }}}

    // B1 {{{
    logic signed[WIDTH-1:0] b1_1, b1_l_i, b1_l, b1_l_1;
    logic signed[WIDTH-1:0] a1b0_i_truncated, a1b0;
    logic signed[WIDTH*2-1:0] a1b0_i;
    // D=1
    register #(.WIDTH(WIDTH)) R_b1(.clk(clk), .rst(rst), .in(b1), .out(b1_1), .en(1'b1));
    mult #(.WIDTH(WIDTH)) Mult_a1b0(.in0(a_c1), .in1(b0), .out(a1b0_i));
    assign a1b0_i_truncated = a1b0_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a1b0(.clk(clk), .rst(rst), .in(a1b0_i_truncated), .out(a1b0), .en(1'b1));
    // D=2
    subtr #(.WIDTH(WIDTH)) subtr_b1_a1b0(.in0(b1_1), .in1(a1b0), .out(b1_l_i));
    register #(.WIDTH(WIDTH)) R_b1_l(.clk(clk), .rst(rst), .in(b1_l_i), .out(b1_l), .en(1'b1));
    // D=3
    register #(.WIDTH(WIDTH)) R_b1_l_1(.clk(clk), .rst(rst), .in(b1_l), .out(b1_l_1), .en(1'b1));
    // D=4
    register #(.WIDTH(WIDTH)) R_b1_lat(.clk(clk), .rst(rst), .in(b1_l_1), .out(b1_lat), .en(1'b1));
    // }}}

    // B2 {{{
    logic signed[WIDTH-1:0] b2_1, b2_l_i, b2ma1b1_i, b2ma1b1, b2ma1b1_1, a2b01ma1a1b0_i, a2b01ma1a1b0;
    logic signed[WIDTH-1:0] a1b1_i_truncated, a1b1;
    logic signed[WIDTH*2-1:0] a1b1_i;
    logic signed[WIDTH-1:0] a2b0_i_truncated, a2b0, a2b0_1;
    logic signed[WIDTH*2-1:0] a2b0_i;
    logic signed[WIDTH-1:0] a1a1b0_i_truncated, a1a1b0;
    logic signed[WIDTH*2-1:0] a1a1b0_i;
    // D=1
    register #(.WIDTH(WIDTH)) R_b2(.clk(clk), .rst(rst), .in(b2), .out(b2_1), .en(1'b1));
    mult #(.WIDTH(WIDTH)) Mult_a1b1(.in0(a_c1), .in1(b1), .out(a1b1_i));
    assign a1b1_i_truncated = a1b1_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a1b1(.clk(clk), .rst(rst), .in(a1b1_i_truncated), .out(a1b1), .en(1'b1));
    mult #(.WIDTH(WIDTH)) Mult_a2b0(.in0(a_c2), .in1(b0), .out(a2b0_i));
    assign a2b0_i_truncated = a2b0_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a2b0(.clk(clk), .rst(rst), .in(a2b0_i_truncated), .out(a2b0), .en(1'b1));
    // <a1b0> shared from before
    // D=2
    subtr #(.WIDTH(WIDTH)) subtr_b2_a1b1(.in0(b2_1), .in1(a1b1), .out(b2ma1b1_i));
    register #(.WIDTH(WIDTH)) R_b2_minus_a1b1(.clk(clk), .rst(rst), .in(b2ma1b1_i), .out(b2ma1b1), .en(1'b1));
    register #(.WIDTH(WIDTH)) R_a2b0_1(.clk(clk), .rst(rst), .in(a2b0), .out(a2b0_1), .en(1'b1));
    mult #(.WIDTH(WIDTH)) Mult_a1a1b0(.in0(a1b0), .in1(a_c1), .out(a1a1b0_i));
    assign a1a1b0_i_truncated = a1a1b0_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a1a1b0(.clk(clk), .rst(rst), .in(a1a1b0_i_truncated), .out(a1a1b0), .en(1'b1));
    // D=3
    register #(.WIDTH(WIDTH)) R_b2_minus_a1b1_1(.clk(clk), .rst(rst), .in(b2ma1b1), .out(b2ma1b1_1), .en(1'b1));
    subtr #(.WIDTH(WIDTH)) subtr_a2b0_1_a1a1b0(.in0(a2b0_1), .in1(a1a1b0), .out(a2b01ma1a1b0_i));
    register #(.WIDTH(WIDTH)) R_a2b01_minus_a1a1b0(.clk(clk), .rst(rst), .in(a2b01ma1a1b0_i), .out(a2b01ma1a1b0), .en(1'b1));
    // D=4
    subtr #(.WIDTH(WIDTH)) subtr_b2_l(.in0(b2ma1b1_1), .in1(a2b01ma1a1b0), .out(b2_l_i));
    register #(.WIDTH(WIDTH)) R_b2_l(.clk(clk), .rst(rst), .in(b2_l_i), .out(b2_lat), .en(1'b1));
    // }}}

    // B3 {{{
    logic signed[WIDTH-1:0] b3_l_i, b3_l;
    logic signed[WIDTH-1:0] a1b2_i_truncated, a1b2;
    logic signed[WIDTH*2-1:0] a1b2_i;
    logic signed[WIDTH-1:0] a2b1_i_truncated, a2b1;
    logic signed[WIDTH*2-1:0] a2b1_i;
    logic signed[WIDTH-1:0] a1a1b1_i_truncated, a1a1b1;
    logic signed[WIDTH*2-1:0] a1a1b1_i;
    logic signed[WIDTH-1:0] a1b2pa2b1_i, a1b2pa2b1;
    // D=1
    // <a1b1> shared from before
    mult #(.WIDTH(WIDTH)) Mult_a1b2(.in0(a_c1), .in1(b2), .out(a1b2_i));
    assign a1b2_i_truncated = a1b2_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a1b2(.clk(clk), .rst(rst), .in(a1b2_i_truncated), .out(a1b2), .en(1'b1));
    mult #(.WIDTH(WIDTH)) Mult_a2b1(.in0(a_c2), .in1(b1), .out(a2b1_i));
    assign a2b1_i_truncated = a2b1_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a2b1(.clk(clk), .rst(rst), .in(a2b1_i_truncated), .out(a2b1), .en(1'b1));
    // D=2
    mult #(.WIDTH(WIDTH)) Mult_a1a1b1(.in0(a_c1), .in1(a1b1), .out(a1a1b1_i));
    assign a1a1b1_i_truncated = a1a1b1_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a1a1b1(.clk(clk), .rst(rst), .in(a1a1b1_i_truncated), .out(a1a1b1), .en(1'b1));
    adder #(.WIDTH(WIDTH)) Add_a1b2_a2b1(.in0(a1b2), .in1(a2b1), .out(a1b2pa2b1_i));
    register #(.WIDTH(WIDTH)) R_a1b2_plus_a2b1(.clk(clk), .rst(rst), .in(a1b2pa2b1_i), .out(a1b2pa2b1), .en(1'b1));
    // D=3
    subtr #(.WIDTH(WIDTH)) subtr_b3_l(.in0(a1a1b1), .in1(a1b2pa2b1), .out(b3_l_i));
    register #(.WIDTH(WIDTH)) R_b3_l(.clk(clk), .rst(rst), .in(b3_l_i), .out(b3_l), .en(1'b1));
    // D=4
    register #(.WIDTH(WIDTH)) R_b3_lat(.clk(clk), .rst(rst), .in(b3_l), .out(b3_lat), .en(1'b1));
    // }}}

    // B4 {{{
    logic signed[WIDTH-1:0] a1a1b2_i_truncated, a1a1b2, b4_l_i, b4_l;
    logic signed[WIDTH*2-1:0] a1a1b2_i;
    logic signed[WIDTH-1:0] a2b2_i_truncated, a2b2, a2b2_1;
    logic signed[WIDTH*2-1:0] a2b2_i;
    // D=1
    // <a1b2> shared from before
    mult #(.WIDTH(WIDTH)) Mult_a2b2(.in0(a_c2), .in1(b2), .out(a2b2_i));
    assign a2b2_i_truncated = a2b2_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a2b2(.clk(clk), .rst(rst), .in(a2b2_i_truncated), .out(a2b2), .en(1'b1));
    // D=2
    mult #(.WIDTH(WIDTH)) Mult_a1a1b2(.in0(a_c1), .in1(a1b2), .out(a1a1b2_i));
    assign a1a1b2_i_truncated = a1a1b2_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a1a1b2(.clk(clk), .rst(rst), .in(a1a1b2_i_truncated), .out(a1a1b2), .en(1'b1));
    register #(.WIDTH(WIDTH)) R_a2b2_1(.clk(clk), .rst(rst), .in(a2b2), .out(a2b2_1), .en(1'b1));
    // D=3
    subtr #(.WIDTH(WIDTH)) subtr_b4_l(.in0(a1a1b2), .in1(a2b2_1), .out(b4_l_i));
    register #(.WIDTH(WIDTH)) R_b4_l(.clk(clk), .rst(rst), .in(b4_l_i), .out(b4_l), .en(1'b1));
    // D=4
    register #(.WIDTH(WIDTH)) R_b4_lat(.clk(clk), .rst(rst), .in(b4_l), .out(b4_lat), .en(1'b1));
    // }}}

    // A1 {{{
    logic signed[WIDTH*2-1:0] a1a2_i;
    logic signed[WIDTH-1:0] a1a2_i_truncated, a1a2, a1_l_i, a1_l;
    logic signed[WIDTH-1:0] two_a1a2_i_truncated, two_a1a2;
    logic signed[WIDTH*2-1:0] a1a1_i;
    logic signed[WIDTH-1:0] a1a1_i_truncated, a1a1;
    logic signed[WIDTH*2-1:0] a1a1a1_i;
    logic signed[WIDTH-1:0] a1a1a1_i_truncated, a1a1a1;
    // D=1
    mult #(.WIDTH(WIDTH)) Mult_a1a2(.in0(a_c1), .in1(a_c2), .out(a1a2_i));
    assign a1a2_i_truncated = a1a2_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a1a2(.clk(clk), .rst(rst), .in(a1a2_i_truncated), .out(a1a2), .en(1'b1));
    mult #(.WIDTH(WIDTH)) Mult_a1a1(.in0(a_c1), .in1(a_c1), .out(a1a1_i));
    assign a1a1_i_truncated = a1a1_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a1a1(.clk(clk), .rst(rst), .in(a1a1_i_truncated), .out(a1a1), .en(1'b1));
    // D=2
    assign two_a1a2_i_truncated = {a1a2[WIDTH-2:0], 1'b0}; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_two_a1a2(.clk(clk), .rst(rst), .in(two_a1a2_i_truncated), .out(two_a1a2), .en(1'b1));
    mult #(.WIDTH(WIDTH)) Mult_a1a1a1(.in0(a_c1), .in1(a1a1), .out(a1a1a1_i));
    assign a1a1a1_i_truncated = a1a1a1_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a1a1a1(.clk(clk), .rst(rst), .in(a1a1a1_i_truncated), .out(a1a1a1), .en(1'b1));
    // D=3
    subtr #(.WIDTH(WIDTH)) subtr_a1_l(.in0(two_a1a2), .in1(a1a1a1), .out(a1_l_i));
    register #(.WIDTH(WIDTH)) R_a1_l(.clk(clk), .rst(rst), .in(a1_l_i), .out(a1_l), .en(1'b1));
    // D=4
    register #(.WIDTH(WIDTH)) R_a1_lat(.clk(clk), .rst(rst), .in(a1_l), .out(a1_lat), .en(1'b1));
    // }}}

    // A2 {{{
    logic signed[WIDTH*2-1:0] a2a2_i;
    logic signed[WIDTH-1:0] a2a2_i_truncated, a2a2, a2a2_1, a2_l_i, a2_l;
    logic signed[WIDTH-1:0] a1a1a2_i_truncated, a1a1a2;
    logic signed[WIDTH*2-1:0] a1a1a2_i;
    // D=1
    // <a1a2> shared from before
    mult #(.WIDTH(WIDTH)) Mult_a2a2(.in0(a_c2), .in1(a_c2), .out(a2a2_i));
    assign a2a2_i_truncated = a2a2_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a2a2(.clk(clk), .rst(rst), .in(a2a2_i_truncated), .out(a2a2), .en(1'b1));
    // D=2
    mult #(.WIDTH(WIDTH)) Mult_a1a1a2(.in0(a_c1), .in1(a1a2), .out(a1a1a2_i));
    assign a1a1a2_i_truncated = a1a1a2_i[FRAC_BITS +: WIDTH]; // truncate outputs of multipliers
    register #(.WIDTH(WIDTH)) R_a1a1a2(.clk(clk), .rst(rst), .in(a1a1a2_i_truncated), .out(a1a1a2), .en(1'b1));
    register #(.WIDTH(WIDTH)) R_a2a2_1(.clk(clk), .rst(rst), .in(a2a2), .out(a2a2_1), .en(1'b1));
    // D=3
    adder #(.WIDTH(WIDTH)) Add_a2_l(.in0(a1a1a2), .in1(a2a2_1), .out(a2_l_i));
    register #(.WIDTH(WIDTH)) R_a2_l(.clk(clk), .rst(rst), .in(a2_l_i), .out(a2_l), .en(1'b1));
    // D=4
    register #(.WIDTH(WIDTH)) R_a2_lat(.clk(clk), .rst(rst), .in(a2_l), .out(a2_lat), .en(1'b1));
    // }}}

    // }}}

    // Direct Form 1, Look-Ahead Transformed Second Order Structure {{{
    logic sample_and_filter_ready;
    assign sample_and_filter_ready = sample_ready & LAT_coefficients_ready;

    // Four clocks before b0*x[n] sample outputted
    logic signed v1, v2, v3;
    register #(.WIDTH(1)) valid_out_logic_R1(.clk(clk), .rst(rst), .in(sample_ready), .out(v1),        .en(sample_and_filter_ready));
    register #(.WIDTH(1)) valid_out_logic_R2(.clk(clk), .rst(rst), .in(     v1     ), .out(v2),        .en(sample_and_filter_ready));
    register #(.WIDTH(1)) valid_out_logic_R3(.clk(clk), .rst(rst), .in(     v2     ), .out(v3),        .en(sample_and_filter_ready));
    register #(.WIDTH(1)) valid_out_logic_R4(.clk(clk), .rst(rst), .in(     v3     ), .out(valid_out), .en(sample_and_filter_ready));

    // Filter
    register #(.WIDTH(WIDTH)) R_x(.clk(clk), .rst(rst), .in(x_i), .out(x_n), .en(sample_and_filter_ready));

    mult #(.WIDTH(WIDTH)) Mult_b0(.in0(x_n), .in1(b0_lat), .out(xb0_i));
    mult #(.WIDTH(WIDTH)) Mult_b1(.in0(x_n), .in1(b1_lat), .out(xb1_i));
    mult #(.WIDTH(WIDTH)) Mult_b2(.in0(x_n), .in1(b2_lat), .out(xb2_i));
    mult #(.WIDTH(WIDTH)) Mult_b3(.in0(x_n), .in1(b3_lat), .out(xb3_i));
    mult #(.WIDTH(WIDTH)) Mult_b4(.in0(x_n), .in1(b4_lat), .out(xb4_i));
    register #(.WIDTH(WIDTH+3)) R_xb0   (.clk(clk), .rst(rst), .in(xb0_i_truncated), .out(xb0   ), .en(sample_and_filter_ready));
    register #(.WIDTH(WIDTH+3)) R_xb1   (.clk(clk), .rst(rst), .in(xb1_i_truncated), .out(xb1   ), .en(sample_and_filter_ready));
    register #(.WIDTH(WIDTH+3)) R_xb2   (.clk(clk), .rst(rst), .in(xb2_i_truncated), .out(xb2   ), .en(sample_and_filter_ready));
    register #(.WIDTH(WIDTH+3)) R_xb3   (.clk(clk), .rst(rst), .in(xb3_i_truncated), .out(xb3   ), .en(sample_and_filter_ready));
    register #(.WIDTH(WIDTH+3)) R_xb4_ii(.clk(clk), .rst(rst), .in(xb4_i_truncated), .out(xb4_ii), .en(sample_and_filter_ready));
    register #(.WIDTH(WIDTH+3)) R_xb4   (.clk(clk), .rst(rst), .in(xb4_ii         ), .out(xb4   ), .en(sample_and_filter_ready));
    adder #(.WIDTH(WIDTH+3)) Add_b    (.in0(xb0), .in1(sum_b1234), .out(sum_b));
    adder #(.WIDTH(WIDTH+3)) Add_b1234(.in0(xb1), .in1(sum_b234 ), .out(sum_b1234_i));
    adder #(.WIDTH(WIDTH+3)) Add_b234 (.in0(xb2), .in1(sum_b34  ), .out(sum_b234_i));
    adder #(.WIDTH(WIDTH+3)) Add_b34  (.in0(xb3), .in1(xb4      ), .out(sum_b34_i));
    register #(.WIDTH(WIDTH+3)) R_sumb1234(.clk(clk), .rst(rst), .in(sum_b1234_i), .out(sum_b1234), .en(sample_and_filter_ready));
    register #(.WIDTH(WIDTH+3)) R_sumb234 (.clk(clk), .rst(rst), .in(sum_b234_i ), .out(sum_b234 ), .en(sample_and_filter_ready));
    register #(.WIDTH(WIDTH+3)) R_sumb34  (.clk(clk), .rst(rst), .in(sum_b34_i  ), .out(sum_b34  ), .en(sample_and_filter_ready));

    register #(.WIDTH(WIDTH+3)) R_y3(.clk(clk), .rst(rst), .in(sum_ab_i), .out(y_3), .en(sample_and_filter_ready));
    register #(.WIDTH(WIDTH+3)) R_y4(.clk(clk), .rst(rst), .in(   y_3  ), .out(y_4), .en(sample_and_filter_ready));
    mult #(.WIDTH(WIDTH+3)) Mult_a1(.in0(y_3), .in1({3'b0, a1_lat}), .out(y3a1_i));
    mult #(.WIDTH(WIDTH+3)) Mult_a2(.in0(y_4), .in1({3'b0, a2_lat}), .out(y4a2_i));
    register #(.WIDTH(WIDTH+3)) R_y3a1(.clk(clk), .rst(rst), .in(y3a1_i_truncated), .out(y3a1), .en(sample_and_filter_ready));
    register #(.WIDTH(WIDTH+3)) R_y4a2(.clk(clk), .rst(rst), .in(y4a2_i_truncated), .out(y4a2), .en(sample_and_filter_ready));
    adder #(.WIDTH(WIDTH+3)) Add_ab(.in0(sum_b), .in1(sum_a), .out(sum_ab_i));
    adder #(.WIDTH(WIDTH+3)) Add_a (.in0(y3a1 ), .in1(y4a2 ), .out(sum_a_i));
    register #(.WIDTH(WIDTH+3)) R_sumab(.clk(clk), .rst(rst), .in(sum_ab_i), .out(sum_ab), .en(sample_and_filter_ready));
    register #(.WIDTH(WIDTH+3)) R_suma (.clk(clk), .rst(rst), .in(sum_a_i ), .out(sum_a ), .en(sample_and_filter_ready));

    assign y_n_i = ($signed(sum_ab[FRAC_BITS +: WHOLE_BITS+3]) > $signed({{WHOLE_BITS+3-ADC_BITS+1{1'b0}}, {ADC_BITS-1{1'b1}}})) ? {1'b0, {ADC_BITS-1{1'b1}}} :
                   ($signed(sum_ab[FRAC_BITS +: WHOLE_BITS+3]) < $signed({{WHOLE_BITS+3-ADC_BITS+1{1'b1}}, {ADC_BITS-1{1'b0}}})) ? {1'b1, {ADC_BITS-1{1'b0}}} :
                                                                                                                                   sum_ab[FRAC_BITS +: ADC_BITS];
    register #(.WIDTH(ADC_BITS)) R_y_n (.clk(clk), .rst(rst), .in(y_n_i), .out(y_n), .en(sample_and_filter_ready));
    // }}}

endmodule

