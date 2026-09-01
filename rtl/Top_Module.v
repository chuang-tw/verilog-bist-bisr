module Top_Module #(
    parameter WIDTH = 16,
    parameter TEST_CYCLES = 64,
    parameter LFSR_WIDTH = 33,
    parameter SIGNATURE_WIDTH = 17,
    parameter INDEX_WIDTH = 4,
    parameter COUNT_WIDTH = 7,
    parameter [LFSR_WIDTH-1:0] LFSR_SEED = 33'h1ace12345,
    parameter [SIGNATURE_WIDTH-1:0] MISR_POLYNOMIAL = 17'h02001,
    parameter [SIGNATURE_WIDTH-1:0] GOLDEN_SIGNATURE = 17'h1338d
) (
    input  [WIDTH-1:0] X,
    input  [WIDTH-1:0] Y,
    input  Cin,
    input  Clk,
    input  Rst,
    input  Test,
    input  En,
    input  en_decoder,
    input  fault_value,
    input  [INDEX_WIDTH-1:0] Fault_select,
    output [WIDTH-1:0] Sum,
    output Cout,
    output PF,
    output Done,
    output Busy,
    output Fault_detected,
    output Repair_enable,
    output Repair_success,
    output Fault_type,
    output [INDEX_WIDTH-1:0] Faulty_FA,
    output [SIGNATURE_WIDTH-1:0] Signature,
    output [SIGNATURE_WIDTH-1:0] Signature_diff,
    output [SIGNATURE_WIDTH-1:0] Fault_signature,
    output [LFSR_WIDTH-1:0] Pattern,
    output [COUNT_WIDTH-1:0] Cycle_count,
    output [2:0] State
);

    reg [WIDTH-1:0] adder_x;
    reg [WIDTH-1:0] adder_y;
    reg adder_cin;
    wire [LFSR_WIDTH-1:0] lfsr_state;
    wire [SIGNATURE_WIDTH-1:0] misr_signature;
    wire [SIGNATURE_WIDTH-1:0] response;
    wire [SIGNATURE_WIDTH-1:0] diag_expected;
    wire [SIGNATURE_WIDTH-1:0] diag_difference;
    wire lbist_init;
    wire lbist_step;
    wire lbist_active;
    wire diag_active;
    wire diag_pattern;

    always @(*) begin
        adder_x = X;
        adder_y = Y;
        adder_cin = Cin;
        if (lbist_active) begin
            adder_x = lfsr_state[WIDTH-1:0];
            adder_y = lfsr_state[2*WIDTH-1:WIDTH];
            adder_cin = lfsr_state[2*WIDTH];
        end else if (diag_active) begin
            adder_x = diag_pattern ? {WIDTH{1'b1}} : {WIDTH{1'b0}};
            adder_y = diag_pattern ? {WIDTH{1'b1}} : {WIDTH{1'b0}};
            adder_cin = diag_pattern;
        end
    end

    assign response = {Cout, Sum};
    assign diag_expected = diag_pattern ?
                           {SIGNATURE_WIDTH{1'b1}} :
                           {SIGNATURE_WIDTH{1'b0}};
    assign diag_difference = response ^ diag_expected;
    assign Pattern = lfsr_state;
    assign Signature = misr_signature;
    assign Signature_diff = misr_signature ^ GOLDEN_SIGNATURE;

    ripple_carry_adder #(
        .WIDTH(WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) u_adder (
        .a(adder_x),
        .b(adder_y),
        .cin(adder_cin),
        .fault_enable(en_decoder),
        .fault_value(fault_value),
        .fault_select(Fault_select),
        .repair_enable(Repair_enable),
        .repair_select(Faulty_FA),
        .sum(Sum),
        .cout(Cout)
    );

    lfsr_prpg #(
        .WIDTH(LFSR_WIDTH),
        .SEED(LFSR_SEED),
        .TAP_A(LFSR_WIDTH-1),
        .TAP_B(19)
    ) u_prpg (
        .clk(Clk),
        .rst(Rst),
        .load(lbist_init),
        .enable(lbist_step),
        .state(lfsr_state)
    );

    misr_compactor #(
        .WIDTH(SIGNATURE_WIDTH),
        .POLYNOMIAL(MISR_POLYNOMIAL)
    ) u_misr (
        .clk(Clk),
        .rst(Rst),
        .load(lbist_init),
        .enable(lbist_step),
        .data_in(response),
        .signature(misr_signature)
    );

    lbist_controller #(
        .TEST_CYCLES(TEST_CYCLES),
        .SIGNATURE_WIDTH(SIGNATURE_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .COUNT_WIDTH(COUNT_WIDTH),
        .GOLDEN_SIGNATURE(GOLDEN_SIGNATURE)
    ) u_controller (
        .clk(Clk),
        .rst(Rst),
        .en(En),
        .start(Test),
        .signature(misr_signature),
        .diag_difference(diag_difference),
        .init(lbist_init),
        .step(lbist_step),
        .lbist_active(lbist_active),
        .diag_active(diag_active),
        .diag_pattern(diag_pattern),
        .busy(Busy),
        .done(Done),
        .pass(PF),
        .fault_detected(Fault_detected),
        .repair_enable(Repair_enable),
        .repair_success(Repair_success),
        .fault_type(Fault_type),
        .repair_index(Faulty_FA),
        .fault_signature(Fault_signature),
        .cycle_count(Cycle_count),
        .state_code(State)
    );

endmodule
