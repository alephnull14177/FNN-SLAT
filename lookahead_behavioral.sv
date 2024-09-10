//Changes to be made: Enable thats fed into the filter that is then fed into the registers
//Valid output signal
//Pad front and back of 10 bit input to make it WIDTH wide
//To do: adjust bits of multiplication and y_n/x_adc, add two more bits to take into account that the parameters can be up to 2/-2
//Make sure that the intermediate truncation is two extra bits

module lookahead_behavioral 
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
    localparam ADD_BUFF = 4; //4 because there are 9 additions so 4 bits extra needed
    logic signed[WIDTH-1:0] a_c3, a_c6;

    assign a_c3 = ~a3+1;
    assign a_c6 = ~a6+1;

    logic signed[WIDTH-1+ADD_BUFF:0] a_c3_extended, a_c6_extended;
    assign a_c3_extended = { {a_c3[WIDTH-1:WIDTH-1]},{a_c3[WIDTH-1:WIDTH-1]},{a_c3[WIDTH-1:WIDTH-1]},{a_c3[WIDTH-1:WIDTH-1]}, {a_c3[WIDTH-1:0]} };
    assign a_c6_extended = { {a_c6[WIDTH-1:WIDTH-1]},{a_c6[WIDTH-1:WIDTH-1]},{a_c6[WIDTH-1:WIDTH-1]},{a_c6[WIDTH-1:WIDTH-1]}, {a_c6[WIDTH-1:0]} };

    logic signed[WIDTH-1:0] x_n;
    assign x_n = {{WHOLE_BITS-ADC_BITS{x_adc[ADC_BITS-1]}},{x_adc[ADC_BITS-1:0]},{FRAC_BITS{1'b0}}};

    logic signed[WIDTH-1:0] rx_n;
    logic signed[WIDTH-1+ADD_BUFF:0] rmb0, rmb1, rmb2, rmb3, rmb4, rmb5, rmb6, rcb6;
    logic signed[WIDTH-1+ADD_BUFF:0] ab0, ab1, ab2, ab3, ab4, ab5, rab1, rab2, rab3, rab4, rab5;

    //active low reset
    assign rst = (~coefficients_ready) | reset;

    register #( .WIDTH(1)) valid_out_logic_R1(.clk(clk), .rst(rst), .in(sample_ready), .out(Q_0), .en(sample_ready));
    register #( .WIDTH(1)) valid_out_logic_R2(.clk(clk), .rst(rst), .in(Q_0), .out(Q_1), .en(sample_ready));
    assign valid_out = Q_1 & sample_ready;

    logic signed[WIDTH-1+ADD_BUFF:0] rma3, rma6;
    logic signed[WIDTH-1+ADD_BUFF:0] afinal, raa3, aa3; 
    logic signed[WIDTH-1+ADD_BUFF:0] ra3, ra6, ra6_d1, ra6_d2; 
    logic[ADC_BITS-1:0] y_n_o;

    function [WIDTH-1+ADD_BUFF:0] trunc_b(input [(WIDTH)*2-1:0] val_in);
        trunc_b = val_in[FRAC_BITS +: WIDTH+ADD_BUFF];
    endfunction

    function [WIDTH-1+ADD_BUFF:0] trunc_a(input [(WIDTH+ADD_BUFF)*2-1:0] val_in);
        trunc_a = val_in[FRAC_BITS +: WIDTH+ADD_BUFF];
    endfunction

    always_ff@(posedge clk) begin
        if(rst) begin
            rx_n <= '0;
            rmb0 <= '0;
            rmb1 <= '0;
            rmb2 <= '0;
            rmb3 <= '0;
            rmb4 <= '0;
            rmb5 <= '0;
            rmb6 <= '0;
            rcb6 <= '0;

            rab1  <= '0;
            rab2 <= '0;
            rab3 <= '0;
            rab4 <= '0;
            rab5 <= '0;
            ra3 <= '0;
            ra6_d1 <= '0;
            ra6_d2 <= '0;
            ra6 <= '0;
            rma3 <= '0;
            rma6 <= '0;
            raa3 <= '0;
            y_n <= '0;

        end else if(sample_ready) begin
            rx_n <= {{WHOLE_BITS-ADC_BITS{x_adc[ADC_BITS-1]}},{x_adc[ADC_BITS-1:0]},{FRAC_BITS{1'b0}}};
            rmb0 <= trunc_b(signed'(rx_n) * signed'(b0));
            rmb1 <= trunc_b(signed'(rx_n) * signed'(b1));
            rmb2 <= trunc_b(signed'(rx_n) * signed'(b2));
            rmb3 <= trunc_b(signed'(rx_n) * signed'(b3));
            rmb4 <= trunc_b(signed'(rx_n) * signed'(b4));
            rmb5 <= trunc_b(signed'(rx_n) * signed'(b5));
            rmb6 <= trunc_b(signed'(rx_n) * signed'(b6));
            rcb6 <= rmb6;

            ab0   = rab1 + rmb0;
            rab1 <= rab2 + rmb1;
            rab2 <= rab3 + rmb2;
            rab3 <= rab4 + rmb3;
            rab4 <= rab5 + rmb4;
            rab5 <= rcb6 + rmb5;
            
            afinal = ab0 + raa3;
            ra3 <= afinal;
            ra6_d1 <= ra3;
            ra6_d2 <= ra6_d1;
            ra6 <= ra6_d2;

            rma3 <= trunc_a(a_c3_extended * ra3); //multiplier still takes too long
            rma6 <= trunc_a(a_c6_extended * ra6); //multiplier takes too long

            raa3 <= rma6 + rma3;
            y_n_o = ($signed(afinal[FRAC_BITS +: WHOLE_BITS+ADD_BUFF]) > $signed({{WHOLE_BITS+ADD_BUFF-ADC_BITS+1{1'b0}}, {ADC_BITS-1{1'b1}}})) ? {1'b0, {ADC_BITS-1{1'b1}}} :
                    ($signed(afinal[FRAC_BITS +: WHOLE_BITS+ADD_BUFF]) < $signed({{WHOLE_BITS+ADD_BUFF-ADC_BITS+1{1'b1}}, {ADC_BITS-1{1'b0}}})) ? {1'b1, {ADC_BITS-1{1'b0}}} :
                    afinal[FRAC_BITS +: ADC_BITS];
            y_n <= y_n_o;
        end
    end
endmodule