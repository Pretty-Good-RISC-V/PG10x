import PGTypes::*;
import SoCMap::*;
import TileLink::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;

interface Crossbar;
    interface TileLinkLiteWordServer#(SizeOf#(TileId), SizeOf#(TileId), XLEN) cpu;

    interface TileLinkLiteWordClient#(SizeOf#(TileId), SizeOf#(TileId), XLEN) clint;
    interface TileLinkLiteWordClient#(SizeOf#(TileId), SizeOf#(TileId), XLEN) uart0;
    interface TileLinkLiteWordClient#(SizeOf#(TileId), SizeOf#(TileId), XLEN) rom0;
    interface TileLinkLiteWordClient#(SizeOf#(TileId), SizeOf#(TileId), XLEN) ram0;
endinterface

module mkCrossbar#(
    TileId tileId
)(Crossbar);
    SoCMap socMap <- mkSoCMap;

    FIFO#(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN)) cpuRequests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) cpuResponses <- mkFIFO;

    FIFO#(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN)) clintRequests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) clintResponses <- mkFIFO;

    FIFO#(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN)) uart0Requests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) uart0Responses <- mkFIFO;

    FIFO#(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN)) rom0Requests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) rom0Responses <- mkFIFO;

    FIFO#(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN)) ram0Requests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) ram0Responses <- mkFIFO;

    rule handleCPURequests;
        // Get the request
        let request = cpuRequests.first;
        cpuRequests.deq;

        // Determine how to route the request
        if (request.a_address >= socMap.clintBase && request.a_address < socMap.clintEnd) begin
            clintRequests.enq(request);
        end else 
        if (request.a_address >= socMap.uart0Base && request.a_address < socMap.uart0End) begin
            uart0Requests.enq(request);
        end else
        if (request.a_address >= socMap.rom0Base && request.a_address < socMap.rom0End) begin
            rom0Requests.enq(request);
        end else
        if (request.a_address >= socMap.ram0Base && request.a_address < socMap.ram0End) begin
            ram0Requests.enq(request);
        end else begin
            cpuResponses.enq(TileLinkLiteWordResponse {
                d_opcode: d_ACCESS_ACK,
                d_param: 0,
                d_size: request.a_size,
                d_source: unpack(tileId),
                d_sink: request.a_source,
                d_denied: True,
                d_data: ?,
                d_corrupt: False
            });
        end
    endrule

    interface TileLinkLiteWordServer cpu = toGPServer(cpuRequests, cpuResponses);
    interface TileLinkLiteWordClient clint = toGPClient(clintRequests, clintResponses);
    interface TileLinkLiteWordClient rom0 = toGPClient(rom0Requests, rom0Responses);
    interface TileLinkLiteWordClient ram0 = toGPClient(ram0Requests, ram0Responses);
    interface TileLinkLiteWordClient uart0 = toGPClient(uart0Requests, uart0Responses);
endmodule
