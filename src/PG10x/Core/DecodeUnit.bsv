//
// DecodeUnit
//
// This module is a RISC-V instruction decode unit.  It is responsible for decoding machine 
// code (a 'EncodedInstruction' structure) values into a 'DecodedInstruction' structure.
//
import PGTypes::*;

import EncodedInstruction::*;
import DecodedInstruction::*;
import PipelineController::*;
import RegisterFile::*;
import Scoreboard::*;

import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export DecodeUnit(..), mkDecodeUnit;

interface DecodeUnit;
    interface FIFO#(DecodedInstruction) getDecodedInstructionQueue;
endinterface

module mkDecodeUnit#(
    Reg#(Word64) cycleCounter,
    Integer stageNumber,
    PipelineController pipelineController,
    FIFO#(EncodedInstruction) inputQueue,
    Scoreboard#(4) scoreboard,
    RegisterFile registerFile
)(DecodeUnit);
    FIFO#(DecodedInstruction) outputQueue <- mkPipelineFIFO();

    function Bool isValidLoadInstruction(Bit#(3) func3);
`ifdef RV32
        return (func3 == pack(UNSUPPORTED_LOAD_OPERATOR_011) ||
                func3 == pack(UNSUPPORTED_LOAD_OPERATOR_110) ||
                func3 == pack(UNSUPPORTED_LOAD_OPERATOR_111) ? False : True);
`elsif RV64
        return (func3 == pack(UNSUPPORTED_LOAD_OPERATOR_111) ? False : True);
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
        return (func3 == pack(UNSUPPORTED_BRANCH_OPERATOR_010) || 
                func3 == pack(UNSUPPORTED_BRANCH_OPERATOR_011) ? False : True);
    endfunction

    function DecodedInstruction decodeInstruction(ProgramCounter programCounter, Word32 instruction);
        let opcode = instruction[6:0];
        let rd = instruction[11:7];
        let func3 = instruction[14:12];
        let rs1 = instruction[19:15];
        let uimm = instruction[19:15];   // same bits as rs1
        let rs2 = instruction[24:20];
        let shamt = instruction[24:20];  // same bits as rs2
        let func7 = instruction[31:25];
        let immediate31_20 = signExtend(instruction[31:20]); // same bits as {func7, rs2}

        let decodedInstruction = DecodedInstruction {
            fetchIndex: ?,
            pipelineEpoch: ?,
            opcode: UNSUPPORTED_OPCODE,
            programCounter: programCounter,
            predictedNextProgramCounter: ?,
            aluOperator: unpack({func7, func3}),
            loadOperator: unpack(func3),
            storeOperator: unpack(func3),
            csrOperator: unpack(func3),
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
                // Check for shift instructions
                if (func3[1:0] == 2'b01) begin
                    if (func7 == 7'b0000000 || func7 == 7'b0100000) begin
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
            //
            // AUIPC
            //
            7'b0010111: begin
                decodedInstruction.opcode = COPY_IMMEDIATE;
                decodedInstruction.rd = tagged Valid rd;
                decodedInstruction.immediate = tagged Valid (signExtend({instruction[31:12], 12'b0}));
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
                                decodedInstruction.systemOperator = pack(ECALL);
                            end
                            //
                            // EBREAK
                            //
                            25'b0000000_00001_00000_000_00000: begin
                                decodedInstruction.opcode = SYSTEM;
                                decodedInstruction.systemOperator = pack(EBREAK);
                            end
                            //
                            // SRET
                            //
                            25'b0001000_00010_00000_000_00000: begin
                                decodedInstruction.opcode = SYSTEM;
                                decodedInstruction.systemOperator = pack(SRET);
                            end
                            //
                            // MRET
                            //
                            25'b0011000_00010_00000_000_00000: begin
                                decodedInstruction.opcode = SYSTEM;
                                decodedInstruction.systemOperator = pack(MRET);
                            end
                            //
                            // WFI
                            //
                            25'b0001000_00101_00000_000_00000: begin
                                decodedInstruction.opcode = SYSTEM;
                                decodedInstruction.systemOperator = pack(WFI);
                            end
                        endcase
                    end

                    //
                    // CSR operations
                    //
                    pack(CSRRW), pack(CSRRS), pack(CSRRC): begin
                        decodedInstruction.opcode = CSR;
                        decodedInstruction.rd = tagged Valid rd;
                        decodedInstruction.rs1 = tagged Valid rs1;
                    end

                    pack(CSRRWI), pack(CSRRSI), pack(CSRRCI): begin
                        decodedInstruction.opcode = CSR;
                        decodedInstruction.rd = tagged Valid rd;
                        decodedInstruction.immediate = tagged Valid extend(uimm);
                    end
                endcase
            end
        endcase

        return decodedInstruction;
    endfunction

    (* fire_when_enabled *)
    rule decode;
        let instructionMemoryResponse = inputQueue.first;
        let fetchIndex = instructionMemoryResponse.fetchIndex;
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 2);

        if (!pipelineController.isCurrentEpoch(stageNumber, 2, instructionMemoryResponse.pipelineEpoch)) begin
            $display("%0d,%0d,%0d,%0d,%0d,decode,stale instruction...ignoring", fetchIndex, cycleCounter, instructionMemoryResponse.pipelineEpoch, instructionMemoryResponse.programCounter, stageNumber);
            inputQueue.deq();
        end else begin
            let encodedInstruction = instructionMemoryResponse.rawInstruction;
            let programCounter = instructionMemoryResponse.programCounter;

            let decodedInstruction = decodeInstruction(programCounter, encodedInstruction);
            decodedInstruction.fetchIndex = instructionMemoryResponse.fetchIndex;
            decodedInstruction.pipelineEpoch = stageEpoch;
            decodedInstruction.predictedNextProgramCounter = instructionMemoryResponse.predictedNextProgramCounter;

            $display("%0d,%0d,%0d,%0d,%0d,decode,scoreboard size: %0d", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber, scoreboard.size);

            let stallWaitingForOperands = scoreboard.search(decodedInstruction.rs1, decodedInstruction.rs2);
            if (stallWaitingForOperands) begin
                $display("%0d,%0d,%0d,%0d,%0d,decode,stall waiting for operands", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber);
            end else begin
                inputQueue.deq;

                // Read the source operand registers since the scoreboard indicates it's available.
                if (isValid(decodedInstruction.rs1))
                    decodedInstruction.rs1Value = registerFile.read1(unJust(decodedInstruction.rs1));

                if (isValid(decodedInstruction.rs2))
                    decodedInstruction.rs2Value = registerFile.read2(unJust(decodedInstruction.rs2));

                scoreboard.insert(decodedInstruction.rd);

                $display("%0d,%0d,%0d,%0d,%0d,decode,inserting into scoreboard (new count = %0d): ", 
                    fetchIndex, 
                    cycleCounter, 
                    stageEpoch, 
                    programCounter, 
                    stageNumber, 
                    scoreboard.size,
                    (isValid(decodedInstruction.rd) ? 
                        $format("x%0d", unJust(decodedInstruction.rd)) : $format("INVALID")));

                // Send the decode result to the output queue.
                outputQueue.enq(decodedInstruction);

                $display("%0d,%0d,%0d,%0d,%0d,decode,decode complete", fetchIndex, cycleCounter, stageEpoch, programCounter, stageNumber);
    //                $display("%0d,%0d,%0d,2,decode,", cycleCounter, stageEpoch, programCounter, fshow(decodedInstruction));
            end
        end
    endrule

    interface FIFO getDecodedInstructionQueue = outputQueue;
endmodule
