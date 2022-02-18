import PGTypes::*;
import BranchPredictor::*;

typedef struct {
    Bit#(7) opcode;
    Bit#(13) offset;
    Bool expectedBranchTaken;
} BranchPredictorTest deriving(Bits, Eq, FShow);

(* synthesize *)
module mkBranchPredictor_tb(Empty);
    Reg#(Word) testNumber <- mkReg(0);

    BranchPredictor branchPredictor <- mkBackwardBranchTakenPredictor();

    Integer arraySize = 4;
    BranchPredictorTest tests[arraySize] = {
        // Non branches should always predict not taken
        BranchPredictorTest { opcode: 7'b0000000, offset: -'h20, expectedBranchTaken: False },
        BranchPredictorTest { opcode: 7'b0000000, offset: 'h20, expectedBranchTaken: False },

        // Branch instructions with negative and positive offsets.  Negative should be taken.
        BranchPredictorTest { opcode: 7'b1100011, offset: -'h20, expectedBranchTaken: True },
        BranchPredictorTest { opcode: 7'b1100011, offset: 'h20, expectedBranchTaken: False }
    };

    rule check;
        let test = tests[testNumber];

        Word32 encodedInstruction = {
            test.offset[12],
            test.offset[10:5],
            5'b0,   // RS2
            5'b0,   // RS1,
            3'b0,   // func3 (branch operator)
            test.offset[4:1],
            test.offset[11],
            test.opcode
        };

        Word currentProgramCounter = 'h8000;
        let predictedNextProgramCounter = branchPredictor.predictNextProgramCounter(currentProgramCounter, encodedInstruction);
        let branchTaken = (predictedNextProgramCounter != currentProgramCounter + 4);
        if (branchTaken != test.expectedBranchTaken) begin
            $display("FAILED test #%0d - unexpected predictiont: ", testNumber, fshow(test));
            $fatal();
        end

        if (testNumber + 1 >= fromInteger(arraySize)) begin
            $display("    PASS");
            $finish();
        end

        testNumber <= testNumber + 1;
    endrule
endmodule
