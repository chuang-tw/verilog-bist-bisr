module lfsr_prpg #(
    parameter WIDTH = 33,
    parameter [WIDTH-1:0] SEED = 33'h1ace12345,
    parameter TAP_A = 32,
    parameter TAP_B = 19
) (
    input  clk,
    input  rst,
    input  load,
    input  enable,
    output reg [WIDTH-1:0] state
);

    wire feedback;

    assign feedback = state[TAP_A] ^ state[TAP_B];

    always @(posedge clk) begin
        if (rst || load)
            state <= SEED;
        else if (enable)
            state <= {state[WIDTH-2:0], feedback};
    end

endmodule
