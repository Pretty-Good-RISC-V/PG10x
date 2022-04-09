import PGTypes::*;
import Debug::*;
import HART::*;
import ReadOnly::*;
import TileLink::*;

import Assert::*;
import ClientServer::*;
import Connectable::*;
import FIFO::*;
import GetPut::*;

export Core(..), mkCore, HART::*;

interface Core;
    method Action start;
    method HARTState getState;

    interface StdTileLinkClient systemMemoryBusClient;

    interface Put#(Bool) putPipeliningEnabled;

    interface Debug debug;

    interface Get#(Maybe#(MemoryAccess)) getMemoryAccess;

`ifdef ENABLE_ISA_TESTS
    interface Put#(Maybe#(Word)) putToHostAddress;
`endif

`ifdef ENABLE_RISCOF_TESTS
    interface Get#(Bool) getRISCOFHaltRequested;
`endif

endinterface

module mkCore#(
    ProgramCounter initialProgramCounter
)(Core);
    //
    // HART
    //
`ifdef ENABLE_ISA_TESTS
    ReadOnly#(Maybe#(Word)) toHostAddress <- mkReadOnly(tagged Valid 'h8000_1000);
`endif
    HART hart <- mkHART(initialProgramCounter);

    FIFO#(StdTileLinkRequest) instructionMemoryRequests <- mkFIFO;
    FIFO#(StdTileLinkResponse) instructionMemoryResponses <- mkFIFO;

    FIFO#(StdTileLinkRequest) dataMemoryRequests <- mkFIFO;
    FIFO#(StdTileLinkResponse) dataMemoryResponses <- mkFIFO;

    mkConnection(toGPServer(instructionMemoryRequests, instructionMemoryResponses), hart.instructionMemoryClient);
    mkConnection(toGPServer(dataMemoryRequests, dataMemoryResponses), hart.dataMemoryClient);

    FIFO#(StdTileLinkRequest) systemBusRequests <- mkFIFO;
    FIFO#(StdTileLinkResponse) systemBusResponses <- mkFIFO;

    rule handleInstructionMemoryRequests;
        let request <- pop(instructionMemoryRequests);

        request.a_source = 0;   // Instruction Memory
        systemBusRequests.enq(request);
    endrule

    rule handleDataMemoryRequests;
        let request <- pop(dataMemoryRequests);

        request.a_source = 1;   // Data Memory
        systemBusRequests.enq(request);
    endrule

    (* descending_urgency = "handleInstructionMemoryRequests, handleDataMemoryRequests" *)
    rule handleSystemBusResponses;
        let response <- pop(systemBusResponses);
        
        if (response.d_sink == 0) begin
            instructionMemoryResponses.enq(response);
        end else 
        if (response.d_sink == 1) begin
            dataMemoryResponses.enq(response);
        end else begin
            dynamicAssert(False, "Unexpected .d_sink value");
        end
    endrule

    method Action start = hart.start;
    method HARTState getState = hart.getState;
    interface TileLinkLiteWordClient systemMemoryBusClient = toGPClient(systemBusRequests, systemBusResponses);
    interface Put putPipeliningEnabled = hart.putPipeliningEnabled;
    interface Debug debug = hart.debug;

    interface Get getMemoryAccess = hart.getMemoryAccess;

`ifdef ENABLE_ISA_TESTS
    interface Put putToHostAddress = hart.putToHostAddress;
`endif

`ifdef ENABLE_RISCOF_TESTS
    interface Get getRISCOFHaltRequested = hart.getRISCOFHaltRequested;
`endif

endmodule
