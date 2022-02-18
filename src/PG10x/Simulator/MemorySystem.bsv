import PGTypes::*;
import TileLink::*;
import MemoryInterfaces::*;
import BRAMServerTile::*;

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
    interface InstructionMemoryServer instructionMemory;
    interface DataMemoryServer dataMemory;
endinterface

module mkMemorySystem#(
    DualPortBRAMServerTile memoryServer,
    Integer memoryBaseAddress
)(MemorySystem);
    Word baseAddress = fromInteger(memoryBaseAddress);
    Word highMemoryAddress = baseAddress + fromInteger(memoryServer.getMemorySize);

`ifdef RV64
    FIFO#(DataMemoryRequest) rv64requestQueue <- mkFIFO;
    FIFO#(DataMemoryResponse) rv64responseQueue <- mkFIFO;

    Reg#(Maybe#(DataMemoryRequest)) requestInFlight <- mkReg(tagged Invalid);

    Reg#(Maybe#(TileLinkChannelDResponse32)) lower32Response <- mkReg(tagged Invalid);

    rule bramRequestHandler(!isValid(requestInFlight));
        let request = rv64requestQueue.first();
        rv64requestQueue.deq();

        requestInFlight <= tagged Valid request;

        // Send the first request to the memory server.
        memoryServer.portB.request.put(TileLinkChannelARequest32 {
            a_opcode: request.a_opcode,
            a_param: request.a_param,
            a_size: request.a_size,
            a_source: request.a_source,
            a_address: request.a_address,
            a_mask: request.a_mask[3:0],    // lower four mask bits
            a_data: request.a_data[31:0],   // lower 32 bits of data
            a_corrupt: request.a_corrupt
        });
    endrule

    rule bramResponseHandler(isValid(requestInFlight));
        let response <- memoryServer.portB.response.get;
        let request = unJust(requestInFlight);

        //
        // If a response to the lower 32 bit request hasn't
        // been received yet, store that response and send
        // the request for the upper 32 bits.
        if (isValid(lower32Response) == False) begin
            // Remember the response and send the request
            // for the upper 32 bits
            lower32Response <= tagged Valid response;

            memoryServer.portB.request.put(TileLinkChannelARequest32 {
                a_opcode: request.a_opcode,
                a_param: request.a_param,
                a_size: request.a_size,
                a_source: request.a_source,
                a_address: request.a_address + 4,
                a_mask: request.a_mask[7:4],     // upper four mask bits
                a_data: request.a_data[63:32],   // upper 32 bits of data
                a_corrupt: request.a_corrupt
            });
        end else begin
            // Received the response to the upper 32 bits
            let lower32bits = unJust(lower32Response);

            //
            // Combine the lower 32 and upper 32 bits into a
            // single response to the client
            //
            rv64responseQueue.enq(DataMemoryResponse {
                d_opcode: response.d_opcode,
                d_param: response.d_param,
                d_size: response.d_size,
                d_source: response.d_source,
                d_sink: response.d_sink,
                d_denied: (response.d_denied || lower32bits.d_denied),
                d_data: {response.d_data, lower32bits.d_data},
                d_corrupt: (response.d_corrupt || lower32bits.d_corrupt)
            });

            lower32Response <= tagged Invalid;
            requestInFlight <= tagged Invalid;
        end
    endrule
`endif

    interface InstructionMemoryServer instructionMemory;
        interface Get response;
            method ActionValue#(InstructionMemoryResponse) get;
                let response <- memoryServer.portA.response.get();
                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(InstructionMemoryRequest request);
                if (request.a_address >= baseAddress && 
                    request.a_address < highMemoryAddress) begin
                    request.a_address = request.a_address - baseAddress;
                end else begin
                    request.a_corrupt = True;
                end
                memoryServer.portA.request.put(request);                
            endmethod
        endinterface
    endinterface

    interface DataMemoryServer dataMemory;
        interface Get response;
            method ActionValue#(DataMemoryResponse) get;
`ifdef RV32
                let response <- memoryServer.portB.response.get;
                return response;
`else
                let response = rv64responseQueue.first;
                rv64responseQueue.deq;
                return response;
`endif
            endmethod
        endinterface

        interface Put request;
            method Action put(DataMemoryRequest request);
                if (request.a_address >= baseAddress && 
                    request.a_address < highMemoryAddress) begin
                    request.a_address = request.a_address - baseAddress;
                end else begin
                    request.a_corrupt = True;
                end

`ifdef RV64
                rv64requestQueue.enq(request);
`else
                memoryServer.portB.request.put(request);
`endif
            endmethod
        endinterface
    endinterface
endmodule
