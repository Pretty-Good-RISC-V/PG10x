import PGTypes::*;

import GPRFile::*;
import PipelineTypes::*;

import GetPut::*;

interface DecodeStage;
    interface Put#(IF_ID) putInput;
    interface Get#(ID_EX) getOutput;
endinterface

function ProgramCounter getEffectiveAddress(Word base, Word signedOffset);
    Int#(XLEN) offset = unpack(signedOffset);
    return pack(unpack(base) + offset);
endfunction

module mkDecodeStage#(GPRFile gprFile)(DecodeStage);
    Reg#(IF_ID) if_id <- mkRegU;

    interface Put putInput = toPut(asIfc(if_id));
    interface Get getOutput;
        method ActionValue#(ID_EX) get;
            let arg1 = gprFile.read1(if_id.pcommon.rawInstruction[19:15]); // RS1
            let arg2 = gprFile.read2(if_id.pcommon.rawInstruction[24:20]); // RS2
            let immediate = signExtend(if_id.pcommon.rawInstruction[31:20]);  // Immediate

            return ID_EX {
                pcommon: if_id.pcommon,
                branchTarget: getEffectiveAddress(if_id.pcommon.nextProgramCounter, immediate),
                arg1: arg1,
                arg2: arg2,
                immediate: immediate
            };
        endmethod
    endinterface
endmodule
