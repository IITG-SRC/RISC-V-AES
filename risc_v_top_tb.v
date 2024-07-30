
`timescale 1ns / 1ps
module tb_main();
	reg reset;
	initial begin
	  reset <= 1;
	  #1001 reset <= 0;
	end

	reg clk;
	initial clk <= 0;
	always #25 clk <= ~clk;
	
	wire [31:0] axi_add, axi_rdata, axi_wdata;
	wire [ 3:0] axi_wen; 
	wire uart_tx,b,c;
	
	
	
	// initial begin
		// $set_toggle_region(tb_main.main_inst);
		// $toggle_start();
		// #100000
		// $toggle_stop();
		// $toggle_report("cpu.saif", 1.0e-12, "tb_main");
		// #40 $finish;
	// end


assign b = reset;
	
	reg [31:0] temp; 
	always@(posedge clk) if (reset) temp <= 0; else temp <= temp+1 ;
	
	assign c = temp[27] ;
	
	localparam AWIDTH_DBP = 10 ;          // Size of history table
	localparam DWIDTH_DBP = 32+2 ;
	
	wire [AWIDTH_DBP-1:0] dbp_add1   ;
	wire [DWIDTH_DBP-1:0] dbp_rdata1 ;
	wire [AWIDTH_DBP-1:0] dbp_add2   ;
	wire [DWIDTH_DBP-1:0] dbp_rdata2 ;
	wire                  dbp_wen2   ;
	wire [DWIDTH_DBP-1:0] dbp_wdata2 ;
	
	
	
	DBP_BHT #(
	   .AWIDTH ( AWIDTH_DBP ),
	   .DWIDTH ( DWIDTH_DBP )
	)  BHT (
	   .clk    ( clk        ),
	   .reset  ( reset      ),
	   .add1   ( dbp_add1   ),
	   .rdata1 ( dbp_rdata1 ),
	   .add2   ( dbp_add2   ),
	   .rdata2 ( dbp_rdata2 ),
	   .wen2   ( dbp_wen2   ),
	   .wdata2 ( dbp_wdata2 )
	);
	
	wire [31:0] add1   ;
	wire [31:0] rdata1 ;
	wire [ 3:0] wen1   ;
	wire [31:0] wdata1 ;
	
	wire [31:0] add2   ;
	wire [31:0] rdata2 ;
	wire [ 3:0] wen2   ;
	wire [31:0] wdata2 ;
	
	
	
	
	wire [3:0] wen_D   ; assign wen_D    = (add2 == 32'h000001f0) ? 0    : wen2 ;
	wire [3:0] wen_peph; assign wen_peph = (add2 == 32'h000001f0) ? wen2 : 0    ;
	
	
	
	
	
	         
	
	wire[127:0] cipher;         /////////////////////////////////////
	reg[31:0] cipher_addr;         ///////////////////////////////////////////
	///////////////////////////////////////////
	reg [31:0] cipher_text;         //////////////////////////////////
	reg wen_aes_d; 
     wire Dvld;	////////////////////////////////
	always@(posedge Dvld)             /////////////////////////////////////////////
	begin
	
	cipher_addr <= 32'h0000004c;
	wen_aes_d<=1;
	end
	
	
	reg wait_en;
	always@(posedge clk)                          //////////////////////////////////////////
	begin
	if(reset)
	wait_en <=0;
	else  begin
	if ((add2 == 32'h00000030)&&(wen_D!=4'b0000))begin
	wait_en <=1;
	
	end   end
	end
	
	always@(posedge clk)        //////////////////////////////////////////
	begin
	case(cipher_addr)
	32'h0000004c: begin cipher_text<=cipher[127:96];
	                    cipher_addr <= 32'h00000050; 
                       					end
    32'h00000050: begin cipher_text<=cipher[95:64];
	                    cipher_addr <= 32'h00000054;   end
	32'h00000054: begin cipher_text<=cipher[63:32];
	                    cipher_addr <= 32'h00000058;   end
    32'h00000058: begin cipher_text<=cipher[31:0];   
	                    cipher_addr <= 32'h0000005c; end
    32'h0000005c:begin	wen_aes_d<=0;  
                         cipher_addr <= 32'h00000000; 
                          wait_en<=0;	   end  //////////////////////////////////////////
						
    endcase
	end                           
	
	
	
	
	
	
 //cpu and aes
	
	cpu_aes #(
	   .AWIDTH_DBP ( AWIDTH_DBP ),
	   .DWIDTH_DBP ( DWIDTH_DBP )
	) cpuaes_inst (
		.clk   ( clk  ),
		.reset ( reset),
		// Channel 1
		.add1   ( add1   ),
		.rdata1 ( rdata1 ),
		.wen1   ( wen1   ),
		.wdata1 ( wdata1 ),
		// Channel 2
		.add2   ( add2   ),
		.rdata2 ( rdata2 ),
		.wen2   ( wen2   ),
		.wdata2 ( wdata2 ),
		
		.dbp_add1   ( dbp_add1   ),
		.dbp_rdata1 ( dbp_rdata1 ),
		.dbp_add2   ( dbp_add2   ),
		.dbp_rdata2 ( dbp_rdata2 ),
		.dbp_wen2   ( dbp_wen2   ),
		.dbp_wdata2 ( dbp_wdata2 ),
		
     .cipher(cipher),
    .Dvld(Dvld),
	.wait_en(wait_en)
	);
	
	
	
	
	// data cache 64KB
	
	cache_I #( .ADD_WIDTH(18) ) 
	cache_instruction (
		.clk   ( clk    ),
		.reset ( reset  ),
		.add   ( add1   ),
		.rdata ( rdata1 ),
		.wen   ( wen1   ),
		.wdata ( wdata1 )
	);
	
	cache_D #( .ADD_WIDTH(18) ) 
	cache_data (
		.clk   ( clk    ),
		.reset ( reset  ),
		.add   ( add2   ),
		.rdata ( rdata2 ),
		.wen   ( wen_D  ),
		.wdata ( wdata2 ),
		.wen_aes_d(wen_aes_d),                //////////////////////////////////////////////////////////////////////////////
		.cipher_addr(cipher_addr),           //////////////////////////////////////////////////////////////////////////////
		.cipher_text(cipher_text)           //////////////////////////////////////////////////////////////////////////////
	);
	
	uart uart_inst(
		.clk_100MHz(clk), .reset(reset),
		.din(wdata2[7:0]),
		.vdin(wen_peph[3] | wen_peph[2] | wen_peph[1] | wen_peph[0]),
		.dout(uart_tx)
	);

	
	initial
	begin
	$dumpfile ("top.vcd");
      $dumpvars();
	 
  #240000 $finish;
 

	end

	
    endmodule