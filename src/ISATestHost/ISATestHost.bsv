import PGTypes::*;
import DebugModule::*;
import ProgramMemoryTile::*;
import ReadOnly::*;

import Connectable::*;
import Core::*;
import GetPut::*;
import RegFile::*;

(* synthesize *)
module mkISATestHost(Empty);
    Reg#(Bool) initialized <- mkReg(False);
    Reg#(Maybe#(MemoryAccess)) memoryAccess <- mkReg(tagged Invalid);

`ifdef ENABLE_PIPELINING
    ReadOnly#(Bool) pipeliningEnabled <- mkReadOnly(True);
`else
    ReadOnly#(Bool) pipeliningEnabled <- mkReadOnly(False);
`endif

    // RAM
    ProgramMemoryTile ram <- mkProgramMemoryTile(0);

    // Core
    ProgramCounter initialProgramCounter = 'h8000_0000;
    Core core <- mkCore(initialProgramCounter);

    mkConnection(toGet(pipeliningEnabled), core.putPipeliningEnabled);
    mkConnection(core.getMemoryAccess, toPut(asIfc(memoryAccess)));

    mkConnection(ram.portA, core.systemMemoryBusClient);

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
