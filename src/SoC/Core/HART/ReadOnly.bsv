module mkReadOnly#(t x)(ReadOnly#(t));
    function ReadOnly#(t) readOnlyReg(t r);
        return (interface ReadOnly;
                method t _read = r;
            endinterface);
    endfunction

    return readOnlyReg(x);
endmodule
