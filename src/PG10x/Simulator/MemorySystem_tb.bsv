import PGTypes::*;
import MemorySystem::*;
import BRAMServerTile::*;

import Assert::*;

typedef enum {
    INSTRUCTION_MEMORY_TEST_SETUP,
    INSTRUCTION_MEMORY_TEST,
    DATA_MEMORY_READ_TEST_SETUP,
    DATA_MEMORY_READ_TEST,
    DATA_MEMORY_WRITE_TEST_SETUP,
    DATA_MEMORY_WRITE_TEST,
    DATA_MEMORY_WRITE_VERIFY_TEST,
    COMPLETE
} TestPhase deriving(Bits, Eq);

(* synthesize *)
module mkMemorySystem_tb(Empty);
    // BRAM Server Tile
    DualPortBRAMServerTile memory <- mkBRAMServerTileFromFile(32, "MemorySystem_tb.hex");

    // Memory System
    let memoryBaseAddress = 'hC000_0000;
    MemorySystem memorySystem <- mkMemorySystem(memory, memoryBaseAddress);

    Reg#(TestPhase) testPhase <- mkReg(INSTRUCTION_MEMORY_TEST_SETUP);
    Reg#(Word) addressToCheck <- mkReg(memoryBaseAddress);
    Reg#(Word) testNumber <- mkReg(0);

    Reg#(Word) cycleCounter <- mkReg(0);
    Reg#(Word) startCycle <- mkReg(0);
    Reg#(Bool) waitingForResponse <- mkReg(False);

    (* fire_when_enabled, no_implicit_conditions *)
    rule incrementCycleCounter;
        cycleCounter <= cycleCounter + 1;
    endrule

    rule instructionMemoryTestSetup(testPhase == INSTRUCTION_MEMORY_TEST_SETUP);
        testPhase <= INSTRUCTION_MEMORY_TEST;
    endrule

    (* fire_when_enabled *)
    rule instructionMemoryRequest(testPhase == INSTRUCTION_MEMORY_TEST && waitingForResponse == False);
        $display("[Instruction Memory] Requesting value from $%x", addressToCheck);
        memorySystem.instructionMemory.request.put(InstructionMemoryRequest {
            a_opcode: pack(A_GET),
            a_param: 0,
            a_size: 1,
            a_source: 0,
            a_address: addressToCheck,
            a_mask: ?,
            a_data: ?,
            a_corrupt: False
        });
        startCycle <= cycleCounter;
        waitingForResponse <= True;
    endrule

    (* fire_when_enabled *) //descending_urgency="incrementCycleCounter, request, check" *)
    rule instructionMemoryCheck(testPhase == INSTRUCTION_MEMORY_TEST && waitingForResponse == True);
        let response <- memorySystem.instructionMemory.response.get;
        dynamicAssert(response.d_opcode == pack(D_ACCESS_ACK_DATA), "[Instruction Memory] FAILED: Incorrect d_opcode");
        dynamicAssert(response.d_param == 0, "[Instruction Memory] FAILED: Incorrect d_param");
        dynamicAssert(response.d_source == 0, "[Instruction Memory] FAILED: Incorrect d_source");
        dynamicAssert(response.d_sink == 0, "[Instruction Memory] FAILED: Incorrect d_sink");
        dynamicAssert(response.d_denied == False, "[Instruction Memory] FAILED: Response marked as denied");
        dynamicAssert(response.d_corrupt == False, "[Instruction Memory] FAILED: Response marked as corrupted");
        dynamicAssert(response.d_size == 1, "[Instruction Memory] FAILED: Incorrect d_size");
        dynamicAssert(response.d_data == truncate(addressToCheck - fromInteger(memoryBaseAddress)), "[Instruction Memory] FAILED: Incorrect d_data");

        Word expectedLatency = 3;
        let requestLatency = cycleCounter - startCycle;
        if (requestLatency != expectedLatency) begin
            $display("[Instruction Memory] FAILED: Request latency ($%x) != expected latency ($%x)", requestLatency, expectedLatency);
            $fatal();
        end

        if (addressToCheck == memoryBaseAddress + 'h10) begin
            testPhase <= DATA_MEMORY_READ_TEST_SETUP;
        end

        addressToCheck <= addressToCheck + 4;
        waitingForResponse <= False;
    endrule

    (* fire_when_enabled *)
    rule dataMemoryReadTestSetup(testPhase == DATA_MEMORY_READ_TEST_SETUP);
        testPhase <= DATA_MEMORY_READ_TEST;
        addressToCheck <= memoryBaseAddress;
        waitingForResponse <= False;
    endrule

    (* fire_when_enabled *)
    rule dataMemoryReadRequest(testPhase == DATA_MEMORY_READ_TEST && waitingForResponse == False);
        $display("[Data Memory] Requesting value from $%x", addressToCheck);
        memorySystem.dataMemory.request.put(DataMemoryRequest {
            a_opcode: pack(A_GET),
            a_param: 0,
            a_size: 1,
            a_source: 0,
            a_address: addressToCheck,
            a_mask: ?,
            a_data: ?,
            a_corrupt: False
        });

        startCycle <= cycleCounter;
        waitingForResponse <= True;
    endrule

`ifdef RV32
    Integer testCount = 6;
    Word expectedData[testCount] = {
        'h00000000,
        'h00000004,
        'h00000008,
        'h0000000C,
        'h00000010,
        'h00000014
    };
`else
    Integer testCount = 3;
    Word expectedData[testCount] = {
        'h00000004_00000000,
        'h0000000C_00000008,
        'h00000014_00000010
    };
`endif

    rule dataMemoryReadCheck(testPhase == DATA_MEMORY_READ_TEST && waitingForResponse == True);
        let response <- memorySystem.dataMemory.response.get;
        dynamicAssert(response.d_opcode == pack(D_ACCESS_ACK_DATA), "[Data Memory Read] FAILED: Incorrect d_opcode");
        dynamicAssert(response.d_param == 0, "[Data Memory Read] FAILED: Incorrect d_param");
        dynamicAssert(response.d_source == 0, "[Data Memory Read] FAILED: Incorrect d_source");
        dynamicAssert(response.d_sink == 0, "[Data Memory Read] FAILED: Incorrect d_sink");
        dynamicAssert(response.d_denied == False, "[Data Memory Read] FAILED: Response marked as denied");
        dynamicAssert(response.d_corrupt == False, "[Data Memory Read] FAILED: Response marked as corrupt");
        dynamicAssert(response.d_size == 1, "[Data Memory Read] FAILED: Incorrect d_size");

        Word expectedDataThisRound = expectedData[testNumber];
        if (response.d_data != expectedDataThisRound) begin
            $display("[Data Memory Read] FAILED: Received data $%x != Expected data: $%x", response.d_data, expectedDataThisRound);
            $fatal();
        end

`ifdef RV32
        Word expectedLatency = 3;
`else
        Word expectedLatency = 8;
`endif
        let requestLatency = cycleCounter - startCycle;
        if (requestLatency != expectedLatency) begin
            $display("[Data Memory Read] FAILED: Request latency ($%x) != expected latency ($%x)", requestLatency, expectedLatency);
            $fatal();
        end

        testNumber <= testNumber + 1;
        if (testNumber >= fromInteger(testCount)) begin
            testPhase <= DATA_MEMORY_WRITE_TEST_SETUP;
        end

        addressToCheck <= addressToCheck + fromInteger(valueOf(TDiv#(XLEN, 8)));
        waitingForResponse <= False;
    endrule

    (* fire_when_enabled *)
    rule dataMemoryWriteTestSetup(testPhase == DATA_MEMORY_WRITE_TEST_SETUP);
        testPhase <= DATA_MEMORY_WRITE_TEST;
        addressToCheck <= memoryBaseAddress;
        waitingForResponse <= False;
        testNumber <= 0;
    endrule

    (* fire_when_enabled *)
    rule dataMemoryWriteRequest(testPhase == DATA_MEMORY_WRITE_TEST && waitingForResponse == False);
        $display("[Data Memory] Writing value $%x to $%x", testNumber, addressToCheck);
        memorySystem.dataMemory.request.put(DataMemoryRequest {
            a_opcode: pack(A_PUT_FULL_DATA),
            a_param: 0,
            a_size: 1,
            a_source: 0,
            a_address: addressToCheck,
`ifdef RV64
            a_mask: 8'b1111_1111,
`else // RV32
            a_mask: 4'b1111,
`endif
            a_data: testNumber,
            a_corrupt: False
        });

        startCycle <= cycleCounter;
        waitingForResponse <= True;
    endrule

    rule dataMemoryWriteResponse(testPhase == DATA_MEMORY_WRITE_TEST && waitingForResponse == True);
        let response <- memorySystem.dataMemory.response.get;
        dynamicAssert(response.d_opcode == pack(D_ACCESS_ACK), "[Data Memory Write] FAILED: Incorrect d_opcode");
        dynamicAssert(response.d_param == 0, "[Data Memory Write] FAILED: Incorrect d_param");
        dynamicAssert(response.d_source == 0, "[Data Memory Write] FAILED: Incorrect d_source");
        dynamicAssert(response.d_sink == 0, "[Data Memory Write] FAILED: Incorrect d_sink");
        dynamicAssert(response.d_denied == False, "[Data Memory Write] FAILED: Response marked as denied");
        dynamicAssert(response.d_corrupt == False, "[Data Memory Write] FAILED: Response marked as corrupt");
        dynamicAssert(response.d_size == 0, "[Data Memory Write] FAILED: Incorrect d_size");

`ifdef RV32
        Word expectedLatency = 3;
`else
        Word expectedLatency = 8;
`endif
        let requestLatency = cycleCounter - startCycle;
        if (requestLatency != expectedLatency) begin
            $display("[Data Memory Write] FAILED: Request latency ($%x) != expected latency ($%x)", requestLatency, expectedLatency);
            $fatal();
        end

        waitingForResponse <= False;
        if (testNumber >= 100) begin
            $display("[Data Memory Write] completed writing test values to ($%x)", addressToCheck);
            testPhase <= DATA_MEMORY_WRITE_VERIFY_TEST;
            addressToCheck <= memoryBaseAddress;
            testNumber <= 0;
        end else begin
            addressToCheck <= addressToCheck + fromInteger(valueOf(TDiv#(XLEN, 8)));
            testNumber <= testNumber + 1;
        end
    endrule

    rule dataMemoryWriteVerifyRequest(testPhase == DATA_MEMORY_WRITE_VERIFY_TEST && waitingForResponse == False);
        $display("[Data Memory] Reading written value $%x", addressToCheck);
        memorySystem.dataMemory.request.put(DataMemoryRequest {
            a_opcode: pack(A_GET),
            a_param: 0,
            a_size: 1,
            a_source: 0,
            a_address: addressToCheck,
            a_mask: ?,
            a_data: ?,
            a_corrupt: False
        });

        startCycle <= cycleCounter;
        waitingForResponse <= True;
    endrule

    rule dataMemoryWriteVerifyResponse(testPhase == DATA_MEMORY_WRITE_VERIFY_TEST && waitingForResponse == True);
        let response <- memorySystem.dataMemory.response.get;
        dynamicAssert(response.d_opcode == pack(D_ACCESS_ACK_DATA), "[Data Memory Write] FAILED: Incorrect d_opcode");
        dynamicAssert(response.d_param == 0, "[Data Memory Write] FAILED: Incorrect d_param");
        dynamicAssert(response.d_source == 0, "[Data Memory Write] FAILED: Incorrect d_source");
        dynamicAssert(response.d_sink == 0, "[Data Memory Write] FAILED: Incorrect d_sink");
        dynamicAssert(response.d_denied == False, "[Data Memory Write] FAILED: Response marked as denied");
        dynamicAssert(response.d_corrupt == False, "[Data Memory Write] FAILED: Response marked as corrupt");
        dynamicAssert(response.d_size == 1, "[Data Memory Write] FAILED: Incorrect d_size");

`ifdef RV32
        Word expectedLatency = 3;
`else
        Word expectedLatency = 8;
`endif
        let requestLatency = cycleCounter - startCycle;
        if (requestLatency != expectedLatency) begin
            $display("[Data Memory Write] FAILED: Request latency ($%x) != expected latency ($%x)", requestLatency, expectedLatency);
            $fatal();
        end

        Word expectedDataThisRound = testNumber;
        if (response.d_data != expectedDataThisRound) begin
            $display("[Data Memory Write] FAILED: Received data $%x != Expected data: $%x", response.d_data, expectedDataThisRound);
            $fatal();
        end

        if (testNumber >= 100) begin
            testPhase <= COMPLETE;
        end

        testNumber <= testNumber + 1;
        addressToCheck <= addressToCheck + fromInteger(valueOf(TDiv#(XLEN, 8)));
        waitingForResponse <= False;
    endrule

    rule complete(testPhase == COMPLETE);
        $display("    PASS");
        $finish();
    endrule
endmodule
