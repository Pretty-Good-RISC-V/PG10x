function Reg#(t) readOnlyReg(t r);
    return (interface Reg;
            method t _read = r;
            method Action _write(t x) = noAction;
        endinterface);
endfunction

function Reg#(t) readOnlyRegWarn(t r, String msg);
    return (interface Reg;
            method t _read = r;
            method Action _write(t x);
                $fdisplay(stderr, "[WARNING] readOnlyReg: %s", msg);
            endmethod
        endinterface);
endfunction

function Reg#(t) readOnlyRegError(t r, String msg);
    return (interface Reg;
            method t _read = r;
            method Action _write(t x);
                $fdisplay(stderr, "[ERROR] readOnlyReg: %s", msg);
                $finish(1);
            endmethod
        endinterface);
endfunction

module mkReadOnlyReg#(t x)(Reg#(t));
    return readOnlyReg(x);
endmodule

module mkReadOnlyRegWarn#(t x, String msg)(Reg#(t));
    return readOnlyRegWarn(x, msg);
endmodule

module mkReadOnlyRegError#(t x, String msg)(Reg#(t));
    return readOnlyRegError(x, msg);
endmodule
