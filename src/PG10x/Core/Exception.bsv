import PGTypes::*;

//
// Exception
//
// Structure containing information about an exceptional condition
// encounted by the processor.
typedef union tagged {
    RVExceptionCause ExceptionCause;
    RVInterruptCause InterruptCause;
} Exception deriving(Bits, Eq, FShow);

function Word getMCAUSE(Exception exception);
    return case(exception) matches
        tagged ExceptionCause .cause: begin
            Word mcause = ?;
            mcause[valueOf(XLEN)-1] = 0;
            mcause[valueOf(XLEN)-2:0] = cause;
            return mcause;
        end
        tagged InterruptCause .cause: begin
            Word mcause = ?;
            mcause[valueOf(XLEN)-1] = 1;
            mcause[valueOf(XLEN)-2:0] = cause;
            return mcause;
        end
    endcase;
endfunction
