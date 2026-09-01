module lbist_controller #(
    parameter TEST_CYCLES = 64,
    parameter SIGNATURE_WIDTH = 17,
    parameter INDEX_WIDTH = 4,
    parameter COUNT_WIDTH = 7,
    parameter [SIGNATURE_WIDTH-1:0] GOLDEN_SIGNATURE = 17'h1338d
) (
    input  clk,
    input  rst,
    input  en,
    input  start,
    input  [SIGNATURE_WIDTH-1:0] signature,
    input  [SIGNATURE_WIDTH-1:0] diag_difference,
    output init,
    output step,
    output lbist_active,
    output diag_active,
    output diag_pattern,
    output reg busy,
    output reg done,
    output reg pass,
    output reg fault_detected,
    output reg repair_enable,
    output reg repair_success,
    output reg fault_type,
    output reg [INDEX_WIDTH-1:0] repair_index,
    output reg [SIGNATURE_WIDTH-1:0] fault_signature,
    output reg [COUNT_WIDTH-1:0] cycle_count,
    output [2:0] state_code
);

    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] RUN_INITIAL   = 3'd1;
    localparam [2:0] CHECK_INITIAL = 3'd2;
    localparam [2:0] DIAG_SA1      = 3'd3;
    localparam [2:0] DIAG_SA0      = 3'd4;
    localparam [2:0] INIT_REPAIR   = 3'd5;
    localparam [2:0] RUN_REPAIR    = 3'd6;
    localparam [2:0] CHECK_REPAIR  = 3'd7;

    reg [2:0] state;

    function [INDEX_WIDTH-1:0] decode_index;
        input [SIGNATURE_WIDTH-1:0] difference;
        integer bit_index;
        reg found;
        begin
            decode_index = {INDEX_WIDTH{1'b0}};
            found = 1'b0;
            for (bit_index = 1; bit_index < SIGNATURE_WIDTH;
                 bit_index = bit_index + 1) begin
                if (!found && difference[bit_index]) begin
                    decode_index = bit_index - 1;
                    found = 1'b1;
                end
            end
        end
    endfunction

    assign init = en && (((state == IDLE) && start) ||
                         (state == INIT_REPAIR));
    assign step = en && ((state == RUN_INITIAL) ||
                         (state == RUN_REPAIR));
    assign lbist_active = (state == RUN_INITIAL) ||
                          (state == CHECK_INITIAL) ||
                          (state == RUN_REPAIR) ||
                          (state == CHECK_REPAIR);
    assign diag_active = (state == DIAG_SA1) || (state == DIAG_SA0);
    assign diag_pattern = (state == DIAG_SA0);
    assign state_code = state;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            pass <= 1'b0;
            fault_detected <= 1'b0;
            repair_enable <= 1'b0;
            repair_success <= 1'b0;
            fault_type <= 1'b0;
            repair_index <= {INDEX_WIDTH{1'b0}};
            fault_signature <= {SIGNATURE_WIDTH{1'b0}};
            cycle_count <= {COUNT_WIDTH{1'b0}};
        end else begin
            done <= 1'b0;
            if (en) begin
                case (state)
                    IDLE: begin
                        busy <= 1'b0;
                        if (start) begin
                            state <= RUN_INITIAL;
                            busy <= 1'b1;
                            pass <= 1'b0;
                            fault_detected <= 1'b0;
                            repair_enable <= 1'b0;
                            repair_success <= 1'b0;
                            fault_type <= 1'b0;
                            fault_signature <= {SIGNATURE_WIDTH{1'b0}};
                            cycle_count <= {COUNT_WIDTH{1'b0}};
                        end
                    end
                    RUN_INITIAL: begin
                        cycle_count <= cycle_count + 1'b1;
                        if (cycle_count == TEST_CYCLES - 1)
                            state <= CHECK_INITIAL;
                    end
                    CHECK_INITIAL: begin
                        if (signature == GOLDEN_SIGNATURE) begin
                            state <= IDLE;
                            busy <= 1'b0;
                            done <= 1'b1;
                            pass <= 1'b1;
                        end else begin
                            state <= DIAG_SA1;
                            fault_detected <= 1'b1;
                            fault_signature <= signature;
                        end
                    end
                    DIAG_SA1: begin
                        if (|diag_difference) begin
                            state <= INIT_REPAIR;
                            fault_type <= 1'b1;
                            repair_index <= decode_index(diag_difference);
                            repair_enable <= 1'b1;
                        end else begin
                            state <= DIAG_SA0;
                        end
                    end
                    DIAG_SA0: begin
                        if (|diag_difference) begin
                            state <= INIT_REPAIR;
                            fault_type <= 1'b0;
                            repair_index <= decode_index(diag_difference);
                            repair_enable <= 1'b1;
                        end else begin
                            state <= IDLE;
                            busy <= 1'b0;
                            done <= 1'b1;
                            pass <= 1'b0;
                            repair_success <= 1'b0;
                        end
                    end
                    INIT_REPAIR: begin
                        state <= RUN_REPAIR;
                        cycle_count <= {COUNT_WIDTH{1'b0}};
                    end
                    RUN_REPAIR: begin
                        cycle_count <= cycle_count + 1'b1;
                        if (cycle_count == TEST_CYCLES - 1)
                            state <= CHECK_REPAIR;
                    end
                    CHECK_REPAIR: begin
                        state <= IDLE;
                        busy <= 1'b0;
                        done <= 1'b1;
                        pass <= (signature == GOLDEN_SIGNATURE);
                        repair_success <= (signature == GOLDEN_SIGNATURE);
                    end
                    // VCS coverage off
                    default: begin
                        state <= IDLE;
                        busy <= 1'b0;
                    end
                    // VCS coverage on
                endcase
            end
        end
    end

endmodule
