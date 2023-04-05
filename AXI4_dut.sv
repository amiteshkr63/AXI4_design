module AXI4_DUT (
	
	//Global Signals
	ACLK, 
	ARESETn,
	
	//Write Address Channel	(AW|aw)
	AWVALID,
	AWID,
	AWLEN,
	AWSIZE, 
	AWADDR,  
	AWBURST,
	AWREADY,
	
	//Write Data Channel (W|w)
	WVALID,
	WID,
	WDATA,
	WSTRB,
	WLAST,
	WREADY,
	
	//Write Response Channel (B|b)
	BVALID,
	BID,
	BRESP,
	BREADY,
	
	//Read Address Channel (AR|ar)
	ARVALID,
	ARID,
	ARADDR,
	ARLEN,
	ARSIZE,
	ARBURST,
	ARREADY,
	
	//Read Data Channel (R|r)
	RVALID,
	RID,
	RDATA,
	RRESP,
	RLAST,
	RREADY
	);

	//Global Signals
	input ACLK; 
	input ARESETn;

	//An address channel carries control information that describes the nature of the data to be transferred.
	//Write Address Channel (AW|aw)
	input AWVALID; //Indicates Master sending Valid write address and Other Control Signals
	input [3:0]AWID; //Indicates Write Address ID || IDENTIFICATION TAG for the Write Address Group of Signals
	input [7:0]AWLEN; //Indicates BURST LENGTH || (BURST LENGTH = AWLEN + 1) 
	input [2:0]AWSIZE; //Indicates Unique Transaction size (BURST SIZE = 2 ^ AWSIZE) || Size of a Beat
	input [31:0]AWADDR; //Indicates Starting Write Address of First Transfer of WRITE BURST TRANSACTION  
	input [1:0]AWBURST; //Indicates BURST TYPE || FIXED, INCR, WRAP
	output reg AWREADY; //Indicates Slave ready to accept an Write Address from Master

	//Write Data Channel (W|w)
	input WVALID; //Indicates Master Sending Valid Data and other Control signals 
	input [3:0]WID; //Indicates Write Data ID || IDENTIFICATION TAG for the Write Data Group of Signals
	input [31:0]WDATA; //Indicates Write Data per Beat
	input [3:0]WSTRB; //Indicates which field of WDATA contains INFORMATION {[31:24] [23:16] [15:8] [7:0]}
	input WLAST; //Indicates Last set of Write Data available for Transfer || Indicates Last Beat
	output reg WREADY; //Indicates Slave Ready to accept MASTER's DATA

	//Write Response Channel (B|b)
	output reg BVALID; //Indicates Slave Sending Write Response(acknowledgement) and other Control Signals
	output reg [3:0]BID; //Indicates Write Response ID || IDENTIFICATION TAG for the Write Response Group of Signals
	output reg [1:0]BRESP; //Indicates Status of Write Transaction (Successful or Nature of Failure) 
	input BREADY; //Indicates Master is ready to accept Slave's Write Response {BREADY=>[BVALID, BID, BRESP]}

	//Read Address Channel (AR|ar)
	input ARVALID; //Indicates Master Sending Valid Read Address and Other Control signals 
	input [3:0]ARID; //Indicates Read Address ID || IDENTIFICATION TAG for Read Address group of Signals
	input ARADDR; //Indicates Starting Read Address of First Transfer of READ BURST TRANSACTION
	input [7:0]ARLEN; //Indicates Burst Length (BURST_LENGTH = ARLEN +1)
	input [3:0]ARSIZE; //Indicates Size of 1 Transaction of BURST (BURST SIZE = 2 ^ ARSIZE) || Beat Size
	input [1:0]ARBURST; //Indicates BURST TYPE || FIXED, INCR, WRAP
	output reg ARREADY; //Indicates Slave Ready to accept an Read Address from Master

	//Read Data Channel (R|r)
	output reg RVALID; //Indicates Slave Sending Valid Read Data and Other Control Signals
	output reg [3:0]RID; //Indicates Read Data ID || IDENTIFICATION TAG for Read Data group of Signals
	output reg [31:0]RDATA; //Indicates Read Data per Beat
	output reg [1:0]RRESP; //Indicates Status of Read Transaction (Successful or Nature of Failure) {[RREADY(always asserted)=>RLAST]=>[RVALID, RRESP]}
	output reg RLAST; //Indicates Last set of Read Data available for Transfer || Indicates Last Beat
	input RREADY; //Indicates Master Ready to accept SLAVE's DATA

	//Internal Registers
	reg [31:0]r_AWADDR;
	
	reg [7:0]mem[127:0];
	////////////////////////////////////////////////////////////State Declaration//////////////////////////////////////////////////////////////////
	//Write Address States
	typedef enum bit[1:0]{AW_IDLE, AW_START, AW_READY}aw_state;
	aw_state AW_PST, AW_NST;

	//Write Data States
	typedef enum bit[1:0]{W_IDLE, W_START, W_READY}w_state;
	w_state W_PST, W_NST;

	//Write Response States
	typedef enum bit[1:0]{B_IDLE, B_START, B_READY}b_state;
	b_state B_PST, B_NST;

	//Read Address States
	typedef enum bit[1:0]{AR_IDLE, AR_START, AR_READY}ar_state;
	ar_state AR_PST, AR_NST;

	//Read Data States
	typedef enum bit[1:0]{R_IDLE, R_START, R_READY}r_state;
	r_state R_PST, R_NST;

	//State Assignment
	always_ff @(posedge clk or negedge ARESETn) begin
		if(~ARESETn) begin
			AW_PST <= 0;
			W_PST <= 0;
			B_PST <= 0;
			AR_PST <= 0;
			R_PST <= 0;
		end else begin
			AW_PST <= AW_NST;
			W_PST <= W_NST;
			B_PST <= B_NST;
			AR_PST <= AR_NST;
			R_PST <= R_NST;
		end
	end

	//Write Address States
	always_comb begin
		case (AW_PST)
			AW_IDLE: 
				begin
					AW_NST = AW_START;
					AWREADY = 0;
				end
			AW_START:
				begin
					if (AWVALID) begin
						AW_NST = AW_READY;
						r_AWADDR = AWADDR;
					end	
					else AW_NST = AW_PST;
					AWREADY = 0;
				end
			AW_READY:
				begin
					AW_NST = AW_IDLE;
					AWREADY = 1;
				end
			default : /* default */;
		endcase
	end

	function fixed_write_mode(input [31:0]awaddr, input [31:0]wdata, input [3:0]wstrb);
		unique case (wstrb)
			4'b0001: mem[awaddr]=wdata[7:0];
			4'b0010: mem[awaddr]=wdata[15:8];
			4'b0011: begin
						mem[awaddr]=wdata[7:0];
						mem[awaddr+1]=wdata[15:8];
					 end
			4'b0100: mem[awaddr]=wdata[23:16];
			4'b0101: begin
					 	mem[awaddr]=wdata[7:0];
					 	mem[awaddr+1]=wdata[23:16];
					 end
			4'b0110: begin
						mem[awaddr]=wdata[15:8];
						mem[awaddr+1]=wdata[23:16];
					 end
			4'b0111: begin
						mem[awaddr]=wdata[7:0];
						mem[awaddr+1]=wdata[15:8];
						mem[awaddr+2]=wdata[23:16];
					 end
			4'b1000: mem[awaddr]=wdata[31:24];
			4'b1001: begin
					 	mem[awaddr]=wdata[7:0];
					 	mem[awaddr+1]=wdata[31:24];
					 end
			4'b1010: begin
						mem[awaddr]=wdata[15:8];
						mem[awaddr+1]=wdata[31:24];
					 end
			4'b1011: begin
						mem[awaddr]=wdata[7:0];
						mem[awaddr+1]=wdata[15:8];
						mem[awaddr+2]=wdata[31:24];
					 end
			4'b1100: begin
						mem[awaddr]=wdata[23:16];
						mem[awaddr+1]=wdata[31:24];
					 end
			4'b1101: begin
						mem[awaddr]=wdata[7:0];
						mem[awaddr+1]=wdata[23:16];
						mem[awaddr+2]=wdata[31:24];
					 end
			4'b1110: begin
						mem[awaddr]=wdata[15:8];
						mem[awaddr+1]=wdata[23:16];
						mem[awaddr+2]=wdata[31:24];
					 end
			4'b1111: begin
						mem[awaddr]=wdata[7:0];
						mem[awaddr+1]=wdata[15:8];
						mem[awaddr+1]=wdata[23:16];
						mem[awaddr+1]=wdata[31:24];
					 end
		endcase
		return awaddr;
	endfunction : fixed_write_mode

	function incr_write_mode(input [31:0]awaddr, input [31:0]wdata, input [3:0]wstrb, output [31:0]ret_addr);
		unique case (wstrb)
			4'b0001: begin
						mem[awaddr]=wdata[7:0];
						return ret_addr = awaddr+1;
					 end
			4'b0010: begin
						mem[awaddr]=wdata[15:8];
						return ret_addr = awaddr+1;
					 end
			4'b0011: begin
						mem[awaddr]=wdata[7:0];
						mem[awaddr+1]=wdata[15:8];
						return ret_addr = awaddr+2;
					 end
			4'b0100: begin
						mem[awaddr]=wdata[23:16];
						return ret_addr = awaddr+1;
					 end
			4'b0101: begin
					 	mem[awaddr]=wdata[7:0];
					 	mem[awaddr+1]=wdata[23:16];
						return ret_addr = awaddr+2;
					 end
			4'b0110: begin
						mem[awaddr]=wdata[15:8];
						mem[awaddr+1]=wdata[23:16];
						return ret_addr = awaddr+2;
					 end
			4'b0111: begin
						mem[awaddr]=wdata[7:0];
						mem[awaddr+1]=wdata[15:8];
						mem[awaddr+2]=wdata[23:16];
						return ret_addr = awaddr+3;
					 end
			4'b1000: begin
						mem[awaddr]=wdata[31:24];
						return ret_addr = awaddr+1;
					 end
			4'b1001: begin
					 	mem[awaddr]=wdata[7:0];
					 	mem[awaddr+1]=wdata[31:24];
						return ret_addr = awaddr+2;
					 end
			4'b1010: begin
						mem[awaddr]=wdata[15:8];
						mem[awaddr+1]=wdata[31:24];
						return ret_addr = awaddr+2;
					 end
			4'b1011: begin
						mem[awaddr]=wdata[7:0];
						mem[awaddr+1]=wdata[15:8];
						mem[awaddr+2]=wdata[31:24];
						return ret_addr = awaddr+3;
					 end
			4'b1100: begin
						mem[awaddr]=wdata[23:16];
						mem[awaddr+1]=wdata[31:24];
						return ret_addr = awaddr+2;
					 end
			4'b1101: begin
						mem[awaddr]=wdata[7:0];
						mem[awaddr+1]=wdata[23:16];
						mem[awaddr+2]=wdata[31:24];
						return ret_addr = awaddr+3;
					 end
			4'b1110: begin
						mem[awaddr]=wdata[15:8];
						mem[awaddr+1]=wdata[23:16];
						mem[awaddr+2]=wdata[31:24];
						return ret_addr = awaddr+3;
					 end
			4'b1111: begin
						mem[awaddr]=wdata[7:0];
						mem[awaddr+1]=wdata[15:8];
						mem[awaddr+2]=wdata[23:16];
						mem[awaddr+3]=wdata[31:24];
						return ret_addr = awaddr+4;
					 end
		endcase
	endfunction : incr_write_mode
 endmodule : AXI4_DUT
