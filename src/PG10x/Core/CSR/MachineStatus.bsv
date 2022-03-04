import PGTypes::*;
import RegUtil::*;

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
    method Bool machineModeInterruptsEnabled;

    method Word read;
    method Action write(Word newValue);

`ifdef RV32
    method Word readh;
    method Action writeh(Word newValue);
`endif
endinterface

module mkMachineStatusRegister(MachineStatus);
    Reg#(Bit#(1)) sie           <- mkReadOnlyReg(0);            // Supervisor Interrupt Enable
    Reg#(Bit#(1)) mie           <- mkReg(0);                    // Machine Interrupt Enable
    Reg#(Bit#(1)) spie          <- mkReadOnlyReg(0);            // Supervisor Mode Interupts Enabled During Trap
    Reg#(Bit#(1)) ube           <- mkReadOnlyReg(0);            // User Mode Data Accesses are Big Endian
    Reg#(Bit#(1)) mpie          <- mkReg(0);                    // Machine Mode Interrupts Enabled During Trap
    Reg#(Bit#(1)) spp           <- mkReadOnlyReg(0);            // Supervisor Previous Privilege Mode
    Reg#(FSVSState) vs          <- mkReadOnlyReg(fsvs_OFF);     // Vector Extension State
    Reg#(RVPrivilegeLevel) mpp  <- mkReadOnlyReg(priv_MACHINE); // Machine Previous Privilege Level
    Reg#(FSVSState) fs          <- mkReadOnlyReg(fsvs_OFF);     // Floating Point Status
    Reg#(XSState) xs            <- mkReadOnlyReg(xs_ALL_OFF);   // User Mode Extension Status
    Reg#(Bit#(1)) mprv          <- mkReadOnlyReg(0);            // Modify Privilege Mode For Loads/Stores
    Reg#(Bit#(1)) sum           <- mkReadOnlyReg(0);            // Permit Supervisor User Memory Access
    Reg#(Bit#(1)) mxr           <- mkReadOnlyReg(0);            // Make Executable Pages Readable
    Reg#(Bit#(1)) tvm           <- mkReadOnlyReg(0);            // Trap Virtual Memory Management Accesses
    Reg#(Bit#(1)) tw            <- mkReadOnlyReg(0);            // Timeout-Wait
    Reg#(Bit#(1)) tsr           <- mkReadOnlyReg(0);            // Trap SRET Instruction

`ifdef RV64
    Reg#(XLENEncoding) uxl      <- mkReadOnlyReg(xlen_64);      // User Mode XLEN value
    Reg#(XLENEncoding) sxl      <- mkReadOnlyReg(xlen_64);      // Supervisor Mode XLEN value
`endif
    Reg#(Bit#(1)) sbe           <- mkReadOnlyReg(0);            // Supervisor Mode Data Accesses are Big Endian
    Reg#(Bit#(1)) mbe           <- mkReadOnlyReg(0);            // Machine Mode Data Accesses are Big Endian

    method Bool machineModeInterruptsEnabled;
        return unpack(mie);
    endmethod

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
            mie,
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
            mie,
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
        mie <= newValue[3];
        mpie <= newValue[7];
    endmethod

`ifdef RV32
    method Action writeh(Word newValue);
    endmethod
`endif

endmodule
