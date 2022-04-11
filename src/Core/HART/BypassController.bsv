import PGTypes::*;
import GPRFile::*;

import Assert::*;
import GetPut::*;

typedef struct {
    Bool stallRequired;
    Maybe#(Word) rs1Value;
    Maybe#(Word) rs2Value;
} BypassResult deriving(Bits, Eq);

interface BypassController;
    method ActionValue#(BypassResult) check(Maybe#(RVGPRIndex) rs1, Maybe#(RVGPRIndex) rs2);

    interface Put#(RVGPRIndex) putExecutionDestination;
    interface Put#(Word)       putExecutionResult;

    interface Put#(Maybe#(RVGPRIndex)) putLoadDestination;
    interface Put#(Maybe#(Word))       putLoadResult;
endinterface

module mkBypassController(BypassController);
    Reg#(RVGPRIndex) executionDestination[2] <- mkCReg(2, 0);
    Reg#(Word) executionResult[2] <- mkCReg(2, 0);

    Reg#(Maybe#(RVGPRIndex)) loadDestination[2] <- mkCReg(2, tagged Invalid);
    Reg#(Maybe#(Word)) loadResult[2] <- mkCReg(2, tagged Invalid);

    method ActionValue#(BypassResult) check(Maybe#(RVGPRIndex) instructionRS1, Maybe#(RVGPRIndex) instructionRS2);
        let bypassResult = BypassResult {
            stallRequired: False,
            rs1Value: tagged Invalid,
            rs2Value: tagged Invalid
        };

        $display("bypass - RS1: ", fshow(instructionRS1));
        $display("bypass - RS2: ", fshow(instructionRS2));
        $display("bypass - executionDestination: ", fshow(executionDestination[1]));
        $display("bypass - executionResult     : ", fshow(executionResult[1]));

        let rd = executionDestination[1];
        let rdValue = executionResult[1];

        // Check if either RS1 or RS2 are driven from RD
        if (instructionRS1 matches tagged Valid .rs1 &&& rs1 == rd) begin
            bypassResult.rs1Value = tagged Valid rdValue;
        end else if (instructionRS2 matches tagged Valid .rs2 &&& rs2 == rd) begin
            bypassResult.rs2Value = tagged Valid rdValue;
        end

        // !todo - missing load handling

        return bypassResult;
    endmethod

    interface Put putExecutionDestination = toPut(asIfc(executionDestination[0]));
    interface Put putExecutionResult = toPut(asIfc(executionResult[0]));

    interface Put putLoadDestination = toPut(asIfc(loadDestination[0]));
    interface Put putLoadResult = toPut(asIfc(loadResult[0]));

endmodule
