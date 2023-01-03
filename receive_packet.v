`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:28:19 12/27/2022 
// Design Name: 
// Module Name:    receive_packet 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module receive_packet #(
	DATA_WIDTH = 64,    // the input bus data width, can be: 16, 32 or 64 bits
	DAT_WIDTH = 64    // the output bus data width, can be: 16, 32 or 64 bits
)(
	//system signals
    input 									Rst,  //Reset signal used by the block
    input 									Clk,  //Clock signal used by the block
	 //input Bus
    output reg								InBus_Rdy,  //Flow control for next block to stop transfer.
    input 									InBus_Val,  //Data is valid on the bus.
    input 									InBus_Sop,  //Start of message input
    input 									InBus_Eop,  //End of message input
    input [DATA_WIDTH /8-1:0]				InBus_Mod,  //Modulo valid bytes
    input [DATA_WIDTH-1:0]					InBus_Dat,  //Actual Data
	output reg								InBus_Error,				
	 
	 //fifo interface
	 output									fifo0_empty,
	 input									fifo0_rd,
	 output reg								fifo0_busy,
	 output [DAT_WIDTH-1:0]					fifo0_data_out,
	 output									fifo1_empty,
	 input									fifo1_rd,
	 output reg								fifo1_busy,
	 output [DAT_WIDTH-1:0]					fifo1_data_out
    );

//State machine states_sm0
localparam IDLE_SM0              = 3'h0; 
localparam FIFO0_READY_SM0       = 3'h1; 
localparam FIFO1_READY_SM0       = 3'h2;
localparam FIFO0_RECEIVE_SM0   	= 3'h3; 
localparam FIFO0_STOP_SM0        = 3'h4;
localparam FIFO1_RECEIVE_SM0   	= 3'h5; 
localparam FIFO1_STOP_SM0        = 3'h6;
reg [3:0]             state_0;


reg [DATA_WIDTH-1:0] 	fifo0_data_in;
reg [DATA_WIDTH-1:0] 	fifo1_data_in;
reg							fifo0_wr;
reg							fifo1_wr;
reg [15:0]				remain_length;
reg	[DATA_WIDTH-1:0]	InBus_Dat_reg;

always@(posedge Clk)
begin
    if(Rst)
	 begin
		state_0   		<= IDLE_SM0;
		InBus_Rdy 		<= 1'b0;
		fifo0_wr 		<= 1'b0;
		fifo1_wr 		<= 1'b0;
		fifo0_data_in	<= 0;
		fifo1_data_in	<= 0;
		fifo0_busy		<= 1'b0;
		fifo1_busy		<= 1'b0;
		remain_length	<= 16'b0;
		InBus_Error		<= 1'b0;
		InBus_Dat_reg	<= 0;
	 end
    else 
	 begin
		  case(state_0)
			IDLE_SM0 :
			begin
				fifo0_wr 	<= 1'b0;
				fifo1_wr 	<= 1'b0;
				fifo0_busy	<= 1'b0;
				fifo1_busy	<= 1'b0;
				remain_length	<= 16'b0;
				InBus_Error	<= 1'b0;
				InBus_Dat_reg	<= 0;
				if (fifo0_empty)
				begin
					state_0   <= FIFO0_READY_SM0;
					InBus_Rdy <= 1'b1;
				end
				else if (fifo1_empty)
				begin
					state_0   <= FIFO1_READY_SM0;
					InBus_Rdy <= 1'b1;
				end
				else
				begin
					state_0   <= IDLE_SM0;
					InBus_Rdy <= 1'b0;
				end
			end
			FIFO0_READY_SM0:
			begin
				if((InBus_Mod != 0) & InBus_Sop & InBus_Val)
				begin
					state_0   <= IDLE_SM0;
					InBus_Error	<= 1'b1;
				end
				else
				begin if (InBus_Sop & InBus_Val)
					state_0   <= FIFO0_RECEIVE_SM0;
					InBus_Dat_reg<= InBus_Dat;
					remain_length	<= InBus_Dat[DATA_WIDTH-1:DATA_WIDTH-16] - DATA_WIDTH/8;
				end
			end
			FIFO0_RECEIVE_SM0:
			begin
				fifo0_wr 	<= 1'b1;
				fifo0_busy	<= 1'b1;
				fifo0_data_in<= {InBus_Dat_reg[DATA_WIDTH-25:0],InBus_Dat[DATA_WIDTH-1:DATA_WIDTH-24]};  //currently only support the 32/64 bits DATA_WIDTH
				//fifo0_data_in<= {InBus_Dat_reg[DATA_WIDTH-24:0],24'b0};
				InBus_Dat_reg<= InBus_Dat;
				remain_length	<= remain_length - DATA_WIDTH/8;
				if(InBus_Eop  & InBus_Val & (remain_length!=InBus_Mod))
				begin
					state_0   <= IDLE_SM0;
					InBus_Error	<= 1'b1;
				end
				else if(InBus_Eop & InBus_Val & (remain_length > 3))
				begin
					state_0   <= FIFO0_STOP_SM0;
				end
				else if(InBus_Eop & InBus_Val)
				begin
					state_0   <= IDLE_SM0;
				end
			end
			FIFO0_STOP_SM0:
			begin
				state_0   <= IDLE_SM0;
				fifo0_wr 	<= 1'b1;
				fifo0_busy	<= 1'b1;
				fifo0_data_in<= {InBus_Dat_reg[DATA_WIDTH-25:0],InBus_Dat[DATA_WIDTH-1:DATA_WIDTH-24]};
			end
			FIFO1_READY_SM0:
			begin
				if((InBus_Mod != 0) & InBus_Sop & InBus_Val)
				begin
					state_0   <= IDLE_SM0;
					InBus_Error	<= 1'b1;
				end
				else
				begin if (InBus_Sop & InBus_Val)
					state_0   <= FIFO1_RECEIVE_SM0;
					InBus_Dat_reg<= InBus_Dat;
					remain_length	<= InBus_Dat[DATA_WIDTH-1:DATA_WIDTH-16] - DATA_WIDTH/8;
				end
			end
			FIFO1_RECEIVE_SM0:
			begin
				fifo1_wr 	<= 1'b1;
				fifo1_busy	<= 1'b1;
				fifo1_data_in<= {InBus_Dat_reg[DATA_WIDTH-25:0],InBus_Dat[DATA_WIDTH-1:DATA_WIDTH-24]};  //currently only support the 32/64 bits DATA_WIDTH
				//fifo0_data_in<= {InBus_Dat_reg[DATA_WIDTH-24:0],24'b0};
				InBus_Dat_reg<= InBus_Dat;
				remain_length	<= remain_length - DATA_WIDTH/8;
				if(InBus_Eop  & InBus_Val & (remain_length!=InBus_Mod))
				begin
					state_0   <= IDLE_SM0;
					InBus_Error	<= 1'b1;
				end
				else if(InBus_Eop & InBus_Val & (remain_length > 3))
				begin
					state_0   <= FIFO1_STOP_SM0;
				end
				else if(InBus_Eop & InBus_Val)
				begin
					state_0   <= IDLE_SM0;
				end
			end
			FIFO1_STOP_SM0:
			begin
				state_0   <= IDLE_SM0;
				fifo1_wr 	<= 1'b1;
				fifo1_busy	<= 1'b1;
				fifo1_data_in<= {InBus_Dat_reg[DATA_WIDTH-25:0],InBus_Dat[DATA_WIDTH-1:DATA_WIDTH-24]};
			end
			
			default:
			begin
				state_0   		<= IDLE_SM0;
				InBus_Rdy 		<= 1'b0;
				fifo0_wr 		<= 1'b0;
				fifo1_wr 		<= 1'b0;
				fifo0_data_in	<= 0;
				fifo1_data_in	<= 0;
				fifo0_busy		<= 1'b0;
				fifo1_busy		<= 1'b0;
				remain_length	<= 16'b0;
				InBus_Error		<= 1'b0;
				InBus_Dat_reg	<= 0;
			end
		  endcase
	 end
end

generate
	if(DATA_WIDTH == DAT_WIDTH ) begin :fifos
		FIFO_SYNC_MACRO  #(
			  .DEVICE("VIRTEX6"), // Target Device: "VIRTEX5", "VIRTEX6" 
			  .ALMOST_EMPTY_OFFSET(9'h080), // Sets the almost empty threshold
			  .ALMOST_FULL_OFFSET(9'h080),  // Sets almost full threshold
			  .DATA_WIDTH(DATA_WIDTH), // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
			  .DO_REG(0),     // Optional output register (0 or 1)
			  .FIFO_SIZE ("36Kb") // Target BRAM: "18Kb" or "36Kb" 
		   ) data_fifo_inst0 (
			  .ALMOSTEMPTY(ALMOSTEMPTY), // 1-bit output almost empty
			  .ALMOSTFULL(ALMOSTFULL),   // 1-bit output almost full
			  .DO									(fifo0_data_out),                   // Output data, width defined by DATA_WIDTH parameter
			  .EMPTY								(fifo0_empty),             // 1-bit output empty
			  .FULL									(fifo0_full),               // 1-bit output full
			  .RDCOUNT(RDCOUNT),         // Output read count, width determined by FIFO depth
			  .RDERR(RDERR),             // 1-bit output read error
			  .WRCOUNT(WRCOUNT),         // Output write count, width determined by FIFO depth
			  .WRERR(WRERR),             // 1-bit output write error
			  .CLK									(Clk),                 // 1-bit input clock
			  .DI									(fifo0_data_in),                   // Input data, width defined by DATA_WIDTH parameter
			  .RDEN									(fifo0_rd),               // 1-bit input read enable
			  .RST									(Rst),                 // 1-bit input reset
			  .WREN									(fifo0_wr)                // 1-bit input write enable
		   );
			
		FIFO_SYNC_MACRO  #(
			  .DEVICE("VIRTEX6"), // Target Device: "VIRTEX5", "VIRTEX6" 
			  .ALMOST_EMPTY_OFFSET(9'h080), // Sets the almost empty threshold
			  .ALMOST_FULL_OFFSET(9'h080),  // Sets almost full threshold
			  .DATA_WIDTH(DATA_WIDTH), // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
			  .DO_REG(0),     // Optional output register (0 or 1)
			  .FIFO_SIZE ("36Kb") // Target BRAM: "18Kb" or "36Kb" 
		   ) data_fifo_inst1 (
			  .ALMOSTEMPTY(ALMOSTEMPTY), // 1-bit output almost empty
			  .ALMOSTFULL(ALMOSTFULL),   // 1-bit output almost full
			  .DO								(fifo1_data_out),                   // Output data, width defined by DATA_WIDTH parameter
			  .EMPTY							(fifo1_empty),             // 1-bit output empty
			  .FULL(fifo1_full),               // 1-bit output full
			  .RDCOUNT(RDCOUNT),         // Output read count, width determined by FIFO depth
			  .RDERR(RDERR),             // 1-bit output read error
			  .WRCOUNT(WRCOUNT),         // Output write count, width determined by FIFO depth
			  .WRERR(WRERR),             // 1-bit output write error
			  .CLK								(Clk),                 // 1-bit input clock
			  .DI								(fifo1_data_in),        // Input data, width defined by DATA_WIDTH parameter
			  .RDEN								(fifo1_rd),               // 1-bit input read enable
			  .RST								(Rst),                 // 1-bit input reset
			  .WREN								(fifo1_wr)                // 1-bit input write enable
		   );
   end
   else if((DATA_WIDTH ==64) && (DAT_WIDTH == 32)) begin : fifos
   fifo_64in_32out	data_fifo_inst0(
		.rst	(Rst			),
		.wr_clk	(Clk			),
		.rd_clk	(Clk			),
		.din	(fifo0_data_in	),
		.wr_en	(fifo0_wr		),
		.rd_en	(fifo0_rd		),
		.dout	(fifo0_data_out	),
		.full	(fifo0_full		),
		.empty  (fifo0_empty	)
   );
   
   fifo_64in_32out	data_fifo_inst1(
		.rst	(Rst			),
		.wr_clk	(Clk			),
		.rd_clk	(Clk			),
		.din	(fifo1_data_in	),
		.wr_en	(fifo1_wr		),
		.rd_en	(fifo1_rd		),
		.dout	(fifo1_data_out	),
		.full	(fifo1_full		),
		.empty  (fifo1_empty	)
   );
   end
   else if((DATA_WIDTH ==32) && (DAT_WIDTH == 64)) begin : fifos
   fifo_32in_64out	data_fifo_inst0(
		.rst	(Rst			),
		.wr_clk	(Clk			),
		.rd_clk	(Clk			),
		.din	(fifo0_data_in	),
		.wr_en	(fifo0_wr		),
		.rd_en	(fifo0_rd		),
		.dout	(fifo0_data_out	),
		.full	(fifo0_full		),
		.empty  (fifo0_empty	)
   );
   
   fifo_32in_64out	data_fifo_inst1(
		.rst	(Rst			),
		.wr_clk	(Clk			),
		.rd_clk	(Clk			),
		.din	(fifo1_data_in	),
		.wr_en	(fifo1_wr		),
		.rd_en	(fifo1_rd		),
		.dout	(fifo1_data_out	),
		.full	(fifo1_full		),
		.empty  (fifo1_empty	)
   );
   end
endgenerate
	
endmodule
