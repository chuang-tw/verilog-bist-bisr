module misr_compactor #(
    parameter WIDTH = 17,
    parameter [WIDTH-1:0] POLYNOMIAL = 17'h02001
) (
    input  clk,
    input  rst,
    input  load,
    input  enable,
    input  [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] signature
);

    reg [WIDTH-1:0] next_signature;

    always @(*) begin
        next_signature = {signature[WIDTH-2:0], 1'b0};
        if (signature[WIDTH-1])
            next_signature = next_signature ^ POLYNOMIAL;
        next_signature = next_signature ^ data_in;
    end

    always @(posedge clk) begin
        if (rst || load)
            signature <= {WIDTH{1'b0}};
        else if (enable)
            signature <= next_signature;
    end

endmodule
