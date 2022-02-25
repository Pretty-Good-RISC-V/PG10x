import PGTypes::*;
import Exception::*;
import MemoryInterfaces::*;

//
// LoadRequest
//
// Structure containing information about a request to load data
// from memory.
//
typedef struct {
    TileLinkLiteWordRequest tlRequest;

    RegisterIndex rd;
    Bool signExtend;
} LoadRequest deriving(Bits, Eq, FShow);

function Word getWordAddress(Word effectiveAddress);
    Bit#(XLEN) shift = fromInteger(valueOf(TLog#(TDiv#(XLEN,8))));
    Bit#(XLEN) mask = ~((1 << shift) - 1);

    return effectiveAddress & mask;
endfunction

function Result#(LoadRequest, Exception) getLoadRequest(
    RVLoadOperator loadOperator,
    RegisterIndex rd,
    Word effectiveAddress);

    Result#(LoadRequest, Exception) result = 
        tagged Error tagged ExceptionCause extend(pack(ILLEGAL_INSTRUCTION));

    let loadRequest = LoadRequest {
        tlRequest: TileLinkLiteWordRequest {
            a_opcode: pack(A_GET),
            a_param: 0,
            a_size: ?,
            a_source: 0,
            a_address: effectiveAddress,
            a_mask: ?,
            a_data: ?,
            a_corrupt: False
        },
        rd: rd,
        signExtend: True
    };

    case (loadOperator)
        // Byte
        pack(LB): begin
            loadRequest.tlRequest.a_size = 0; // 1 byte
            loadRequest.tlRequest.a_mask = 'b1;
            result = tagged Success loadRequest;
        end

        pack(LBU): begin
            loadRequest.tlRequest.a_size = 0; // 1 byte
            loadRequest.tlRequest.a_mask = 'b1;
            loadRequest.signExtend = False;
            result = tagged Success loadRequest;
        end

        // Half-word
        pack(LH): begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(LOAD_ADDRESS_MISALIGNED));
            end else begin
                loadRequest.tlRequest.a_size = 1; // 2 bytes
                loadRequest.tlRequest.a_mask = 'b11;
                result = tagged Success loadRequest;
            end
        end

        pack(LHU): begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(LOAD_ADDRESS_MISALIGNED));
            end else begin
                loadRequest.tlRequest.a_size = 1; // 2 bytes
                loadRequest.tlRequest.a_mask = 'b11;
                loadRequest.signExtend = False;
                result = tagged Success loadRequest;
            end
        end

        // Word
        pack(LW): begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(LOAD_ADDRESS_MISALIGNED));
            end else begin
                loadRequest.tlRequest.a_size = 2; // 4 bytes
                loadRequest.tlRequest.a_mask = 'b1111;
                result = tagged Success loadRequest;
            end
        end

`ifdef RV64
        pack(LWU): begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(LOAD_ADDRESS_MISALIGNED));
            end else begin
                loadRequest.tlRequest.a_size = 2; // 4 bytes
                loadRequest.tlRequest.a_mask = 'b1111;
                loadRequest.signExtend = False;
                result = tagged Success loadRequest;
            end
        end

        pack(LD): begin
            if ((effectiveAddress & 'b111) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(LOAD_ADDRESS_MISALIGNED));
            end else begin
                loadRequest.tlRequest.a_size = 3; // 8 bytes
                loadRequest.tlRequest.a_mask = 'b1111_1111;
                result = tagged Success loadRequest;
            end
        end
`endif
    endcase

    return result;
endfunction

//
// StoreRequest
//
// Structure containing information about a request to store data
// to memory.
//
typedef struct {
    TileLinkLiteWordRequest tlRequest;
} StoreRequest deriving(Bits, Eq, FShow);

function Result#(StoreRequest, Exception) getStoreRequest(
    RVStoreOperator storeOperator,
    Word effectiveAddress,
    Word value);

    Result#(StoreRequest, Exception) result = 
        tagged Error tagged ExceptionCause extend(pack(ILLEGAL_INSTRUCTION));

    let storeRequest = StoreRequest {
        tlRequest: TileLinkLiteWordRequest {
            a_opcode: pack(A_PUT_PARTIAL_DATA),
            a_param: 0,
            a_size: ?,
            a_source: 0,
            a_address: effectiveAddress,
            a_mask: ?,
            a_data: ?,
            a_corrupt: False
        }
    };

    case (storeOperator)
        // Byte
        pack(SB): begin
            storeRequest.tlRequest.a_size = 0; // 1 byte
            storeRequest.tlRequest.a_mask = 'b1;
            storeRequest.tlRequest.a_data = (value & 'hFF);

            result = tagged Success storeRequest;
        end
        // Half-word
        pack(SH): begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED));
            end else begin
                storeRequest.tlRequest.a_size = 1; // 2 bytes
                storeRequest.tlRequest.a_mask = 'b11;
                storeRequest.tlRequest.a_data = (value & 'hFFFF);

                result = tagged Success storeRequest;
            end
        end
        // Word
        pack(SW): begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED));
            end else begin
`ifdef RV32
                storeRequest.tlRequest.a_opcode = pack(A_PUT_FULL_DATA);
`endif
                storeRequest.tlRequest.a_size = 2; // 4 bytes
                storeRequest.tlRequest.a_mask = 'b1111;
                storeRequest.tlRequest.a_data = (value & 'hFFFF_FFFF);


                result = tagged Success storeRequest;
            end
        end
`ifdef RV64
        // Double-word
        pack(SD): begin
            if ((effectiveAddress & 'b111) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED));
            end else begin
                storeRequest.tlRequest.a_opcode = pack(A_PUT_FULL_DATA);
                storeRequest.tlRequest.a_size = 3; // 8 bytes
                storeRequest.tlRequest.a_mask = 'b1111_1111;
                storeRequest.tlRequest.a_data = (value & 'hFFFF_FFFF_FFFF_FFFF);

                result = tagged Success storeRequest;
            end
        end
`endif
    endcase

    return result;
endfunction
