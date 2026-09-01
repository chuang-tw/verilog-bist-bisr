module ripple_carry_adder #(
    parameter WIDTH = 16,
    parameter INDEX_WIDTH = 4
) (
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    input  cin,
    input  fault_enable,
    input  fault_value,
    input  [INDEX_WIDTH-1:0] fault_select,
    input  repair_enable,
    input  [INDEX_WIDTH-1:0] repair_select,
    output [WIDTH-1:0] sum,
    output cout
);

    wire [WIDTH:0] carry;
    wire [WIDTH-1:0] main_sum;
    wire [WIDTH-1:0] main_carry;
    wire spare_sum;
    wire spare_cout;

    assign carry[0] = cin;
    assign cout = carry[WIDTH];

    full_adder u_spare_fa (
        .a(a[repair_select]),
        .b(b[repair_select]),
        .cin(carry[repair_select]),
        .sum(spare_sum),
        .cout(spare_cout)
    );

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : gen_fa
            wire selected_fault;
            wire selected_repair;
            wire faulty_carry;

            full_adder u_main_fa (
                .a(a[i]),
                .b(b[i]),
                .cin(carry[i]),
                .sum(main_sum[i]),
                .cout(main_carry[i])
            );

            assign selected_fault = fault_enable && (fault_select == i);
            assign selected_repair = repair_enable && (repair_select == i);
            assign faulty_carry = selected_fault ? fault_value : main_carry[i];
            assign sum[i] = selected_repair ? spare_sum : main_sum[i];
            assign carry[i+1] = selected_repair ? spare_cout : faulty_carry;
        end
    endgenerate

endmodule
