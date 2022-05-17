import PGTypes::*;

typedef struct {
    ProgramCounter programCounter;      // PC of this instruction
    ProgramCounter nextProgramCounter;  // PC of the next instruction
    Word32 rawInstruction;
} PipelineCommon deriving(Bits, Eq, FShow);

typedef struct {
    ProgramCounter branchTarget;    // from ID_EX
    Bool branchTaken;               // from EX
} IDEX_IF deriving(Bits, Eq, FShow);

typedef struct {
    PipelineCommon pcommon;
} IF_ID deriving(Bits, Eq, FShow);

typedef struct {
    PipelineCommon pcommon;
    ProgramCounter branchTarget;

    Word arg1;
    Word arg2;
    Word immediate;
} ID_EX deriving(Bits, Eq, FShow);

typedef struct {
    PipelineCommon pcommon;
    Maybe#(Word) aluOutput;  // OP/OP-IMM result
    Word arg2;
} EX_MEM deriving(Bits, Eq, FShow);

typedef struct {
    PipelineCommon pcommon;
    Maybe#(Word) writebackValue; // ALU output, LOAD value, etc.
} MEM_WB deriving(Bits, Eq, FShow);
