import PGTypes::*;
import Exception::*;
import InstructionCommon::*;

//
// EncodedInstruction
//
// Structure holding a *encoded* RISC-V instruction. 
//
typedef struct {
    // instructionCommon - common instruction info
    InstructionCommon instructionCommon;

    // exception - exception encountered during fetch
    Maybe#(Exception) exception;
} EncodedInstruction deriving(Bits, Eq, FShow);
