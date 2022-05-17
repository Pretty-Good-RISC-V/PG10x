import PGTypes::*;

import HART::*;

(* synthesize *)
module mkHART_tb(Empty);
    HART hart <- mkHART;

    rule run;
        $display("PASS");
        $finish();
    endrule
endmodule
