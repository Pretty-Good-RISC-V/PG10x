import RVTypes::*;
import Memory::*;

typedef Bit#(XLEN) Word;
typedef Bit#(32) Word32;
typedef Bit#(64) Word64;
typedef Bit#(128) Word128;

typedef Bit#(XLEN) UnsignedInt;
typedef Int#(XLEN) SignedInt;

typedef Word ProgramCounter;
typedef Bit#(5) RegisterIndex;
typedef Bit#(12) CSRIndex;

typedef TLog#(TDiv#(n,8)) DataSz#(numeric type n);

// A Rust inspired Result type.
typedef union tagged {
    success_type Success;
    error_type Error;
} Result#(type success_type, type error_type);

function Bool isSuccess(Result#(success_type, error_type) result);
    if (result matches tagged Success .*) begin
        return True;
    end else begin
        return False;
    end
endfunction

export Memory::*, RVTypes::*, PGTypes::*;
