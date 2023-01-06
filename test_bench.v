`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   16:38:21 12/27/2022
// Design Name:   packet_chopper
// Module Name:   D:/FPGA_Proj/packet_chopper/RTL/test_bench.v
// Project Name:  packet_chopper
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: packet_chopper
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////
`include "test_bench_ctl.v"

module test_bench;


	localparam  HALF_CYCLE_250_CLK = 2;

	// Inputs
	reg Rst;
	reg system_clk;
	reg InBus_Val;
	reg InBus_Sop;
	reg InBus_Eop;
	reg [DATA_WIDTH /8-1:0] InBus_Mod;
	reg [DATA_WIDTH-1:0] InBus_Dat;
	
	reg [15:0]   			remain_data;
	reg [7:0]	 			i;
	reg [DATA_WIDTH -1:0] 	tx_data [1023:0];
	reg [DATA_WIDTH-1:0] 	InBus_Dat_reg;
	
	// Outputs
	wire InBus_Rdy;
	wire OutBus_Val;
	wire OutBus_Sop;
	wire OutBus_Eop;
	wire [$clog2(DAT_WIDTH/8):0] OutBus_Mod;
	wire [DAT_WIDTH -1:0] OutBus_Dat;
	wire [15:0] OutBus_PktLen;
	wire [7:0] OutBus_PktType;
	wire Error;
	
	

	// Instantiate the Unit Under Test (UUT)
	packet_chopper #(
		.DATA_WIDTH	(DATA_WIDTH),
		.DAT_WIDTH	(DAT_WIDTH)
	)uut (
		.Rst(Rst), 
		.Clk(system_clk), 
		.InBus_Rdy(InBus_Rdy), 
		.InBus_Val(InBus_Val), 
		.InBus_Sop(InBus_Sop), 
		.InBus_Eop(InBus_Eop), 
		.InBus_Mod(InBus_Mod), 
		.InBus_Dat(InBus_Dat), 
		.OutBus_Val(OutBus_Val), 
		.OutBus_Sop(OutBus_Sop), 
		.OutBus_Eop(OutBus_Eop), 
		.OutBus_Mod(OutBus_Mod), 
		.OutBus_Dat(OutBus_Dat), 
		.OutBus_PktLen(OutBus_PktLen), 
		.OutBus_PktType(OutBus_PktType), 
		.Error(Error)
	);

   //Clocl generation
	initial begin
		system_clk = 1'b0;
		forever 
			#HALF_CYCLE_250_CLK  system_clk = ~ system_clk;
	end


/************************************************************
 Task : Send a packet to the DUT with 8bits bus width
 Description : Send a packet to the DUT with 8bits bus width,
			   packet_length: Total length of the packet
			   packet_type: packet type
			   i_in: the start location of the data source
 *************************************************************/

task tsk_send_8bits_pacaket;
	input 	 [15:0]		packet_length;
	input    [7:0]		packet_type;
	input    [31:0]     i_in;
	
	reg [DATA_WIDTH-1:0] InBus_Dat_reg; 	
	begin
		
		$readmemh("D:/FPGA_Proj/packet_chopper/RTL/tx_8bits_data.txt", tx_data);
		$display("[%t] : Send one packet...", $realtime);
		
		if(uut.InBus_Rdy)
		//make sure all the previous operations have finished!
		begin
            @(posedge system_clk);
		end
		i <= i_in;
		InBus_Val <= 1;
		InBus_Sop <= 1;
		InBus_Eop <= 0;
		if(packet_length > (DATA_WIDTH/8))
		begin
			InBus_Dat_reg <= tx_data[i];
			InBus_Mod <= 0;
			InBus_Dat <= {packet_length,packet_type,tx_data[i][39:0]};
		end
		remain_data <= 1016;
		i = i + 1;
		@(posedge system_clk);
		
		while (remain_data > 8)
		begin
			InBus_Dat_reg <= tx_data[i];
			InBus_Val <= 1;
			InBus_Sop <= 0;
			InBus_Eop <= 0;
			InBus_Mod <= tx_data[i];
			InBus_Dat <= tx_data[i];
			remain_data <= remain_data - 8;
			i <= i + 1;
			@(posedge system_clk);
		end
		
		InBus_Dat_reg <= tx_data[i];
		InBus_Val <= 1;
		InBus_Sop <= 0;
		InBus_Eop <= 1;
		InBus_Dat <= tx_data[i];
		
		@(posedge system_clk);
		
		InBus_Val <= 0;
		InBus_Sop <= 0;
		InBus_Eop <= 1;
		InBus_Mod <= 0;
		InBus_Dat <= 0;

	end
endtask // tsk_send_8bits_pacaket end

/************************************************************
 Task : Send a packet to the DUT with 32 bits bus width
 Description : Send a packet to the DUT with 8bits bus width,
			   packet_length: Total length of the packet
			   packet_type: packet type
			   i_in: the start location of the data source
 *************************************************************/

task tsk_send_32bits_packet;
	input 	 [15:0]		packet_length;
	input    [7:0]		packet_type;
	input    [7:0]     i_in;
	 	
	begin
		
		$readmemh("D:/FPGA_Proj/packet_chopper/RTL/tx_32bits_data.txt", tx_data);
		$display("[%t] : Send one packet...", $realtime);
		@(posedge system_clk);
		i <= i_in;
		if(uut.InBus_Rdy)
		//make sure all the previous operations have finished!
		begin
            @(posedge system_clk);
		end
		
		InBus_Val <= 1;
		InBus_Sop <= 1;
		InBus_Eop <= 0;
		if(packet_length > (DATA_WIDTH/8 - 3))
		begin
			InBus_Dat_reg <= tx_data[i];
			InBus_Mod <= 0;
			InBus_Dat <= {packet_length+3,packet_type,tx_data[i][DATA_WIDTH-1:24]};
			remain_data <= packet_length - (DATA_WIDTH/8 - 3) ;
			i <= i + 1;
			@(posedge system_clk);
		end
		
		
		while (remain_data > (DATA_WIDTH/8 - 1))
		begin
			InBus_Val <= 1;
			InBus_Sop <= 0;
			InBus_Eop <= 0;
			InBus_Mod <= 0;
			InBus_Dat <= {InBus_Dat_reg[23:0],tx_data[i][DATA_WIDTH-1:24]};
			InBus_Dat_reg <= tx_data[i];
			remain_data <= remain_data - (DATA_WIDTH/8);
			i <= i + 1;
			@(posedge system_clk);
		end
		
		i <= i + 1;
		InBus_Val <= 1;
		InBus_Sop <= 0;
		InBus_Eop <= 1;
		if(remain_data == DATA_WIDTH/8 )
		begin
			InBus_Mod <= 0;
		end
		else
		begin
			InBus_Mod <= remain_data;
		end
		InBus_Dat <= {InBus_Dat_reg[23:0],tx_data[i][DATA_WIDTH-1:24]};
		
		@(posedge system_clk);
		
		InBus_Val <= 0;
		InBus_Sop <= 0;
		InBus_Eop <= 0;
		InBus_Mod <= 0;
		InBus_Dat <= 0;

	end
endtask // tsk_send_32bits_pacaket end

/************************************************************
 Task : Send a packet to the DUT with 64 bits bus width
 Description : Send a packet to the DUT with 8bits bus width,
			   packet_length: Total length of the packet
			   packet_type: packet type
			   i_in: the start location of the data source
 *************************************************************/

task tsk_send_64bits_packet;
	input 	 [15:0]		packet_length;
	input    [7:0]		packet_type;
	input    [7:0]     i_in;
	 	
	begin
		
		$readmemh("D:/FPGA_Proj/RTL/packet_chopper/tx_64bits_data.txt", tx_data);
		$display("[%t] : Send one packet...", $realtime);
		@(posedge system_clk);
		i <= i_in;
		remain_data <= 0;
		if(uut.InBus_Rdy)
		//make sure all the previous operations have finished!
		begin
            @(posedge system_clk);
		end
		
		InBus_Val <= 1;
		InBus_Sop <= 1;
		InBus_Eop <= 0;
		if(packet_length > (DATA_WIDTH/8 - 3))
		begin
			InBus_Dat_reg <= tx_data[i];
			InBus_Mod <= 0;
			InBus_Dat <= {packet_length+3,packet_type,tx_data[i][DATA_WIDTH-1:24]};
			remain_data <= packet_length -(DATA_WIDTH/8 - 3) ;
			i <= i + 1;
			@(posedge system_clk);
		end
		
		
		while (remain_data > (DATA_WIDTH/8 - 1))
		begin
			InBus_Val <= 1;
			InBus_Sop <= 0;
			InBus_Eop <= 0;
			InBus_Mod <= 0;
			InBus_Dat <= {InBus_Dat_reg[23:0],tx_data[i][DATA_WIDTH-1:24]};
			InBus_Dat_reg <= tx_data[i];
			remain_data <= remain_data - (DATA_WIDTH/8);
			i <= i + 1;
			@(posedge system_clk);
		end
		
		i <= i + 1;	 
		InBus_Val <= 1;
		InBus_Sop <= 0;
		InBus_Eop <= 1;
		if(remain_data == DATA_WIDTH/8 )
		begin
			InBus_Mod <= 0;
		end
		else
		begin
			InBus_Mod <= remain_data;
		end
		InBus_Dat <= {InBus_Dat_reg[23:0],tx_data[i][DATA_WIDTH-1:24]};
		
		@(posedge system_clk);
		
		InBus_Val <= 0;
		InBus_Sop <= 0;
		InBus_Eop <= 1;
		InBus_Mod <= 0;
		InBus_Dat <= 0;

	end
endtask // tsk_send_64bits_pacaket end


//Reset generation
initial begin
	// Initialize Inputs
	$display("[%t] : System Reset Asserted...", $realtime);
	Rst <= 1;
	InBus_Val <= 0;
	InBus_Sop <= 0;
	InBus_Eop <= 1;
	InBus_Mod <= 0;
	InBus_Dat <= 0;
	// Wait 100 ns for global reset to finish
	#100;
	Rst <= 0;  
	// Add stimulus here
	$display("[%t] : System Reset De-asserted...", $realtime);
	#100;
	

	if(DATA_WIDTH==64) begin 
		// 'z': 122;
		//sub-packet: types 'o'( fix length = 4), plus 3 bytes overhead, use 'z' type of packet to send
		//tsk_send_64bits_packet(7,122,0);
		
		#100;
		// sub-packet1: types 'B'( length = 7), plus 3 bytes overhead, use 'z' type of packet to send
		// sub-packet2: types 'B'( length = 20), plus 3 bytes overhead, use 'z' type of packet to send
		// sub-packet3: types 'D'( length = 5), plus 3 bytes overhead, use 'z' type of packet to send
		// sub-packet4: types 'A'( length = 4), plus 3 bytes overhead, use 'z' type of packet to send
		tsk_send_64bits_packet(36,122,0);
		
		#100;
		// types 'q'( fix length = 28), plus 3 bytes overhead, use 'z' type of packet to send
		tsk_send_64bits_packet(79,122,5);
		
		#100;
		// types 'q'( fix length = 28), plus 3 bytes overhead, use 'z' type of packet to send
		tsk_send_64bits_packet(79,122,5);
		
	end
	else if(DATA_WIDTH==32) begin 
		// 'z': 122;
		//sub-packet: types 'o'( fix length = 4), plus 3 bytes overhead, use 'z' type of packet to send
		//tsk_send_64bits_packet(7,122,0);
		
		#100;
		// sub-packet1: types 'B'( length = 20), plus 3 bytes overhead, use 'z' type of packet to send
		// sub-packet2: types 'D'( length = 5), plus 3 bytes overhead, use 'z' type of packet to send
		// sub-packet3: types 'A'( length = 4), plus 3 bytes overhead, use 'z' type of packet to send
		tsk_send_32bits_packet(32,122,2);
				
		#100;
		// types 'q'( fix length = 28), plus 3 bytes overhead, use 'z' type of packet to send
		// types 'X'( fix length = 51), plus 3 bytes overhead, use 'z' type of packet to send
		tsk_send_32bits_packet(79,122,10);
		
		#100;
		// types 'q'( fix length = 28), plus 3 bytes overhead, use 'z' type of packet to send
		// types 'X'( fix length = 51), plus 3 bytes overhead, use 'z' type of packet to send
		tsk_send_32bits_packet(79,122,10);
	end
		

	
	#1000;
	$stop;
	
end		


endmodule

