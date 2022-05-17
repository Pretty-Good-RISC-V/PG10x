import PGTypes::*;

import WritebackStage::*;
import GPRFile::*;

(* synthesize *)
module mkWritebackStage_tb(Empty);
    GPRFile gprFile <- mkGPRFile;
    WritebackStage writebackStage <- mkWritebackStage(gprFile);

    rule run;
        $display("PASS");
        $finish();
    endrule
endmodule
