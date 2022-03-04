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
} Exception deriving(Bits, Eq, FShow);

function Word getCause(Exception exception);
    return case(exception) matches
        tagged ExceptionCause .exceptionCause: begin
            Word cause = ?;
            cause[valueOf(XLEN)-1] = 0;
            cause[valueOf(XLEN)-2:0] = exceptionCause;
            return cause;
        end
        tagged InterruptCause .interruptCause: begin
            Word cause = ?;
            cause[valueOf(XLEN)-1] = 1;
            cause[valueOf(XLEN)-2:0] = interruptCause;
            return cause;
        end
    endcase;
endfunction
