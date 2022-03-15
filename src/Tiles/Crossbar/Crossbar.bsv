import PGTypes::*;
import SoCAddressMap::*;
import TileLink::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;

interface Crossbar;
    interface TileLinkLiteWordServer#(SizeOf#(TileId), SizeOf#(TileId), XLEN) systemMemoryBusServer;

    interface TileLinkLiteWordClient#(SizeOf#(TileId), SizeOf#(TileId), XLEN) clintClient;
    interface TileLinkLiteWordClient#(SizeOf#(TileId), SizeOf#(TileId), XLEN) uart0Client;
    interface TileLinkLiteWordClient#(SizeOf#(TileId), SizeOf#(TileId), XLEN) rom0Client;
    interface TileLinkLiteWordClient#(SizeOf#(TileId), SizeOf#(TileId), XLEN) ram0Client;
endinterface

module mkCrossbar#(
    SoCAddressMap socMap
)(Crossbar);
    FIFO#(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN)) systemMemoryBusRequests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) systemMemoryBusResponses <- mkFIFO;

    FIFO#(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN)) clintRequests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) clintResponses <- mkFIFO;

    FIFO#(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN)) uart0Requests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) uart0Responses <- mkFIFO;

    FIFO#(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN)) rom0Requests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) rom0Responses <- mkFIFO;

    FIFO#(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN)) ram0Requests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) ram0Responses <- mkFIFO;

    rule handleSystemMemoryBusRequests;
        // Get the request
        let request = systemMemoryBusRequests.first;
        systemMemoryBusRequests.deq;

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
            $display("ERROR: Crossbar rejecting memory request for address: $%0x", request.a_address);
            systemMemoryBusResponses.enq(TileLinkLiteWordResponse {
                d_opcode: d_ACCESS_ACK,
                d_param: 0,
                d_size: request.a_size,
                d_source: unpack(socMap.crossbarId),
                d_sink: request.a_source,
                d_denied: True,
                d_data: ?,
                d_corrupt: False
            });
        end
    endrule

    rule handleClintResponses;
        let response = clintResponses.first;
        clintResponses.deq;

        systemMemoryBusResponses.enq(response);
    endrule

    rule handleUart0Responses;
        let response = uart0Responses.first;
        uart0Responses.deq;

        systemMemoryBusResponses.enq(response);
    endrule

    rule handleROM0Responses;
        let response = rom0Responses.first;
        rom0Responses.deq;

        systemMemoryBusResponses.enq(response);
    endrule

    (* descending_urgency = 
        "handleSystemMemoryBusRequests, handleClintResponses, handleUart0Responses, handleROM0Responses, handleRAM0Responses" *)
    rule handleRAM0Responses;
        let response = ram0Responses.first;
        ram0Responses.deq;

        systemMemoryBusResponses.enq(response);
    endrule

    interface TileLinkLiteWordServer systemMemoryBusServer = toGPServer(systemMemoryBusRequests, systemMemoryBusResponses);
    interface TileLinkLiteWordClient clintClient = toGPClient(clintRequests, clintResponses);
    interface TileLinkLiteWordClient rom0Client = toGPClient(rom0Requests, rom0Responses);
    interface TileLinkLiteWordClient ram0Client = toGPClient(ram0Requests, ram0Responses);
    interface TileLinkLiteWordClient uart0Client = toGPClient(uart0Requests, uart0Responses);
endmodule
