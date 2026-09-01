`timescale 1ns/1ps

module TESTINGHW11TB;

    localparam [16:0] GOLDEN_SIGNATURE = 17'h1338d;
    localparam [16:0] FA13_SA1_SIGNATURE = 17'h1dd39;

    reg [15:0] X;
    reg [15:0] Y;
    reg [3:0] Fault_select;
    reg Cin;
    reg Clk;
    reg Rst;
    reg Test;
    reg En;
    reg en_decoder;
    reg fault_value;
    wire [15:0] Sum;
    wire Cout;
    wire PF;
    wire Done;
    wire Busy;
    wire Fault_detected;
    wire Repair_enable;
    wire Repair_success;
    wire Fault_type;
    wire [3:0] Faulty_FA;
    wire [16:0] Signature;
    wire [16:0] Signature_diff;
    wire [16:0] Fault_signature;
    wire [32:0] Pattern;
    wire [6:0] Cycle_count;
    wire [2:0] State;
    reg [16:0] expected_normal;
    integer error_count;
    integer done_count;
    integer fault_index;
    integer fault_kind;

    Top_Module uut (
        .X(X),
        .Y(Y),
        .Cin(Cin),
        .Clk(Clk),
        .Rst(Rst),
        .Test(Test),
        .En(En),
        .en_decoder(en_decoder),
        .fault_value(fault_value),
        .Fault_select(Fault_select),
        .Sum(Sum),
        .Cout(Cout),
        .PF(PF),
        .Done(Done),
        .Busy(Busy),
        .Fault_detected(Fault_detected),
        .Repair_enable(Repair_enable),
        .Repair_success(Repair_success),
        .Fault_type(Fault_type),
        .Faulty_FA(Faulty_FA),
        .Signature(Signature),
        .Signature_diff(Signature_diff),
        .Fault_signature(Fault_signature),
        .Pattern(Pattern),
        .Cycle_count(Cycle_count),
        .State(State)
    );

    always #10 Clk = ~Clk;

    always @(posedge Done)
        done_count = done_count + 1;

    task automatic check_normal;
        input [15:0] test_x;
        input [15:0] test_y;
        input test_cin;
        begin
            X = test_x;
            Y = test_y;
            Cin = test_cin;
            expected_normal = {1'b0, test_x} + {1'b0, test_y} + test_cin;
            #1;
            if ({Cout, Sum} !== expected_normal) begin
                error_count = error_count + 1;
                $display("ERROR normal X=%h Y=%h Cin=%b response=%05h expected=%05h",
                         X, Y, Cin, {Cout, Sum}, expected_normal);
            end
        end
    endtask

    task automatic pulse_start;
        begin
            Test = 1'b1;
            @(posedge Clk);
            #1 Test = 1'b0;
        end
    endtask

    task automatic run_no_fault;
        begin
            en_decoder = 1'b0;
            pulse_start;

            wait (Cycle_count == 7'd5);
            @(negedge Clk);
            En = 1'b0;
            repeat (2) @(posedge Clk);
            #1;
            if (Cycle_count !== 7'd5) begin
                error_count = error_count + 1;
                $display("ERROR En pause changed cycle_count=%0d", Cycle_count);
            end
            @(negedge Clk);
            En = 1'b1;

            wait (Done === 1'b1);
            #1;
            if ((PF !== 1'b1) || (Signature !== GOLDEN_SIGNATURE) ||
                (Signature_diff !== 17'b0) || Fault_detected ||
                Repair_enable || Repair_success ||
                (Cycle_count !== 7'd64)) begin
                error_count = error_count + 1;
                $display("ERROR no-fault sig=%05h diff=%05h PF=%b detected=%b repair=%b",
                         Signature, Signature_diff, PF,
                         Fault_detected, Repair_success);
            end else begin
                $display("PASS no-fault LBIST signature=%05h", Signature);
            end
        end
    endtask

    task automatic run_fault;
        input integer selected_fa;
        input integer stuck_value;
        begin
            en_decoder = 1'b1;
            fault_value = stuck_value;
            Fault_select = selected_fa;
            X = 16'h0001 << selected_fa;
            Y = ~X;
            Cin = stuck_value;
            expected_normal = {1'b0, X} + {1'b0, Y} + Cin;

            pulse_start;
            wait (Done === 1'b1);
            #1;

            if ((PF !== 1'b1) || !Fault_detected || !Repair_enable ||
                !Repair_success || (Faulty_FA !== selected_fa[3:0]) ||
                (Fault_type !== stuck_value[0]) ||
                (Fault_signature === GOLDEN_SIGNATURE) ||
                (Signature !== GOLDEN_SIGNATURE) ||
                (Signature_diff !== 17'b0) ||
                (Cycle_count !== 7'd64)) begin
                error_count = error_count + 1;
                $display("ERROR FA%0d SA%0d PF=%b detected=%b repaired=%b diagnosed=%0d type=%b fault_sig=%05h final_sig=%05h",
                         selected_fa + 1, stuck_value, PF, Fault_detected,
                         Repair_success, Faulty_FA, Fault_type,
                         Fault_signature, Signature);
            end else if ({Cout, Sum} !== expected_normal) begin
                error_count = error_count + 1;
                $display("ERROR repaired normal FA%0d SA%0d response=%05h expected=%05h",
                         selected_fa + 1, stuck_value,
                         {Cout, Sum}, expected_normal);
            end else begin
                $display("PASS FA%0d SA%0d diagnosed=%0d repaired signature=%05h",
                         selected_fa + 1, stuck_value,
                         Faulty_FA, Signature);
            end

            if ((selected_fa == 12) && (stuck_value == 1) &&
                (Fault_signature !== FA13_SA1_SIGNATURE)) begin
                error_count = error_count + 1;
                $display("ERROR FA13 SA1 signature=%05h expected=%05h",
                         Fault_signature, FA13_SA1_SIGNATURE);
            end
        end
    endtask

    task automatic run_unlocatable_fault;
        begin
            en_decoder = 1'b1;
            fault_value = 1'b0;
            Fault_select = 4'd0;
            pulse_start;
            wait (State == 3'd4);
            force uut.u_controller.diag_difference = 17'b0;
            @(posedge Clk);
            #1;
            release uut.u_controller.diag_difference;
            if ((PF !== 1'b0) || !Fault_detected || Repair_enable ||
                Repair_success || (State !== 3'd0)) begin
                error_count = error_count + 1;
                $display("ERROR unlocatable fault handling");
            end
        end
    endtask

    task automatic run_forced_repair_failure;
        begin
            en_decoder = 1'b1;
            fault_value = 1'b1;
            Fault_select = 4'd0;
            pulse_start;
            wait (State == 3'd6);
            force uut.u_controller.repair_index = 4'd1;
            wait (Done === 1'b1);
            #1;
            release uut.u_controller.repair_index;
            if ((PF !== 1'b0) || !Fault_detected || !Repair_enable ||
                Repair_success || (Signature === GOLDEN_SIGNATURE)) begin
                error_count = error_count + 1;
                $display("ERROR forced repair failure handling");
            end
        end
    endtask

    task automatic abort_at_state;
        input [2:0] target_state;
        input stuck_value;
        begin
            en_decoder = (target_state == 3'd1) ? 1'b0 : 1'b1;
            fault_value = stuck_value;
            Fault_select = 4'd0;
            pulse_start;
            wait (State == target_state);
            @(negedge Clk);
            Rst = 1'b1;
            @(posedge Clk);
            #1;
            if ((State !== 3'd0) || Busy || Repair_enable) begin
                error_count = error_count + 1;
                $display("ERROR reset from state %0d", target_state);
            end
            @(negedge Clk);
            Rst = 1'b0;
        end
    endtask

    task automatic disabled_start_check;
        begin
            @(negedge Clk);
            En = 1'b0;
            Test = 1'b1;
            @(posedge Clk);
            #1;
            if (Busy || (State !== 3'd0)) begin
                error_count = error_count + 1;
                $display("ERROR LBIST started while En=0");
            end
            @(negedge Clk);
            Test = 1'b0;
            En = 1'b1;
        end
    endtask

    initial begin
        $timeformat(-9, 0, " ns", 8);
        Clk = 1'b0;
        Rst = 1'b1;
        Test = 1'b0;
        En = 1'b1;
        en_decoder = 1'b0;
        fault_value = 1'b1;
        Fault_select = 4'd0;
        X = 16'h0000;
        Y = 16'h0000;
        Cin = 1'b0;
        expected_normal = 17'b0;
        error_count = 0;
        done_count = 0;

        #100;
        Rst = 1'b0;
        check_normal(16'h0000, 16'h0000, 1'b0);
        check_normal(16'hffff, 16'hffff, 1'b1);
        check_normal(16'haaaa, 16'h5555, 1'b0);
        check_normal(16'h1234, 16'h5678, 1'b1);

        @(negedge Clk);
        run_no_fault;

        for (fault_kind = 0; fault_kind < 2;
             fault_kind = fault_kind + 1) begin
            for (fault_index = 0; fault_index < 16;
                 fault_index = fault_index + 1) begin
                @(negedge Clk);
                run_fault(fault_index, fault_kind);
            end
        end

        @(negedge Clk);
        run_unlocatable_fault;
        @(negedge Clk);
        run_forced_repair_failure;

        @(negedge Clk);
        abort_at_state(3'd1, 1'b0);
        @(negedge Clk);
        abort_at_state(3'd3, 1'b1);
        @(negedge Clk);
        abort_at_state(3'd4, 1'b0);
        @(negedge Clk);
        abort_at_state(3'd5, 1'b1);
        @(negedge Clk);
        abort_at_state(3'd6, 1'b1);
        disabled_start_check;

        en_decoder = 1'b0;
        for (fault_index = 0; fault_index < 16;
             fault_index = fault_index + 1) begin
            Fault_select = fault_index;
            #1;
        end

        en_decoder = 1'b0;
        check_normal(16'h1234, 16'h5678, 1'b1);

        if (done_count !== 35) begin
            error_count = error_count + 1;
            $display("ERROR expected 35 DONE pulses, observed %0d",
                     done_count);
        end

        if (error_count == 0)
            $display("TEST PASS: 32/32 faults detected, diagnosed and repaired");
        else
            $display("TEST FAIL: %0d checks failed", error_count);

        #20 $finish;
    end

endmodule
