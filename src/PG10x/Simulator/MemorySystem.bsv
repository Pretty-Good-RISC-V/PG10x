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
    interface TileLinkLiteWordServer#(XLEN) instructionMemoryServer;
    interface TileLinkLiteWordServer#(XLEN) dataMemoryServer;
endinterface

module mkMemorySystem#(
    ProgramMemoryTile memoryServer,
    Integer memoryBaseAddress
)(MemorySystem);
    Word baseAddress = fromInteger(memoryBaseAddress);

    interface TileLinkLiteWordServer instructionMemoryServer;
        interface Get response;
            method ActionValue#(TileLinkLiteWordResponse#(XLEN)) get;
                let response <- memoryServer.portA.response.get;
                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkLiteWordRequest#(XLEN) request);
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
            method ActionValue#(TileLinkLiteWordResponse#(XLEN)) get;
                let response <- memoryServer.portB.response.get;
                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkLiteWordRequest#(XLEN) request);
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
