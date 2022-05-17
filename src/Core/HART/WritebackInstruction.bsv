import PGTypes::*;

import Exception::*;
import ExecutedInstruction::*;

import InstructionCommon::*;

typedef struct {
    InstructionCommon instructionCommon;
    Maybe#(Exception) exception;
    Result#(GPRWriteback, Exception) gprWriteback;
    Result#(CSRWriteback, Exception) csrWriteback;
} WritebackInstruction deriving(Bits, Eq, FShow);
