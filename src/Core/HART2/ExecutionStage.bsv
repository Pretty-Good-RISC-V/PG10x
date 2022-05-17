import PGTypes::*;

import ALU::*;
import PipelineTypes::*;

import GetPut::*;

interface ExecutionStage;
    interface Put#(ID_EX) putInput;
    interface Get#(EX_MEM) getOutput;

    method Bool getBranchTaken;
endinterface

function ProgramCounter getEffectiveAddress(Word base, Word signedOffset);
    Int#(XLEN) offset = unpack(signedOffset);
    return pack(unpack(base) + offset);
endfunction

(* synthesize *)
module mkExecutionStage(ExecutionStage);
    Reg#(ID_EX) id_ex <- mkRegU;
    ALU alu <- mkALU;

    let opcode = id_ex.pcommon.rawInstruction[6:0];
    let func3  = id_ex.pcommon.rawInstruction[14:12];
    let func7  = id_ex.pcommon.rawInstruction[31:25];
    
    RVALUOperator aluOperator = {1'b0, func7, func3};

    function Maybe#(Word) getALUOutput;
        return case(id_ex.pcommon.rawInstruction[6:0])
            opcode_LOAD: begin
                return tagged Valid getEffectiveAddress(id_ex.arg1, id_ex.immediate);
            end

            opcode_OP_IMM, opcode_OP: begin
                Word arg1 = id_ex.arg1;
                Word arg2 = (opcode == opcode_OP_IMM ? id_ex.immediate : id_ex.arg2);
                return alu.execute(aluOperator, arg1, arg2);
            end

            default: begin
                return tagged Invalid;
            end
        endcase;
    endfunction

    method Bool getBranchTaken;
        let branchTaken = False;
        if (opcode == opcode_BRANCH) begin
            branchTaken = case(func3)
                branch_BEQ: begin
                    return id_ex.arg1 == id_ex.arg2;
                end

                branch_BNE: begin
                    return id_ex.arg1 != id_ex.arg2;
                end

                branch_BLT: begin
                    return signedLT(id_ex.arg1, id_ex.arg2);
                end

                branch_BGE: begin
                    return signedGE(id_ex.arg1, id_ex.arg2);
                end

                branch_BLTU: begin
                    return id_ex.arg1 < id_ex.arg2;
                end

                branch_BGEU: begin
                    return id_ex.arg1 >= id_ex.arg2;
                end

                default: begin
                    False;
                end
            endcase;
        end

        return branchTaken;
    endmethod

    interface Put putInput = toPut(asIfc(id_ex));
    interface Get getOutput;
        method ActionValue#(EX_MEM) get;
            return EX_MEM {
                pcommon: id_ex.pcommon,
                aluOutput: getALUOutput,
                arg2: id_ex.arg2
            };
        endmethod
    endinterface
endmodule
