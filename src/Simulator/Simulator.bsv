import PGTypes::*;
import Crossbar::*;
import DebugModule::*;
import ProgramMemoryTile::*;
import ReadOnly::*;
import SoCAddressMap::*;
import SoCMap::*;

import Connectable::*;
import Core::*;
import GetPut::*;
import RegFile::*;

(* synthesize *)
module mkSimulator(Empty);
`ifdef ENABLE_ISA_TESTS
    ReadOnly#(Maybe#(Word)) toHostAddress <- mkReadOnly(tagged Valid 'h8000_1000);
`endif
    Reg#(Bool) initialized <- mkReg(False);

`ifdef DISABLE_PIPELINING
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(False);
`else
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(True);
`endif
    SoCAddressMap socMap <- mkSoCAddressMap;

    // RAM
    ProgramMemoryTile ram <- mkProgramMemoryTile(socMap.ram0Id);

    // Crossbar
    Crossbar crossbar <- mkCrossbar(socMap);

    // Core
    ProgramCounter initialProgramCounter = socMap.ram0Base;
    Core core <- mkCore(initialProgramCounter);

`ifdef ENABLE_ISA_TESTS
    mkConnection(toGet(toHostAddress), core.putToHostAddress);
`endif

    // Core -> Crossbar
    mkConnection(crossbar.systemMemoryBusServer, core.systemMemoryBusClient);

    // Crossbar -> RAM
    mkConnection(ram.portA, crossbar.ram0Client);

`ifdef ENABLE_RISCOF_TESTS
    mkConnection(ram.getSignatureBeginAddress, core.putSignatureBeginAddress);
    mkConnection(ram.getSignatureEndAddress, core.putSignatureEndAddress);
`endif

    (* fire_when_enabled *)
    rule initialization(initialized == False && core.getState == RESET);
        initialized <= True;

        $display("----------------");
`ifdef DISABLE_PIPELINING
        $display("PG-10x Simulator");
        $display("*Pipelining OFF*");
`else
        $display("PG-10x Simulator");
`endif
        $display("----------------");

        core.start;
    endrule
endmodule
