import PGTypes::*;

import FetchStage::*;

(* synthesize *)
module mkFetchStage_tb(Empty);
    FetchStage fetchStage <- mkFetchStage;

    rule run;
        $display("PASS");
        $finish();
    endrule
endmodule
