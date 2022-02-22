import PGTypes::*;
import TileLink::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;

interface ProgramMemoryTile;
    interface TileLinkADServer32 portA;
    interface TileLinkADServer32 portB;

    method Bool isValidAddress(Word32 address);
endinterface

typedef Word32 ContextHandle;

//
// Imports from C++
//
import "BDPI" function ContextHandle program_memory_open();
import "BDPI" function void program_memory_close(ContextHandle ctx);
import "BDPI" function Word32 program_memory_read(ContextHandle ctx, Word32 address);
import "BDPI" function void program_memory_write(ContextHandle ctx, Word32 address, Word32 value, Word32 write_mask);
import "BDPI" function Bool program_memory_is_valid_address(ContextHandle ctx, Word32 address);

module mkProgramMemoryTile(ProgramMemoryTile);
    Word32 programMemoryContext = program_memory_open();

    FIFO#(TileLinkChannelARequest32) requests[2];
    requests[0] <- mkFIFO;
    requests[1] <- mkFIFO;

    FIFO#(TileLinkChannelDResponse32) responses[2];
    responses[0] <- mkFIFO;
    responses[1] <- mkFIFO;

    Reg#(Bool) requestInFlight[2];
    requestInFlight[0] <- mkReg(False);
    requestInFlight[1] <- mkReg(False);

    function Action handleRequest(Integer portNumber);
        action
        let request = requests[portNumber].first();
        requests[portNumber].deq;

        let wordAddress = request.a_address >> 2;
        let aligned = (request.a_address & 3) == 0 ? True : False;
        let addressValid = program_memory_is_valid_address(programMemoryContext, request.a_address);

        if (addressValid && !request.a_corrupt && aligned && request.a_opcode == pack(A_GET)) begin
            let value = program_memory_read(programMemoryContext, wordAddress);

            responses[portNumber].enq(TileLinkChannelDResponse32 {
                d_opcode: pack(D_ACCESS_ACK_DATA),
                d_param: 0,
                d_size: fromInteger(valueOf(TLog#(4))),
                d_source: 0,
                d_sink: 0,
                d_denied: False,
                d_data: ?,
                d_corrupt: False
            });
        
            requestInFlight[portNumber] <= True;
        end else if (addressValid && !request.a_corrupt && aligned && request.a_opcode == pack(A_PUT_FULL_DATA)) begin
            responses[portNumber].enq(TileLinkChannelDResponse32 {
                d_opcode: pack(D_ACCESS_ACK),
                d_param: 0,
                d_size: fromInteger(valueOf(TLog#(4))),
                d_source: 0,
                d_sink: 0,
                d_denied: False,
                d_data: request.a_data,
                d_corrupt: False
            });
        
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

    rule requestA(!requestInFlight[0]);
        handleRequest(0);
    endrule

    rule requestB(!requestInFlight[1]);
        handleRequest(1);
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

    method Bool isValidAddress(Word address);
        return program_memory_is_valid_address(programMemoryContext, address);
    endmethod
endmodule
