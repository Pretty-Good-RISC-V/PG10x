import PGTypes::*;

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

typedef struct {
    Bool sie;               // Supervisor Interrupt Enable
    Bool mie;               // Machine Interrupt Enable
    Bool spie;              // Supervisor Mode Interupts Enabled During Trap
    Bool ube;               // User Mode Data Accesses are Big Endian
    Bool mpie;              // Machine Mode Interrupts Enabled During Trap
    Bool spp;               // Supervisor Previous Privilege Mode
    FSVSState vs;           // Vector Extension State
    RVPrivilegeLevel mpp;   // Machine Previous Privilege Level
    FSVSState fs;           // Floating Point Status
    XSState xs;             // User Mode Extension Status
    Bool mprv;              // Modify Privilege Mode For Loads/Stores
    Bool sum;               // Permit Supervisor User Memory Access
    Bool mxr;               // Make Executable Pages Readable
    Bool tvm;               // Trap Virtual Memory Management Accesses
    Bool tw;                // Timeout-Wait
    Bool tsr;               // Trap SRET Instruction

`ifdef RV64
    XLENEncoding uxl;      // User Mode XLEN value
    XLENEncoding sxl;      // Supervisor Mode XLEN value
`endif
    Bool sbe;               // Supervisor Mode Data Accesses are Big Endian
    Bool mbe;               // Machine Mode Data Accesses are Big Endian
} MachineStatus deriving(Eq);

instance DefaultValue#(MachineStatus);
    defaultValue = MachineStatus {
        sie: False,
        mie: False,
        spie: False,
        ube: False,
        mpie: False,
        spp: False,
        vs: fsvs_OFF,
        mpp: priv_MACHINE,
        fs: fsvs_OFF,
        xs: xs_ALL_OFF,
        mprv: False,
        sum: False,
        mxr: False,
        tvm: False,
        tw: False,
        tsr: False,
`ifdef RV64
        uxl: xlen_64,
        sxl: xlen_64,
`endif
        sbe: False,
        mbe: False
    };
endinstance

instance Bits#(MachineStatus, XLEN);
`ifdef RV64
    function Bit#(XLEN) pack(MachineStatus mstatus);
        Bit#(1) sd = ((mstatus.vs | mstatus.fs | mstatus.xs) == 0 ? 0 : 1);
        return {
            sd,
            25'b0,
            pack(mstatus.mbe),
            pack(mstatus.sbe),
            pack(mstatus.sxl),
            pack(mstatus.uxl),
            9'b0,
            pack(mstatus.tsr),
            pack(mstatus.tw),
            pack(mstatus.tvm),
            pack(mstatus.mxr),
            pack(mstatus.sum),
            pack(mstatus.mprv),
            pack(mstatus.xs),
            pack(mstatus.fs),
            pack(mstatus.mpp),
            pack(mstatus.vs),
            pack(mstatus.spp),
            pack(mstatus.mpie),
            pack(mstatus.ube),
            pack(mstatus.spie),
            1'b0,
            pack(mstatus.mie),
            1'b0,
            pack(mstatus.sie),
            1'b0
        };    
    endfunction
`elsif RV32
    function Bit#(XLEN) pack(MachineStatus mstatus);
        Bit#(1) sd = ((mstatus.vs | mstatus.fs | mstatus.xs) == 0 ? 0 : 1);
        return {
            sd,
            8'b0,
            pack(mstatus.tsr),
            pack(mstatus.tw),
            pack(mstatus.tvm),
            pack(mstatus.mxr),
            pack(mstatus.sum),
            pack(mstatus.mprv),
            pack(mstatus.xs),
            pack(mstatus.fs),
            pack(mstatus.mpp),
            pack(mstatus.vs),
            pack(mstatus.spp),
            pack(mstatus.mpie),
            pack(mstatus.ube),
            pack(mstatus.spie),
            1'b0,
            pack(mstatus.mie),
            1'b0,
            pack(mstatus.sie),
            1'b0
        };
    endfunction
`endif

    function MachineStatus unpack(Bit#(XLEN) value);
        MachineStatus mstatus = defaultValue;
`ifdef ENABLE_S_MODE
        mstatus.mpp  = unpack(value[12:11]);
`else
        // Supervisor mode not supported, ensure only USER and MACHINE
        // mode are set in MPP.
        RVPrivilegeLevel requestedMPP = unpack(value[12:11]);
        if (requestedMPP == priv_USER || requestedMPP == priv_MACHINE) begin
            mstatus.mpp = requestedMPP;
        end
`endif
        mstatus.mpie = unpack(value[7]);
        mstatus.mie  = unpack(value[3]);

        return mstatus;
    endfunction
endinstance
