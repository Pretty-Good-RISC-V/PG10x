import PGTypes::*;
import TileLink::*;

import BRAM::*;
import FIFO::*;

interface DualPortBRAMServerTile;
    interface TileLinkADServer32 portA;
    interface TileLinkADServer32 portB;

    method Integer getMemorySize();
endinterface

module mkBRAMServerTileFromFile#(
    Integer sizeInKb,
    String memoryContents
)(DualPortBRAMServerTile);
    BRAM_Configure cfg = defaultValue;
    cfg.memorySize = 1024 * sizeInKb;
    cfg.loadFormat = tagged Hex memoryContents;
    BRAM2PortBE#(Word32, Word32, 4) bram <- mkBRAM2ServerBE(cfg);

    FIFO#(TileLinkChannelARequest32) requests[2];
    requests[0] <- mkFIFO;
    requests[1] <- mkFIFO;

    FIFO#(TileLinkChannelDResponse32) responses[2];
    responses[0] <- mkFIFO;
    responses[1] <- mkFIFO;

    Reg#(Bool) lastRequestIsWrite[2];
    lastRequestIsWrite[0] <- mkReg(False);
    lastRequestIsWrite[1] <- mkReg(False);

    Reg#(Bool) requestInFlight[2];
    requestInFlight[0] <- mkReg(False);
    requestInFlight[1] <- mkReg(False);

    Word validAddressBits = fromInteger((1024 * sizeInKb) - 1);

    function Action handleBRAMRequest(BRAMServerBE#(Word32, Word32, 4) bramPort, Integer portNumber);
        action
        let request = requests[portNumber].first();
        requests[portNumber].deq;

        let wordAddress = request.a_address >> 2;
        let aligned = (request.a_address & 3) == 0 ? True : False;
        let oob = (request.a_address & ~validAddressBits) != 0;

        if (!oob && !request.a_corrupt && aligned && request.a_opcode == pack(A_GET)) begin
            bramPort.request.put(BRAMRequestBE {
                writeen: 0,
                responseOnWrite: False,
                address: wordAddress[31:0],
                datain: ?
            });
            lastRequestIsWrite[portNumber] <= False;
            requestInFlight[portNumber] <= True;
        end else if (!oob && !request.a_corrupt && aligned && request.a_opcode == pack(A_PUT_FULL_DATA)) begin
            bramPort.request.put(BRAMRequestBE {
                writeen: request.a_mask,
                responseOnWrite: True,
                address: wordAddress[31:0],
                datain: request.a_data
            });
            lastRequestIsWrite[portNumber] <= True;
            requestInFlight[portNumber] <= True;
        end else begin
            responses[portNumber].enq(TileLinkChannelDResponse32 {
                d_opcode: pack(D_ACCESS_ACK_DATA),
                d_param: 0,
                d_size: 0,
                d_source: 0,
                d_sink: 0,
                d_denied: True,
                d_data: ?,
                d_corrupt: request.a_corrupt
            });
        end
        endaction
    endfunction

    rule bramRequestA(!requestInFlight[0]);
        handleBRAMRequest(bram.portA, 0);
    endrule

    rule bramRequestB(!requestInFlight[1]);
        handleBRAMRequest(bram.portB, 1);
    endrule

    function Action handleBRAMResponse(BRAMServerBE#(Word32, Word32, 4) bramPort, Integer portNumber);
        action
        let response <- bramPort.response.get;
        Word32 data = extend(response);

        requestInFlight[portNumber] <= False;

        responses[portNumber].enq(TileLinkChannelDResponse32 {
            d_opcode: lastRequestIsWrite[portNumber] ? pack(D_ACCESS_ACK) : pack(D_ACCESS_ACK_DATA),
            d_param: 0,
            d_size: lastRequestIsWrite[portNumber] ? 0 : 1,
            d_source: 0,
            d_sink: 0,
            d_denied: False,
            d_data: lastRequestIsWrite[portNumber] ? 0 : data,
            d_corrupt: False
        });
        endaction
    endfunction

    rule bramResponseA(requestInFlight[0]);
        handleBRAMResponse(bram.portA, 0);
    endrule

    rule bramResponseB(requestInFlight[1]);
        handleBRAMResponse(bram.portB, 1);
    endrule

    interface TileLinkADServer32 portA;
        interface Get response;
            method ActionValue#(TileLinkChannelDResponse32) get;
                let response = responses[0].first();
                responses[0].deq;

                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkChannelARequest32 request);
                requests[0].enq(request);
            endmethod
        endinterface
    endinterface

    interface TileLinkADServer32 portB;
        interface Get response;
            method ActionValue#(TileLinkChannelDResponse32) get;
                let response = responses[1].first();
                responses[1].deq;

                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkChannelARequest32 request);
                requests[1].enq(request);
            endmethod
        endinterface
    endinterface

    method Integer getMemorySize;
        return 1024 * sizeInKb;
    endmethod
endmodule
