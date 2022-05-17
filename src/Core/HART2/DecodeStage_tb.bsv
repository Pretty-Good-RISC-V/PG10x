import PGTypes::*;

import DecodeStage::*;
import GPRFile::*;

(* synthesize *)
module mkDecodeStage_tb(Empty);
    GPRFile gprFile <- mkGPRFile;
    DecodeStage decodeStage <- mkDecodeStage(gprFile);

    rule run;
        $display("PASS");
        $finish();
    endrule
endmodule
