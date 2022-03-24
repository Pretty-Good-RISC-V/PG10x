import PGTypes::*;

import Exception::*;
import LoadStore::*;
import PipelineController::*;

//
// WriteBack
//
// Structure containing data to be written back to CPU registers
//
typedef struct {
    RVGPRIndex rd;
    Word value;
} WriteBack deriving(Bits, Eq, FShow);

//
// ExecutedInstruction
//
// Structure describing an executed instruction including any resulting
// data.
//
typedef struct {
    // fetchIndex - Monotically increasing index of all instructions fetched.
    Word fetchIndex;

    // pipelineEpoch - Records which pipeline epoch corresponds to this instruction.
    PipelineEpoch pipelineEpoch;

    // programCounter - The program counter corresponding to this instruction.
    ProgramCounter programCounter;

    // rawInstruction - The raw instruction bits
    Word32 rawInstruction;

    // changedProgramCounter - The next program counter if this instruction was a
    //                         jump/branch/etc.
    Maybe#(ProgramCounter) changedProgramCounter;

    // exception - The exception (if any) encounted during execution of the instruction.
    Maybe#(Exception) exception;

    // loadRequest - The load request (if any) of the executed instruction.
    Maybe#(LoadRequest) loadRequest;

    // storeRequest - The store request (if any) of the executed instruction.
    Maybe#(StoreRequest) storeRequest;

    // writeBack - The data to be written to the register file (if any) for the instruction.
    Maybe#(WriteBack) writeBack;
} ExecutedInstruction deriving(Bits, Eq, FShow);

instance DefaultValue#(ExecutedInstruction);
    defaultValue = ExecutedInstruction {
        fetchIndex: ?,
        pipelineEpoch: ?,
        programCounter: ?,
        rawInstruction: ?,
        changedProgramCounter: tagged Invalid,
        loadRequest: tagged Invalid,
        storeRequest: tagged Invalid,
        exception: tagged Invalid,
        writeBack: tagged Invalid
    };
endinstance

function ExecutedInstruction newExecutedInstruction(ProgramCounter programCounter, Word32 rawInstruction);
    ExecutedInstruction executedInstruction = defaultValue;
    executedInstruction.programCounter = programCounter;
    executedInstruction.rawInstruction = rawInstruction;
    executedInstruction.exception = tagged Valid createIllegalInstructionException(rawInstruction);

    return executedInstruction;
endfunction
