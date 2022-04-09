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

`ifdef ENABLE_PIPELINING
    ReadOnly#(Bool) pipeliningEnabled <- mkReadOnly(True);
`else
    ReadOnly#(Bool) pipeliningEnabled <- mkReadOnly(False);
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
    mkConnection(toGet(pipeliningEnabled), core.putPipeliningEnabled);

    // Core -> Crossbar
    mkConnection(crossbar.systemMemoryBusServer, core.systemMemoryBusClient);

    // Crossbar -> RAM
    mkConnection(ram.portA, crossbar.ram0Client);

    (* fire_when_enabled *)
    rule initialization(initialized == False && core.getState == RESET);
        initialized <= True;

        $display("----------------");
        $display("PG-10x Simulator");
`ifndef ENABLE_PIPELINING
        $display("*Pipelining OFF*");
`endif
        $display("----------------");

        core.start;
    endrule

`ifdef ENABLE_RISCOF_TESTS
    Reg#(Bool) riscofHaltRequested <- mkReg(False);
    rule handleRISCOFHaltRequested(riscofHaltRequested == True);
        $display("RISCOF Halt Requested");
//        ram.dump;
        ram.dumpSignatures;
        $finish();
    endrule

    mkConnection(core.getRISCOFHaltRequested, toPut(asIfc(riscofHaltRequested)));
`endif
endmodule
