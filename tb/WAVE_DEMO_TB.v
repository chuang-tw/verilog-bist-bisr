`timescale 1ns/1ps

module WAVE_DEMO_TB;

    localparam [16:0] GOLDEN_SIGNATURE = 17'h1338d;
    localparam [16:0] FA13_SA1_SIGNATURE = 17'h1dd39;
    localparam [1:0] NORMAL_MODE = 2'd0;
    localparam [1:0] HEALTHY_BIST = 2'd1;
    localparam [1:0] FAULT_DETECT = 2'd2;
    localparam [1:0] REPAIR_VERIFY = 2'd3;

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
    reg [1:0] Demo_phase;
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
    integer error_count;

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

    task pulse_start;
        begin
            Test = 1'b1;
            @(posedge Clk);
            #1 Test = 1'b0;
        end
    endtask

    initial begin
        $fsdbDumpfile("bist_wave.fsdb");
        $fsdbDumpvars(0, WAVE_DEMO_TB);
        $dumpfile("bist_wave.vcd");
        $dumpvars(0, WAVE_DEMO_TB);
    end

    initial begin
        $timeformat(-9, 0, " ns", 8);
        Clk = 1'b0;
        Rst = 1'b1;
        Test = 1'b0;
        En = 1'b1;
        en_decoder = 1'b0;
        fault_value = 1'b0;
        Fault_select = 4'd0;
        X = 16'h0000;
        Y = 16'h0000;
        Cin = 1'b0;
        Demo_phase = NORMAL_MODE;
        error_count = 0;

        #100;
        Rst = 1'b0;
        X = 16'h1234;
        Y = 16'h5678;
        Cin = 1'b1;
        #40;
        if ({Cout, Sum} !== 17'h068ad) begin
            error_count = error_count + 1;
            $display("ERROR normal response=%05h expected=068ad", {Cout, Sum});
        end
        $display("[WAVE] NORMAL_MODE  start=100 ns end=%0t response=%05h",
                 $time, {Cout, Sum});

        @(negedge Clk);
        Demo_phase = HEALTHY_BIST;
        en_decoder = 1'b0;
        $display("[WAVE] HEALTHY_BIST start=%0t", $time);
        pulse_start;
        wait (Done === 1'b1);
        #1;
        if ((PF !== 1'b1) || (Signature !== GOLDEN_SIGNATURE) ||
            Fault_detected || Repair_enable) begin
            error_count = error_count + 1;
            $display("ERROR healthy BIST signature=%05h PF=%b", Signature, PF);
        end
        $display("[WAVE] HEALTHY_BIST done=%0t signature=%05h PF=%b",
                 $time, Signature, PF);

        #39;
        @(negedge Clk);
        Demo_phase = FAULT_DETECT;
        en_decoder = 1'b1;
        fault_value = 1'b1;
        Fault_select = 4'd12;
        X = 16'h1234;
        Y = 16'h5678;
        Cin = 1'b1;
        $display("[WAVE] FAULT_DETECT start=%0t FA13 stuck-at-1", $time);
        pulse_start;

        wait (Fault_detected === 1'b1);
        #1;
        if (Fault_signature !== FA13_SA1_SIGNATURE) begin
            error_count = error_count + 1;
            $display("ERROR fault signature=%05h expected=%05h",
                     Fault_signature, FA13_SA1_SIGNATURE);
        end
        $display("[WAVE] FAULT_FOUND  time=%0t fault_signature=%05h",
                 $time, Fault_signature);

        wait (Repair_enable === 1'b1);
        #1 Demo_phase = REPAIR_VERIFY;
        if ((Faulty_FA !== 4'd12) || (Fault_type !== 1'b1)) begin
            error_count = error_count + 1;
            $display("ERROR diagnosis FA=%0d type=%b", Faulty_FA, Fault_type);
        end
        $display("[WAVE] REPAIR_VERIFY start=%0t faulty_FA=%0d type=SA%0d",
                 $time, Faulty_FA + 1, Fault_type);

        wait (Done === 1'b1);
        #1;
        X = 16'h1234;
        Y = 16'h5678;
        Cin = 1'b1;
        #20;
        if ((PF !== 1'b1) || !Repair_success ||
            (Signature !== GOLDEN_SIGNATURE) ||
            ({Cout, Sum} !== 17'h068ad)) begin
            error_count = error_count + 1;
            $display("ERROR repair PF=%b success=%b signature=%05h response=%05h",
                     PF, Repair_success, Signature, {Cout, Sum});
        end
        $display("[WAVE] REPAIR_DONE time=%0t signature=%05h response=%05h PF=%b",
                 $time, Signature, {Cout, Sum}, PF);

        if (error_count == 0)
            $display("WAVE DEMO PASS");
        else
            $display("WAVE DEMO FAIL: %0d checks failed", error_count);

        #40 $finish;
    end

endmodule
