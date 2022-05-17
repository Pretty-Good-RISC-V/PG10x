import PGTypes::*;

import GPRFile::*;
import PipelineTypes::*;

import GetPut::*;

interface WritebackStage;
    interface Put#(MEM_WB) putInput;
    interface Get#(MEM_WB) getOutput;
endinterface

module mkWritebackStage#(GPRFile gprFile)(WritebackStage);
    Reg#(MEM_WB) mem_wb <- mkReg(MEM_WB {
        pcommon: PipelineCommon {
            programCounter: 'hbeef_beef,
            nextProgramCounter: 'hfeeb_feeb,
            rawInstruction: 0
        },
        writebackValue: tagged Invalid
    });

    interface Put putInput = toPut(asIfc(mem_wb));
    interface Get getOutput;
        method ActionValue#(MEM_WB) get;
            let rd = mem_wb.pcommon.rawInstruction[11:7];

            if (mem_wb.writebackValue matches tagged Valid .value) begin
                gprFile.write(rd, value);
            end

            return mem_wb;
        endmethod
    endinterface
endmodule
