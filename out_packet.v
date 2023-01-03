`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:38:06 12/28/2022 
// Design Name: 
// Module Name:    out_packet 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//			Read data from FIFO and send the data to the out bus.
//			Currently, we assum that the InBus and OutBus are same width
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module out_packet #(
	DATA_WIDTH = 64,    // the input bus data width, can be: 16, 32 or 64 bits
	DAT_WIDTH = 64    // the output bus data width, can be: 16, 32 or 64 bits
)(	//system signals
    input 								Rst,  //Reset signal used by the block
    input 								Clk,  //Clock signal used by the block
	//fifo interface
	input								fifo0_empty,
	output	reg							fifo0_rd,
	input 								fifo0_busy,
	input [DAT_WIDTH-1:0]				fifo0_data_out,
	input								fifo1_empty,
	output	reg							fifo1_rd,
	input 								fifo1_busy,
	input [DAT_WIDTH-1:0]				fifo1_data_out,
	 
	//Output Bus
    output reg							OutBus_Val,  //Data Valid output
    output reg							OutBus_Sop,  //Start of message output
    output reg							OutBus_Eop,  //End of message output
    output reg [$clog2(DAT_WIDTH/8):0]	OutBus_Mod,  //Number of valid bytes on the output.
    output reg [DAT_WIDTH -1:0]			OutBus_Dat,  //Data output.
    output reg [15:0] 					OutBus_PktLen,  //Length of extracted packet
    output reg [7:0] 					OutBus_PktType,  //Type of packet
    output reg 							OutBus_Error	//Error Signal
    );

//State machine states_sm0
localparam IDLE_SM0             = 4'h0;
localparam FIFO0_LOAD_SM0      	= 4'h1;
localparam FIFO0_START_SM0      = 4'h2; 
localparam FIFO0_SEND_SM0   	= 4'h3; 
localparam FIFO1_LOAD_SM0      	= 4'h4;
localparam FIFO1_START_SM0      = 4'h5;
localparam FIFO1_SEND_SM0   	= 4'h6; 
reg [3:0]             			state_0;

reg [15:0]				remain_length;

always@(posedge Clk)
begin
    if(Rst)
	begin
		state_0   		<= IDLE_SM0;
		fifo0_rd		<= 1'b0;
		fifo1_rd		<= 1'b0;
		remain_length	<= 16'b0;
		OutBus_Val		<= 1'b0;
		OutBus_Sop		<= 1'b0;
		OutBus_Eop		<= 1'b0;
		OutBus_PktLen	<= 16'b0;
		OutBus_PktType	<= 8'b0;
		OutBus_Dat		<= 0;
		OutBus_Mod		<= 0;
	end
    else 
	begin
		case(state_0)
		IDLE_SM0 :
		begin
			fifo0_rd		<= 1'b0;
			fifo1_rd		<= 1'b0;
			remain_length	<= 16'b0;
			OutBus_Val		<= 1'b0;
			OutBus_Sop		<= 1'b0;
			OutBus_Eop		<= 1'b0;
			OutBus_PktLen	<= 16'b0;
			OutBus_PktType	<= 8'b0;
			OutBus_Dat		<= 0;
			OutBus_Mod		<= 0;
			if (~(fifo0_empty | fifo0_busy))
			begin
				state_0 		<= FIFO0_LOAD_SM0;
				fifo0_rd		<= 1'b1;
			end
			else if (~(fifo1_empty | fifo1_busy))
			begin
				state_0 		<= FIFO1_LOAD_SM0;
				fifo1_rd		<= 1'b1;
			end
		end
		FIFO0_LOAD_SM0:
		begin
			state_0 		<= FIFO0_START_SM0;
		end
		FIFO0_START_SM0:
		begin
			OutBus_Dat		<= fifo0_data_out;
			if(fifo0_data_out[DAT_WIDTH-1:DAT_WIDTH-16] > DAT_WIDTH/8)
			begin
				fifo0_rd		<= 1'b1;
				remain_length	<= fifo0_data_out[DAT_WIDTH-1:DAT_WIDTH-16]- DAT_WIDTH/8;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b1;
				OutBus_Eop		<= 1'b0;
				OutBus_PktType	<= fifo0_data_out[DAT_WIDTH-17:DAT_WIDTH-24];
				OutBus_PktLen	<= fifo0_data_out[DAT_WIDTH-1:DAT_WIDTH-16];
				OutBus_Mod		<= DAT_WIDTH/8;
				state_0   		<= FIFO0_SEND_SM0;
			end
			else if(!fifo0_empty)
			begin
				fifo0_rd		<= 1'b1;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b1;
				OutBus_Eop		<= 1'b1;
				OutBus_Mod		<= fifo0_data_out[DAT_WIDTH- 1:DAT_WIDTH-16];
				state_0 		<= FIFO0_START_SM0;
			end
			else
			begin
				fifo0_rd		<= 1'b0;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b1;
				OutBus_Eop		<= 1'b1;
				OutBus_Mod		<= fifo0_data_out[DAT_WIDTH-1:DAT_WIDTH-16];
				state_0   		<= IDLE_SM0;
			end
		end
		FIFO0_SEND_SM0:
		begin
			OutBus_Dat		<= fifo0_data_out;
			if(remain_length > (DAT_WIDTH/8))
			begin
				fifo0_rd		<= 1'b1;
				remain_length	<= remain_length - DAT_WIDTH/8;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b0;
				OutBus_Eop		<= 1'b0;
				OutBus_Mod		<= DAT_WIDTH/8;
				state_0   		<= FIFO0_SEND_SM0;
			end
			else if(!fifo0_empty)
			begin
				fifo0_rd		<= 1'b1;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b0;
				OutBus_Eop		<= 1'b1;
				OutBus_Mod		<= remain_length;
				state_0 		<= FIFO0_START_SM0;
			end
			else
			begin
				fifo0_rd		<= 1'b0;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b0;
				OutBus_Eop		<= 1'b1;
				OutBus_Mod		<= remain_length;
				state_0   		<= IDLE_SM0;
			end
		end
		FIFO1_LOAD_SM0:
		begin
			state_0 		<= FIFO1_START_SM0;
		end
		FIFO1_START_SM0:
		begin
			OutBus_Dat		<= fifo1_data_out;
			if(fifo1_data_out[DAT_WIDTH-1:DAT_WIDTH-16] > DAT_WIDTH/8)
			begin
				fifo1_rd		<= 1'b1;
				remain_length	<= fifo1_data_out[DAT_WIDTH-1:DAT_WIDTH-16] - DAT_WIDTH/8;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b1;
				OutBus_Eop		<= 1'b0;
				OutBus_PktType	<= fifo1_data_out[DAT_WIDTH-17:DAT_WIDTH-24];
				OutBus_PktLen	<= fifo1_data_out[DAT_WIDTH-1:DAT_WIDTH-16];
				OutBus_Mod		<= DAT_WIDTH/8;
				state_0   		<= FIFO1_SEND_SM0;
			end
			else if(!fifo1_empty)
			begin
				fifo1_rd		<= 1'b1;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b1;
				OutBus_Eop		<= 1'b1;
				OutBus_Mod		<= fifo1_data_out[DAT_WIDTH- 1:DAT_WIDTH-16];
				state_0 		<= FIFO1_START_SM0;
			end
			else
			begin
				fifo1_rd		<= 1'b0;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b1;
				OutBus_Eop		<= 1'b1;
				OutBus_Mod		<= fifo1_data_out[DAT_WIDTH-1:DAT_WIDTH-16];
				state_0   		<= IDLE_SM0;
			end
		end
		FIFO1_SEND_SM0:
		begin
			OutBus_Dat		<= fifo1_data_out;
			if(remain_length > DAT_WIDTH/8)
			begin
				fifo1_rd		<= 1'b1;
				remain_length	<= remain_length - DAT_WIDTH/8;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b0;
				OutBus_Eop		<= 1'b0;
				OutBus_Mod		<= DAT_WIDTH/8;
				state_0   		<= FIFO1_SEND_SM0;
			end
			else if(!fifo1_empty)
			begin
				fifo1_rd		<= 1'b1;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b0;
				OutBus_Eop		<= 1'b1;
				OutBus_Mod		<= remain_length;
				state_0 		<= FIFO1_START_SM0;
			end
			else
			begin
				fifo1_rd		<= 1'b0;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b0;
				OutBus_Eop		<= 1'b1;
				OutBus_Mod		<= remain_length;
				state_0   		<= IDLE_SM0;
			end
		end
		default:
			begin
				state_0   		<= IDLE_SM0;
			end
		endcase
	end
end		







endmodule
