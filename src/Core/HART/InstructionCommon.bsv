import PGTypes::*;
import PipelineController::*;

export PipelineController::*, InstructionCommon(..);

typedef struct {
    // fetchIndex - Monotically increasing index of all instructions fetched.
    Word fetchIndex;

    // pipelineEpoch - Records which pipeline epoch corresponds to this instruction.
    PipelineEpoch pipelineEpoch;

    // programCounter - The program counter corresponding to this instruction.
    ProgramCounter programCounter;

    // rawInstruction - The raw instruction bits
    Word32 rawInstruction;

    // predictedNextProgramCounter - Contains the *predicted* program counter following this
    //                               instruction.
    ProgramCounter predictedNextProgramCounter;
} InstructionCommon deriving(Bits, Eq, FShow);

instance DefaultValue#(InstructionCommon);
    defaultValue = InstructionCommon {
        fetchIndex: 0,
        pipelineEpoch: 0,
        programCounter: 0,
        rawInstruction: 0,
        predictedNextProgramCounter: 0
    };
endinstance
