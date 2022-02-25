import PGTypes::*;
import TileLink::*;
import MemoryInterfaces::*;
import ProgramMemoryTile::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;

export MemorySystem(..), 
       mkMemorySystem, 
       MemoryInterfaces::*,
       TileLink::*,
       ClientServer::*,
       GetPut::*;

interface MemorySystem;
    interface TileLinkLiteWordServer instructionMemory;
    interface TileLinkLiteWordServer dataMemory;
endinterface

module mkMemorySystem#(
    ProgramMemoryTile memoryServer,
    Integer memoryBaseAddress
)(MemorySystem);
    Word baseAddress = fromInteger(memoryBaseAddress);

    interface TileLinkLiteWordServer instructionMemory;
        interface Get response;
            method ActionValue#(TileLinkLiteWordResponse) get;
                let response <- memoryServer.portA.response.get();
                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkLiteWordRequest request);
                if (memoryServer.isValidAddress(request.a_address)) begin
                    request.a_address = request.a_address - baseAddress;
                end else begin
                    request.a_corrupt = True;
                end
                memoryServer.portA.request.put(request);                
            endmethod
        endinterface
    endinterface

    interface TileLinkLiteWordServer dataMemory;
        interface Get response;
            method ActionValue#(TileLinkLiteWordResponse) get;
                let response <- memoryServer.portB.response.get;
                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkLiteWordRequest request);
                if (memoryServer.isValidAddress(request.a_address)) begin
                    request.a_address = request.a_address - baseAddress;
                end else begin
                    request.a_corrupt = True;
                end

                memoryServer.portB.request.put(request);
            endmethod
        endinterface
    endinterface
endmodule
