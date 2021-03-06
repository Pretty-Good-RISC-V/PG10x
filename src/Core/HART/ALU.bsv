//
// ALU
//
// This module is a Arithmetic Logic Unit (ALU) implementation for RISC-V.  It is
// reponsible for mathematical operations inside the CPU.
//
import PGTypes::*;

interface ALU;
    method Maybe#(Word) execute(RVALUOperator operator, Word operand1, Word operand2);
endinterface

(* synthesize *)
module mkALU(ALU);
    function Word setLessThanUnsigned(Word operand1, Word operand2);
        return (operand1 < operand2 ? 1 : 0);
    endfunction

    function Word setLessThan(Word operand1, Word operand2);
        Int#(XLEN) signedOperand1 = unpack(pack(operand1));
        Int#(XLEN) signedOperand2 = unpack(pack(operand2));
        return (signedOperand1 < signedOperand2 ? 1 : 0);
    endfunction

    method Maybe#(Word) execute(RVALUOperator operator, Word operand1, Word operand2);
        return case(operator)
            alu_ADD:    tagged Valid (operand1 + operand2);
            alu_SUB:    tagged Valid (operand1 - operand2);
            alu_AND:    tagged Valid (operand1 & operand2);
            alu_OR:     tagged Valid (operand1 | operand2);
            alu_XOR:    tagged Valid (operand1 ^ operand2);
            alu_SLTU:   tagged Valid setLessThanUnsigned(operand1, operand2);
            alu_SLT:    tagged Valid setLessThan(operand1, operand2);
`ifdef RV32
            alu_SLL:    tagged Valid (operand1 << operand2[4:0]);
            alu_SRA:    tagged Valid signedShiftRight(operand1, operand2[4:0]);
            alu_SRL:    tagged Valid (operand1 >> operand2[4:0]);
`elsif RV64
            alu_SLL:    tagged Valid (operand1 << operand2[5:0]);
            alu_SRA:    tagged Valid signedShiftRight(operand1, operand2[5:0]);
            alu_SRL:    tagged Valid (operand1 >> operand2[5:0]);

            alu_ADD32: begin
                let result = operand1[31:0] + operand2[31:0];
                return tagged Valid signExtend(result[31:0]);
            end
            alu_SUB32: begin
                let result = (operand1[31:0] - operand2[31:0]);
                return tagged Valid signExtend(result[31:0]);
            end
            alu_SLL32: begin
                let result = (operand1[31:0] << operand2[4:0]);
                return tagged Valid signExtend(result[31:0]);
            end
            alu_SRA32: begin
                let result = signedShiftRight(operand1[31:0], operand2[4:0]);
                return tagged Valid signExtend(result[31:0]);
            end
            alu_SRL32: begin
                let result = (operand1[31:0] >> operand2[4:0]);
                return tagged Valid signExtend(result[31:0]);
            end
`endif
            default: tagged Invalid;
        endcase;
    endmethod
endmodule
