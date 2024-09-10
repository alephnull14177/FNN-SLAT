module mult #(
    parameter WIDTH
)
(
    input logic signed[WIDTH-1:0] in0, in1,
    output logic signed[WIDTH*2-1:0] out
);
    assign out = signed'(in0) * signed'(in1);

endmodule