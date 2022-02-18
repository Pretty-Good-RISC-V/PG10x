`include "CacheTypes.bsvi"

import PGTypes::*;
import TileLink::*;

import BRAM::*;

typedef struct {
    Integer lineBytes;
    Integer lineCount;
} InstructionCache_Configure;

instance DefaultValue #(InstructionCache_Configure);
    defaultValue = InstructionCache_Configure {
       lineBytes : 64,
       lineCount : 64
    };
endinstance

typedef TileLinkChannelARequest#(1, 1, XLEN, TDiv#(XLEN, 8)) InstructionMemoryRequest;
typedef TileLinkChannelDResponse#(1, 1, 1, 4) InstructionMemoryResponse;

typedef Server#(InstructionMemoryRequest, InstructionMemoryResponse) InstructionMemoryServer;

module mkDirectMappedInstructionCache#(
    InstructionCache_Configure cfg
)(Empty);
    let lineBytes = cfg.lineBytes;
    let lineCount = cfg.lineCount;
    // Integer index_bits = TLog#(line_count);
    // let tag_bits = valueOf(TSub#(XLEN, TAdd#(index_bits, TLog#(line_bytes))));
    // let tagged_line_size = valueOf(SizeOf#(TaggedLine#(line_bytes, tag_bits)));

    BRAM_Configure bramCfg = defaultValue;
    bramCfg.memorySize = lineCount;
    bramCfg.loadFormat = None;

    BRAM2PortBE#(Word, TaggedLine#(valueOf(lineCount), 10), 1) bram <- mkBRAM2ServerBE(bramCfg);

endmodule
