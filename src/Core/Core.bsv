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

    interface Put#(Bool) putPipeliningDisabled;
    interface Put#(Maybe#(Word)) putToHostAddress;

    interface Debug debug;

`ifdef ENABLE_RISCOF_TESTS
    interface Put#(Word) putSignatureBeginAddress;
    interface Put#(Word) putSignatureEndAddress;
`endif    

endinterface

module mkCore#(
    ProgramCounter initialProgramCounter
)(Core);
    //
    // HART
    //
    ReadOnly#(Maybe#(Word)) toHostAddress <- mkReadOnly(tagged Valid 'h8000_1000);

`ifdef DISABLE_PIPELINING
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(False);
`else
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(True);
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
    interface Put putPipeliningDisabled = hart.putPipeliningDisabled;
    interface Put putToHostAddress = hart.putToHostAddress;
    interface Debug debug = hart.debug;

`ifdef ENABLE_RISCOF_TESTS
    interface Put putSignatureBeginAddress = hart.putSignatureBeginAddress;
    interface Put putSignatureEndAddress = hard.putSignatureEndAddress;
`endif

endmodule
