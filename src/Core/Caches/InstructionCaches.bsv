import PGTypes::*;
import TileLink::*;

import Assert::*;
import ClientServer::*;
import FIFO::*;
import GetPut::*;
import Vector::*;

interface InstructionCache;
    interface Put#(Maybe#(StdTileLinkRequest)) putInstructionCacheRequest;
    interface Get#(StdTileLinkResponse) getInstructionCacheResponse;

    // systemMemoryClient - client to main system memory bus.
    interface StdTileLinkClient systemMemoryClient;
endinterface

module mkSingleLineInstructionCache(InstructionCache);
    Vector#(16, Reg#(Word32)) line <- replicateM(mkRegU);
    Reg#(Maybe#(Word)) lineTag <- mkReg(tagged Invalid);

    RWire#(StdTileLinkRequest) instructionCacheRequest <- mkRWire;
    FIFO#(StdTileLinkResponse) instructionCacheResponses <- mkFIFO;

    FIFO#(StdTileLinkRequest) systemMemoryRequests <- mkFIFO;
    FIFO#(StdTileLinkResponse) systemMemoryResponses <- mkFIFO;

    function Word getTag(Word address);
        return {address[valueOf(XLEN) - 1:6], 6'b0};
    endfunction

    Reg#(Bool) filling <- mkReg(False);
    Reg#(Bool) fillRequested <- mkReg(False);
    Reg#(Bit#(5)) fillOffset <- mkRegU; // 1 extra bit to allow for checking against 16

    Reg#(StdTileLinkResponse) delayedResponse <- mkRegU;
    Reg#(Bit#(4)) delayedResponseOffset <- mkRegU;

    rule handleFillRequest(filling == True && fillRequested == False);
        if (fillOffset < 16) begin
            let lt = unJust(lineTag);
            Word address = {lt[valueOf(XLEN) - 1:6], fillOffset[3:0], 2'b0};
            let request = StdTileLinkRequest {
                a_opcode: a_GET,
                a_param: 0,
                a_size: 2,
                a_source: ?,
                a_address: address,
                a_data: ?,
                a_mask: 'b1111,
                a_corrupt: False
            };

            fillRequested <= True;
            systemMemoryRequests.enq(request);
        end else begin
            // Fill complete.
            $display("Cache fill complete");

            filling <= False;
            fillRequested <= False;

            let response = delayedResponse;
            response.d_opcode = d_ACCESS_ACK_DATA;
            response.d_data = extend(line[delayedResponseOffset]);
            response.d_denied = False;

            instructionCacheResponses.enq(response);
        end
    endrule

    rule handleFillResponse(filling == True && fillRequested == True);
        let response <- pop(systemMemoryResponses);

        if (response.d_denied || response.d_corrupt) begin
            dynamicAssert(response.d_opcode == d_ACCESS_ACK, "");
            let dr = delayedResponse;
            dr.d_opcode = d_ACCESS_ACK;
            dr.d_data = 0;
            dr.d_denied = response.d_denied;
            dr.d_corrupt = response.d_corrupt;

            instructionCacheResponses.enq(dr);

            lineTag <= tagged Invalid;
            filling <= False;
            fillRequested <= False;
        end else begin
            line[fillOffset] <= response.d_data[31:0];

            let lt = unJust(lineTag);
            Word address = {lt[valueOf(XLEN) - 1:6], fillOffset[3:0], 2'b0};

            $display("Cache fill received for $%0x = $%0x", address, response.d_data[31:0]);

            fillOffset <= fillOffset + 1;
            fillRequested <= False;
        end
    endrule

    rule handleInstructionCacheRequests(filling == False);
        if (instructionCacheRequest.wget matches tagged Valid .request) begin
            let response = StdTileLinkResponse {
                d_opcode: d_ACCESS_ACK,
                d_param: 0,
                d_source: 15,
                d_sink: request.a_source,
                d_size: 2,
                d_denied: True,
                d_data: ?,
                d_corrupt: False
            };

            $display("I$ Request for $%0x", request.a_address);

            if (request.a_opcode == a_GET) begin
                let requestTag = getTag(request.a_address);
                let offset = request.a_address[5:2]; // ignore bottom two bits since a word address is needed.

                if (lineTag matches tagged Valid .tag &&& tag == requestTag) begin
                    // Tags match, no need to fill.
                    $display("$%0x hit for tag $%0x", request.a_address, tag);

                    response.d_opcode = d_ACCESS_ACK_DATA;
                    response.d_data = extend(line[offset]);
                    response.d_denied = False;

                    instructionCacheResponses.enq(response);                
                end else begin
                    // Tags don't match - request line fill
                    lineTag <= tagged Valid requestTag;
                    filling <= True;
                    fillOffset <= 0; 

                    delayedResponse <= response;
                    delayedResponseOffset <= offset;
                end
            end
        end
    endrule

    interface Put putInstructionCacheRequest;
        method Action put(Maybe#(StdTileLinkRequest) request);
            if (request matches tagged Valid .r) begin
                instructionCacheRequest.wset(r);
            end
        endmethod
    endinterface

    interface Get getInstructionCacheResponse = toGet(instructionCacheResponses);

    interface StdTileLinkClient systemMemoryClient = toGPClient(systemMemoryRequests, systemMemoryResponses);
endmodule
