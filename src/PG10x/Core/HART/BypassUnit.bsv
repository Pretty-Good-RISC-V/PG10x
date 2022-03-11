import PGTypes::*;
import DecodedInstruction::*;
import GPRFile::*;

import GetPut::*;

typedef struct {
    RVGPRIndex rd;
    Maybe#(Word) value;
} GPRBypassValue deriving(Bits, Eq);

interface GPRBypassUnit;
    method ActionValue#(Tuple2#(Bool, DecodedInstruction)) processBypass(DecodedInstruction decodedInstruction);

    interface Put#(Maybe#(GPRBypassValue)) putGPRBypassValue;
endinterface

module mkGPRBypassUnit#(
    GPRFile gprFile
)(GPRBypassUnit);
    Reg#(Maybe#(GPRBypassValue)) gprBypassValue[2] <- mkCReg(2, tagged Invalid);

    method ActionValue#(Tuple2#(Bool, DecodedInstruction)) processBypass(DecodedInstruction decodedInstruction);
        Bool gprUsed = False;
        Bool stallWaitingForOperands = False;
        if (decodedInstruction.rs1 matches tagged Valid .rs1 &&& gprBypassValue[1] matches tagged Valid .bypass &&& bypass.rd == rs1) begin
            if (isValid(bypass.value)) begin
                decodedInstruction.rs1Value = unJust(bypass.value);
                // $display("%0d,%0d,%0d,%0x,%0d,decode,Bypassed value available for RS1: %0d (from execution)", 
                //     fetchIndex, 
                //     cycleCounter, 
                //     stageEpoch, 
                //     programCounter, 
                //     stageNumber,
                //     rs1);
                gprBypassValue[1] <= tagged Invalid;
                gprUsed = True;
            end else begin
                // $display("%0d,%0d,%0d,%0x,%0d,decode,Need to stall waiting for RS1: %0d (from execution)", 
                //     fetchIndex, 
                //     cycleCounter, 
                //     stageEpoch, 
                //     programCounter, 
                //     stageNumber,
                //     rs1);
                stallWaitingForOperands = True;
            end
        end else begin
            decodedInstruction.rs1Value = gprFile.read1(fromMaybe(0, decodedInstruction.rs1));
        end

        if (!gprUsed) begin
            if (decodedInstruction.rs2 matches tagged Valid .rs2 &&& gprBypassValue[1] matches tagged Valid .bypass &&& bypass.rd == rs2) begin
                if (isValid(bypass.value)) begin
                    decodedInstruction.rs2Value = unJust(bypass.value);
                    // $display("%0d,%0d,%0d,%0x,%0d,decode,Bypassed value available for RS2: %0d (from execution)", 
                    //     fetchIndex, 
                    //     cycleCounter, 
                    //     stageEpoch, 
                    //     programCounter, 
                    //     stageNumber,
                    //     rs2);
                    gprBypassValue[1] <= tagged Invalid;
                end else begin
                    // $display("%0d,%0d,%0d,%0x,%0d,decode,Need to stall waiting for RS2: %0d (from execution)", 
                    //     fetchIndex, 
                    //     cycleCounter, 
                    //     stageEpoch, 
                    //     programCounter, 
                    //     stageNumber,
                    //     rs2);
                    stallWaitingForOperands = True;
                end
            end else begin
                decodedInstruction.rs2Value = gprFile.read2(fromMaybe(0, decodedInstruction.rs2));
            end
        end
        
        return tuple2(stallWaitingForOperands, decodedInstruction);
    endmethod

    interface Put putGPRBypassValue = toPut(asReg(gprBypassValue[0]));
endmodule
