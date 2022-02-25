import PGTypes::*;

import Exception::*;
import LoadStore::*;
import TileLink::*;

import Assert::*;
import Printf::*;

typedef enum {
    INIT,
    STORE_REQUEST_TEST,
    LOAD_REQUEST_TEST,
    COMPLETE
} State deriving(Bits, Eq, FShow);

typedef struct {
    Bool shouldSucceed;
    RVStoreOperator storeOperator;
    Word effectiveAddress;
    Word value;

    Maybe#(Exception) expectedException;
    Bit#(TDiv#(XLEN, 8)) expectedMask;
    Word expectedValue;
} StoreTestCase deriving(Bits, Eq, FShow);

typedef struct {
    Bool shouldSucceed;
    RVLoadOperator loadOperator;
    Word effectiveAddress;

    Maybe#(Exception) expectedException;
    Bit#(TLog#(TDiv#(XLEN, 8))) expectedLog2Size;
    Bit#(TDiv#(XLEN, 8)) expectedMask;
    Bool expectedSignExtend;
} LoadTestCase deriving(Bits, Eq, FShow);

(* synthesize *)
module mkLoadStore_tb(Empty);
    Reg#(State) state <- mkReg(INIT);
    Reg#(Word) testNumber <- mkReg(0);

`ifdef RV64
    let storeTestCaseCount = 19;
`else // RV32
    let storeTestCaseCount = 8;
`endif
    StoreTestCase storeTestCases[storeTestCaseCount] = {
        //
        // Single byte store
        //
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4000,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedMask:           'b1,
            expectedValue:          'hff
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4001,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedMask:           'b1,
            expectedValue:          'hff
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4002,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedMask:           'b1,
            expectedValue:          'hff
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4003,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedMask:           'b1,
            expectedValue:          'hff
        },
`ifdef RV64
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4004,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedMask:           'b1,
            expectedValue:          'hff
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4005,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedMask:           'b1,
            expectedValue:          'hff
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4006,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedMask:           'b1,
            expectedValue:          'hff
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SB),
            effectiveAddress:       'h4007,
            value:                  'hff,

            expectedException:      tagged Invalid,
            expectedMask:           'b1,
            expectedValue:          'hff
        },
`endif

        //
        // Half-word store
        //
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4000,
            value:                  'hff44,

            expectedException:      tagged Invalid,
            expectedMask:           'b11,
            expectedValue:          'hff44
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4002,
            value:                  'h0000_ff44,

            expectedException:      tagged Invalid,
            expectedMask:           'b11,
            expectedValue:          'h0000_ff44
        },
`ifdef RV64
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4004,
            value:                  'hff44,

            expectedException:      tagged Invalid,
            expectedMask:           'b11,
            expectedValue:          'hff44
        },
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4006,
            value:                  'hff44,

            expectedException:      tagged Invalid,
            expectedMask:           'b11,
            expectedValue:          'hff44
        },
`endif
        StoreTestCase { 
            shouldSucceed:          False,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4001,
            value:                  ?,

            expectedException:      tagged Valid tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED)),
            expectedMask:           'b11,
            expectedValue:          ?
        },
`ifdef RV64
        StoreTestCase { 
            shouldSucceed:          False,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4003,
            value:                  ?,

            expectedException:      tagged Valid tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED)),
            expectedMask:           'b11,
            expectedValue:          ?
        },
        StoreTestCase { 
            shouldSucceed:          False,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4005,
            value:                  ?,

            expectedException:      tagged Valid tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED)),
            expectedMask:           'b11,
            expectedValue:          ?
        },
        StoreTestCase { 
            shouldSucceed:          False,
            storeOperator:          pack(SH),
            effectiveAddress:       'h4007,
            value:                  ?,

            expectedException:      tagged Valid tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED)),
            expectedMask:           'b11,
            expectedValue:          ?
        },
`endif
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SW),
            effectiveAddress:       'h4000,
            value:                  'hff44_AA11,

            expectedException:      tagged Invalid,
            expectedMask:           'b1111,
            expectedValue:          'hff44_AA11
        }
`ifdef RV64
        ,
        StoreTestCase { 
            shouldSucceed:          True,
            storeOperator:          pack(SW),
            effectiveAddress:       'h4004,
            value:                  'hff44_AA11,

            expectedException:      tagged Invalid,
            expectedMask:           'b1111_1111,
            expectedValue:          'hff44_AA11
        },
        StoreTestCase { 
            shouldSucceed:          False,
            storeOperator:          pack(SW),
            effectiveAddress:       'h4002,
            value:                  ?,

            expectedException:      tagged Valid tagged ExceptionCause extend(pack(STORE_ADDRESS_MISALIGNED)),
            expectedMask:           ?,
            expectedValue:          ?
        }
`endif
    };

`ifdef RV64
    let loadTestCaseCount = 8;
`else // RV32
    let loadTestCaseCount = 4;
`endif
    LoadTestCase loadTestCases[loadTestCaseCount] = {
        LoadTestCase {
            shouldSucceed: True,
            loadOperator: pack(LB),
            effectiveAddress: 'h4000,

            expectedException: tagged Invalid,
            expectedLog2Size: 0,
            expectedMask: 'b1,
            expectedSignExtend: True
        },
        LoadTestCase {
            shouldSucceed: True,
            loadOperator: pack(LB),
            effectiveAddress: 'h4001,

            expectedException: tagged Invalid,
            expectedLog2Size: 0,
            expectedMask: 'b1,
            expectedSignExtend: True
        },
        LoadTestCase {
            shouldSucceed: True,
            loadOperator: pack(LB),
            effectiveAddress: 'h4002,

            expectedException: tagged Invalid,
            expectedLog2Size: 0,
            expectedMask: 'b1,
            expectedSignExtend: True
        },
        LoadTestCase {
            shouldSucceed: True,
            loadOperator: pack(LB),
            effectiveAddress: 'h4003,

            expectedException: tagged Invalid,
            expectedLog2Size: 0,
            expectedMask: 'b1,
            expectedSignExtend: True
        }
`ifdef RV64
        ,
        LoadTestCase {
            shouldSucceed: True,
            loadOperator: pack(LB),
            effectiveAddress: 'h4004,

            expectedException: tagged Invalid,
            expectedLog2Size: 0,
            expectedMask: 'b1,
            expectedSignExtend: True
        },
        LoadTestCase {
            shouldSucceed: True,
            loadOperator: pack(LB),
            effectiveAddress: 'h4005,

            expectedException: tagged Invalid,
            expectedLog2Size: 0,
            expectedMask: 'b1,
            expectedSignExtend: True
        },
        LoadTestCase {
            shouldSucceed: True,
            loadOperator: pack(LB),
            effectiveAddress: 'h4006,

            expectedException: tagged Invalid,
            expectedLog2Size: 0,
            expectedMask: 'b1,
            expectedSignExtend: True
        },
        LoadTestCase {
            shouldSucceed: True,
            loadOperator: pack(LB),
            effectiveAddress: 'h4007,

            expectedException: tagged Invalid,
            expectedLog2Size: 0,
            expectedMask: 'b1,
            expectedSignExtend: True
        }
`endif
    };

    rule init(state == INIT);
        state <= STORE_REQUEST_TEST;
    endrule

    rule store_request_test(state == STORE_REQUEST_TEST);
        let testCase = storeTestCases[testNumber];

        let result = getStoreRequest(
            testCase.storeOperator, 
            testCase.effectiveAddress, 
            testCase.value);

        dynamicAssert(isSuccess(result) == testCase.shouldSucceed, "Request success should be what's expected");
        if (result matches tagged Success .storeRequest) begin
            if (storeRequest.tlRequest.a_data != testCase.expectedValue) begin
                $display("Value incorrect: %x, expected: %x", storeRequest.tlRequest.a_data, testCase.expectedValue);
                $fatal();
            end
        end else begin
            dynamicAssert(result.Error == unJust(testCase.expectedException), "Incorrect exception returned");
        end

        if (testNumber == storeTestCaseCount - 1) begin
            state <= LOAD_REQUEST_TEST;
            testNumber <= 0;
        end else begin
            testNumber <= testNumber + 1;
        end
    endrule

    rule load_request_test(state == LOAD_REQUEST_TEST);
        let testCase = loadTestCases[testNumber];

        let result = getLoadRequest(
            testCase.loadOperator, 
            1, 
            testCase.effectiveAddress);

        dynamicAssert(isSuccess(result) == testCase.shouldSucceed, "Request success should be what's expected");
        if (result matches tagged Success .loadRequest) begin
            dynamicAssert(loadRequest.tlRequest.a_size == testCase.expectedLog2Size, "Log2Size incorrect.");
            dynamicAssert(loadRequest.tlRequest.a_mask == testCase.expectedMask, "Mask incorrect.");
            dynamicAssert(loadRequest.signExtend == testCase.expectedSignExtend, "Sign extension incorrect.");
        end else begin
            dynamicAssert(result.Error == unJust(testCase.expectedException), "Incorrect exception returned");
        end

        if (testNumber == loadTestCaseCount - 1) begin
            state <= COMPLETE;
            testNumber <= 0;
        end else begin
            testNumber <= testNumber + 1;
        end
    endrule

    rule complete(state == COMPLETE);
        $display("    PASS");
        $finish();
    endrule
endmodule
