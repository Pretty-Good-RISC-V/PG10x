import PGTypes::*;

import PipelineTypes::*;

import GetPut::*;

interface MemoryStage;
    interface Put#(EX_MEM) putInput;
    interface Get#(MEM_WB) getOutput;
endinterface

(* synthesize *)
module mkMemoryStage(MemoryStage);
    Reg#(EX_MEM) ex_mem <- mkRegU;

    let opcode = ex_mem.pcommon.rawInstruction[6:0];

    interface Put putInput = toPut(asIfc(ex_mem));
    interface Get getOutput;
        method ActionValue#(MEM_WB) get;
            Maybe#(Word) writebackValue = case(opcode)
                opcode_LOAD: begin
                    // ex_mem.writebackValue = Memory[ex_mem.aluOutput]
                    return tagged Invalid;
                end

                opcode_STORE: begin
                    // Memory[ex_mem.aluOutput] = ex_mem.b
                    return tagged Invalid;  // No writeback
                end

                default: begin
                    return ex_mem.aluOutput; // May be invalid
                end
            endcase;

            return MEM_WB {
                pcommon: ex_mem.pcommon,
                writebackValue: writebackValue
            };
        endmethod
    endinterface
endmodule
