//
// BranchPredictor
//
// This module contains a branch predictor interface and several implementation variants.
//
`include "PGLib.bsh"

interface BranchPredictor;
    method ProgramCounter predictNextProgramCounter(ProgramCounter currentProgramCounter, Word32 instruction);
endinterface

module mkNullBranchPredictor(BranchPredictor);
    method ProgramCounter predictNextProgramCounter(ProgramCounter currentProgramCounter, Word32 instruction);
        return currentProgramCounter + 4;
    endmethod
endmodule

module mkBackwardBranchTakenPredictor(BranchPredictor);
    method ProgramCounter predictNextProgramCounter(ProgramCounter currentProgramCounter, Word32 instruction);
        let opcode = instruction[6:0];
        let predictedProgramCounter = currentProgramCounter + 4;

        case(opcode)
            7'b1100011: begin // BRANCH
                // If the offset is negative (upper bit set), predict branch taken
                if (instruction[31] == 1) begin
                    Word immediate = signExtend({
                        instruction[31],        // 1 bit
                        instruction[7],         // 1 bit
                        instruction[30:25],     // 6 bits
                        instruction[11:8],      // 4 bits
                        1'b0                    // 1 bit
                    });

                    predictedProgramCounter = getEffectiveAddress(currentProgramCounter, immediate);
                end 
            end
        endcase
        return predictedProgramCounter;
    endmethod
endmodule
