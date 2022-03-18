import PGTypes::*;
import Exception::*;
import PipelineController::*;

//
// Opcode - various (micro)operation codes available inside the CPU
//
typedef enum {
    // Arithmetic Logic Unit (ALU) operation.
    ALU,
`ifdef RV64
    // Arithmetic Logic Unit (ALU) operations (32 bit on 64bit ISA)
    ALU3264,
`endif

    // Conditional branch.
    BRANCH,

    // Copies immediate value to destination register (used by LUI and AUIPC instructions).
    COPY_IMMEDIATE,

    // Operations pertaining to Control Status Registers (CSRs)
    CSR,

    // Memory ordering (fences)
    FENCE,

    // Unconditional JUMP.
    JUMP,
    JUMP_INDIRECT,

    // Load register from memory.
    LOAD,

    // No-operation.
    NO_OP,

    // Store register to memory.
    STORE,

    // Perform system operation.
    SYSTEM,

    // Unsupported opcode (error case).
    UNSUPPORTED_OPCODE
} Opcode deriving(Bits, Eq, FShow);

//
// DecodedInstruction
//
// Structure holding the decoded representation of a RISC-V instruction.
//
typedef struct {
    // fetchIndex - Monotically increasing index of all instructions fetched.
    Word fetchIndex;

    // pipelineEpoch - Records which pipeline epoch corresponds to this instruction.
    PipelineEpoch pipelineEpoch;

    // programCounter - The program counter corresponding to this instruction.
    ProgramCounter programCounter;

    // rawInstruction - The raw 32 bit instruction.
    Word32 rawInstruction;

    // predictedNextProgramCounter - Contains the *predicted* program counter following this
    //                               instruction.
    ProgramCounter predictedNextProgramCounter;

    // opcode - Records which (micro)operation code corresponding to this instruction.
    Opcode opcode;

    // aluOperator - The ALU operator (if any) corresponding to this instruction (validity of this
    //               field is determined by 'opcode'.)
    RVALUOperator aluOperator;

    // loadOperator - The LOAD operator (if any) corresponding to this instruction  (validity of this
    //               field is determined by 'opcode'.)
    RVLoadOperator loadOperator;

    // storeOperator - The STORE operator (if any) corresponding to this instruction  (validity of this
    //                 field is determined by 'opcode'.)
    RVStoreOperator storeOperator;

    // branchOperator - The BRANCH operator (if any) corresponding to this instruction  (validity of this
    //                  field is determined by 'opcode'.)
    RVBranchOperator branchOperator;

    // systemOperator - The SYSTEM operator (if any) corresponding to this instruction  (validity of this
    //                  field is determined by 'opcode'.)
    RVSystemOperator systemOperator;

    // csrOperator - The CSR operator (if any) corresponding to this instruction  (validity of this
    //               field is determined by 'opcode'.)
    RVCSROperator csrOperator;

    // csrIndex - The CSR index corresponding to this instruction.
    RVCSRIndex csrIndex;

    // rd - The *destination* register (if any) corresponding to this instruction.
    Maybe#(RVGPRIndex) rd;

    // rs1 - The first *source* register (if any) corresponding to this instruction.
    Maybe#(RVGPRIndex) rs1;

    // rs2 - The second *source* register (if any) corresponding to this instruction.
    Maybe#(RVGPRIndex) rs2;

    // immediate - The immediate value (if any) corresponding to this instruction.
    Maybe#(Word) immediate;

    // rs1Value - The value held inside the first *source* register (validith of this is determined
    //            by the validity of the 'rs1' field.)
    Word rs1Value;

    // rs2Value - The value held inside the second *source* register (validith of this is determined
    //            by the validity of the 'rs2' field.)
    Word rs2Value;

    // exception - Any exception detected in the decode (or previous) stages
    Maybe#(Exception) exception;
} DecodedInstruction deriving(Bits, Eq, FShow);
