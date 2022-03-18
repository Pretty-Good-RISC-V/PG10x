import PGTypes::*;
import Exception::*;
import PipelineController::*;

//
// EncodedInstruction
//
// Structure holding a *encoded* RISC-V instruction. 
//
typedef struct {
    // fetchIndex - Monotonically increasing index of all instructions fetched.
    Word fetchIndex;

    // pipelineEpoch - Records which pipeline epoch corresponds to this instruction.
    PipelineEpoch pipelineEpoch;

    // programCounter - The program counter corresponding to this instruction.
    ProgramCounter programCounter;

    // predictedNextProgramCounter - Contains the *predicted* program counter following this
    //                               instruction.
    ProgramCounter predictedNextProgramCounter;

    // rawInstruction - encoded (raw) instruction bytes.
    Word32 rawInstruction;

    // exception - exception encountered during fetch
    Maybe#(Exception) exception;
} EncodedInstruction deriving(Bits, Eq, FShow);
