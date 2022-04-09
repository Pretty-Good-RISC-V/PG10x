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
    RWire#(RVGPRIndex) executionDestination <- mkRWire;
    RWire#(Word) executionResult <- mkRWire;

    // loadDestination is a register because it needs to hold onto the
    // destination register until the load completes (which may be many cycles)
    Reg#(Maybe#(RVGPRIndex)) loadDestination <- mkReg(tagged Invalid);

    // loadResult is a wire since it will be written once the load completes
    RWire#(Word) loadResult <- mkRWire;

    method ActionValue#(BypassResult) check(Maybe#(RVGPRIndex) instructionRS1, Maybe#(RVGPRIndex) instructionRS2);
        let bypassResult = BypassResult {
            stallRequired: False,
            rs1Value: tagged Invalid,
            rs2Value: tagged Invalid
        };

        if (executionDestination.wget() matches tagged Valid .rd) begin
            let rdValueResult = executionResult.wget();
            dynamicAssert(isValid(rdValueResult), "BypassController - execution result expected to be valid if execution destination exists");
            let rdValue = unJust(rdValueResult);

            // Check if either RS1 or RS2 are driven from RD
            if (instructionRS1 matches tagged Valid .rs1 &&& rs1 == rd) begin
                bypassResult.rs1Value = tagged Valid rdValue;
            end else if (instructionRS2 matches tagged Valid .rs2 &&& rs2 == rd) begin
                bypassResult.rs2Value = tagged Valid rdValue;
            end
        end

        return bypassResult;
    endmethod

    interface Put putExecutionDestination = toPut(asIfc(executionDestination));
    interface Put putExecutionResult = toPut(asIfc(executionResult));

    interface Put putLoadDestination;
        method Action put(RVGPRIndex gprIndex);
            loadDestination <= tagged Valid gprIndex;
        endmethod
    endinterface

    interface Put putLoadResult;
        method Action put(Word result);
            loadResult.wset(result);
            loadDestination <= tagged Invalid;
        endmethod
    endinterface
endmodule
