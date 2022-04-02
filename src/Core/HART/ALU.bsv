//
// ALU
//
// This module is a Arithmetic Logic Unit (ALU) implementation for RISC-V.  It is
// reponsible for mathematical operations inside the CPU.
//
import PGTypes::*;
import IntMulDiv::*;

interface ALU;
    method Maybe#(Word) execute(RVALUOperator operator, Word operand1, Word operand2);
`ifdef RV64
    method Maybe#(Word) execute32(RVALUOperator operator, Word operand1, Word operand2);
`endif
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
        Int#(XLEN) operand1s = unpack(operand1);
        Int#(XLEN) operand2s = unpack(operand2);

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
`endif

            alu_REM:    tagged Valid pack(operand1s % operand2s);
            alu_REMU:   tagged Valid (operand1 % operand2);
            alu_MUL:    tagged Valid (operand1 * operand2);
`ifdef RV32
            alu_MULH:   begin
                Int#(64) o1s = extend(operand1s);
                Int#(64) o2s = extend(operand2s);
                Int#(64) product = o1s * o2s;
                return tagged Valid pack(product)[63:32];
            end

            alu_MULHU: begin
                Word64 o1s = extend(operand1);    // unsigned
                Word64 o2s = extend(operand2);    // unsigned
                Word64 product = o1s * o2s;
                return tagged Valid pack(product)[63:32];
            end

            alu_MULHSU: begin
                Int#(64) o1s = extend(operand1s);           // signed
                Int#(64) o2s = unpack(extend(operand2));    // unsigned
                Int#(64) product = o1s * o2s;
                return tagged Valid pack(product)[63:32];
            end
`endif
            alu_DIV:    tagged Valid pack(operand1s / operand2s);
            alu_DIVU:   tagged Valid (operand1 / operand2);

            default:    tagged Invalid;
        endcase;
    endmethod

`ifdef RV64
    method Maybe#(Word) execute32(RVALUOperator operator, Word operand1, Word operand2);
        return case(operator)
            alu_ADD: begin
                let result = operand1[31:0] + operand2[31:0];
                return tagged Valid signExtend(result[31:0]);
            end
            alu_SUB: begin
                let result = (operand1[31:0] - operand2[31:0]);
                return tagged Valid signExtend(result[31:0]);
            end
            alu_SLL: begin
                let result = (operand1[31:0] << operand2[4:0]);
                return tagged Valid signExtend(result[31:0]);
            end
            alu_SRA: begin
                let result = signedShiftRight(operand1[31:0], operand2[4:0]);
                return tagged Valid signExtend(result[31:0]);
            end
            alu_SRL: begin
                let result = (operand1[31:0] >> operand2[4:0]);
                return tagged Valid signExtend(result[31:0]);
            end
            default: tagged Invalid;
        endcase;
    endmethod
`endif
endmodule
