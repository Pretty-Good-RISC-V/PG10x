import PGTypes::*;

import "BDPI" function Action logInstructionFFI(Word programCounter, Word32 instruction);

function Action logRawInstruction(ProgramCounter programCounter, Word32 instruction);
    action
        logInstructionFFI(programCounter, instruction);
    endaction
endfunction
