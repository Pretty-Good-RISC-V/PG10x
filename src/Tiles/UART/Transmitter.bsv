`include "UART.bsvi"

import Cntrs::*;
import Connectable::*;
import FIFO::*;
import GetPut::*;

interface Transmitter;
    // putData         - puts data to be transmitted
    interface Put#(Bit#(8)) putData;
    // putBaudX2Ticked - puts value indicating if the 2x baud rate time has elapsed
    interface Put#(Bool) putBaudX2Ticked;
    // get_tx          - gets the TX transmission line value
    interface Get#(Bit#(1)) get_tx;
endinterface

(* synthesize *)
(* gate_input_clocks = "default_clock" *)
module mkTransmitter(Transmitter);
    // txQueue  - (INPUT) queue holding bytes to be transmitted
    FIFO#(Bit#(8)) transmitQueue <- mkSizedFIFO(16);
    // txLine   - (OUTPUT) contains the TX line output from the transmitter
    Reg#(Bit#(1)) txLine <- mkReg(1);
    // txState  - contains the transmitter state
    Reg#(UARTState) txState <- mkReg(UART_IDLE);
    // txByte   - the byte being transmitted
    Reg#(Bit#(8)) txByte <- mkRegU;     
    // txBit    - the bit number inside txByte currently being transmitted
    Reg#(Bit#(3)) txBit <- mkRegU;
    // txTick   - counter that ticks every *half* baud *during* transmission (0 = start of transmission period)
    UCount txTick <- mkUCount(0, 1);
    // txBaudX2Ticked   - indicates if the 2x baud tick time has elapsed (driven externally)
    Reg#(Bool) txBaudX2Ticked <- mkReg(False);

    rule handleTransmitIDLE(txState == UART_IDLE);
        $display("XMIT: Popping from queue");
        let data <- pop(transmitQueue);

        txByte <= data;
        txState <= UART_START_BIT;
        txTick <= 0;
    endrule

    rule handleTransmitNonIDLE(txState != UART_IDLE && txBaudX2Ticked);
        if (txTick.isEqual(0)) begin
            case(txState)
                UART_START_BIT: begin
                    $display("Writing start bit");
                    txLine <= 0;        // lower TX
                    txState <= UART_DATA;
                    txBit <= 0;
                end
                UART_DATA: begin
                    $display("Writing data bit #%0d", txBit);
                    if ((txByte & (1 << txBit)) == 1) begin
                        txLine <= 0;    // lower TX
                    end else begin
                        txLine <= 1;    // raise TX
                    end

                    if (txBit == 7) begin
                        txState <= UART_STOP_BIT;
                    end else begin
                        txBit <= txBit + 1;
                    end
                end
                UART_STOP_BIT: begin
                    $display("Writing stop bit");
                    txLine <= 0;        // lower TX
                    txState <= UART_FINISH;
                end
                UART_FINISH: begin
                    $display("Character complete");
                    txLine <= 1;        // raise TX
                    txState <= UART_IDLE;
                end
            endcase
        end

        txTick.incr(1);
    endrule

    interface Put putData = toPut(asIfc(transmitQueue));
    interface Put putBaudX2Ticked = toPut(asIfc(txBaudX2Ticked));
    interface Get get_tx = toGet(txLine);
endmodule
