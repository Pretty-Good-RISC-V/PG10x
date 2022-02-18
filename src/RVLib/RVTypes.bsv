`ifdef RV64
typedef 64 XLEN;
`elsif RV128
typedef 128 XLEN
`else
typedef 32 XLEN;
`endif

typedef Bit#(3) RVFunc3;  // Corresponds to the func3 instruction field.

//
// RVALUOperator(s)
//
typedef Bit#(10) RVALUOperator;
typedef enum {  // NOTE: These are decoded as the concat of func7 and func3
    ADD    = 10'b0000000000,
    SLL    = 10'b0000000001,
    SLT    = 10'b0000000010, 
    SLTU   = 10'b0000000011, 
    XOR    = 10'b0000000100,
    SRL    = 10'b0000000101,
    OR     = 10'b0000000110,
    AND    = 10'b0000000111,
`ifdef ISA_M
    MUL    = 10'b0000001000,
    MULH   = 10'b0000001001,
    MULHSU = 10'b0000001010,
    MULHU  = 10'b0000001011,
    DIV    = 10'b0000001100,
    DIVU   = 10'b0000001101,
    REM    = 10'b0000001110,
    REMU   = 10'b0000001111,
`endif
    SUB    = 10'b0100000000,
    SRA    = 10'b0100000101,
    UNSUPPORTED_ALU_OPERATOR = 10'b1111111111
} RVALUOperators deriving(Bits, Eq, FShow);

//
// RVBranchOperator(s)
//
typedef RVFunc3 RVBranchOperator;
typedef enum {
    BEQ  = 3'b000,
    BNE  = 3'b001,
    UNSUPPORTED_BRANCH_OPERATOR_010 = 3'b010,
    UNSUPPORTED_BRANCH_OPERATOR_011 = 3'b011,
    BLT  = 3'b100,
    BGE  = 3'b101,
    BLTU = 3'b110,
    BGEU = 3'b111
} RVBranchOperators deriving(Bits, Eq, FShow);

//
// RVCSROperator(s)
//
typedef RVFunc3 RVCSROperator;
typedef enum {
    UNSUPPORTED_CSR_OPERATOR_000 = 3'b000,
    CSRRW  = 3'b001,
    CSRRS  = 3'b010,
    CSRRC  = 3'b011,
    UNSUPPORTED_CSR_OPERATOR_100 = 3'b100,
    CSRRWI = 3'b101,
    CSRRSI = 3'b110,
    CSRRCI = 3'b111
} RVCSROperators deriving(Bits, Eq, FShow);

//
// RVExceptionCause(s)
//
typedef Bit#(TSub#(XLEN, 1)) RVExceptionCause;
typedef enum {
    INSTRUCTION_ADDRESS_MISALIGNED = 0,
    INSTRUCTION_ACCESS_FAULT = 1,
    ILLEGAL_INSTRUCTION = 2,
    BREAKPOINT = 3,
    LOAD_ADDRESS_MISALIGNED = 4,
    LOAD_ACCESS_FAULT = 5,
    STORE_ADDRESS_MISALIGNED = 6,
    STORE_ADDRESS_FAULT = 7,
    ENVIRONMENT_CALL_FROM_U_MODE = 8,
    ENVIRONMENT_CALL_FROM_S_MODE = 9,
    // RESERVED = 10
    ENVIRONMENT_CALL_FROM_M_MODE = 11,
    INSTRUCTION_PAGE_FAULT = 12,
    LOAD_PAGE_FAULT = 13,
    // RESERVED = 14,
    STORE_PAGE_FAULT = 15
    // RESERVED = 16-23
    // CUSTOM USE = 24-31
    // RESERVED = 32-47
    // CUSTOM USE = 48-63
    // RESERVED >= 64
} RVExceptionCauses deriving(Bits, Eq, FShow);

//
// RVInterruptCause(s)
//
typedef Bit#(TSub#(XLEN, 1)) RVInterruptCause;
typedef enum {
    // RESERVED = 0
    SUPERVISOR_SOFTWARE_INTERRUPT = 1,
    // RESERVED = 2
    MACHINE_SOFTWARE_INTERRUPT = 3,
    // RESERVED = 4,
    SUPERVISOR_TIMER_INTERRUPT = 5,
    // RESERVED = 6
    MACHINE_TIMER_INTERRUPT = 7,
    // RESERVED = 8,
    SUPERVISOR_EXTERNAL_INTERRUPT = 9,
    // RESERVED = 10
    MACHINE_EXTERNAL_INTERRUPT = 11
    // RESERVED = 12-15
    // PLATFORM RESERVED >= 16
} RVInterruptCauses deriving(Bits, Eq, FShow);

//
// RVLoadOperator(s)
//
typedef RVFunc3 RVLoadOperator;
typedef enum {
    LB  = 3'b000,
    LH  = 3'b001,
    LW  = 3'b010,
`ifdef RV32
    UNSUPPORTED_LOAD_OPERATOR_011 = 3'b011,
`elsif RV64
    LD = 3'b011,
`endif
    LBU = 3'b100,
    LHU = 3'b101,
`ifdef RV32
    UNSUPPORTED_LOAD_OPERATOR_110 = 3'b110,
`elsif RV64
    LWU = 3'b110,
`endif
    UNSUPPORTED_LOAD_OPERATOR_111 = 3'b111
} RVLoadOperators deriving(Bits, Eq, FShow);

//
// RVPrivilegeLevel
//
typedef enum {
    PRIVILEGE_LEVEL_USER        = 2'b00,
    PRIVILEGE_LEVEL_SUPERVISOR  = 2'b01,
    PRIVILEGE_LEVEL_HYPERVISOR  = 2'b10,
    PRIVILEGE_LEVEL_MACHINE     = 2'b11
} RVPrivilegeLevel deriving(Bits, Eq);

//
// RVStoreOoperator(s)
//
typedef RVFunc3 RVStoreOperator;
typedef enum {
    SB  = 3'b000,
    SH  = 3'b001,
    SW  = 3'b010,
`ifdef RV32
    UNSUPPORTED_STORE_OPERATOR_011 = 3'b011,
`elsif RV64
    SD = 3'b011,
`endif
    UNSUPPORTED_STORE_OPERATOR_100 = 3'b100,
    UNSUPPORTED_STORE_OPERATOR_101 = 3'b101,
    UNSUPPORTED_STORE_OPERATOR_110 = 3'b110,
    UNSUPPORTED_STORE_OPERATOR_111 = 3'b111
} RVStoreOperators deriving(Bits, Eq, FShow);

//
// RVSystemOperator(s)
//
typedef Bit#(3) RVSystemOperator;
typedef enum {
    ECALL,
    EBREAK,
    SRET,
    MRET,
    WFI,
    UNSUPPORTED_SYSTEM_OPERATOR
} RVSystemOperators deriving(Bits, Eq, FShow);
