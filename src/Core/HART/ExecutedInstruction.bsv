import PGTypes::*;

import Exception::*;
import InstructionCommon::*;
import LoadStore::*;

//
// GPRWriteback
//
// Structure containing data to be written back to the GPR file
//
typedef struct {
    RVGPRIndex rd;
    Word value;
} GPRWriteback deriving(Bits, Eq, FShow);

//
// CSRWriteback
//
// Structure containing data to be written back to the CSR file
//
typedef struct {
    RVCSRIndex rd;
    Word value;
} CSRWriteback deriving(Bits, Eq, FShow);

//
// ExecutedInstruction
//
// Structure describing an executed instruction including any resulting
// data.
//
typedef struct {
    // instructionCommon - common instruction info
    InstructionCommon instructionCommon;

    // redirectedProgramCounter - The next program counter if this instruction was a
    //                            jump/branch/etc.
    Result#(ProgramCounter, Exception) redirectedProgramCounter;

    // exception - The exception (if any) encounted during execution of the instruction.
    Maybe#(Exception) exception;

    // loadRequest - The load request (if any) of the executed instruction.
    Result#(LoadRequest, Exception) loadRequest;

    // storeRequest - The store request (if any) of the executed instruction.
    Result#(StoreRequest, Exception) storeRequest;

    // gprWriteback - The data to be written to the GPR file (if any) for the instruction.
    Result#(GPRWriteback, Exception) gprWriteback;

    // csrWriteback - The data to be written to the CSR file (if any) for the instruction.
    Result#(CSRWriteback, Exception) csrWriteback;
} ExecutedInstruction deriving(Bits, Eq, FShow);

instance DefaultValue#(ExecutedInstruction);
    defaultValue = ExecutedInstruction {
        instructionCommon: defaultValue,
        redirectedProgramCounter: tagged Invalid,
        loadRequest: tagged Invalid,
        storeRequest: tagged Invalid,
        exception: tagged Invalid,
        gprWriteback: tagged Invalid,
        csrWriteback: tagged Invalid
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
