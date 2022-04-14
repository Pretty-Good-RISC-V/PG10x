import PGTypes::*;

import Exception::*;
import InstructionCommon::*;
import LoadStore::*;

//
// GPRWriteBack
//
// Structure containing data to be written back to the GPR file
//
typedef struct {
    RVGPRIndex rd;
    Word value;
} GPRWriteBack deriving(Bits, Eq, FShow);

//
// CSRWriteBack
//
// Structure containing data to be written back to the CSR file
//
typedef struct {
    RVCSRIndex rd;
    Word value;
} CSRWriteBack deriving(Bits, Eq, FShow);

//
// ExecutedInstruction
//
// Structure describing an executed instruction including any resulting
// data.
//
typedef struct {
    // instructionCommon - common instruction info
    InstructionCommon instructionCommon;

    // changedProgramCounter - The next program counter if this instruction was a
    //                         jump/branch/etc.
    Maybe#(ProgramCounter) changedProgramCounter;

    // exception - The exception (if any) encounted during execution of the instruction.
    Maybe#(Exception) exception;

    // loadRequest - The load request (if any) of the executed instruction.
    Maybe#(LoadRequest) loadRequest;

    // storeRequest - The store request (if any) of the executed instruction.
    Maybe#(StoreRequest) storeRequest;

    // gprWriteBack - The data to be written to the GPR file (if any) for the instruction.
    Maybe#(GPRWriteBack) gprWriteBack;

    // gprWriteBack - The data to be written to the GPR file (if any) for the instruction.
    Maybe#(CSRWriteBack) csrWriteBack;
} ExecutedInstruction deriving(Bits, Eq, FShow);

instance DefaultValue#(ExecutedInstruction);
    defaultValue = ExecutedInstruction {
        instructionCommon: ?,
        changedProgramCounter: tagged Invalid,
        loadRequest: tagged Invalid,
        storeRequest: tagged Invalid,
        exception: tagged Invalid,
        gprWriteBack: tagged Invalid,
        csrWriteBack: tagged Invalid
    };
endinstance

function ExecutedInstruction newExecutedInstruction(ProgramCounter programCounter, Word32 rawInstruction);
    ExecutedInstruction executedInstruction = defaultValue;
    executedInstruction.instructionCommon.programCounter = programCounter;
    executedInstruction.instructionCommon.rawInstruction = rawInstruction;
    executedInstruction.exception = tagged Valid createIllegalInstructionException(rawInstruction);

    return executedInstruction;
endfunction

function ExecutedInstruction newNOOPExecutedInstruction(ProgramCounter programCounter);
    ExecutedInstruction executedInstruction = defaultValue;
    executedInstruction.instructionCommon.programCounter = programCounter;
    executedInstruction.instructionCommon.rawInstruction = 0;
    executedInstruction.exception = tagged Invalid;

    return executedInstruction;
endfunction
