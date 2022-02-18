import PGTypes::*;
import ALU::*;

typedef struct {
    RVALUOperators operator;
    Word operand1;
    Word operand2;
    Word expectedResult;
} ALUTest deriving(Bits, Eq, FShow);

(* synthesize *)
module mkALU_test(Empty);
    Reg#(Word) testNumber <- mkReg(0);
    ALU alu <- mkALU();

    Integer arraySize = 18;
    ALUTest tests[arraySize] = {
        ALUTest { operator: ADD, operand1: 0, operand2: 0, expectedResult: 0 },
        ALUTest { operator: ADD, operand1: 5, operand2: 7, expectedResult: 12 },
        ALUTest { operator: ADD, operand1: 5, operand2: -7, expectedResult: -2 },
        ALUTest { operator: SUB, operand1: 0, operand2: 0, expectedResult: 0 },
        ALUTest { operator: SUB, operand1: 5, operand2: 7, expectedResult: -2 },
        ALUTest { operator: SUB, operand1: 5, operand2: -7, expectedResult: 12 },
        ALUTest { operator: AND, operand1: 'ha7, operand2: 'h65, expectedResult: 'h25 },
        ALUTest { operator: OR,  operand1: 'ha7, operand2: 'h65, expectedResult: 'he7 },
        ALUTest { operator: XOR, operand1: 'ha7, operand2: 'h65, expectedResult: 'hc2 },
        ALUTest { operator: SLTU, operand1: 90, operand2: 100, expectedResult: 1 },
        ALUTest { operator: SLTU, operand1: 100, operand2: 90, expectedResult: 0 },
        ALUTest { operator: SLTU, operand1: 100, operand2: 100, expectedResult: 0 },
        ALUTest { operator: SLT, operand1: -1, operand2: 1, expectedResult: 1 },
        ALUTest { operator: SLT, operand1: 1, operand2: -1, expectedResult: 0 },
        ALUTest { operator: SLT, operand1: -1, operand2: -1, expectedResult: 0 },
        ALUTest { operator: SLL, operand1: 'hF0F0, operand2: 8, expectedResult: 'hF0F000 },
        ALUTest { operator: SRA, operand1: -16, operand2: 2, expectedResult: -4 },
        ALUTest { operator: SRL, operand1: 'hF0F0F0F0, operand2: 4, expectedResult: 'h0F0F0F0F }
    };

    rule runme;
        let test = tests[testNumber];
        let result = alu.execute(pack(test.operator), test.operand1, test.operand2);
        if (isValid(result) == False) begin
            $display("FAILED test #%0d - result invalid:", testNumber, fshow(test));
            $fatal();
        end
        if (unJust(result) != test.expectedResult) begin
            $display("FAILED test #%0d - unexpected result: ", testNumber, fshow(test));
            $fatal();
        end

        if (testNumber + 1 >= fromInteger(arraySize)) begin
            $display("    PASS");
            $finish();
        end

        testNumber <= testNumber + 1;
    endrule
endmodule
