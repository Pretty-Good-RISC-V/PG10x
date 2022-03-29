import PGTypes::*;

//
// Exception
//
// Structure containing information about an exceptional condition
// encounted by the processor.
//
typedef union tagged {
    RVExceptionCause ExceptionCause;
    RVInterruptCause InterruptCause;
} Cause deriving(Bits, Eq, FShow);

typedef struct {
    Cause cause;
    Word tval;
} Exception deriving(Bits, Eq, FShow);

function Exception createIllegalInstructionException(Word32 rawInstruction);
    return Exception {
        cause: tagged ExceptionCause exception_ILLEGAL_INSTRUCTION,
        tval: extend(rawInstruction)
    };
endfunction

function Exception createInstructionAccessFaultException(ProgramCounter programCounter);
    return Exception {
        cause: tagged ExceptionCause exception_INSTRUCTION_ACCESS_FAULT,
        tval: programCounter
    };
endfunction

function Exception createMisalignedInstructionException(ProgramCounter programCounter);
    return Exception {
        cause: tagged ExceptionCause exception_INSTRUCTION_ADDRESS_MISALIGNED,
        tval: programCounter
    };
endfunction

function Exception createMisalignedLoadException(Word effectiveAddress);
    return Exception {
        cause: tagged ExceptionCause exception_LOAD_ADDRESS_MISALIGNED,
        tval: effectiveAddress
    };
endfunction

function Exception createMisalignedStoreException(Word effectiveAddress);
    return Exception {
        cause: tagged ExceptionCause exception_STORE_ADDRESS_MISALIGNED,
        tval: effectiveAddress
    };
endfunction

function Exception createEnvironmentCallException(RVPrivilegeLevel currentPrivilegeLevel, ProgramCounter programCounter);
    return Exception {
        cause: tagged ExceptionCause (exception_ENVIRONMENT_CALL_FROM_U_MODE + extend(currentPrivilegeLevel)),
        tval: programCounter
    };
endfunction

function Exception createBreakpointException(ProgramCounter programCounter);
    return Exception {
        cause: tagged ExceptionCause exception_BREAKPOINT,
        tval: programCounter
    };
endfunction

function Exception createInterruptException(ProgramCounter programCounter, Bit#(TSub#(XLEN, 1)) interruptNumber);
    return Exception {
        cause: tagged InterruptCause pack(interruptNumber),
        tval: programCounter
    };
endfunction

function Exception createStoreAccessFaultException(Word storeAddress);
    return Exception {
        cause: tagged ExceptionCause exception_STORE_ACCESS_FAULT,
        tval: storeAddress
    };
endfunction

function Exception createLoadAccessFaultException(Word loadAddress);
    return Exception {
        cause: tagged ExceptionCause exception_LOAD_ACCESS_FAULT,
        tval: loadAddress
    };
endfunction

`ifdef ENABLE_RISCOF_TESTS
RVExceptionCause exception_RISCOFTestHaltException = 24;

function Exception createRISCOFTestHaltException(Word programCounter);
    return Exception {
        cause: tagged ExceptionCause exception_RISCOFTestHaltException,
        tval: programCounter
    };
endfunction
`endif
