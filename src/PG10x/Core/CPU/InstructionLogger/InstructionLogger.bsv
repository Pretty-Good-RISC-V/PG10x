import PGTypes::*;

interface InstructionLog;
    method Action logInstruction(Word programCounter, Word32 instruction);
endinterface

import "BDPI" function Action logInstructionFFI(Word programCounter, Word32 instruction);

module mkInstructionLog(InstructionLog);
    method Action logInstruction(Word programCounter, Word32 instruction);
        logInstructionFFI(programCounter, instruction);
    endmethod
endmodule
