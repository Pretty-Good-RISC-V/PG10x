import PGTypes::*;
import Exception::*;

//
// LoadRequest
//
// Structure containing information about a request to load data
// from memory.
//
typedef struct {
    Word effectiveAddress;      // Data aligned
    Word wordAddress;           // XLEN aligned
    Bit#(TDiv#(XLEN, 8)) mask;
    Bit#(TLog#(XLEN)) log2Size;

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

    // Determine the *word* address of the store request.
    let wordAddress = getWordAddress(effectiveAddress);

    // Determine how much to shift bytes by to find the right byte address inside a word.
    Bit#(6) rightShiftBytes = truncate(effectiveAddress - wordAddress);

    let loadRequest = LoadRequest {
        effectiveAddress: effectiveAddress,
        wordAddress: wordAddress,
        mask: ?,
        log2Size: ?,
        rd: rd,
        signExtend: True
    };

    case (loadOperator)
        // Byte
        pack(LB): begin
            loadRequest.mask = 'b1;
            loadRequest.log2Size = 0;
            result = tagged Success loadRequest;
        end

        pack(LBU): begin
            loadRequest.mask = 'b1;
            loadRequest.log2Size = 0;
            loadRequest.signExtend = False;
            result = tagged Success loadRequest;
        end

        // Half-word
        pack(LH): begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(LOAD_ADDRESS_MISALIGNED));
            end else begin
                loadRequest.mask = 'b11;
                loadRequest.log2Size = 1;
                result = tagged Success loadRequest;
            end
        end

        pack(LHU): begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(LOAD_ADDRESS_MISALIGNED));
            end else begin
                loadRequest.mask = 'b11;
                loadRequest.log2Size = 1;
                loadRequest.signExtend = False;
                result = tagged Success loadRequest;
            end
        end

        // Word
        pack(LW): begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(LOAD_ADDRESS_MISALIGNED));
            end else begin
                loadRequest.mask = 'b1111;
                loadRequest.log2Size = 2;
                result = tagged Success loadRequest;
            end
        end

`ifdef RV64
        pack(LWU): begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(LOAD_ADDRESS_MISALIGNED));
            end else begin
                loadRequest.mask = 'b1111;
                loadRequest.log2Size = 2;
                loadRequest.signExtend = False;
                result = tagged Success loadRequest;
            end
        end

        pack(LD): begin
            if ((effectiveAddress & 'b111) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(LOAD_ADDRESS_MISALIGNED));
            end else begin
                loadRequest.mask = 'b1111_1111;
                loadRequest.log2Size = 3;
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
    Word wordAddress;       // XLEN aligned
    Bit#(TDiv#(XLEN, 8)) byteEnable;
    Word value;
} StoreRequest deriving(Bits, Eq, FShow);

function Result#(StoreRequest, Exception) getStoreRequest(
    RVStoreOperator storeOperator,
    Word effectiveAddress,
    Word value);

    Result#(StoreRequest, Exception) result = 
        tagged Error tagged ExceptionCause extend(pack(ILLEGAL_INSTRUCTION));

    let wordAddress = getWordAddress(effectiveAddress);

    // Determine how much to shift bytes by to find the right byte address inside a word.
    let leftShiftBytes = effectiveAddress - wordAddress;

    let storeRequest = StoreRequest {
        wordAddress: wordAddress,
        byteEnable: ?,
        value: ?
    };

    case (storeOperator)
        // Byte
        pack(SB): begin
            storeRequest.byteEnable = ('b1 << leftShiftBytes);
            storeRequest.value = (value & 'hFF) << (8 * leftShiftBytes);

            result = tagged Success storeRequest;
        end
        // Half-word
        pack(SH): begin
            if ((effectiveAddress & 'b01) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED));
            end else begin
                storeRequest.byteEnable = ('b11 << leftShiftBytes);
                storeRequest.value = (value & 'hFFFF) << (8 * leftShiftBytes);

                result = tagged Success storeRequest;
            end
        end
        // Word
        pack(SW): begin
            if ((effectiveAddress & 'b11) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED));
            end else begin
                storeRequest.byteEnable = ('b1111 << leftShiftBytes);
                storeRequest.value = (value & 'hFFFF_FFFF) << (8 * leftShiftBytes);

                result = tagged Success storeRequest;
            end
        end
`ifdef RV64
        // Double-word
        pack(SD): begin
            if ((effectiveAddress & 'b111) != 0) begin
                result = tagged Error tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED));
            end else begin
                storeRequest.byteEnable = 'b1111_1111;
                storeRequest.value = value;

                result = tagged Success storeRequest;
            end
        end
`endif
    endcase

    return result;
endfunction
