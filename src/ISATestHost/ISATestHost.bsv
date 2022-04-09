import PGTypes::*;
import Crossbar::*;
import DebugModule::*;
import ProgramMemoryTile::*;
import ReadOnly::*;
import SoCAddressMap::*;
import ISATestHostSocMap::*;

import Connectable::*;
import Core::*;
import GetPut::*;
import RegFile::*;

(* synthesize *)
module mkISATestHost(Empty);
    ReadOnly#(Maybe#(Word)) toHostAddress <- mkReadOnly(tagged Valid 'h8000_1000);
    Reg#(Bool) initialized <- mkReg(False);
    Reg#(Maybe#(MemoryAccess)) memoryAccess <- mkReg(tagged Invalid);

`ifdef ENABLE_PIPELINING
    ReadOnly#(Bool) pipeliningEnabled <- mkReadOnly(True);
`else
    ReadOnly#(Bool) pipeliningEnabled <- mkReadOnly(False);
`endif
    SoCAddressMap socMap <- mkISATestHostSoCMap;

    // RAM
    ProgramMemoryTile ram <- mkProgramMemoryTile(socMap.ram0Id);

    // Crossbar
    Crossbar crossbar <- mkCrossbar(socMap);

    // Core
    ProgramCounter initialProgramCounter = socMap.ram0Base;
    Core core <- mkCore(initialProgramCounter);
//    mkConnection(toGet(toHostAddress), core.putToHostAddress);
    mkConnection(toGet(pipeliningEnabled), core.putPipeliningEnabled);
    mkConnection(core.getMemoryAccess, toPut(asIfc(memoryAccess)));

    // Core -> Crossbar
    mkConnection(crossbar.systemMemoryBusServer, core.systemMemoryBusClient);

    // Crossbar -> RAM
    mkConnection(ram.portA, crossbar.ram0Client);
    
    (* fire_when_enabled *)
    rule initialization(initialized == False && core.getState == RESET);
        initialized <= True;

        $display("----------------");
        $display("PG-10x ISA TEST");
`ifndef ENABLE_PIPELINING
        $display("*Pipelining OFF*");
`endif
        $display("----------------");

        core.start;
    endrule

    (* fire_when_enabled *)
    rule checkMemoryAccess(initialized == True);
        if (memoryAccess matches tagged Valid .memoryAccess &&& memoryAccess.isStore) begin
            $display("ISATestHost Memory Access: ", fshow(memoryAccess));
            if (memoryAccess.address == 'h8000_1000) begin
                let test_num = memoryAccess.value >> 1;
                $display("ISATestHost WriteToHost Detected");
                if (test_num == 0) $display ("    PASS");
                else               $display ("    FAIL <test_%0d>", test_num);

                $finish();
            end
        end
    endrule
endmodule
