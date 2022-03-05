import PGTypes::*;
import MemoryInterfaces::*;
import TileLink::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;

interface ProgramMemoryTile;
    interface TileLinkLiteWordServer portA;
    interface TileLinkLiteWordServer portB;

    method Bool isValidAddress(Word address);
endinterface

typedef Word32 ContextHandle;

//
// Imports from C++
//
import "BDPI" function ContextHandle program_memory_open();
import "BDPI" function void program_memory_close(ContextHandle ctx);
import "BDPI" function Bool program_memory_is_valid_address(ContextHandle ctx, Word address);
import "BDPI" function Bit#(8) program_memory_read_u8(ContextHandle ctx, Word address);
import "BDPI" function Bit#(16) program_memory_read_u16(ContextHandle ctx, Word address);
import "BDPI" function Bit#(32) program_memory_read_u32(ContextHandle ctx, Word address);
import "BDPI" function Bit#(64) program_memory_read_u64(ContextHandle ctx, Word address);
import "BDPI" function void program_memory_write_u8(ContextHandle ctx, Word address, Bit#(8) newValue);
import "BDPI" function void program_memory_write_u16(ContextHandle ctx, Word address, Bit#(16) newValue);
import "BDPI" function void program_memory_write_u32(ContextHandle ctx, Word address, Bit#(32) newValue);
import "BDPI" function void program_memory_write_u64(ContextHandle ctx, Word address, Bit#(64) newValue);

module mkProgramMemoryTile(ProgramMemoryTile);
    Word32 programMemoryContext = program_memory_open();

    FIFO#(TileLinkLiteWordRequest) requests[2];
    requests[0] <- mkFIFO;
    requests[1] <- mkFIFO;

    FIFO#(TileLinkLiteWordResponse) responses[2];
    responses[0] <- mkFIFO;
    responses[1] <- mkFIFO;

    function Action handleRequest(Integer portNumber);
        action
        let request = requests[portNumber].first;
        requests[portNumber].deq;

        TileLinkLiteWordResponse response = TileLinkLiteWordResponse{
            d_opcode: d_ACCESS_ACK,
            d_param: 0,
            d_size: request.a_size,
            d_source: request.a_source,
            d_sink: 0,
            d_denied: True,
            d_data: ?,
            d_corrupt: request.a_corrupt
        };

        let addressValid = program_memory_is_valid_address(programMemoryContext, truncate(request.a_address));
        if (addressValid && !request.a_corrupt && request.a_opcode == a_GET) begin
            case (request.a_size)
                0:  begin   // 1 byte
                    response.d_opcode = d_ACCESS_ACK_DATA;
                    response.d_denied = False;
                    response.d_data = extend(program_memory_read_u8(programMemoryContext, request.a_address));
                end
                1:  begin   // 2 bytes
                    if (request.a_address[0] == 0) begin
                        response.d_opcode = d_ACCESS_ACK_DATA;
                        response.d_denied = False;
                        response.d_data = extend(program_memory_read_u16(programMemoryContext, request.a_address));
                    end
                end
                2:  begin   // 4 bytes
                    if (request.a_address[1:0] == 0) begin
                        response.d_opcode = d_ACCESS_ACK_DATA;
                        response.d_denied = False;
                        response.d_data = extend(program_memory_read_u32(programMemoryContext, request.a_address));
                    end
                end
`ifdef RV64
                3:  begin   // 8 bytes
                    if (request.a_address[2:0] == 0) begin
                        response.d_opcode = d_ACCESS_ACK_DATA;
                        response.d_denied = False;
                        response.d_data = program_memory_read_u64(programMemoryContext, request.a_address);
                    end
                end
`endif
            endcase
        end else if (addressValid && !request.a_corrupt && request.a_opcode == a_PUT_FULL_DATA) begin
            response.d_opcode = d_ACCESS_ACK;
            response.d_denied = False;
        end else begin
            response.d_denied = True;
        end

        responses[portNumber].enq(response);

        endaction
    endfunction

    rule requestA;
        handleRequest(0);
    endrule

    rule requestB;
        handleRequest(1);
    endrule

    interface TileLinkLiteWordServer portA;
        interface Get response;
            method ActionValue#(TileLinkLiteWordResponse) get;
                let response = responses[0].first();
                responses[0].deq;

                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkLiteWordRequest request);
                requests[0].enq(request);
            endmethod
        endinterface
    endinterface

    interface TileLinkLiteWordServer portB;
        interface Get response;
            method ActionValue#(TileLinkLiteWordResponse) get;
                let response = responses[1].first();
                responses[1].deq;

                return response;
            endmethod
        endinterface

        interface Put request;
            method Action put(TileLinkLiteWordRequest request);
                requests[1].enq(request);
            endmethod
        endinterface
    endinterface

    method Bool isValidAddress(Word address);
        return program_memory_is_valid_address(programMemoryContext, address);
    endmethod
endmodule
