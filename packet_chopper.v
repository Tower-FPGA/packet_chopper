`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:38:44 12/27/2022 
// Design Name: 
// Module Name:    packet_chopper 
// Project Name: 
// Target Devices: Virtex6
// Tool versions: ISE 14.7
// Description: 
//     The input is a stream of data containing a large packet with complete smaller sub-packets.
//     This code takes the larger packet and chop it up into SOP/EOP of smaller packets
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module packet_chopper #(
	DATA_WIDTH = 64,    // the input bus data width, can be: 16, 32 or 64 bits
	DAT_WIDTH = 64    // the output bus data width, can be: 16, 32 or 64 bits
)
(
	//system signals
    input 									Rst,  //Reset signal used by the block
    input 									Clk,  //Clock signal used by the block
	 //input Bus
    output 									InBus_Rdy,  //Flow control for next block to stop transfer.
    input 									InBus_Val,  //Data is valid on the bus.
    input 									InBus_Sop,  //Start of message input
    input 									InBus_Eop,  //End of message input
    input [DATA_WIDTH /8-1:0]				InBus_Mod,  //Modulo valid bytes
    input [DATA_WIDTH-1:0]					InBus_Dat,  //Actual Data
	 
	 //Output Bus
    output 									OutBus_Val,  //Data Valid output
    output 									OutBus_Sop,  //Start of message output
    output 									OutBus_Eop,  //End of message output
    output [$clog2(DAT_WIDTH/8):0]			OutBus_Mod,  //Number of valid bytes on the output.
    output [DAT_WIDTH -1:0]					OutBus_Dat,  //Data output.
    output [15:0] 							OutBus_PktLen,  //Length of extracted packet
    output [7:0] 							OutBus_PktType,  //Type of packet
    output 									Error				//Error Signal
    );


wire [DAT_WIDTH-1:0]				fifo0_data_out;
wire [DAT_WIDTH-1:0]				fifo1_data_out;

assign Error = InBus_Error;

receive_packet #(
	.DATA_WIDTH (DATA_WIDTH),
	.DAT_WIDTH	(DAT_WIDTH)
)recv_packet_inst(
	.Rst		(Rst),
	.Clk		(Clk),
	//input Bus
	.InBus_Rdy	(InBus_Rdy),
	.InBus_Val	(InBus_Val),
	.InBus_Sop	(InBus_Sop),
	.InBus_Eop	(InBus_Eop),
	.InBus_Mod	(InBus_Mod),
	.InBus_Dat	(InBus_Dat),
	.InBus_Error(InBus_Error),
	//fifo interface
	.fifo0_empty	(fifo0_empty	),
	.fifo0_rd		(fifo0_rd		),
	.fifo0_busy		(fifo0_busy		),
	.fifo0_data_out	(fifo0_data_out	),
	.fifo1_empty	(fifo1_empty	),
	.fifo1_rd		(fifo1_rd		),
	.fifo1_busy		(fifo1_busy		),
	.fifo1_data_out	(fifo1_data_out	)
);

out_packet #(
	.DATA_WIDTH (DATA_WIDTH),
	.DAT_WIDTH	(DAT_WIDTH)
)out_packet_inst(
	.Rst		(Rst),
	.Clk		(Clk),
	//fifo interface
	.fifo0_empty	(fifo0_empty	),
	.fifo0_rd		(fifo0_rd		),
	.fifo0_busy		(fifo0_busy		),
	.fifo0_data_out	(fifo0_data_out	),
	.fifo1_empty	(fifo1_empty	),
	.fifo1_rd		(fifo1_rd		),
	.fifo1_busy		(fifo1_busy		),
	.fifo1_data_out	(fifo1_data_out	),
	//OutBus
	.OutBus_Val		(OutBus_Val		), 
	.OutBus_Sop		(OutBus_Sop		), 
	.OutBus_Eop		(OutBus_Eop		), 
	.OutBus_Mod		(OutBus_Mod		), 
	.OutBus_Dat		(OutBus_Dat		), 
	.OutBus_PktLen	(OutBus_PktLen	),  
	.OutBus_PktType	(OutBus_PktType	), 
	.OutBus_Error	(OutBus_Error	)
	
);

endmodule
