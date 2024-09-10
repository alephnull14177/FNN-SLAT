module adder #(
    parameter WIDTH
)
(
    input logic signed[WIDTH-1:0] in0, in1,
    output logic signed[WIDTH-1:0] out
);

    assign out = in0 + in1;

endmodule