import PGTypes::*;

import MemoryStage::*;
import GPRFile::*;

(* synthesize *)
module mkMemoryStage_tb(Empty);
    MemoryStage memoryStage <- mkMemoryStage;

    rule run;
        $display("PASS");
        $finish();
    endrule
endmodule
