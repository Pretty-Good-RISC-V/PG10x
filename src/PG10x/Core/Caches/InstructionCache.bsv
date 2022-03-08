import PGTypes::*;
import TileLink::*;

import Assert::*;
import BRAM::*;
import FIFO::*;

typedef Bit#(2) LineStatus;
LineStatus status_INVALID = 2'b00;  // Line is unused.
LineStatus status_CLEAN   = 2'b01;  // Line unchanged with respect to main memory.
LineStatus status_DIRTY   = 2'b10;  // Line needs to be written back to main memory.

typedef struct {
    LineStatus status;
    Bit#(TMul#(dataBytes, 8)) data;
    Bit#(tagBits) tag;
} CacheLine#(type dataBytes, type tagBits) deriving(Bits, Eq, FShow);

typedef BRAM2Port#(Word, Bit#(TLog#(cacheLineCount))) TagBRAM2Port#(numeric type cacheLineCount);
typedef BRAM2PortBE#(Word, Bit#(TMul#(dataByteCount, 8)), TDiv#(dataByteCount, 8)) TagBRAM2PortBE#(numeric type cacheLineCount, numeric type dataByteCount);

interface InstructionCache;
    interface TileLinkLiteWordServer#(XLEN) cpuInterface;
    interface TileLinkLiteWordClient#(XLEN) systemBusInterface;
endinterface

`ifndef ICACHE_LINE_COUNT
`define ICACHE_LINE_COUNT 1024
`endif

`ifndef ICACHE_LINE_SIZE
`define ICACHE_LINE_SIZE 64
`endif

module mkDirectMappedInstructionCache(InstructionCache);
    //
    // Tag BRAM configuration
    //
    BRAM_Configure tagBRAMCfg = defaultValue;
    tagBRAMCfg.memorySize = cacheLineCount;
    tagBRAMCfg.loadFormat = None;

    TagBRAM2Port#(cacheLineCount) tagMemory <- mkBRAM2Server(tagBRAMCfg);

    //
    // Data BRAM configuration
    //
    BRAM_Configure dataBRAMCfg = defaultValue;
    dataBRAMCfg.memorySize = cacheLineCount;
    dataBRAMCfg.loadFormat = None;

    TagBRAM2PortBE#(1024, 64) dataMemory <- mkBRAM2ServerBE(dataBRAMCfg);

    FIFO#(TileLinkLiteWordResponse#(XLEN)) responses <- mkFIFO;

    function Action handleRequest(TileLinkLiteWordRequest#(XLEN) request);
        action
            dynamicAssert(request.a_size == 2, "Instruction Cache Request must be 4 bytes"); 

            // Locate the cache line

        endaction
    endfunction

    interface TileLinkLiteWordServer cpuInterface;
        interface Get response = toGet(responses);

        interface Put request;
            method Action put(TileLinkLiteWordRequest#(XLEN) request);
                handleRequest(request);
            endmethod
        endinterface
    endinterface

endmodule
