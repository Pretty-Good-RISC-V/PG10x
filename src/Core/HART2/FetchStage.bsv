import PGTypes::*;

import PipelineTypes::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;
import Memory::*;

interface FetchStage;
    interface MemoryClient#(XLEN, 32) instructionMemoryClient;

    interface Put#(IDEX_IF) putInput;
    interface Get#(IF_ID) getOutput;

//    interface Get#(Maybe#(StdTileLinkRequest)) getInstructionMemoryRequest;
//    interface Put#(StdTileLinkResponse) putInstructionMemoryResponse;

//    interface Put#(ProgramCounter) putRedirectedProgramCounter;
endinterface

module mkFetchStage(FetchStage);
    FIFO#(MemoryRequest#(XLEN, 32)) instructionMemoryRequests <- mkFIFO;
    FIFO#(MemoryResponse#(32)) instructionMemoryResponses <- mkFIFO;

    Reg#(ProgramCounter) programCounter <- mkReg('h8000_0000);
    Reg#(IDEX_IF) idex_if <- mkReg(
        IDEX_IF { 
            branchTarget: 0,
            branchTaken: False
        }
    );

    interface MemoryClient instructionMemoryClient = toGPClient(instructionMemoryRequests, instructionMemoryResponses);

    interface Put putInput = toPut(asIfc(idex_if));
    interface Get getOutput;
        method ActionValue#(IF_ID) get;
            // Fetch the instruction at PC
            Word32 rawInstruction = 0;  // FIXME

            // Calculate the next program counter
            let nextProgramCounter = 
                (idex_if.branchTaken ? idex_if.branchTarget : programCounter + 4);

            programCounter <= nextProgramCounter;

            return IF_ID {
                pcommon: PipelineCommon {
                    programCounter: programCounter,
                    nextProgramCounter: nextProgramCounter,
                    rawInstruction: rawInstruction
                }                
            };
        endmethod
    endinterface
endmodule
