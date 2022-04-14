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
