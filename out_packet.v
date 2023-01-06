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
	input								fifo_empty,
	output	reg							fifo_rd,
	input 								fifo_busy,
	input [DAT_WIDTH-1:0]				fifo_data_out,
	 
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

parameter 	DATA_BYTE_WIDTH 	= DATA_WIDTH/8;
parameter 	DAT_BYTE_WIDTH 		= DAT_WIDTH/8;
//out_bus is narrow than in_bus
parameter 	NARROW = DATA_WIDTH > DAT_WIDTH;
// required number of cycles in out_bus
parameter 	CYCLE_COUNT = NARROW ? (DATA_WIDTH / DAT_WIDTH) : (DAT_WIDTH / DATA_WIDTH);


//State machine states_sm0
localparam IDLE_SM0             = 4'h0;
localparam FIFO_LOAD0_SM0      	= 4'h1;
localparam FIFO_LOAD1_SM0      	= 4'h2;
localparam FIFO_LOAD2_SM0      	= 4'h3;
localparam FIFO_LOAD3_SM0      	= 4'h4;
localparam SUB_START_SM0      	= 4'h5; 
localparam SUB_SEND_SM0   		= 4'h6; 

reg [3:0]             			state_0;

reg [15:0]				total_length;
reg [15:0]				sub_length;
reg [7:	0]				sub_type;
reg [3: 0] 				byte_counter;
reg [DATA_WIDTH -1:0]	fifo_data_reg;
reg [DATA_WIDTH -1:0]	OutBus_Dat_reg;
reg [3:0]				bytes_shift;

always@(posedge Clk)
begin
    if(Rst)
	begin
		state_0   		<= IDLE_SM0;
		fifo_rd			<= 1'b0;
		total_length	<= 16'b0;
		sub_length		<= 16'b0;
		sub_type		<= 8'b0;
		fifo_data_reg	<= 0;
		OutBus_Dat_reg	<= 0;
		OutBus_Val		<= 1'b0;
		OutBus_Sop		<= 1'b0;
		OutBus_Eop		<= 1'b0;
		OutBus_PktLen	<= 16'b0;
		OutBus_PktType	<= 8'b0;
		OutBus_Dat		<= 0;
		OutBus_Mod		<= 0;
		byte_counter	<= 4'b0;
		bytes_shift		<= 0;
	end
    else 
	begin
		case(state_0)
		IDLE_SM0 :
		begin
			fifo_rd			<= 1'b0;
			total_length	<= 16'b0;
			sub_length		<= 16'b0;
			sub_type		<= 8'b0;
			fifo_data_reg	<= 0;
			OutBus_Dat_reg	<= 0;
			OutBus_Val		<= 1'b0;
			OutBus_Sop		<= 1'b0;
			OutBus_Eop		<= 1'b0;
			OutBus_PktLen	<= 16'b0;
			OutBus_PktType	<= 8'b0;
			OutBus_Dat		<= 0;
			OutBus_Mod		<= 0;
			byte_counter	<= 4'b0;
			bytes_shift		<= 0;
			if (~(fifo_empty))
			begin
				state_0 	<= FIFO_LOAD0_SM0;
				fifo_rd		<= 1'b1;
			end
		end
		FIFO_LOAD0_SM0:
		begin
			state_0 	<= FIFO_LOAD1_SM0;
		end
		FIFO_LOAD1_SM0:
		begin
			//if in_bus is wider than 2 bytes, we can get all the larger packet information
			if (DATA_BYTE_WIDTH > 3)
			begin
				total_length	<= fifo_data_out[DATA_WIDTH-1:DATA_WIDTH-16];  
				state_0 		<= FIFO_LOAD3_SM0;
				fifo_data_reg	<= fifo_data_out;
				fifo_rd			<= 1'b1;
				bytes_shift		<= 4'h3;
			end	
			//if in_bus is 2 bytes width, we can get length information the larger packet information
			else if (DATA_BYTE_WIDTH == 2)
			begin
				total_length	<= fifo_data_out[DATA_WIDTH-1:DATA_WIDTH-16];  //assume the in_bus is wider than 16 bits
				state_0 		<= FIFO_LOAD2_SM0;
				fifo_rd			<= 1'b1;
			end
		end
		FIFO_LOAD2_SM0:
		begin
			fifo_data_reg	<= fifo_data_out;
			state_0 		<= FIFO_LOAD3_SM0;
			fifo_rd			<= 1'b1;
			total_length	<= total_length - DATA_BYTE_WIDTH;
		end
		FIFO_LOAD3_SM0:
		begin
			if (DATA_BYTE_WIDTH > 3)
			begin
				OutBus_Dat_reg 	<= {fifo_data_reg[DATA_WIDTH-((bytes_shift)<<3)-1:0], fifo_data_out[DATA_WIDTH-1:DATA_WIDTH-((bytes_shift)<<3)]};	
				fifo_data_reg	<= fifo_data_out;
				state_0 		<= SUB_START_SM0;
			end
		end
		SUB_START_SM0:
		begin
			//if in_bus is wider than 2 bytes, we can get all the larger packet information
			if ((DATA_BYTE_WIDTH > 3) &&(OutBus_Dat_reg[DAT_WIDTH-1:DAT_WIDTH-16] > DAT_WIDTH/8))
			begin
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b1;
				OutBus_Eop		<= 1'b0;
				OutBus_Mod		<= DAT_BYTE_WIDTH;
				state_0   		<= FIFO_SEND_SM0;
				byte_counter	<= CYCLE_COUNT;	
				total_length	<= total_length - DATA_BYTE_WIDTH;
				bytes_shift		<= (bytes_shift + OutBus_Dat_reg[DAT_WIDTH-1:DAT_WIDTH-16]) % DAT_BYTE_WIDTH;
				OutBus_Dat		<= ({DATA_WIDTH{1'b1}} << ((DATA_BYTE_WIDTH - OutBus_Dat_reg[DAT_WIDTH-1:DAT_WIDTH-16])<<3)) & OutBus_Dat_reg;
				sub_length		<= OutBus_Dat_reg[DAT_WIDTH-1:DAT_WIDTH-16];
			end
			else if (DATA_BYTE_WIDTH > 3)
			begin
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b1;
				OutBus_Eop		<= 1'b1;
				OutBus_Mod		<= DAT_WIDTH/8;
				OutBus_Dat		<= ({DATA_WIDTH{1'b1}} << ((DATA_BYTE_WIDTH - InBus_Mod)<<3)) & OutBus_Dat_reg;
				OutBus_Dat_reg 	<= {fifo_data_reg[DATA_WIDTH-25:0], fifo_data_out[DATA_WIDTH-1:DATA_WIDTH-24]};	
				fifo_data_reg	<= fifo_data_out;
				state_0 		<= SUB_START_SM0;
			end
		end
		SUB_SEND_SM0:
		begin
			OutBus_Dat <= {fifo_data_reg[DATA_WIDTH-25:0], fifo_data_out[DATA_WIDTH-1:DATA_WIDTH-24]};
			fifo_data_reg	<= fifo_data_out;
			if(sub_length > DAT_BYTE_WIDTH)
			begin
				fifo_rd		<= 1'b1;
				total_length	<= total_length - DATA_BYTE_WIDTH;
				sub_length		<= sub_length - DATA_BYTE_WIDTH;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b0;
				OutBus_Eop		<= 1'b0;
				OutBus_Mod		<= DAT_WIDTH/8;
				state_0   		<= FIFO_SEND_SM0;
			end
			else if(!fifo_empty)
			begin
				fifo_rd		<= 1'b1;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b0;
				OutBus_Eop		<= 1'b1;
				OutBus_Mod		<= total_length;
				state_0 		<= FIFO_START_SM0;
			end
			else
			begin
				fifo_rd		<= 1'b0;
				OutBus_Val		<= 1'b1;
				OutBus_Sop		<= 1'b0;
				OutBus_Eop		<= 1'b1;
				OutBus_Mod		<= total_length;
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
