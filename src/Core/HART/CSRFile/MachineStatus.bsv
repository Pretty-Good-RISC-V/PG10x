import PGTypes::*;
import ReadOnly::*;

import GetPut::*;

export MachineStatus(..), mkMachineStatusRegister;

typedef Bit#(2) XLENEncoding;
XLENEncoding xlen_32  = 2'b01;
XLENEncoding xlen_64  = 2'b10;
XLENEncoding xlen_128 = 2'b11;

typedef Bit#(2) FSVSState;
FSVSState fsvs_OFF     = 2'b00;
FSVSState fsvs_INITIAL = 2'b01;
FSVSState fsvs_CLEAN   = 2'b10;
FSVSState fsvs_DIRTY   = 2'b11;

typedef Bit#(2) XSState;
XSState xs_ALL_OFF               = 2'b00;
XSState xs_NONE_DIRTY_OR_CLEAN   = 2'b01;
XSState xs_NONE_DIRTY_SOME_CLEAN = 2'b10;
XSState xs_SOME_DIRTY            = 2'b11;

interface MachineStatus;
    method Word read;
    method Action write(Word newValue);

`ifdef RV32
    method Word readh;
    method Action writeh(Word newValue);
`endif

    interface Get#(Bool) getMIE;
endinterface

module mkMachineStatusRegister(MachineStatus);
    ReadOnly#(Bit#(1)) sie          <- mkReadOnly(0);            // Supervisor Interrupt Enable
    Reg#(Bool) mie                  <- mkReg(False);             // Machine Interrupt Enable
    ReadOnly#(Bit#(1)) spie         <- mkReadOnly(0);            // Supervisor Mode Interupts Enabled During Trap
    ReadOnly#(Bit#(1)) ube          <- mkReadOnly(0);            // User Mode Data Accesses are Big Endian
    Reg#(Bit#(1)) mpie              <- mkReg(0);                 // Machine Mode Interrupts Enabled During Trap
    ReadOnly#(Bit#(1)) spp          <- mkReadOnly(0);            // Supervisor Previous Privilege Mode
    ReadOnly#(FSVSState) vs         <- mkReadOnly(fsvs_OFF);     // Vector Extension State
    ReadOnly#(RVPrivilegeLevel) mpp <- mkReadOnly(priv_MACHINE); // Machine Previous Privilege Level
    ReadOnly#(FSVSState) fs         <- mkReadOnly(fsvs_OFF);     // Floating Point Status
    ReadOnly#(XSState) xs           <- mkReadOnly(xs_ALL_OFF);   // User Mode Extension Status
    ReadOnly#(Bit#(1)) mprv         <- mkReadOnly(0);            // Modify Privilege Mode For Loads/Stores
    ReadOnly#(Bit#(1)) sum          <- mkReadOnly(0);            // Permit Supervisor User Memory Access
    ReadOnly#(Bit#(1)) mxr          <- mkReadOnly(0);            // Make Executable Pages Readable
    ReadOnly#(Bit#(1)) tvm          <- mkReadOnly(0);            // Trap Virtual Memory Management Accesses
    ReadOnly#(Bit#(1)) tw           <- mkReadOnly(0);            // Timeout-Wait
    ReadOnly#(Bit#(1)) tsr          <- mkReadOnly(0);            // Trap SRET Instruction

`ifdef RV64
    ReadOnly#(XLENEncoding) uxl     <- mkReadOnly(0);            // User Mode XLEN value
    ReadOnly#(XLENEncoding) sxl     <- mkReadOnly(0);            // Supervisor Mode XLEN value
`endif
    ReadOnly#(Bit#(1)) sbe          <- mkReadOnly(0);            // Supervisor Mode Data Accesses are Big Endian
    ReadOnly#(Bit#(1)) mbe          <- mkReadOnly(0);            // Machine Mode Data Accesses are Big Endian

`ifdef RV64
    method Word read;
        Bit#(1) sd = ((vs | fs | xs) == 0 ? 0 : 1);
        return {
            sd,
            25'b0,
            mbe,
            sbe,
            sxl,
            uxl,
            9'b0,
            tsr,
            tw,
            tvm,
            mxr,
            sum,
            mprv,
            xs,
            fs,
            mpp,
            vs,
            spp,
            mpie,
            ube,
            spie,
            1'b0,
            pack(mie),
            1'b0,
            sie,
            1'b0
        };
    endmethod

`elsif RV32
    method Word read;
        Bit#(1) sd = ((vs | fs | xs) == 0 ? 0 : 1);
        return {
            sd,
            8'b0,
            tsr,
            tw,
            tvm,
            mxr,
            sum,
            mprv,
            xs,
            fs,
            mpp,
            vs,
            spp,
            mpie,
            ube,
            spie,
            1'b0,
            pack(mie),
            1'b0,
            sie,
            1'b0
        };
    endmethod

    method Word readh;
        return {
            26'b0,
            mbe,
            sbe,
            4'b0
        };
    endmethod
`endif

    method Action write(Word newValue);
        mie <= unpack(newValue[3]);
        mpie <= newValue[7];
    endmethod

`ifdef RV32
    method Action writeh(Word newValue);
    endmethod
`endif

    interface Get getMIE = toGet(mie);
endmodule
