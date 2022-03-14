import PGTypes::*;
import Debug::*;
import HART::*;
import InstructionCache::*;
import ReadOnly::*;
import TileLink::*;

import Connectable::*;
import GetPut::*;

export PG10xCore(..), mkPG10xCore, HART::*;

interface PG10xCore;
    method Action start;
    method HARTState getState;

    interface TileLinkLiteWordClient#(XLEN) instructionMemoryClient;
    interface TileLinkLiteWordClient#(XLEN) dataMemoryClient;

    interface Put#(Bool) putPipeliningDisabled;
    interface Put#(Maybe#(Word)) putToHostAddress;

    interface Debug debug;
endinterface

module mkPG10xCore#(
    ProgramCounter initialProgramCounter
)(PG10xCore);
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

    method Action start;
        hart.start;
    endmethod

    method HARTState getState = hart.getState;
    interface TileLinkLiteWordClient instructionMemoryClient = hart.instructionMemoryClient;
    interface TileLinkLiteWordClient dataMemoryClient = hart.dataMemoryClient;
    interface Put putPipeliningDisabled = hart.putPipeliningDisabled;
    interface Put putToHostAddress = hart.putToHostAddress;
    interface Debug debug = hart.debug;
endmodule
