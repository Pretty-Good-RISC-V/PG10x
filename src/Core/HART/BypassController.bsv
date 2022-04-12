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

    interface Put#(RVGPRIndex) putLoadDestination;
    interface Put#(Word)       putLoadResult;
endinterface

module mkBypassController(BypassController);
    Reg#(RVGPRIndex) executionDestination[2] <- mkCReg(2, 0);
    Reg#(Word) executionResult[2] <- mkCReg(2, 0);

    Reg#(RVGPRIndex) loadDestination[2] <- mkCReg(2, 0);
    Reg#(Word) loadResult[2] <- mkCReg(2, 0);

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

        $display("bypass - loadDestination: ", fshow(loadDestination[1]));
        $display("bypass - loadResult     : ", fshow(loadResult[1]));

        // Check if either RS1 or RS2 are driven from RD
        if (instructionRS1 matches tagged Valid .rs1 &&& rs1 == executionDestination[1]) begin
            bypassResult.rs1Value = tagged Valid (rs1 == 0 ? 0 : executionResult[1]);
        end 
        
        if (instructionRS2 matches tagged Valid .rs2 &&& rs2 == executionDestination[1]) begin
            bypassResult.rs2Value = tagged Valid (rs2 == 0 ? 0 : executionResult[1]);
        end

        // !todo - missing load handling

        return bypassResult;
    endmethod

    interface Put putExecutionDestination = toPut(asIfc(executionDestination[0]));
    interface Put putExecutionResult = toPut(asIfc(executionResult[0]));

    interface Put putLoadDestination = toPut(asIfc(loadDestination[0]));
    interface Put putLoadResult = toPut(asIfc(loadResult[0]));
endmodule
