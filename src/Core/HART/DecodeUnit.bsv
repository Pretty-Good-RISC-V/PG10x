//
// DecodeUnit
//
// This module is a RISC-V instruction decode unit.  It is responsible for decoding machine 
// code (a 'EncodedInstruction' structure) values into a 'DecodedInstruction' structure.
//
import PGTypes::*;

import BypassUnit::*;
import CSRFile::*;
import EncodedInstruction::*;
import Exception::*;
import DecodedInstruction::*;
import GPRFile::*;
import PipelineController::*;
import Scoreboard::*;

import FIFO::*;
import FIFOF::*;
import GetPut::*;
import SpecialFIFOs::*;

export DecodeUnit(..), mkDecodeUnit;

interface DecodeUnit;
    interface Put#(Word64) putCycleCounter;

    interface Put#(EncodedInstruction) putEncodedInstruction;
    interface Get#(DecodedInstruction) getDecodedInstruction;

    interface Put#(Maybe#(GPRBypassValue)) putGPRBypassValue1;
    interface Put#(Maybe#(GPRBypassValue)) putGPRBypassValue2;
endinterface

`ifdef ENABLE_RISCOF_TESTS
RVCSRIndex csr_RISCOF_HALT = 12'h7C0;      // Register, that when written, is used to halt a RISCOF test (and the simulation).
`endif

module mkDecodeUnit#(
    Integer stageNumber,
    PipelineController pipelineController,
    GPRFile gprFile,
    CSRFile csrFile,
    Scoreboard#(4) scoreboard
)(DecodeUnit);
    Wire#(Word64) cycleCounter <- mkBypassWire;
    GPRBypassUnit gprBypassUnit1 <- mkGPRBypassUnit(gprFile);
    GPRBypassUnit gprBypassUnit2 <- mkGPRBypassUnit(gprFile);

    function Bool isValidLoadInstruction(Bit#(3) func3);
`ifdef RV32
        return ((func3 == load_UNSUPPORTED_011 ||
                func3 == load_UNSUPPORTED_110 ||
                func3 == load_UNSUPPORTED_111) ? False : True);
`elsif RV64
        return (func3 == load_UNSUPPORTED_111 ? False : True);
`else
        return False;
`endif
    endfunction

    function Bool isValidStoreInstruction(Bit#(3) func3);
`ifdef RV32
        return (func3 < 3 ? True : False);
`elsif RV64
        return (func3 < 4 ? True : False);
`else
    return False;
`endif
    endfunction

    function Bool isValidBranchInstruction(Bit#(3) func3);
        return (func3 == branch_UNSUPPORTED_010 || 
                func3 == branch_UNSUPPORTED_011) ? False : True;
    endfunction

    function DecodedInstruction decode000(DecodedInstruction decodedInstruction, Word32 instruction);
        let func7 = instruction[31:25];
        let rs2 = instruction[24:20];
        let rs1 = instruction[19:15];
        let func3 = instruction[14:12];
        let rd = instruction[11:7];

        case(instruction[6:5])
            2'b00: begin    // LOAD
                if (isValidLoadInstruction(func3)) begin
                    decodedInstruction.opcode = LOAD;
                    decodedInstruction.loadOperator = func3;
                    decodedInstruction.rd = tagged Valid rd;
                    decodedInstruction.rs1 = tagged Valid rs1;
                    decodedInstruction.immediate = tagged Valid signExtend({func7,rs2});
                end
            end

            2'b01: begin    // STORE
                if (isValidStoreInstruction(func3)) begin
                    decodedInstruction.opcode = STORE;
                    decodedInstruction.storeOperator = func3;
                    decodedInstruction.rs1 = tagged Valid rs1;
                    decodedInstruction.rs2 = tagged Valid rs2;
                    decodedInstruction.immediate = tagged Valid (signExtend({instruction[31:25], instruction[11:7]}));
                end
            end

            2'b10: begin    // MADD
            end

            2'b11: begin    // BRANCH
                if (isValidBranchInstruction(func3)) begin
                    Word immediate = signExtend({
                        instruction[31],        // 1 bit
                        instruction[7],         // 1 bit
                        instruction[30:25],     // 6 bits
                        instruction[11:8],      // 4 bits
                        1'b0                    // 1 bit
                    });
                    let branchTarget = decodedInstruction.programCounter + signExtend(immediate);
                    Bool branchDirectionNegative = (msb(immediate) == 1'b1 ? True : False);
                    decodedInstruction.opcode = BRANCH;
                    decodedInstruction.branchOperator = func3;
                    decodedInstruction.rs1 = tagged Valid rs1;
                    decodedInstruction.rs2 = tagged Valid rs2;
                    decodedInstruction.immediate = tagged Valid immediate;
                end
            end
        endcase

        return decodedInstruction;
    endfunction

    function DecodedInstruction decode001(DecodedInstruction decodedInstruction, Word32 instruction);
        let rs1 = instruction[19:15];
        let rd = instruction[11:7];

        case(instruction[6:5])
            2'b00: begin    // LOAD-FP
            end

            2'b01: begin    // STORE-FP
            end

            2'b10: begin    // MSUB
            end

            2'b11: begin    // JALR
                decodedInstruction.opcode = JUMP_INDIRECT;
                decodedInstruction.rd = tagged Valid rd;
                decodedInstruction.rs1 = tagged Valid rs1;
                decodedInstruction.immediate = tagged Valid signExtend(instruction[31:20]);
            end
        endcase

        return decodedInstruction;
    endfunction

    function DecodedInstruction decode010(DecodedInstruction decodedInstruction, Word32 instruction);
        case(instruction[6:5])
            2'b00: begin    // CUSTOM-0
            end

            2'b01: begin    // CUSTOM-1
            end

            2'b10: begin    // NMSUB
            end

            2'b11: begin    // ** RESERVED **
            end
        endcase

        return decodedInstruction;
    endfunction

    function DecodedInstruction decode011(DecodedInstruction decodedInstruction, Word32 instruction);
        let rs1 = instruction[19:15];
        let func3 = instruction[14:12];
        let rd = instruction[11:7];

        case(instruction[6:5])
            2'b00: begin    // MISC-MEM
                if (func3 == 3'b000) begin
                    decodedInstruction.opcode = FENCE;
                    decodedInstruction.rd = tagged Valid rd;
                    decodedInstruction.rs1 = tagged Valid rs1;
                end
            end

            2'b01: begin    // AMO
            end

            2'b10: begin    // NMADD
            end

            2'b11: begin    // JAL
                decodedInstruction.opcode = JUMP;
                decodedInstruction.rd = tagged Valid rd;
                decodedInstruction.immediate = tagged Valid signExtend({
                    instruction[31],    // 1 bit
                    instruction[19:12], // 8 bits
                    instruction[20],    // 1 bit
                    instruction[30:21], // 10 bits
                    1'b0                // 1 bit
                });            
            end
        endcase

        return decodedInstruction;
    endfunction

    function DecodedInstruction decode100(DecodedInstruction decodedInstruction, Word32 instruction);
        let func7 = instruction[31:25];
        let rs2 = instruction[24:20];
        let rs1 = instruction[19:15];
        let func3 = instruction[14:12];
        let rd = instruction[11:7];
`ifdef RV32
        let shamt = instruction[24:20];  // same bits as rs2
`elsif RV64
        let shamt = instruction[25:20];  // same bits as rs2 including 1 bit above.
`endif
        let immediate31_20 = signExtend({func7, rs2});
        let uimm = instruction[19:15];   // same bits as rs1

        case(instruction[6:5])
            2'b00: begin    // OP-IMM
                // Check for shift instructions
                if (func3[1:0] == 2'b01) begin
`ifdef RV32
                    if (func7 == 7'b0000000 || func7 == 7'b0100000) begin
                        decodedInstruction.aluOperator = {1'b0, func7, func3};
`elsif RV64
                    if (func7[6:1] == 6'b000000 || func7[6:1] == 6'b010000) begin
                        decodedInstruction.aluOperator = {1'b0, func7[6:1], 1'b0, func3};
`endif
                        decodedInstruction.opcode = ALU;
                        decodedInstruction.rd = tagged Valid rd;
                        decodedInstruction.rs1 = tagged Valid rs1;
                        decodedInstruction.immediate = tagged Valid extend(shamt);
                    end
                end else begin
                    decodedInstruction.aluOperator = {1'b0, 7'b0, func3};
                    decodedInstruction.opcode = ALU;
                    decodedInstruction.rd = tagged Valid rd;
                    decodedInstruction.rs1 = tagged Valid rs1;
                    decodedInstruction.immediate = tagged Valid immediate31_20;
                end
            end

            2'b01: begin    // OP
                if (func7 == 7'b0000000 || (func7 == 7'b0100000 && (func3 == 3'b000 || func3 == 3'b101))) begin
                    decodedInstruction.aluOperator = {1'b0, func7, func3};
                    decodedInstruction.opcode = ALU;
                    decodedInstruction.rd = tagged Valid rd;
                    decodedInstruction.rs1 = tagged Valid rs1;
                    decodedInstruction.rs2 = tagged Valid rs2;            
                end
            end

            2'b10: begin    // OP-FP
            end

            2'b11: begin    // SYSTEM
                case(func3)
                    3'b000: begin
                        let systemOperator = instruction[31:7];
                        case(systemOperator)
                            //
                            // ECALL
                            //
                            25'b0000000_00000_00000_000_00000: begin
                                decodedInstruction.opcode = SYSTEM;
                                decodedInstruction.systemOperator = sys_ECALL;
                            end
                            //
                            // EBREAK
                            //
                            25'b0000000_00001_00000_000_00000: begin
                                decodedInstruction.opcode = SYSTEM;
                                decodedInstruction.systemOperator = sys_EBREAK;
                            end
                            //
                            // SRET
                            //
                            25'b0001000_00010_00000_000_00000: begin
                                decodedInstruction.opcode = SYSTEM;
                                decodedInstruction.systemOperator = sys_SRET;
                            end
                            //
                            // MRET
                            //
                            25'b0011000_00010_00000_000_00000: begin
                                decodedInstruction.opcode = SYSTEM;
                                decodedInstruction.systemOperator = sys_MRET;
                            end
                            //
                            // WFI
                            //
                            25'b0001000_00101_00000_000_00000: begin
                                decodedInstruction.opcode = SYSTEM;
                                decodedInstruction.systemOperator = sys_WFI;
                            end
                        endcase
                    end

                    //
                    // CSR operations
                    //
                    csr_CSRRW, csr_CSRRS, csr_CSRRC: begin
                        decodedInstruction.opcode = CSR;
                        decodedInstruction.csrOperator = func3;
                        decodedInstruction.csrIndex = tagged Valid ({func7, rs2});
                        decodedInstruction.rd = tagged Valid rd;
                        decodedInstruction.rs1 = tagged Valid rs1;
                    end

                    csr_CSRRWI, csr_CSRRSI, csr_CSRRCI: begin
                        decodedInstruction.opcode = CSR;
                        decodedInstruction.csrOperator = func3;
                        decodedInstruction.csrIndex = tagged Valid ({func7, rs2});
                        decodedInstruction.rd = tagged Valid rd;
                        decodedInstruction.immediate = tagged Valid extend(uimm);
                    end
                endcase
            end
        endcase

        return decodedInstruction;
    endfunction

    function DecodedInstruction decode101(DecodedInstruction decodedInstruction, Word32 instruction);
        let rd = instruction[11:7];

        case(instruction[6:5])
            2'b00: begin    // AUIPC
                decodedInstruction.opcode = COPY_IMMEDIATE;
                decodedInstruction.rd = tagged Valid rd;
                decodedInstruction.immediate = tagged Valid (decodedInstruction.programCounter + (signExtend({instruction[31:12], 12'b0})));
            end

            2'b01: begin    // LUI
                decodedInstruction.opcode = COPY_IMMEDIATE;
                decodedInstruction.rd = tagged Valid rd;
                decodedInstruction.immediate = tagged Valid (signExtend({instruction[31:12], 12'b0}));
            end

            2'b10: begin    // ** RESERVED **
            end

            2'b11: begin    // ** RESERVED **
            end
        endcase

        return decodedInstruction;
    endfunction


    function DecodedInstruction decode110(DecodedInstruction decodedInstruction, Word32 instruction);
        let func7 = instruction[31:25];
        let rs2 = instruction[24:20];
        let rs1 = instruction[19:15];
        let func3 = instruction[14:12];
        let rd = instruction[11:7];
        let immediate31_20 = signExtend({func7,rs2});

        decodedInstruction.rs1 = tagged Valid rs1;
        decodedInstruction.rd = tagged Valid rd;

        case(instruction[6:5])
`ifdef RV64
            2'b00: begin    // OP-IMM-32
                if (func3[1:0] == 2'b01) begin
                    if (func7 == 7'b0000000 || func7 == 7'b0100000) begin
                        decodedInstruction.aluOperator = {1'b1, func7, func3};
                        decodedInstruction.opcode = ALU;
                        decodedInstruction.immediate = tagged Valid extend(instruction[24:20]);
                    end
                end else begin
                    decodedInstruction.aluOperator = {1'b1, 7'b0, func3};
                    decodedInstruction.opcode = ALU;
                    decodedInstruction.immediate = tagged Valid immediate31_20;
                end
            end

            2'b01: begin    // OP-32
                if (func7 == 7'b0000000 || (func7 == 7'b0100000 && (func3 == 3'b000 || func3 == 3'b101))) begin
                    decodedInstruction.aluOperator = {1'b1, func7, func3};
                    decodedInstruction.opcode = ALU;
                    decodedInstruction.rs2 = tagged Valid rs2;
                end
            end
`endif
            2'b10: begin    // Custom for RV32/RV64, Reserved on RV128
            end
            2'b11: begin    // Custom for RV32/RV64, Reserved on RV128
            end
        endcase

        return decodedInstruction;
    endfunction

    function DecodedInstruction decodeInstruction(ProgramCounter programCounter, Word32 instruction);
        let decodedInstruction = newDecodedInstruction(programCounter, instruction);

        if (instruction[1:0] == 2'b11) begin
            decodedInstruction = case (instruction[4:2])
                'b000: decode000(decodedInstruction, instruction);
                'b001: decode001(decodedInstruction, instruction);
                'b010: decode010(decodedInstruction, instruction);
                'b011: decode011(decodedInstruction, instruction);
                'b100: decode100(decodedInstruction, instruction);
                'b101: decode101(decodedInstruction, instruction);
                'b110: decode110(decodedInstruction, instruction);
                // 'b111: begin
                //     // ** Reserved for instruction lengths > 32 bits.
                // end
            endcase;
        end
        
        return decodedInstruction;
    endfunction

    FIFO#(DecodedInstruction) outputQueue <- mkPipelineFIFO;

    FIFOF#(DecodedInstruction) decodedInstructionWaitingForOperands <- mkFIFOF;

    rule waitForOperands;
        Bool verbose <- $test$plusargs ("verbose");
        let decodedInstruction = decodedInstructionWaitingForOperands.first;

        let fetchIndex = decodedInstruction.fetchIndex;
        let programCounter = decodedInstruction.programCounter;
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 2);

        //
        // Check bypasses
        //
        let bypassTpl1 <- gprBypassUnit1.processBypass(decodedInstruction);
        let stallWaitingForOperands1 = tpl_1(bypassTpl1);
        decodedInstruction = tpl_2(bypassTpl1);

        let bypassTpl2 <- gprBypassUnit2.processBypass(decodedInstruction);
        let stallWaitingForOperands2 = tpl_1(bypassTpl2);
        decodedInstruction = tpl_2(bypassTpl2);

        let stallWaitingForCSR = scoreboard.search(decodedInstruction.csrIndex);

        if (stallWaitingForCSR || stallWaitingForOperands1 || stallWaitingForOperands2) begin
            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,decode,stall waiting for operands", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber);
        end else begin
            decodedInstructionWaitingForOperands.deq;

            // Send the decode result to the output queue.
            outputQueue.enq(decodedInstruction);

            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,decode,decode complete", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber);
        end
    endrule

    interface Put putEncodedInstruction;
        method Action put(EncodedInstruction encodedInstruction) if(decodedInstructionWaitingForOperands.notEmpty == False);
            Bool verbose <- $test$plusargs ("verbose");
            let fetchIndex = encodedInstruction.fetchIndex;
            let stageEpoch = pipelineController.stageEpoch(stageNumber, 2);

            if (!pipelineController.isCurrentEpoch(stageNumber, 2, encodedInstruction.pipelineEpoch)) begin
                if (verbose)
                    $display("%0d,%0d,%0d,%0x,%0d,decode,stale instruction...ignoring", fetchIndex, cycleCounter, encodedInstruction.pipelineEpoch, encodedInstruction.programCounter, stageNumber);
            end else if(isValid(encodedInstruction.exception)) begin
                // Pass along any exceptions
                if (verbose)
                    $display("%0d,%0d,%0d,%0x,%0d,decode,exception in encoded instruction...propagating", fetchIndex, cycleCounter, encodedInstruction.pipelineEpoch, encodedInstruction.programCounter, stageNumber);

                let decodedInstruction = newDecodedInstruction(encodedInstruction.programCounter, 0);
                decodedInstruction.fetchIndex = fetchIndex;
                decodedInstruction.pipelineEpoch = stageEpoch;
                decodedInstruction.opcode = NO_OP;
                decodedInstruction.exception = encodedInstruction.exception;
                outputQueue.enq(decodedInstruction);
            end else begin
                let rawInstruction = encodedInstruction.rawInstruction;
                let programCounter = encodedInstruction.programCounter;

                let decodedInstruction = decodeInstruction(programCounter, rawInstruction);
                decodedInstruction.fetchIndex = encodedInstruction.fetchIndex;
                decodedInstruction.pipelineEpoch = stageEpoch;
                decodedInstruction.predictedNextProgramCounter = encodedInstruction.predictedNextProgramCounter;

                //
                // Check GPR bypasses (these may stall if waiting for register values from memory)
                //
                let bypassTpl1 <- gprBypassUnit1.processBypass(decodedInstruction);
                let stallWaitingForOperands1 = tpl_1(bypassTpl1);
                decodedInstruction = tpl_2(bypassTpl1);

                let bypassTpl2 <- gprBypassUnit2.processBypass(decodedInstruction);
                let stallWaitingForOperands2 = tpl_1(bypassTpl2);
                decodedInstruction = tpl_2(bypassTpl2);

                let stallWaitingForCSR = scoreboard.search(decodedInstruction.csrIndex);

                if (stallWaitingForOperands1 || stallWaitingForOperands2 || stallWaitingForCSR) begin
                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,decode,stall waiting for operands", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber);
                    decodedInstructionWaitingForOperands.enq(decodedInstruction);
                end else begin
                    if (decodedInstruction.csrIndex matches tagged Valid .csrIndex) begin
                        let readResult = csrFile.read1(csrIndex);
                        if (readResult matches tagged Valid .csrValue) begin
                            if (verbose)
                                $display("%0d,%0d,%0d,%0x,%0d,decode,CSR ($%0X) read $%0X", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber, csrIndex, csrValue);
                            decodedInstruction.csrValue = csrValue;                                
                        end else begin
`ifdef ENABLE_RISCOF_TESTS
                            if (csrIndex == csr_RISCOF_HALT) begin
                                decodedInstruction.exception = tagged Valid createRISCOFTestHaltException(programCounter);
                            end else
`endif
                            begin
                                if (verbose) begin
                                    let curPriv <- csrFile.getCurrentPrivilegeLevel.get;
                                    $display("%0d,%0d,%0d,%0x,%0d,decode,CSR ($%0X) failed read (PRIV: $%0x)", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber, csrIndex, curPriv);
                                end
                                decodedInstruction.exception = tagged Valid createIllegalInstructionException(decodedInstruction.rawInstruction);
                            end
                        end
                    end

                    // Send the decode result to the output queue.
                    outputQueue.enq(decodedInstruction);

                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,decode,decode complete", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber);
                end
            end
        endmethod
    endinterface

    interface Put putCycleCounter = toPut(asIfc(cycleCounter));
    interface Get getDecodedInstruction = toGet(outputQueue);
    interface Put putGPRBypassValue1 = gprBypassUnit1.putGPRBypassValue;
    interface Put putGPRBypassValue2 = gprBypassUnit2.putGPRBypassValue;
endmodule
