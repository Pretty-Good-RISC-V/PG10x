import PGTypes::*;
import ProgramMemoryTile::*;
import TileLink::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;

export MemorySystem(..), 
       mkMemorySystem, 
       TileLink::*,
       ClientServer::*,
       GetPut::*;

interface MemorySystem;
    interface TileLinkLiteWordServer#(SizeOf#(TileId), SizeOf#(TileId), XLEN) instructionMemoryServer;
    interface TileLinkLiteWordServer#(SizeOf#(TileId), SizeOf#(TileId), XLEN) dataMemoryServer;
endinterface

module mkMemorySystem#(
    ProgramMemoryTile memoryServer,
    FabricAddress memoryBaseAddress
)(MemorySystem);
    interface TileLinkLiteWordServer instructionMemoryServer;
        interface Get response;
            method ActionValue#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) get;
                let response <- memoryServer.portA.response.get;
                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN) request);
                if (memoryServer.isValidAddress(request.a_address)) begin
                    request.a_address = request.a_address;
                end else begin
                    request.a_corrupt = True;
                end
                memoryServer.portA.request.put(request);                
            endmethod
        endinterface
    endinterface

    interface TileLinkLiteWordServer dataMemoryServer;
        interface Get response;
            method ActionValue#(TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN)) get;
                let response <- memoryServer.portB.response.get;
                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN) request);
                if (memoryServer.isValidAddress(request.a_address)) begin
                    request.a_address = request.a_address;
                end else begin
                    request.a_corrupt = True;
                end

                memoryServer.portB.request.put(request);
            endmethod
        endinterface
    endinterface
endmodule

module mkSystemMemory#(
    ProgramMemoryTile memoryServer,
    Integer memoryBaseAddress
)(TileLinkLiteWordServer#(SizeOf#(TileId), SizeOf#(TileId), XLEN));
    Word baseAddress = fromInteger(memoryBaseAddress);

    interface Get response = memoryServer.portA.response;

    interface Put request;
        method Action put(TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN) request);
            if (memoryServer.isValidAddress(request.a_address)) begin
                request.a_address = request.a_address;
            end else begin
                request.a_corrupt = True;
            end
            memoryServer.portA.request.put(request);                
        endmethod
    endinterface
endmodule
