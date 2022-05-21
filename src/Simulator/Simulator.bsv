import PGTypes::*;
import Crossbar::*;
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
