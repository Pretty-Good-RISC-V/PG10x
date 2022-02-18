import PGTypes::*;

export MachineStatus(..), mkMachineStatusRegister;

interface MachineStatus;

`ifdef RV64
    method Word mstatus();
`elsif RV32
    method Word mstatus();
    method Word mstatush();
`endif

endinterface

typedef enum {
    XLEN32  = 2'b01,
    XLEN64  = 2'b10,
    XLEN128 = 2'b11
} XLENEncoding deriving(Bits, Eq);

typedef enum {
    OFF     = 2'b00,
    INITIAL = 2'b01,
    CLEAN   = 2'b10,
    DIRTY   = 2'b11
} FSVSState deriving(Bits, Eq);

typedef enum {
    ALL_OFF                 = 2'b00,
    NONE_DIRTY_OR_CLEAN     = 2'b01,
    NONE_DIRTY_SOME_CLEAN   = 2'b10,
    SOME_DIRTY              = 2'b11
} XSState deriving(Bits, Eq);

typedef struct {
    Bool _reserved0;
    Bool supervisorInterruptEnabled;                        // SIE
    Bool _reserved1;
    Bool machineInterruptEnabled;                           // MIE
    Bool _reserved2;
    Bool supervisorInterruptsEnabledUponTrap;               // SPIE
    Bool userModeMemoryAccessAreBigEndian;                  // UBE
    Bool machineInterruptsEnabledUponTrap;                  // MPIE
    Bool supervisorInterruptPreviousPrivilegeLevel;         // SPP
    FSVSState vectorExtensionTrapState;                     // VS
    RVPrivilegeLevel machineInterruptPreviousPrivilegeLevel;  // MPP
    FSVSState floatingPointExtensionTrapState;              // FS
    XSState userModeExtensionsTrapState;                    // XS
    Bool effectivePrivilegeLevel;                           // MPRV
    Bool permitSupervisorMemoryAccess;                      // SUM
    Bool makeExecutableReadable;                            // MXP
    Bool trapVirtualMemory;                                 // TVM
    Bool timeoutWait;                                       // TW
    Bool trapSRET;                                          // TSR
`ifdef RV32
    Bit#(8) _reserved3;
    Bool stateBitsAvailable;                                // SD (32bit mode)
    Bit#(4) _reserved4;
`elsif RV64
    Bit#(9) _reserved5;
    XLENEncoding userModeXLEN;
    XLENEncoding supervisorModeXLEN;
`endif

    Bool supervisorModeMemoryFetchesBigEndian;              // SBE
    Bool machineModeMemoryFetchesBigEndian;                 // MBE

`ifdef RV32
    Bit#(26) _reserved6;
`elsif RV64
    Bit#(25) _reserved7;
    Bool stateBitsAvailable;                                // SD (64bit mode)
`endif
} MachineStatusRegister deriving(Bits, Eq);

module mkMachineStatusRegister(MachineStatus);
    Reg#(MachineStatusRegister) sr <- mkReg(unpack(0));
`ifdef RV64
    method Word mstatus();
        return pack(sr);
    endmethod
`elsif RV32
    method Word mstatus();
        return pack(sr)[31:0];
    endmethod

    method Word mstatush();
        return pack(sr)[63:32];
    endmethod
`endif

endmodule
