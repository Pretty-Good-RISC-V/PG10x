import PGTypes::*;

import "BDPI" function Action logInstructionFFI(Word programCounter, Word32 instruction);

function Action logInstruction(ProgramCounter programCounter, Word32 instruction);
    action
        logInstructionFFI(programCounter, instruction);
    endaction
endfunction
