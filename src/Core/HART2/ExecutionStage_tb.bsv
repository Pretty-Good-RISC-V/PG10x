import PGTypes::*;

import ExecutionStage::*;

(* synthesize *)
module mkExecutionStage_tb(Empty);
    ExecutionStage executionStage <- mkExecutionStage;

    rule run;
        $display("PASS");
        $finish();
    endrule
endmodule
