import PGTypes::*;
import Debug::*;
import HART::*;
import InstructionCache::*;
import ReadOnly::*;
import TileLink::*;

import Connectable::*;
import GetPut::*;

export Core(..), mkCore, HART::*;

interface Core;
    method Action start;
    method HARTState getState;

    interface TileLinkLiteWordClient#(XLEN) instructionMemoryClient;
    interface TileLinkLiteWordClient#(XLEN) dataMemoryClient;

    interface Put#(Bool) putPipeliningDisabled;
    interface Put#(Maybe#(Word)) putToHostAddress;

    interface Debug debug;
endinterface

module mkCore#(
    ProgramCounter initialProgramCounter
)(Core);
    //
    // HART
    //
    ReadOnly#(Maybe#(Word)) toHostAddress <- mkReadOnly(tagged Valid 'h8000_1000);

`ifdef DISABLE_PIPELINING
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(False);
`else
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(True);
`endif

    HART hart <- mkHART(initialProgramCounter);
    InstructionCache icache <- mkDirectMappedInstructionCache();

    mkConnection(icache.cpuMemoryServer, hart.instructionMemoryClient);

    method Action start = hart.start;
    method HARTState getState = hart.getState;
    interface TileLinkLiteWordClient instructionMemoryClient = icache.instructionMemoryClient;
    interface TileLinkLiteWordClient dataMemoryClient = hart.dataMemoryClient;
    interface Put putPipeliningDisabled = hart.putPipeliningDisabled;
    interface Put putToHostAddress = hart.putToHostAddress;
    interface Debug debug = hart.debug;
endmodule
