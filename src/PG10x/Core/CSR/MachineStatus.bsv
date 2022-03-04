import PGTypes::*;

export MachineStatus(..), mkMachineStatusRegister;

typedef enum {
    XLEN32  = 2'b01,
    XLEN64  = 2'b10,
    XLEN128 = 2'b11
} XLENEncoding deriving(Bits, Eq, FShow);

typedef enum {
    OFF     = 2'b00,
    INITIAL = 2'b01,
    CLEAN   = 2'b10,
    DIRTY   = 2'b11
} FSVSState deriving(Bits, Eq, FShow);

typedef enum {
    ALL_OFF                 = 2'b00,
    NONE_DIRTY_OR_CLEAN     = 2'b01,
    NONE_DIRTY_SOME_CLEAN   = 2'b10,
    SOME_DIRTY              = 2'b11
} XSState deriving(Bits, Eq, FShow);

typedef struct {
    Bool _reserved0;
    Bool supervisorModeInterruptsEnabled;                       // SIE
    Bool _reserved1;
    Bool machineModeInterruptsEnabled;                          // MIE
    Bool _reserved2;
    Bool supervisorInterruptsEnabledUponTrap;                   // SPIE
    Bool userModeMemoryAccessAreBigEndian;                      // UBE
    Bool machineInterruptsEnabledUponTrap;                      // MPIE
    Bool supervisorInterruptPreviousPrivilegeLevel;             // SPP
    FSVSState vectorExtensionTrapState;                         // VS
    RVPrivilegeLevel machineInterruptPreviousPrivilegeLevel;    // MPP
    FSVSState floatingPointExtensionTrapState;                  // FS
    XSState userModeExtensionsTrapState;                        // XS
    Bool effectivePrivilegeLevel;                               // MPRV
    Bool permitSupervisorMemoryAccess;                          // SUM
    Bool makeExecutableReadable;                                // MXP
    Bool trapVirtualMemory;                                     // TVM
    Bool timeoutWait;                                           // TW
    Bool trapSRET;                                              // TSR
`ifdef RV32
    Bit#(8) _reserved3;
    Bool stateBitsAvailable;                                    // SD (32bit mode)
    Bit#(4) _reserved4;
`elsif RV64
    Bit#(9) _reserved5;
    XLENEncoding userModeXLEN;
    XLENEncoding supervisorModeXLEN;
`endif

    Bool supervisorModeMemoryFetchesBigEndian;                  // SBE
    Bool machineModeMemoryFetchesBigEndian;                     // MBE

`ifdef RV32
    Bit#(26) _reserved6;
`elsif RV64
    Bit#(25) _reserved7;
    Bool stateBitsAvailable;                                    // SD (64bit mode)
`endif
} MachineStatusRegister deriving(Bits, Eq, FShow);

interface MachineStatus;
    method Bool machineModeInterruptsEnabled;
    method Action setMachineModeInterruptsEnabled(Bool areEnabled);

    method Word read;
    method Action write(Word newValue);

`ifdef RV32
    method Word readh;
    method Action writeh(Word newValue);
`endif
endinterface

module mkMachineStatusRegister(MachineStatus);
    Reg#(Word64) sr <- mkReg(0);

    method Bool machineModeInterruptsEnabled;
        return ((sr & 'b1000) == 0 ? False : True);
    endmethod

    method Action setMachineModeInterruptsEnabled(Bool areEnabled);
        if (areEnabled)
            sr <= sr | 'b1000;
        else
            sr <= sr & ~'b1000;
    endmethod

`ifdef RV64
    method Word read;
        return sr;
    endmethod

    method Action write(Word newValue);
        sr <= newValue;
    endmethod

`elsif RV32
    method Word read;
        return sr[31:0];
    endmethod

    method Word readh;
        return sr[63:32];
    endmethod

    method Action write(Word newValue);
        sr[31:0] <= newValue;
    endmethod

    method Action writeh(Word newValue);
        sr[63:32] <= newValue;
    endmethod
`endif

endmodule
