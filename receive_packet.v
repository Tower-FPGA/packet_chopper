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
	DATA_WIDTH = 64   // the input bus data width, can be: 16, 32 or 64 bits
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
	 output									fifo_empty,
	 input									fifo_rd,
	 output reg								fifo_busy,
	 output [DATA_WIDTH-1:0]				fifo_data_out
    );

//State machine states_sm0
localparam IDLE_SM0              = 3'h0; 
localparam FIFO_READY_SM0       = 3'h1; 
localparam FIFO_RECEIVE_SM0   	= 3'h3; 
localparam FIFO_STOP_SM0        = 3'h4;

parameter 	DATA_BYTE_WIDTH 	= DATA_WIDTH/8;

reg [3:0]             state_0;


reg [DATA_WIDTH-1:0] 	fifo_data_in;
reg						fifo_wr;
reg [15:0]				remain_length;
reg [DATA_WIDTH-1:0] 	data_mask;

always@(posedge Clk)
begin
    if(Rst)
	 begin
		state_0   		<= IDLE_SM0;
		InBus_Rdy 		<= 1'b0;
		fifo_wr 		<= 1'b0;
		fifo_data_in	<= 0;
		remain_length	<= 16'b0;
		InBus_Error		<= 1'b0;
		data_mask		<= 0;
	 end
    else 
	 begin
		  case(state_0)
			IDLE_SM0 :
			begin
				fifo_wr 	<= 1'b0;
				remain_length	<= 16'b0;
				InBus_Error	<= 1'b0;
				data_mask		<= 0;
				if (!fifo_full)
				begin
					state_0   <= FIFO_READY_SM0;
					InBus_Rdy <= 1'b1;
				end
				else
				begin
					state_0   <= IDLE_SM0;
					InBus_Rdy <= 1'b0;
				end
			end
			FIFO_READY_SM0:
			begin
				if((InBus_Mod != 0) && InBus_Sop && InBus_Val)
				begin
					state_0   <= IDLE_SM0;
					InBus_Error	<= 1'b1;
					fifo_wr 	<= 1'b0;
				end
				else if (InBus_Sop && InBus_Val && (DATA_WIDTH>8))
				begin 
					state_0   <= FIFO_RECEIVE_SM0;
					fifo_data_in<= InBus_Dat;
					fifo_wr 	<= 1'b1;
					remain_length	<= InBus_Dat[DATA_WIDTH-1:DATA_WIDTH-16] - DATA_BYTE_WIDTH; //assume the in_bus is wider than 16 bits 
				end
			end
			FIFO_RECEIVE_SM0:
			begin
				if(fifo_full)
				begin
					state_0   <= IDLE_SM0;
					InBus_Rdy <= 1'b0;
				end
				
				//if the packet end but the length are not matching, send out a error
				//  need to implment a function to terminate the sub-packet
				else if(InBus_Eop  & InBus_Val & (remain_length!=InBus_Mod))
				begin
					state_0   <= IDLE_SM0;
					InBus_Error	<= 1'b1;
				end
				else if(InBus_Eop & InBus_Val)
				
				//add zero after one larger packet to do the data aligment
				begin
					state_0   <= IDLE_SM0;
					//fifo_data_in<= InBus_Dat;
					fifo_wr 	<= 1'b1;
					fifo_data_in<= ({DATA_WIDTH{1'b1}} << ((DATA_BYTE_WIDTH - InBus_Mod)<<3)) & InBus_Dat;
				end
				else
				begin
					state_0   <= FIFO_RECEIVE_SM0;
					fifo_data_in<= InBus_Dat;
					fifo_wr 	<= 1'b1;
					remain_length	<= remain_length - DATA_BYTE_WIDTH;
				end
			end
			
			default:
			begin
				state_0   		<= IDLE_SM0;
				InBus_Rdy 		<= 1'b0;
				fifo_wr 		<= 1'b0;
				fifo_data_in	<= 0;
				remain_length	<= 16'b0;
				InBus_Error		<= 1'b0;
			end
		  endcase
	 end
end


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
	  .DO									(fifo_data_out),                   // Output data, width defined by DATA_WIDTH parameter
	  .EMPTY								(fifo_empty),             // 1-bit output empty
	  .FULL									(fifo_full),               // 1-bit output full
	  .RDCOUNT(RDCOUNT),         // Output read count, width determined by FIFO depth
	  .RDERR(RDERR),             // 1-bit output read error
	  .WRCOUNT(WRCOUNT),         // Output write count, width determined by FIFO depth
	  .WRERR(WRERR),             // 1-bit output write error
	  .CLK									(Clk),                 // 1-bit input clock
	  .DI									(fifo_data_in),                   // Input data, width defined by DATA_WIDTH parameter
	  .RDEN									(fifo_rd),               // 1-bit input read enable
	  .RST									(Rst),                 // 1-bit input reset
	  .WREN									(fifo_wr)                // 1-bit input write enable
   );
			

   
	
endmodule
