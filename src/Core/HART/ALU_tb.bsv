import PGTypes::*;
import ALU::*;

typedef struct {
    RVALUOperator operator;
    Word operand1;
    Word operand2;
    Word expectedResult;
} ALUTest deriving(Bits, Eq, FShow);

(* synthesize *)
module mkALU_tb(Empty);
    Reg#(Word) testNumber <- mkReg(0);
    ALU alu <- mkALU;

`ifdef RV32
    Integer arraySize = 18;
`elsif RV64
    Integer arraySize = 20;
`endif
    ALUTest tests[arraySize] = {
        ALUTest { operator: alu_ADD, operand1: 0, operand2: 0, expectedResult: 0 },
        ALUTest { operator: alu_ADD, operand1: 5, operand2: 7, expectedResult: 12 },
        ALUTest { operator: alu_ADD, operand1: 5, operand2: -7, expectedResult: -2 },
        ALUTest { operator: alu_SUB, operand1: 0, operand2: 0, expectedResult: 0 },
        ALUTest { operator: alu_SUB, operand1: 5, operand2: 7, expectedResult: -2 },
        ALUTest { operator: alu_SUB, operand1: 5, operand2: -7, expectedResult: 12 },
        ALUTest { operator: alu_AND, operand1: 'ha7, operand2: 'h65, expectedResult: 'h25 },
        ALUTest { operator: alu_OR,  operand1: 'ha7, operand2: 'h65, expectedResult: 'he7 },
        ALUTest { operator: alu_XOR, operand1: 'ha7, operand2: 'h65, expectedResult: 'hc2 },
        ALUTest { operator: alu_SLTU, operand1: 90, operand2: 100, expectedResult: 1 },
        ALUTest { operator: alu_SLTU, operand1: 100, operand2: 90, expectedResult: 0 },
        ALUTest { operator: alu_SLTU, operand1: 100, operand2: 100, expectedResult: 0 },
        ALUTest { operator: alu_SLT, operand1: -1, operand2: 1, expectedResult: 1 },
        ALUTest { operator: alu_SLT, operand1: 1, operand2: -1, expectedResult: 0 },
        ALUTest { operator: alu_SLT, operand1: -1, operand2: -1, expectedResult: 0 },
        ALUTest { operator: alu_SLL, operand1: 'hF0F0, operand2: 8, expectedResult: 'hF0F000 },
        ALUTest { operator: alu_SRA, operand1: -16, operand2: 2, expectedResult: -4 },
        ALUTest { operator: alu_SRL, operand1: 'hF0F0F0F0, operand2: 4, expectedResult: 'h0F0F0F0F }
`ifdef RV64
        ,
        ALUTest { operator: alu_SRL, operand1: 'hC000_0000_0000_0000, operand2: 62, expectedResult: 3 },
        ALUTest { operator: alu_SLL, operand1: 3, operand2: 62, expectedResult: 'hC000_0000_0000_0000 }
`endif
    };

    rule runme;
        let test = tests[testNumber];
        let result = alu.execute(test.operator, test.operand1, test.operand2);
        if (isValid(result) == False) begin
            $display("FAILED test #%0d - result invalid:", testNumber, fshow(test));
            $fatal();
        end
        if (unJust(result) != test.expectedResult) begin
            $display("FAILED test #%0d - $%0x != unexpected result: ", testNumber, unJust(result), fshow(test));
            $fatal();
        end

        if (testNumber + 1 >= fromInteger(arraySize)) begin
            $display("    PASS");
            $finish();
        end

        testNumber <= testNumber + 1;
    endrule
endmodule
