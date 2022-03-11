import PGTypes::*;
import TileLink::*;

import Assert::*;
import ClientServer::*;
import FIFO::*;
import GetPut::*;

typedef 1 HARTSELLEN;

//
// Debug Module Interface (DMI) requests/responses
//
typedef TileLinkChannelARequest#(2, 1, 7, 4) DMIRequest;
typedef TileLinkChannelDResponse#(2, 1, 1, 4) DMIResponse;

typedef Client#(DMIRequest, DMIResponse) DMIClient;
typedef Server#(DMIRequest, DMIResponse) DMIServer;

typedef Bit#(7) DMIRegisterIndex;
DMIRegisterIndex dmcontrol  = 7'h10;
DMIRegisterIndex dmstatus   = 7'h11;
DMIRegisterIndex hartinfo   = 7'h12;

interface DebugModule;
    interface DMIServer dmiServer;
endinterface

module mkDebugModule(DebugModule);
    FIFO#(DMIResponse) responseQueue <- mkFIFO;

    // function Action write_dmcontrol(DMIRequest request);
    // endfunction

    // function ActionValue#(Word) read_dmcontrol(DMIRequest request);
    //     return 0;
    // endfunction

    function Action handleReadRequest(DMIRequest request);
        action
            dynamicAssert(request.a_opcode == a_GET, "Unexpected OPCODE");
            dynamicAssert(request.a_size == 2, "Only 32 bit datamrequests are supported");

            // case (request.a_address)
            //     dmcontrol: write_dmcontrol(request);
            // endcase
        endaction
    endfunction

    function Action handleWriteRequest(DMIRequest request);
        action
            dynamicAssert(request.a_opcode == a_PUT_FULL_DATA, "Unexpected OPCODE");
        endaction
    endfunction

    interface DMIServer dmiServer;
        interface Put request;
            method Action put(DMIRequest request);
                case (request.a_opcode)
                    a_GET: begin
                        handleReadRequest(request);
                    end

                    a_PUT_FULL_DATA: begin
                        handleWriteRequest(request);
                    end

                    default: begin
                        responseQueue.enq(DMIResponse{
                            d_opcode: d_ACCESS_ACK,
                            d_param: 0,
                            d_size: 0,
                            d_source: 0,
                            d_sink: request.a_source,
                            d_denied: True,
                            d_data: 0,
                            d_corrupt: False
                        });
                    end
                endcase
            endmethod
        endinterface

        interface Get response = toGet(responseQueue);
    endinterface
endmodule
