import PGTypes::*;
import TileLink::*;

import ClientServer::*;
import FIFO::*;

interface SPIController;
    interface StdTileLinkClient spiClient;
endinterface

module mkSPIController#(
    Clock peripheralClock
)(SPIController);
    FIFO#(StdTileLinkRequest) requests <- mkFIFO;
    FIFO#(StdTileLinkResponse) responses <- mkFIFO;

    interface spiClient = toGPClient(requests, responses);
endmodule
