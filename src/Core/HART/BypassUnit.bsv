import PGTypes::*;
import DecodedInstruction::*;
import GPRFile::*;

import GetPut::*;

interface GPRBypassUnit;
    method ActionValue#(Tuple2#(Bool, DecodedInstruction)) processBypass(DecodedInstruction decodedInstruction);

    interface Put#(RVGPRIndex) putGPRBypassIndex;
    interface Put#(Word) putGPRBypassValue;
endinterface

module mkGPRBypassUnit#(
    GPRFile gprFile
)(GPRBypassUnit);
    RWire#(RVGPRIndex) gprBypassIndex <- mkRWire; // CReg(2, tagged Invalid);
    RWire#(Word) gprBypassValue <- mkRWire;

    method ActionValue#(Tuple2#(Bool, DecodedInstruction)) processBypass(DecodedInstruction decodedInstruction);
        Bool gprUsed = False;
        Bool stallWaitingForOperands = False;
        $display("RS1: ", fshow(decodedInstruction.rs1));
        $display("RS2: ", fshow(decodedInstruction.rs2));

//        $display("BYPASS: gprBypassIndex: ", fshow(gprBypassIndex));
        if (gprBypassValue.wget matches tagged Valid .value) begin
            $display("BYPASS: gprBypassValue: $%0x", value);
        end else begin
            $display("BYPASS: gprBypassValue: tagged Invalid");
        end

        if (decodedInstruction.rs1 matches tagged Valid .rs1 &&& gprBypassIndex.wget() matches tagged Valid .bypassrd &&& bypassrd == rs1) begin
            if (gprBypassValue.wget matches tagged Valid .rs1value) begin
                decodedInstruction.rs1Value = rs1value;
//                gprBypassIndex[1] <= tagged Invalid;
//                gprBypassValue[1] <= tagged Invalid;
                gprUsed = True;
                $display("BYPASS: found match for RS1.");
            end else begin
                stallWaitingForOperands = True;
            end
        end else begin
            decodedInstruction.rs1Value = gprFile.read1(fromMaybe(0, decodedInstruction.rs1));
        end

        if (!gprUsed) begin
            if (decodedInstruction.rs2 matches tagged Valid .rs2 &&& gprBypassIndex.wget() matches tagged Valid .bypassrd &&& bypassrd == rs2) begin
                if (gprBypassValue.wget matches tagged Valid .rs2value) begin
                    decodedInstruction.rs2Value = rs2value;
//                    gprBypassIndex[1] <= tagged Invalid;
//                    gprBypassValue[1] <= tagged Invalid;
                    $display("BYPASS: found match for RS2.");
                end else begin
                    stallWaitingForOperands = True;
                end
            end else begin
                decodedInstruction.rs2Value = gprFile.read2(fromMaybe(0, decodedInstruction.rs2));
            end
        end
        
        return tuple2(stallWaitingForOperands, decodedInstruction);
    endmethod

    interface Put putGPRBypassIndex = toPut(asIfc(gprBypassIndex));
    interface Put putGPRBypassValue = toPut(asIfc(gprBypassValue));
endmodule
