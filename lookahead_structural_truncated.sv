//Changes to be made: Enable thats fed into the filter that is then fed into the registers
//Valid output signal
//Pad front and back of 10 bit input to make it WIDTH wide
//To do: adjust bits of multiplication and y_n/x_adc, add two more bits to take into account that the parameters can be up to 2/-2
//Make sure that the intermediate truncation is two extra bits

module lookahead_structural_truncated 
    #(
    parameter ADC_BITS=10,
    parameter WHOLE_BITS=10, FRAC_BITS=54,
    parameter WIDTH = WHOLE_BITS + FRAC_BITS // Localparam

    )

    (
    input logic[9:0] x_adc,
    input logic[WIDTH-1:0] b0, b1, b2, b3, b4, b5, b6, a3, a6, 
    input logic clk, coefficients_ready, sample_ready, reset,
    output logic[9:0] y_n,
    output logic valid_out
    );
    logic rst;
    //logic always_on;
    logic signed Q_0, Q_1;

    logic signed[WIDTH-1:0] a_c3, a_c6;

    assign a_c3 = ~a3+1;
    assign a_c6 = ~a6+1;

    logic signed[WIDTH-1+4:0] a_c3_extended, a_c6_extended;
    assign a_c3_extended = { {a_c3[WIDTH-1:WIDTH-1]},{a_c3[WIDTH-1:WIDTH-1]},{a_c3[WIDTH-1:WIDTH-1]},{a_c3[WIDTH-1:WIDTH-1]}, {a_c3[WIDTH-1:0]} };
    assign a_c6_extended = { {a_c6[WIDTH-1:WIDTH-1]},{a_c6[WIDTH-1:WIDTH-1]},{a_c6[WIDTH-1:WIDTH-1]},{a_c6[WIDTH-1:WIDTH-1]}, {a_c6[WIDTH-1:0]} };

    logic signed[WIDTH-1:0] x_n;
    assign x_n = {{WHOLE_BITS-ADC_BITS{x_adc[ADC_BITS-1]}},{x_adc[ADC_BITS-1:0]},{FRAC_BITS{1'b0}}};

    logic signed[WIDTH-1:0] rx_n;
    logic signed[WIDTH*2-1:0] multb0_out, multb1_out, multb2_out, multb3_out, multb4_out, multb5_out, multb6_out;
    logic signed[WIDTH-1+4:0] multb0_out_truncated, multb1_out_truncated, multb2_out_truncated, multb3_out_truncated, multb4_out_truncated, multb5_out_truncated, multb6_out_truncated;
    logic signed[WIDTH-1+4:0] rmb0, rmb1, rmb2, rmb3, rmb4, rmb5, rmb6, rcb6;
    logic signed[WIDTH-1+4:0] ab0, ab1, ab2, ab3, ab4, ab5, rab1, rab2, rab3, rab4, rab5;

    //truncate outputs of multipliers
    assign multb0_out_truncated = multb0_out[FRAC_BITS +: WIDTH+4];
    assign multb1_out_truncated = multb1_out[FRAC_BITS +: WIDTH+4];
    assign multb2_out_truncated = multb2_out[FRAC_BITS +: WIDTH+4];
    assign multb3_out_truncated = multb3_out[FRAC_BITS +: WIDTH+4];
    assign multb4_out_truncated = multb4_out[FRAC_BITS +: WIDTH+4];
    assign multb5_out_truncated = multb5_out[FRAC_BITS +: WIDTH+4];
    assign multb6_out_truncated = multb6_out[FRAC_BITS +: WIDTH+4];
    //active low reset
    assign rst = (~coefficients_ready) | reset;
    //assign rst =  reset;

    register #( .WIDTH(1)) valid_out_logic_R1(.clk(clk), .rst(rst), .in(sample_ready), .out(Q_0), .en(sample_ready));
    register #( .WIDTH(1)) valid_out_logic_R2(.clk(clk), .rst(rst), .in(Q_0), .out(Q_1), .en(sample_ready));
    assign valid_out = Q_1 & sample_ready;

    //feedforward
    register #(.WIDTH(WIDTH)) R_xin(.clk(clk), .rst(rst), .in(x_n), .out(rx_n), .en(sample_ready));

    register #(.WIDTH(WIDTH+4)) R_mb0(.clk(clk), .rst(rst), .in(multb0_out_truncated), .out(rmb0), .en(sample_ready));
    register #(.WIDTH(WIDTH+4)) R_mb1(.clk(clk), .rst(rst), .in(multb1_out_truncated), .out(rmb1), .en(sample_ready));
    register #(.WIDTH(WIDTH+4)) R_mb2(.clk(clk), .rst(rst), .in(multb2_out_truncated), .out(rmb2), .en(sample_ready));
    register #(.WIDTH(WIDTH+4)) R_mb3(.clk(clk), .rst(rst), .in(multb3_out_truncated), .out(rmb3), .en(sample_ready));
    register #(.WIDTH(WIDTH+4)) R_mb4(.clk(clk), .rst(rst), .in(multb4_out_truncated), .out(rmb4), .en(sample_ready));
    register #(.WIDTH(WIDTH+4)) R_mb5(.clk(clk), .rst(rst), .in(multb5_out_truncated), .out(rmb5), .en(sample_ready));
    register #(.WIDTH(WIDTH+4)) R_mb6(.clk(clk), .rst(rst), .in(multb6_out_truncated), .out(rmb6), .en(sample_ready));

    register #(.WIDTH(WIDTH+4)) R_ab1(.clk(clk), .rst(rst), .in(ab1), .out(rab1), .en(sample_ready));
    register #(.WIDTH(WIDTH+4)) R_ab2(.clk(clk), .rst(rst), .in(ab2), .out(rab2), .en(sample_ready));
    register #(.WIDTH(WIDTH+4)) R_ab3(.clk(clk), .rst(rst), .in(ab3), .out(rab3), .en(sample_ready));
    register #(.WIDTH(WIDTH+4)) R_ab4(.clk(clk), .rst(rst), .in(ab4), .out(rab4), .en(sample_ready));
    register #(.WIDTH(WIDTH+4)) R_ab5(.clk(clk), .rst(rst), .in(ab5), .out(rab5), .en(sample_ready));
    register #(.WIDTH(WIDTH+4)) R_cb6(.clk(clk), .rst(rst), .in(rmb6), .out(rcb6), .en(sample_ready));

    mult #( .WIDTH(WIDTH)) Mult_b0(.in0(rx_n), .in1(b0), .out(multb0_out));
    mult #( .WIDTH(WIDTH)) Mult_b1(.in0(rx_n), .in1(b1), .out(multb1_out));
    mult #( .WIDTH(WIDTH)) Mult_b2(.in0(rx_n), .in1(b2), .out(multb2_out));
    mult #( .WIDTH(WIDTH)) Mult_b3(.in0(rx_n), .in1(b3), .out(multb3_out));
    mult #( .WIDTH(WIDTH)) Mult_b4(.in0(rx_n), .in1(b4), .out(multb4_out));
    mult #( .WIDTH(WIDTH)) Mult_b5(.in0(rx_n), .in1(b5), .out(multb5_out));
    mult #( .WIDTH(WIDTH)) Mult_b6(.in0(rx_n), .in1(b6), .out(multb6_out));

    adder #( .WIDTH(WIDTH+4)) Add_b0(.in0(rmb0), .in1(rab1), .out(ab0)); //-- gets passed to feedback
    adder #( .WIDTH(WIDTH+4)) Add_b1(.in0(rmb1), .in1(rab2), .out(ab1));
    adder #( .WIDTH(WIDTH+4)) Add_b2(.in0(rmb2), .in1(rab3), .out(ab2));
    adder #( .WIDTH(WIDTH+4)) Add_b3(.in0(rmb3), .in1(rab4), .out(ab3));
    adder #( .WIDTH(WIDTH+4)) Add_b4(.in0(rmb4), .in1(rab5), .out(ab4));
    adder #( .WIDTH(WIDTH+4)) Add_b5(.in0(rmb5), .in1(rcb6), .out(ab5));

    logic signed[(WIDTH)*2-1:0] multa3_out, multa6_out;
    logic signed[WIDTH-1+4:0] multa3_out_truncated, multa6_out_truncated;
    logic signed[WIDTH-1+4:0] rma3, rma6;
    logic signed[WIDTH-1+4:0] afinal, rafinal, ra3, ra6_d1, ra6_d2, ra6, raa3, aa3; 

    assign multa3_out_truncated = multa3_out[FRAC_BITS +: WIDTH+4];
    assign multa6_out_truncated = multa6_out[FRAC_BITS +: WIDTH+4];

    //feedback
    
    logic[ADC_BITS-1:0] y_n_o; 
    

    //register #( .WIDTH(WIDTH+4)) R_final(.clk(clk), .rst(rst), .in(afinal), .out(rafinal), .en(sample_ready));

    register #( .WIDTH(WIDTH+4)) R_a3(.clk(clk), .rst(rst), .in(afinal), .out(ra3), .en(sample_ready));
    register #( .WIDTH(WIDTH+4)) R_a6_d1(.clk(clk), .rst(rst), .in(ra3), .out(ra6_d1), .en(sample_ready));
    register #( .WIDTH(WIDTH+4)) R_a6_d2(.clk(clk), .rst(rst), .in(ra6_d1), .out(ra6_d2), .en(sample_ready));
    register #( .WIDTH(WIDTH+4)) R_a6(.clk(clk), .rst(rst), .in(ra6_d2), .out(ra6), .en(sample_ready));

    register #( .WIDTH(WIDTH+4)) R_ma3(.clk(clk), .rst(rst), .in(multa3_out_truncated), .out(rma3), .en(sample_ready));
    register #( .WIDTH(WIDTH+4)) R_ma6(.clk(clk), .rst(rst), .in(multa6_out_truncated), .out(rma6), .en(sample_ready));

    register #( .WIDTH(WIDTH+4)) R_aa3(.clk(clk), .rst(rst), .in(aa3), .out(raa3), .en(sample_ready));

    adder #( .WIDTH(WIDTH+4)) Add_final(.in0(ab0), .in1(raa3), .out(afinal)); //-- pull from feedforward
    adder #( .WIDTH(WIDTH+4)) Add_a1(.in0(rma6), .in1(rma3), .out(aa3));
    //assign aa3 = rma3 + rma6;


    mult #( .WIDTH(WIDTH)) Mult_a3(.in0(ra3[0 +: WIDTH-1]), .in1(a_c3), .out(multa3_out));
    mult #( .WIDTH(WIDTH)) Mult_a6(.in0(ra6[0 +: WIDTH-1]), .in1(a_c6), .out(multa6_out));

//    assign y_n = (rafinal[WIDTH+4-1 : FRAC_BITS] >  511) ?  511 :
//                 (rafinal[WIDTH+4-1 : FRAC_BITS] < -511) ? -511 :
//                                                            rafinal[FRAC_BITS +: 10];
    
    // assign y_n = ($signed(rafinal[FRAC_BITS +: WHOLE_BITS+4]) > $signed({{WHOLE_BITS+4-ADC_BITS+1{1'b0}}, {ADC_BITS-1{1'b1}}})) ? {1'b0, {ADC_BITS-1{1'b1}}} :
    //                ($signed(rafinal[FRAC_BITS +: WHOLE_BITS+4]) < $signed({{WHOLE_BITS+4-ADC_BITS+1{1'b1}}, {ADC_BITS-1{1'b0}}})) ? {1'b1, {ADC_BITS-1{1'b0}}} :
    //                                                                                                                                rafinal[FRAC_BITS +: ADC_BITS];
    assign y_n_o = ($signed(afinal[FRAC_BITS +: WHOLE_BITS+4]) > $signed({{WHOLE_BITS+4-ADC_BITS+1{1'b0}}, {ADC_BITS-1{1'b1}}})) ? {1'b0, {ADC_BITS-1{1'b1}}} :
                   ($signed(afinal[FRAC_BITS +: WHOLE_BITS+4]) < $signed({{WHOLE_BITS+4-ADC_BITS+1{1'b1}}, {ADC_BITS-1{1'b0}}})) ? {1'b1, {ADC_BITS-1{1'b0}}} :
                    afinal[FRAC_BITS +: ADC_BITS];
    register #( .WIDTH(ADC_BITS)) R_final(.clk(clk), .rst(rst), .in(y_n_o), .out(y_n), .en(sample_ready));
 

endmodule