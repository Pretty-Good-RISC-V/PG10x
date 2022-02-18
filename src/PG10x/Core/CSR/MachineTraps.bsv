import MachineStatus::*;

export MachineTrapSetup(..), MachineTraps(..), mkMachineTrapRegisters;

typedef enum {
    EXTENSION_A = 'h000001,     // Atomic extension
    EXTENSION_B = 'h000002,     // Tentatively reserved for Bit-Manipulation extension
    EXTENSION_C = 'h000004,     // Compressed extension
    EXTENSION_D = 'h000008,     // Double-precision floating-point extension
    EXTENSION_E = 'h000010,     // RV32E base ISA
    EXTENSION_F = 'h000020,     // Single-precision floating-point extension
    EXTENSION_G = 'h000040,     // __ RESERVED __
    EXTENSION_H = 'h000080,     // Hypervisor extension
    EXTENSION_I = 'h000100,     // RV32I/64I/128I base ISA
    EXTENSION_J = 'h000200,     // Tentatively reserved for Dynamically Translated Languages extension
    EXTENSION_K = 'h000400,     // __ RESERVED __
    EXTENSION_L = 'h000800,     // __ RESERVED __
    EXTENSION_M = 'h001000,     // Integer Multiply/Divide extension
    EXTENSION_N = 'h002000,     // Tentatively reserved for User-Level Interrupts extension
    EXTENSION_O = 'h004000,     // __ RESERVED __
    EXTENSION_P = 'h008000,     // Tentatively reserved for Packed-SIMD extension
    EXTENSION_Q = 'h010000,     // Quad-precision floating-point extension
    EXTENSION_R = 'h020000,     // __ RESERVED __
    EXTENSION_S = 'h040000,     // Supervisor mode implemented
    EXTENSION_T = 'h080000,     // __ RESERVED __
    EXTENSION_U = 'h100000,     // User mode implemented
    EXTENSION_V = 'h200000,     // Tentatively reserved for Vector extension
    EXTENSION_W = 'h400000,     // __ RESERVED __
    EXTENSION_X = 'h800000      // Non-standard extensions present
} Extensions deriving(Bits, Eq);

interface MachineTrapSetup;
    interface MachineStatus machineStatus;
endinterface

// interface MachineTrapHandling;
// endinterface

interface MachineTraps;
    interface MachineTrapSetup setup;
//    interface MachineTrapHandling handling;
endinterface

(* synthesize *)
module mkMachineTrapRegisters(MachineTraps);
    MachineStatus ms <- mkMachineStatusRegister();

    interface MachineTrapSetup setup;
        interface MachineStatus machineStatus = ms;
    endinterface
endmodule
