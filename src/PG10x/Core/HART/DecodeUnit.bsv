//
// DecodeUnit
//
// This module is a RISC-V instruction decode unit.  It is responsible for decoding machine 
// code (a 'EncodedInstruction' structure) values into a 'DecodedInstruction' structure.
//
import PGTypes::*;

import BypassUnit::*;
import EncodedInstruction::*;
import DecodedInstruction::*;
import GPRFile::*;
import PipelineController::*;

import FIFO::*;
import FIFOF::*;
import GetPut::*;
import SpecialFIFOs::*;

export DecodeUnit(..), mkDecodeUnit;

interface DecodeUnit;
    interface Put#(EncodedInstruction) putEncodedInstruction;
    interface Get#(DecodedInstruction) getDecodedInstruction;

    interface Put#(Maybe#(GPRBypassValue)) putGPRBypassValue1;
    interface Put#(Maybe#(GPRBypassValue)) putGPRBypassValue2;
endinterface

module mkDecodeUnit#(
    ReadOnly#(Word64) cycleCounter,
    Integer stageNumber,
    PipelineController pipelineController,
    GPRFile gprFile
)(DecodeUnit);
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

    function DecodedInstruction decodeInstruction(ProgramCounter programCounter, Word32 instruction);
        let opcode = instruction[6:0];
        let rd = instruction[11:7];
        let func3 = instruction[14:12];
        let rs1 = instruction[19:15];
        let uimm = instruction[19:15];   // same bits as rs1
        let rs2 = instruction[24:20];
`ifdef RV32
        let shamt = instruction[24:20];  // same bits as rs2
`elsif RV64
        let shamt = instruction[25:20];  // same bits as rs2 including 1 bit above.
`endif
        let func7 = instruction[31:25];
        let immediate31_20 = signExtend(instruction[31:20]); // same bits as {func7, rs2}

        let decodedInstruction = DecodedInstruction {
            fetchIndex: ?,
            pipelineEpoch: ?,
            opcode: UNSUPPORTED_OPCODE,
            programCounter: programCounter,
            rawInstruction: instruction,
            predictedNextProgramCounter: ?,
            aluOperator: {func7, func3},
            loadOperator: func3,
            storeOperator: func3,
            csrOperator: func3,
            csrIndex: {func7, rs2},
            branchOperator: ?,
            systemOperator: ?,
            rd: tagged Invalid,
            rs1: tagged Invalid,
            rs2: tagged Invalid,
            immediate: tagged Invalid,
            rs1Value: ?,
            rs2Value: ?
        };

        case(opcode)
            //
            // LOAD
            //
            7'b0000011: begin
                if (isValidLoadInstruction(func3)) begin
                    decodedInstruction.opcode = LOAD;
                    decodedInstruction.rd = tagged Valid rd;
                    decodedInstruction.rs1 = tagged Valid rs1;
                    decodedInstruction.immediate = tagged Valid immediate31_20;
                end
            end
            //
            // MISC_MEM
            //
            7'b0001111: begin
                if (func3 == 3'b000) begin
                    decodedInstruction.opcode = FENCE;
                    decodedInstruction.rd = tagged Valid rd;
                    decodedInstruction.rs1 = tagged Valid rs1;
                end
            end
            //
            // OP-IMM
            //
            7'b0010011: begin   
                // OP-IMM only used func3 for operator encoding.
                decodedInstruction.aluOperator = extend(func3);

                // Check for shift instructions
                if (func3[1:0] == 2'b01) begin
`ifdef RV32
                    if (func7 == 7'b0000000 || func7 == 7'b0100000) begin
`elsif RV64
                    if (func7[6:1] == 6'b000000 || func7[6:1] == 6'b010000) begin
`endif
                        decodedInstruction.opcode = ALU;
                        decodedInstruction.rd = tagged Valid rd;
                        decodedInstruction.rs1 = tagged Valid rs1;
                        decodedInstruction.immediate = tagged Valid extend(shamt);
                    end
                end else begin
                    decodedInstruction.opcode = ALU;
                    decodedInstruction.rd = tagged Valid rd;
                    decodedInstruction.rs1 = tagged Valid rs1;
                    decodedInstruction.immediate = tagged Valid immediate31_20;
                end
            end
`ifdef RV64
            //
            // OP-IMM32
            //
            7'b0011011: begin
                // OP-IMM only used func3 for operator encoding.
                decodedInstruction.aluOperator = extend(func3);

                // Check for shift instructions
                if (func3[1:0] == 2'b01) begin
                    if (func7 == 7'b0000000 || func7 == 7'b0100000) begin
                        decodedInstruction.opcode = ALU3264;
                        decodedInstruction.rd = tagged Valid rd;
                        decodedInstruction.rs1 = tagged Valid rs1;
                        decodedInstruction.immediate = tagged Valid extend(shamt);
                    end
                end else begin
                    decodedInstruction.opcode = ALU3264;
                    decodedInstruction.rd = tagged Valid rd;
                    decodedInstruction.rs1 = tagged Valid rs1;
                    decodedInstruction.immediate = tagged Valid immediate31_20;
                end
            end
`endif
            //
            // AUIPC
            //
            7'b0010111: begin
                decodedInstruction.opcode = COPY_IMMEDIATE;
                decodedInstruction.rd = tagged Valid rd;
                decodedInstruction.immediate = tagged Valid (decodedInstruction.programCounter + (signExtend({instruction[31:12], 12'b0})));
            end
            //
            // STORE
            //
            7'b0100011: begin
                if (isValidStoreInstruction(func3)) begin
                    decodedInstruction.opcode = STORE;
                    decodedInstruction.rs1 = tagged Valid rs1;
                    decodedInstruction.rs2 = tagged Valid rs2;
                    decodedInstruction.immediate = tagged Valid (signExtend({instruction[31:25], instruction[11:7]}));
                end
            end
            //
            // OP
            // 
            7'b0110011: begin
                if (func7 == 7'b0000000 || (func7 == 7'b0100000 && (func3 == 3'b000 || func3 == 3'b101)))   
                    decodedInstruction.opcode = ALU;
                    decodedInstruction.rd = tagged Valid rd;
                    decodedInstruction.rs1 = tagged Valid rs1;
                    decodedInstruction.rs2 = tagged Valid rs2;
            end
            //
            // LUI
            //
            7'b0110111: begin
                decodedInstruction.opcode = COPY_IMMEDIATE;
                decodedInstruction.rd = tagged Valid rd;
                decodedInstruction.immediate = tagged Valid (signExtend({instruction[31:12], 12'b0}));
            end
            //
            // BRANCH
            //
            7'b1100011: begin
                if (isValidBranchInstruction(func3)) begin
                    Word immediate = signExtend({
                        instruction[31],        // 1 bit
                        instruction[7],         // 1 bit
                        instruction[30:25],     // 6 bits
                        instruction[11:8],      // 4 bits
                        1'b0                    // 1 bit
                    });
                    let branchTarget = programCounter + signExtend(immediate);
                    Bool branchDirectionNegative = (msb(immediate) == 1'b1 ? True : False);
                    decodedInstruction.opcode = BRANCH;
                    decodedInstruction.branchOperator = func3;
                    decodedInstruction.rs1 = tagged Valid rs1;
                    decodedInstruction.rs2 = tagged Valid rs2;
                    decodedInstruction.immediate = tagged Valid immediate;
                end
            end
            //
            // JALR
            //
            7'b1100111: begin
                decodedInstruction.opcode = JUMP_INDIRECT;
                decodedInstruction.rd = tagged Valid rd;
                decodedInstruction.rs1 = tagged Valid rs1;
                decodedInstruction.immediate = tagged Valid signExtend(instruction[31:20]);
            end
            //
            // JAL
            //
            7'b1101111: begin
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
            //
            // SYSTEM
            //
            7'b1110011: begin
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
                        decodedInstruction.rd = tagged Valid rd;
                        decodedInstruction.rs1 = tagged Valid rs1;
                    end

                    csr_CSRRWI, csr_CSRRSI, csr_CSRRCI: begin
                        decodedInstruction.opcode = CSR;
                        decodedInstruction.rd = tagged Valid rd;
                        decodedInstruction.immediate = tagged Valid extend(uimm);
                    end
                endcase
            end
        endcase

        return decodedInstruction;
    endfunction

    FIFO#(DecodedInstruction) outputQueue <- mkPipelineFIFO;

    FIFOF#(DecodedInstruction) decodedInstructionWaitingForOperands <- mkFIFOF;

    (* fire_when_enabled *)
    rule waitForOperands;
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

        if (stallWaitingForOperands1 || stallWaitingForOperands2) begin
            $display("%0d,%0d,%0d,%0x,%0d,decode,stall waiting for operands", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber);
        end else begin
            decodedInstructionWaitingForOperands.deq;

            // Send the decode result to the output queue.
            outputQueue.enq(decodedInstruction);

            $display("%0d,%0d,%0d,%0x,%0d,decode,decode complete", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber);
        end
    endrule

    interface Put putEncodedInstruction;
        method Action put(EncodedInstruction encodedInstruction) if(decodedInstructionWaitingForOperands.notEmpty == False);
            let fetchIndex = encodedInstruction.fetchIndex;
            let stageEpoch = pipelineController.stageEpoch(stageNumber, 2);

            if (!pipelineController.isCurrentEpoch(stageNumber, 2, encodedInstruction.pipelineEpoch)) begin
                $display("%0d,%0d,%0d,%0x,%0d,decode,stale instruction...ignoring", fetchIndex, cycleCounter, encodedInstruction.pipelineEpoch, encodedInstruction.programCounter, stageNumber);
            end else begin
                let rawInstruction = encodedInstruction.rawInstruction;
                let programCounter = encodedInstruction.programCounter;

                let decodedInstruction = decodeInstruction(programCounter, rawInstruction);
                decodedInstruction.fetchIndex = encodedInstruction.fetchIndex;
                decodedInstruction.pipelineEpoch = stageEpoch;
                decodedInstruction.predictedNextProgramCounter = encodedInstruction.predictedNextProgramCounter;

                //
                // Check bypasses
                //
                let bypassTpl1 <- gprBypassUnit1.processBypass(decodedInstruction);
                let stallWaitingForOperands1 = tpl_1(bypassTpl1);
                decodedInstruction = tpl_2(bypassTpl1);

                let bypassTpl2 <- gprBypassUnit2.processBypass(decodedInstruction);
                let stallWaitingForOperands2 = tpl_1(bypassTpl2);
                decodedInstruction = tpl_2(bypassTpl2);

                if (stallWaitingForOperands1 || stallWaitingForOperands2) begin
                    $display("%0d,%0d,%0d,%0x,%0d,decode,stall waiting for operands", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber);
                    decodedInstructionWaitingForOperands.enq(decodedInstruction);
                end else begin
                    // Send the decode result to the output queue.
                    outputQueue.enq(decodedInstruction);

                    $display("%0d,%0d,%0d,%0x,%0d,decode,decode complete", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber);
                end
            end
        endmethod
    endinterface

    interface Get getDecodedInstruction = toGet(outputQueue);
    interface Put putGPRBypassValue1 = gprBypassUnit1.putGPRBypassValue;
    interface Put putGPRBypassValue2 = gprBypassUnit2.putGPRBypassValue;
endmodule
