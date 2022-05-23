import PGTypes::*;
import TileLink::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;

interface ProgramMemoryTile;
    interface StdTileLinkServer portA;
    interface StdTileLinkServer portB;

    method Bool isValidAddress(Word address);

`ifdef ENABLE_RISCOF_TESTS
    method Action dump;
    method Action dumpSignatures;
`endif
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
import "BDPI" function Action program_memory_write_u8(ContextHandle ctx, Word address, Bit#(8) newValue);
import "BDPI" function Action program_memory_write_u16(ContextHandle ctx, Word address, Bit#(16) newValue);
import "BDPI" function Action program_memory_write_u32(ContextHandle ctx, Word address, Bit#(32) newValue);
import "BDPI" function Action program_memory_write_u64(ContextHandle ctx, Word address, Bit#(64) newValue);

`ifdef ENABLE_RISCOF_TESTS
import "BDPI" function Action program_memory_dump(ContextHandle ctx);
import "BDPI" function Action program_memory_dump_signature_area(ContextHandle ctx);
`endif

module mkProgramMemoryTile#(
    TileId tileID
)(ProgramMemoryTile);
    Reg#(Word32) programMemoryContext <- mkRegU;
    Reg#(Bool) loaded <- mkReg(False);
    rule load(loaded == False);
        loaded <= True;
        programMemoryContext <= program_memory_open();
    endrule

    FIFO#(StdTileLinkResponse) responses[2];
    responses[0] <- mkFIFO;
    responses[1] <- mkFIFO;

    function Action handleRequestToPort(StdTileLinkRequest request, Integer portNumber);
        action
        StdTileLinkResponse response = TileLinkLiteWordResponse{
            d_opcode: d_ACCESS_ACK,
            d_param: 0,
            d_size: request.a_size,
            d_source: pack(tileID),
            d_sink: request.a_source,
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
            case (request.a_size)
                0:  begin   // 1 byte
                    response.d_denied = False;
                    program_memory_write_u8(programMemoryContext, request.a_address, request.a_data[7:0]);
                end
                1:  begin   // 2 bytes
                    if (request.a_address[0] == 0) begin
                        response.d_denied = False;
                        program_memory_write_u16(programMemoryContext, request.a_address, request.a_data[15:0]);
                    end
                end
                2:  begin   // 4 bytes
                    if (request.a_address[1:0] == 0) begin
                        response.d_denied = False;
                        program_memory_write_u32(programMemoryContext, request.a_address, request.a_data[31:0]);
                    end
                end
`ifdef RV64
                3:  begin   // 8 bytes
                    if (request.a_address[2:0] == 0) begin
                        response.d_denied = False;
                        program_memory_write_u64(programMemoryContext, request.a_address, request.a_data);
                    end
                end
`endif
            endcase
        end else begin
            response.d_denied = True;
        end

        responses[portNumber].enq(response);

        endaction
    endfunction

    interface TileLinkLiteWordServer portA;
        interface Get response = toGet(responses[0]);

        interface Put request;
            method Action put(StdTileLinkRequest request);
                handleRequestToPort(request, 0);
            endmethod
        endinterface
    endinterface

    interface TileLinkLiteWordServer portB;
        interface Get response = toGet(responses[1]);

        interface Put request;
            method Action put(StdTileLinkRequest request);
                handleRequestToPort(request, 1);
            endmethod
        endinterface
    endinterface

    method Bool isValidAddress(Word address);
        return program_memory_is_valid_address(programMemoryContext, address);
    endmethod

`ifdef ENABLE_RISCOF_TESTS
    method Action dump;
        program_memory_dump(programMemoryContext);
    endmethod
    
    method Action dumpSignatures;
        program_memory_dump_signature_area(programMemoryContext);
    endmethod
`endif

endmodule
