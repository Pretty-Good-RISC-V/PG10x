import PGTypes::*;

import GPRFile::*;

import PipelineTypes::*;
import FetchStage::*;
import DecodeStage::*;
import ExecutionStage::*;
import MemoryStage::*;
import WritebackStage::*;

import GetPut::*;
import Memory::*;

interface HART;
    interface MemoryClient#(XLEN, 32) instructionMemoryClient;
//    interface MemoryClient#(XLEN, XLEN) dataMemoryClient;
endinterface

typedef enum {
    RESET,
    RUNNING_PIPELINED,
    HALTED
} State deriving(Bits, Eq, FShow);

(* synthesize *)
module mkHART(HART);
    // 
    // HART state
    //
    Reg#(State) state <- mkReg(RESET);

    // 
    // GPR file
    //
    GPRFile gprFile <- mkGPRFile;

    // 
    // Pipeline stages
    //
    FetchStage fetchStage <- mkFetchStage;
    DecodeStage decodeStage <- mkDecodeStage(gprFile);
    ExecutionStage executionStage <- mkExecutionStage;
    MemoryStage memoryStage <- mkMemoryStage;
    WritebackStage writebackStage <- mkWritebackStage(gprFile);

    rule on_reset(state == RESET);
        state <= RUNNING_PIPELINED;
    endrule

    rule on_running_pipelined(state == RUNNING_PIPELINED);
        let if_id  <- fetchStage.getOutput.get;
        let id_ex  <- decodeStage.getOutput.get;
        let ex_mem <- executionStage.getOutput.get;
        let mem_wb <- memoryStage.getOutput.get;
        let wb_ex  <- writebackStage.getOutput.get;

        fetchStage.putInput.put(IDEX_IF {
            branchTarget: id_ex.branchTarget,
            branchTaken: executionStage.getBranchTaken
        });



    endrule

    interface MemoryClient instructionMemoryClient = fetchStage.instructionMemoryClient;
endmodule
