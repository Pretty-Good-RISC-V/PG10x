import HART::*;
import InstructionCache::*;

interface PG10xCore;
    interface TileLinkLiteWordClient#(XLEN) systemBusClient;
    interface Debug debug;
endinterface

module mkPG10xCore#(
    ProgramCounter initialProgramCounter,
`ifdef MONITOR_TOHOST_ADDRESS
    Word toHostAddress,
`endif
    Bool disablePipelining
)(PG10xCore);
    HART hart = mkHART(
        initialProgramCounter,
`ifdef MONITOR_TOHOST_ADDRESS
        toHostAddress,
`endif
        disablePipelining        
    );

    InstructionCache_Configure icacheConfig = defaultValue;
    InstructionCache icache <- mkDirectMappedInstructionCache(icacheConfig);

    // 
    // System Bus Requests/Responses
    //
    FIFO#(TileLinkLiteWordRequests) systemBusRequests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponses) systemBusResponses <- mkFIFO;

    mkConnection(icache.cpuInterface, core.instructionMemoryClient);

    interface TileLinkLiteWordClient systemBusClient = toGPClient(systemBusRequests, systemBusResponses);
    interface Debug debug = hart.debug;
endmodule
