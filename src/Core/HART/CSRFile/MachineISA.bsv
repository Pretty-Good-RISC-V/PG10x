import PGTypes::*;
import ReadOnly::*;

interface MachineISA;
    method Word read;
    method Action write(Word value);
endinterface

module mkMachineISARegister(MachineISA);
`ifdef RV32
    ReadOnly#(Bit#(2)) mxl <- mkReadOnly(1);
`elsif RV64
    ReadOnly#(Bit#(2)) mxl <- mkReadOnly(2);
`endif

    ReadOnly#(Bool) extA <- mkReadOnly(False);      // Atomic extension
    ReadOnly#(Bool) extB <- mkReadOnly(False);      // Bit manipulation extension
    ReadOnly#(Bool) extC <- mkReadOnly(False);      // Compressed instruction extension
    ReadOnly#(Bool) extD <- mkReadOnly(False);      // Double precision floating-point extension
    ReadOnly#(Bool) extE <- mkReadOnly(False);      // RV32E base ISA
    ReadOnly#(Bool) extF <- mkReadOnly(False);      // Single precision floating-point extension
    ReadOnly#(Bool) extG <- mkReadOnly(False);      // ** RESERVED **
    ReadOnly#(Bool) extH <- mkReadOnly(False);      // Hypervisor extension
    ReadOnly#(Bool) extI <- mkReadOnly(True);       // RV32I/64I/128I base ISA
    ReadOnly#(Bool) extJ <- mkReadOnly(False);      // Dynamically translated languaged extension
    ReadOnly#(Bool) extK <- mkReadOnly(False);      // ** RESERVED **
    ReadOnly#(Bool) extL <- mkReadOnly(False);      // ** RESERVED **
    ReadOnly#(Bool) extM <- mkReadOnly(False);      // Integer multiply/divide extension
    ReadOnly#(Bool) extN <- mkReadOnly(False);      // User level interrupts extension
    ReadOnly#(Bool) extO <- mkReadOnly(False);      // ** RESERVED **
    ReadOnly#(Bool) extP <- mkReadOnly(False);      // Packed-SIMD extension
    ReadOnly#(Bool) extQ <- mkReadOnly(False);      // Quad precision floating-point extension
    ReadOnly#(Bool) extR <- mkReadOnly(False);      // ** RESERVED **
    ReadOnly#(Bool) extS <- mkReadOnly(False);      // Supervisor mode implemented
    ReadOnly#(Bool) extT <- mkReadOnly(False);      // ** RESERVED **
    ReadOnly#(Bool) extU <- mkReadOnly(False);       // User mode implemented
    ReadOnly#(Bool) extV <- mkReadOnly(False);      // Vector extension
    ReadOnly#(Bool) extW <- mkReadOnly(False);      // ** RESERVED **
    ReadOnly#(Bool) extX <- mkReadOnly(False);      // Non-standard extensions present
    ReadOnly#(Bool) extY <- mkReadOnly(False);      // ** RESERVED **
    ReadOnly#(Bool) extZ <- mkReadOnly(False);      // ** RESERVED **

    method Word read;
        return {
            mxl,
`ifdef RV32
            4'b0,
`elsif RV64
            36'b0,
`endif            
            pack(extZ),
            pack(extY),
            pack(extX),
            pack(extW),
            pack(extV),
            pack(extU),
            pack(extT),
            pack(extS),
            pack(extR),
            pack(extQ),
            pack(extP),
            pack(extO),
            pack(extN),
            pack(extM),
            pack(extL),
            pack(extK),
            pack(extJ),
            pack(extI),
            pack(extH),
            pack(extH),
            pack(extF),
            pack(extE),
            pack(extD),
            pack(extC),
            pack(extB),
            pack(extA)           
        };
    endmethod

    method Action write(Word value);
    endmethod
endmodule
