import PGTypes::*;
import Exception::*;
import TileLink::*;

//
// LoadRequest
//
// Structure containing information about a request to load data
// from memory.
//
typedef struct {
    StdTileLinkRequest tlRequest;

    RVGPRIndex rd;
    Bool signExtend;
} LoadRequest deriving(Bits, Eq, FShow);

function Word getWordAddress(Word effectiveAddress);
    Bit#(XLEN) shift = fromInteger(valueOf(TLog#(TDiv#(XLEN,8))));
    Bit#(XLEN) mask = ~((1 << shift) - 1);

    return effectiveAddress & mask;
endfunction

function Result#(LoadRequest, Exception) getLoadRequest(
    RVLoadOperator loadOperator,
    RVGPRIndex rd,
    Word effectiveAddress);

    Result#(LoadRequest, Exception) result = 
        tagged Error createIllegalInstructionException(0);

    let loadRequest = LoadRequest {
        tlRequest: TileLinkLiteWordRequest {
            a_opcode: a_GET,
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
        load_LB: begin
            loadRequest.tlRequest.a_size = 0; // 1 byte
            loadRequest.tlRequest.a_mask = 'b1;
            result = tagged Success loadRequest;
        end

        load_LBU: begin
            loadRequest.tlRequest.a_size = 0; // 1 byte
            loadRequest.tlRequest.a_mask = 'b1;
            loadRequest.signExtend = False;
            result = tagged Success loadRequest;
        end

        // Half-word
        load_LH: begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error createMisalignedLoadException(effectiveAddress);
            end else begin
                loadRequest.tlRequest.a_size = 1; // 2 bytes
                loadRequest.tlRequest.a_mask = 'b11;
                result = tagged Success loadRequest;
            end
        end

        load_LHU: begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error createMisalignedLoadException(effectiveAddress);
            end else begin
                loadRequest.tlRequest.a_size = 1; // 2 bytes
                loadRequest.tlRequest.a_mask = 'b11;
                loadRequest.signExtend = False;
                result = tagged Success loadRequest;
            end
        end

        // Word
        load_LW: begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error createMisalignedLoadException(effectiveAddress);
            end else begin
                loadRequest.tlRequest.a_size = 2; // 4 bytes
                loadRequest.tlRequest.a_mask = 'b1111;
                result = tagged Success loadRequest;
            end
        end

`ifdef RV64
        load_LWU: begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error createMisalignedLoadException(effectiveAddress);
            end else begin
                loadRequest.tlRequest.a_size = 2; // 4 bytes
                loadRequest.tlRequest.a_mask = 'b1111;
                loadRequest.signExtend = False;
                result = tagged Success loadRequest;
            end
        end

        load_LD: begin
            if ((effectiveAddress & 'b111) != 0) begin
                result = tagged Error createMisalignedLoadException(effectiveAddress);
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
    StdTileLinkRequest tlRequest;
} StoreRequest deriving(Bits, Eq, FShow);

function Result#(StoreRequest, Exception) getStoreRequest(
    RVStoreOperator storeOperator,
    Word effectiveAddress,
    Word value);

    Result#(StoreRequest, Exception) result = 
        tagged Error createIllegalInstructionException(0);

    let storeRequest = StoreRequest {
        tlRequest: TileLinkLiteWordRequest {
            a_opcode: a_PUT_FULL_DATA,
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
        store_SB: begin
            storeRequest.tlRequest.a_size = 0; // 1 byte
            storeRequest.tlRequest.a_mask = 'b1;
            storeRequest.tlRequest.a_data = (value & 'hFF);

            result = tagged Success storeRequest;
        end
        // Half-word
        store_SH: begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error createMisalignedStoreException(effectiveAddress);
            end else begin
                storeRequest.tlRequest.a_size = 1; // 2 bytes
                storeRequest.tlRequest.a_mask = 'b11;
                storeRequest.tlRequest.a_data = (value & 'hFFFF);

                result = tagged Success storeRequest;
            end
        end
        // Word
        store_SW: begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error createMisalignedStoreException(effectiveAddress);
            end else begin
`ifdef RV32
                storeRequest.tlRequest.a_opcode = a_PUT_FULL_DATA;
`endif
                storeRequest.tlRequest.a_size = 2; // 4 bytes
                storeRequest.tlRequest.a_mask = 'b1111;
                storeRequest.tlRequest.a_data = (value & 'hFFFF_FFFF);


                result = tagged Success storeRequest;
            end
        end
`ifdef RV64
        // Double-word
        store_SD: begin
            if ((effectiveAddress & 'b111) != 0) begin
                result = tagged Error createMisalignedStoreException(effectiveAddress);
            end else begin
                storeRequest.tlRequest.a_opcode = a_PUT_FULL_DATA;
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
