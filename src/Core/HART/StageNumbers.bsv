typedef 1 FetchStageNumber;
typedef 2 DecodeStageNumber;
typedef 3 ExecutionStageNumber;
typedef 4 MemoryAccessStageNumber;
typedef 5 WritebackStageNumber;

function String stageName(Integer stageNumber);
    return case(stageNumber)
        1: "fetch";
        2: "decode";
        3: "execute";
        4: "memory";
        5: "writeback";
    endcase;
endfunction
