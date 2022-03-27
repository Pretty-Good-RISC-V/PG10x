import PGTypes::*;

typedef Bit#(2) MXL;
MXL mxl_32bit  = 2'b01;
MXL mxl_64bit  = 2'b10;
MXL mxl_128bit = 2'b11;

typedef struct {
    Bool extA;      // Atomic extension
    Bool extB;      // Bit manipulation extension
    Bool extC;      // Compressed instruction extension
    Bool extD;      // Double precision floating-point extension
    Bool extE;      // RV32E base ISA
    Bool extF;      // Single precision floating-point extension
    Bool extG;      // ** RESERVED **
    Bool extH;      // Hypervisor extension
    Bool extI;      // RV32I/64I/128I base ISA
    Bool extJ;      // Dynamically translated languaged extension
    Bool extK;      // ** RESERVED **
    Bool extL;      // ** RESERVED **
    Bool extM;      // Integer multiply/divide extension
    Bool extN;      // User level interrupts extension
    Bool extO;      // ** RESERVED **
    Bool extP;      // Packed-SIMD extension
    Bool extQ;      // Quad precision floating-point extension
    Bool extR;      // ** RESERVED **
    Bool extS;      // Supervisor mode implemented
    Bool extT;      // ** RESERVED **
    Bool extU;      // User mode implemented
    Bool extV;      // Vector extension
    Bool extW;      // ** RESERVED **
    Bool extX;      // Non-standard extensions present
    Bool extY;      // ** RESERVED **
    Bool extZ;      // ** RESERVED **
} MachineISA deriving(Eq);

instance DefaultValue#(MachineISA);
    defaultValue = MachineISA {
        extA: False,
        extB: False,
        extC: False,
        extD: False,
        extE: False,
        extF: False,
        extG: False,
        extH: False,
        extI: True,     // RV32I/64I/128I base ISA
        extJ: False,
        extK: False,
        extL: False,
        extM: False,
        extN: False,
        extO: False,
        extP: False,
        extQ: False,
        extR: False,
        extS: False,
        extT: False,
        extU: False,
        extV: False,
        extW: False,
        extX: False,
        extY: False,
        extZ: False
    };
endinstance

instance Bits#(MachineISA, XLEN);
    function Bit#(XLEN) pack(MachineISA misa);
`ifdef RV32
        MXL mxl = mxl_32bit;
`elsif RV64
        MXL mxl = mxl_64bit;
`endif
        return {
            mxl,
`ifdef RV32
            4'b0,
`elsif RV64
            36'b0,
`endif            
            pack(misa.extZ),
            pack(misa.extY),
            pack(misa.extX),
            pack(misa.extW),
            pack(misa.extV),
            pack(misa.extU),
            pack(misa.extT),
            pack(misa.extS),
            pack(misa.extR),
            pack(misa.extQ),
            pack(misa.extP),
            pack(misa.extO),
            pack(misa.extN),
            pack(misa.extM),
            pack(misa.extL),
            pack(misa.extK),
            pack(misa.extJ),
            pack(misa.extI),
            pack(misa.extH),
            pack(misa.extH),
            pack(misa.extF),
            pack(misa.extE),
            pack(misa.extD),
            pack(misa.extC),
            pack(misa.extB),
            pack(misa.extA)           
        };
    endfunction

    function MachineISA unpack(Bit#(XLEN) value);
        return defaultValue;
    endfunction
endinstance
