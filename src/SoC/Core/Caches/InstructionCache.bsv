import PGTypes::*;
import TileLink::*;

import Assert::*;
import BRAM::*;
import FIFO::*;
import RegFile::*;

`include "CacheTypes.bsvi"

typedef 64 CACHE_LINE_BYTE_COUNT;
typedef 64 CACHE_LINE_COUNT;

typedef TLog#(CACHE_LINE_COUNT) INDEX_BIT_COUNT;
typedef TLog#(CACHE_LINE_BYTE_COUNT) OFFSET_BIT_COUNT;
typedef TSub#(XLEN, TAdd#(INDEX_BIT_COUNT, OFFSET_BIT_COUNT)) TAG_BIT_COUNT;

typedef TSub#(XLEN, 1) TAG_HIGH_BIT;
typedef TSub#(TAG_HIGH_BIT, TSub#(TAG_BIT_COUNT, 1)) TAG_LOW_BIT;

typedef TSub#(TAG_LOW_BIT, 1) INDEX_HIGH_BIT;
typedef TSub#(INDEX_HIGH_BIT, TSub#(INDEX_BIT_COUNT, 1)) INDEX_LOW_BIT;

typedef TSub#(INDEX_LOW_BIT, 1) OFFSET_HIGH_BIT;
typedef 0 OFFSET_LOW_BIT;

typedef struct {
    LineStatus status;
    Bit#(TAG_BIT_COUNT) tag;
} CacheLineInfo deriving(Bits, Eq);

// Instruction memory requests to memory are 16bit wide.
//typedef TileLinkChannelARequest#(6, 1, XLEN, 2) TileLinkLiteWordRequest#(numeric type word_bit_size);
//typedef TileLinkChannelDResponse#(6, 1, 1, TDiv#(word_bit_size, 8)) TileLinkLiteWordResponse#(numeric type word_bit_size);

interface InstructionCache;
    method Action reset;
    interface TileLinkLiteWordServer#(XLEN) cpuMemoryServer;
    interface TileLinkLiteWordClient#(XLEN) instructionMemoryClient;
endinterface

module mkDirectMappedInstructionCache(InstructionCache);
    //
    // CacheInfo register file
    //
    RegFile#(Bit#(INDEX_BIT_COUNT), CacheLineInfo) cacheLineInfoFile <- mkRegFileFull;

    //
    // Data Memory
    //
    BRAM_Configure dataBRAMCfg = defaultValue;
    dataBRAMCfg.memorySize = 2**valueOf(INDEX_BIT_COUNT);
    dataBRAMCfg.loadFormat = None;
    BRAM2Port#(UInt#(INDEX_BIT_COUNT), Bit#(TMul#(8, TExp#(OFFSET_BIT_COUNT)))) dataMemory <- mkBRAM2Server(dataBRAMCfg);

    //
    // System Bus Requests/Responses
    //
    FIFO#(TileLinkLiteWordRequest#(XLEN)) memoryRequests <- mkFIFO();
    FIFO#(TileLinkLiteWordResponse#(XLEN)) memoryResponses <- mkFIFO();

    // function Action handleRequest(TileLinkLiteWordRequest#(XLEN) request);
    //     action
    //         dynamicAssert(request.a_opcode == a_GET, "Instruction cache request only supports GET opcode");
    //         dynamicAssert(request.a_size == 2, "Instruction cache request must be 4 bytes"); 

    //         // Locate the relevant cache info from the incoming address.
    //         let tag = request.a_address[valueOf(TAG_HIGH_BIT):valueOf(TAG_LOW_BIT)];
    //         let index = request.a_address[valueOf(INDEX_HIGH_BIT):valueOf(INDEX_LOW_BIT)];
    //         let offset = request.a_address[valueOf(OFFSET_HIGH_BIT):valueOf(OFFSET_LOW_BIT)];

    //         // Check the tag of the cache line
    //         let cacheLineInfo = cacheLineInfoFile.sub(index);

    //         // See if a cache hit, otherwise, pull the data from memory
    //         if (cacheLineInfo.status == status_CLEAN && cacheLineInfo.tag == tag) begin
    //             // Send BRAM request to data to retrieve line
    //             dataMemory.portA.request.put(BRAMRequest {
    //                 write: False,
    //                 responseOnWrite: ?,
    //                 address: unpack(index),
    //                 datain: ?
    //             });
    //         end else begin
    //             // Send external memory request to retrieve data for cache

    //         end
    //     endaction
    // endfunction

    // rule handleBRamResponse;
    //     let bramResponse = dataMemory.portA.response.get;
    // endrule

    method Action reset;
        for (Integer i = 0; i < 2**valueOf(INDEX_BIT_COUNT); i = i + 1) begin
            cacheLineInfoFile.upd(fromInteger(i), CacheLineInfo {
                status: status_INVALID,
                tag: ?
            });
        end
    endmethod

    interface TileLinkLiteWordServer cpuMemoryServer = toGPServer(memoryRequests, memoryResponses);
    interface TileLinkLiteWordClient instructionMemoryClient = toGPClient(memoryRequests, memoryResponses);
endmodule
