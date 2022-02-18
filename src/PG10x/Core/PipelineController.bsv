//
// PipelineController
//
// This module is responsible for handling pipeline operations.  It's used by various stages
// to determine if their configure epoch is current.
//
import PGTypes::*;
import List::*;

typedef Bit#(1) PipelineEpoch;

interface PipelineController;
    method PipelineEpoch stageEpoch(Integer stageIndex, Integer portNumber);
    method Bool isCurrentEpoch(Integer stageIndex, Integer portNumber, PipelineEpoch check);
    method Action flush(Integer portNumber);
endinterface

module mkPipelineController#(
    Integer stageCount
)(PipelineController);
    List#(Array#(Reg#(PipelineEpoch))) stageEpochs <- replicateM(stageCount, mkCReg(3, 0));
 
    method PipelineEpoch stageEpoch(Integer stageIndex, Integer portNumber);
        return stageEpochs[stageIndex][portNumber];
    endmethod

    method Bool isCurrentEpoch(Integer stageIndex, Integer portNumber, PipelineEpoch check);
        return (check == stageEpochs[stageIndex][portNumber]);
    endmethod

    method Action flush(Integer portNumber);
        for (Integer i = 0; i < stageCount; i = i + 1) begin
            stageEpochs[i][portNumber] <= stageEpochs[i][portNumber] + 1; 
        end
    endmethod
endmodule
