//
// Generated by Bluespec Compiler, version 2022.01 (build 066c7a87)
//
// On Sat Apr 23 20:31:55 PDT 2022
//
//
// Ports:
// Name                         I/O  size props
// get_tx_get                     O     1 reg
// CLK                            I     1 clock
// RST_N                          I     1 reset
//
// No combinational paths from inputs to outputs
//
//

`ifdef BSV_ASSIGNMENT_DELAY
`else
  `define BSV_ASSIGNMENT_DELAY
`endif

`ifdef BSV_POSITIVE_RESET
  `define BSV_RESET_VALUE 1'b1
  `define BSV_RESET_EDGE posedge
`else
  `define BSV_RESET_VALUE 1'b0
  `define BSV_RESET_EDGE negedge
`endif

module mkTransmitter_tb(CLK,
			RST_N,

			get_tx_get);
  input  CLK;
  input  RST_N;

  // actionvalue method get_tx_get
  output get_tx_get;

  // signals for module outputs
  wire get_tx_get;

  // inlined wires
  wire baudGenerator_baudRateX16$whas, baudGenerator_baudRateX2$whas;

  // register writeOffset
  reg [2 : 0] writeOffset;
  wire [2 : 0] writeOffset$D_IN;
  wire writeOffset$EN;

  // ports of submodule baudGenerator_baudRateX2Counter
  wire [2 : 0] baudGenerator_baudRateX2Counter$DATA_A,
	       baudGenerator_baudRateX2Counter$DATA_B,
	       baudGenerator_baudRateX2Counter$DATA_C,
	       baudGenerator_baudRateX2Counter$DATA_F,
	       baudGenerator_baudRateX2Counter$Q_OUT;
  wire baudGenerator_baudRateX2Counter$ADDA,
       baudGenerator_baudRateX2Counter$ADDB,
       baudGenerator_baudRateX2Counter$SETC,
       baudGenerator_baudRateX2Counter$SETF;

  // ports of submodule baudGenerator_clockCounter
  wire [6 : 0] baudGenerator_clockCounter$DATA_A,
	       baudGenerator_clockCounter$DATA_B,
	       baudGenerator_clockCounter$DATA_C,
	       baudGenerator_clockCounter$DATA_F,
	       baudGenerator_clockCounter$Q_OUT;
  wire baudGenerator_clockCounter$ADDA,
       baudGenerator_clockCounter$ADDB,
       baudGenerator_clockCounter$SETC,
       baudGenerator_clockCounter$SETF;

  // ports of submodule cycleCounter
  wire [23 : 0] cycleCounter$DATA_A,
		cycleCounter$DATA_B,
		cycleCounter$DATA_C,
		cycleCounter$DATA_F,
		cycleCounter$Q_OUT;
  wire cycleCounter$ADDA,
       cycleCounter$ADDB,
       cycleCounter$SETC,
       cycleCounter$SETF;

  // ports of submodule transmitter
  wire [7 : 0] transmitter$putData_put;
  wire transmitter$EN_get_tx_get,
       transmitter$EN_putBaudX2Ticked_put,
       transmitter$EN_putData_put,
       transmitter$RDY_putBaudX2Ticked_put,
       transmitter$RDY_putData_put,
       transmitter$get_tx_get,
       transmitter$putBaudX2Ticked_put;

  // rule scheduling signals
  wire WILL_FIRE_RL_countdown;

  // actionvalue method get_tx_get
  assign get_tx_get = transmitter$get_tx_get ;

  // submodule baudGenerator_baudRateX2Counter
  Counter #(.width(32'd3),
	    .init(3'd0)) baudGenerator_baudRateX2Counter(.CLK(CLK),
							 .RST(RST_N),
							 .DATA_A(baudGenerator_baudRateX2Counter$DATA_A),
							 .DATA_B(baudGenerator_baudRateX2Counter$DATA_B),
							 .DATA_C(baudGenerator_baudRateX2Counter$DATA_C),
							 .DATA_F(baudGenerator_baudRateX2Counter$DATA_F),
							 .ADDA(baudGenerator_baudRateX2Counter$ADDA),
							 .ADDB(baudGenerator_baudRateX2Counter$ADDB),
							 .SETC(baudGenerator_baudRateX2Counter$SETC),
							 .SETF(baudGenerator_baudRateX2Counter$SETF),
							 .Q_OUT(baudGenerator_baudRateX2Counter$Q_OUT));

  // submodule baudGenerator_clockCounter
  Counter #(.width(32'd7), .init(7'd0)) baudGenerator_clockCounter(.CLK(CLK),
								   .RST(RST_N),
								   .DATA_A(baudGenerator_clockCounter$DATA_A),
								   .DATA_B(baudGenerator_clockCounter$DATA_B),
								   .DATA_C(baudGenerator_clockCounter$DATA_C),
								   .DATA_F(baudGenerator_clockCounter$DATA_F),
								   .ADDA(baudGenerator_clockCounter$ADDA),
								   .ADDB(baudGenerator_clockCounter$ADDB),
								   .SETC(baudGenerator_clockCounter$SETC),
								   .SETF(baudGenerator_clockCounter$SETF),
								   .Q_OUT(baudGenerator_clockCounter$Q_OUT));

  // submodule cycleCounter
  Counter #(.width(32'd24), .init(24'd0)) cycleCounter(.CLK(CLK),
						       .RST(RST_N),
						       .DATA_A(cycleCounter$DATA_A),
						       .DATA_B(cycleCounter$DATA_B),
						       .DATA_C(cycleCounter$DATA_C),
						       .DATA_F(cycleCounter$DATA_F),
						       .ADDA(cycleCounter$ADDA),
						       .ADDB(cycleCounter$ADDB),
						       .SETC(cycleCounter$SETC),
						       .SETF(cycleCounter$SETF),
						       .Q_OUT(cycleCounter$Q_OUT));

  // submodule transmitter
  mkTransmitter transmitter(.CLK(CLK),
			    .CLK_GATE(1'd1),
			    .RST_N(RST_N),
			    .putBaudX2Ticked_put(transmitter$putBaudX2Ticked_put),
			    .putData_put(transmitter$putData_put),
			    .EN_putData_put(transmitter$EN_putData_put),
			    .EN_putBaudX2Ticked_put(transmitter$EN_putBaudX2Ticked_put),
			    .EN_get_tx_get(transmitter$EN_get_tx_get),
			    .RDY_putData_put(transmitter$RDY_putData_put),
			    .RDY_putBaudX2Ticked_put(transmitter$RDY_putBaudX2Ticked_put),
			    .get_tx_get(transmitter$get_tx_get),
			    .RDY_get_tx_get());

  // rule RL_countdown
  assign WILL_FIRE_RL_countdown =
	     cycleCounter$Q_OUT != 24'd11999999 ||
	     transmitter$RDY_putData_put ;

  // inlined wires
  assign baudGenerator_baudRateX2$whas =
	     baudGenerator_baudRateX2Counter$Q_OUT == 3'd0 &&
	     baudGenerator_baudRateX16$whas ;
  assign baudGenerator_baudRateX16$whas =
	     WILL_FIRE_RL_countdown &&
	     baudGenerator_clockCounter$Q_OUT == 7'd104 ;

  // register writeOffset
  assign writeOffset$D_IN = writeOffset + 3'd1 ;
  assign writeOffset$EN =
	     WILL_FIRE_RL_countdown && cycleCounter$Q_OUT == 24'd11999999 ;

  // submodule baudGenerator_baudRateX2Counter
  assign baudGenerator_baudRateX2Counter$DATA_A = 3'd1 ;
  assign baudGenerator_baudRateX2Counter$DATA_B = 3'h0 ;
  assign baudGenerator_baudRateX2Counter$DATA_C = 3'h0 ;
  assign baudGenerator_baudRateX2Counter$DATA_F = 3'h0 ;
  assign baudGenerator_baudRateX2Counter$ADDA =
	     baudGenerator_baudRateX16$whas ;
  assign baudGenerator_baudRateX2Counter$ADDB = 1'b0 ;
  assign baudGenerator_baudRateX2Counter$SETC = 1'b0 ;
  assign baudGenerator_baudRateX2Counter$SETF = 1'b0 ;

  // submodule baudGenerator_clockCounter
  assign baudGenerator_clockCounter$DATA_A = 7'd1 ;
  assign baudGenerator_clockCounter$DATA_B = 7'h0 ;
  assign baudGenerator_clockCounter$DATA_C = 7'h0 ;
  assign baudGenerator_clockCounter$DATA_F = 7'h0 ;
  assign baudGenerator_clockCounter$ADDA = WILL_FIRE_RL_countdown ;
  assign baudGenerator_clockCounter$ADDB = 1'b0 ;
  assign baudGenerator_clockCounter$SETC = 1'b0 ;
  assign baudGenerator_clockCounter$SETF = 1'b0 ;

  // submodule cycleCounter
  assign cycleCounter$DATA_A = 24'd1 ;
  assign cycleCounter$DATA_B = 24'h0 ;
  assign cycleCounter$DATA_C = 24'h0 ;
  assign cycleCounter$DATA_F = 24'h0 ;
  assign cycleCounter$ADDA = WILL_FIRE_RL_countdown ;
  assign cycleCounter$ADDB = 1'b0 ;
  assign cycleCounter$SETC = 1'b0 ;
  assign cycleCounter$SETF = 1'b0 ;

  // submodule transmitter
  assign transmitter$putBaudX2Ticked_put = baudGenerator_baudRateX2$whas ;
  assign transmitter$putData_put = 8'd65 + { 5'd0, writeOffset } ;
  assign transmitter$EN_putData_put =
	     WILL_FIRE_RL_countdown && cycleCounter$Q_OUT == 24'd11999999 ;
  assign transmitter$EN_putBaudX2Ticked_put =
	     transmitter$RDY_putBaudX2Ticked_put ;
  assign transmitter$EN_get_tx_get = 1'd1 ;

  // handling of inlined registers

  always@(posedge CLK)
  begin
    if (RST_N == `BSV_RESET_VALUE)
      begin
        writeOffset <= `BSV_ASSIGNMENT_DELAY 3'd0;
      end
    else
      begin
        if (writeOffset$EN)
	  writeOffset <= `BSV_ASSIGNMENT_DELAY writeOffset$D_IN;
      end
  end

  // synopsys translate_off
  `ifdef BSV_NO_INITIAL_BLOCKS
  `else // not BSV_NO_INITIAL_BLOCKS
  initial
  begin
    writeOffset = 3'h2;
  end
  `endif // BSV_NO_INITIAL_BLOCKS
  // synopsys translate_on
endmodule  // mkTransmitter_tb

