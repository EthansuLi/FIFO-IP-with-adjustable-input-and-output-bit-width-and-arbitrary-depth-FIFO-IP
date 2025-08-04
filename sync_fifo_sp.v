//Serial/Parallel

module sync_fifo_sp#( 
	parameter W_WIDTH = 32,
	parameter R_WIDTH = 8 ,
	parameter DEPTH = 16
)(
	input						clk		,
	input						rst_n	,
	input						wr_en	,
	input		[W_WIDTH -1:0] 	din		,
	input						rd_en	,
	
	output  reg	[R_WIDTH -1:0]	dout	,
	output						wfull	,
	output						rempty	,
	output	reg [$clog2(DEPTH) :0]	fifo_cnt
);

localparam AW = $clog2(DEPTH);



reg [AW -1:0] w_ptr;
reg [AW -1:0] r_ptr;
generate 
if(W_WIDTH > R_WIDTH) begin // 32 to 8
	localparam SP_CNT = W_WIDTH/R_WIDTH ;
	reg [W_WIDTH -1:0] mem[0: DEPTH];
	reg  rd_flag;
	reg [$clog2(SP_CNT) -1:0] r_cnt;
	wire [W_WIDTH -1:0] mem_out;
	reg [W_WIDTH -1:0] shift_reg;
	// wr
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			w_ptr <= 'd0;
		else if(wr_en && !wfull && w_ptr == DEPTH -1)
			w_ptr <= 'd0;
		else if(wr_en && !wfull)
			w_ptr <= w_ptr +1;
	end
	always@(posedge clk) begin
		if(wr_en && !wfull)
			mem[w_ptr] <= din;
	end
	// rd
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			rd_flag <= 1'b0;
		else if(rd_en && !rempty)
			rd_flag <= 1'b1;
		else if(rd_flag && r_cnt == SP_CNT -1)
			rd_flag <= 1'b0;	
	end

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			r_cnt <= 'd0;
		else if(rd_flag && r_cnt == SP_CNT -1)
			r_cnt <= 'd0;
		else if(rd_flag)
			r_cnt <= r_cnt +1;
	end
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			r_ptr <= 'd0;
		else if(r_ptr == DEPTH -1)
			r_ptr <= 'd0;
		else if(rd_flag && r_cnt == SP_CNT -1)
			r_ptr <= r_ptr +1;
	end
	assign mem_out = mem[r_ptr];
	always@(*) begin
		if(~rst_n)
			shift_reg = 'd0;
		else if(rd_flag && r_cnt==0) 
			shift_reg = mem_out;
		else if(rd_flag)
			shift_reg = {{R_WIDTH{1'b0}}, shift_reg[W_WIDTH-1: R_WIDTH]};
		else
			shift_reg = shift_reg;
	end
	
	// assign dout = rd_flag? shift_reg[R_WIDTH -1:0] : 0;

	always@(*) begin
		if(~rst_n)
			dout = 'd0;
		else if(rd_flag)
			dout = shift_reg[R_WIDTH -1:0];
		else
			dout = dout;
	end 
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			fifo_cnt <= 'd0;
		else if(wr_en && !wfull && rd_flag && r_cnt == SP_CNT -1 && !rempty)
			fifo_cnt <= fifo_cnt;
		else if(wr_en && !wfull)
			fifo_cnt <= fifo_cnt +1;
		else if(rd_flag && r_cnt == SP_CNT -1 && !rempty)
			fifo_cnt <= fifo_cnt -1;
	end
	
end
else if(W_WIDTH > R_WIDTH) begin // 8 to 32
	localparam SP_CNT = R_WIDTH/W_WIDTH ;
	reg [R_WIDTH -1:0] mem[0: DEPTH];
	reg wr_flag;
	reg [R_WIDTH -1:0] shift_reg;
	reg [$clog2(SP_CNT) -1:0] w_cnt;
	// cnt
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			w_cnt <= 'd0;
		else if(wr_en && w_cnt == SP_CNT -1 && !wfull)
			w_cnt <= 'd0;
		else if(wr_en && !wfull)
			w_cnt <= w_cnt +1;
	end
	// word shift
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			shift_reg <= 'd0;
		else if(wr_en && !wfull)
			shift_reg <= {shift_reg[R_WIDTH-W_WIDTH-1: 0] , din};
	end
	// wr_flag
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			wr_flag <= 1'b0;
		else if(wr_en && w_cnt == SP_CNT -1 && !wfull)
			wr_flag <= 1'b1;
		else
			wr_flag <= 1'b0;
	end
	// pointer
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			w_ptr <= 'd0;
		else if(wr_flag && !wfull && w_ptr == DEPTH -1)
			w_ptr <= 'd0;
		else if(wr_flag && !wfull)
			w_ptr <= w_ptr +1;
	end
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			r_ptr <= 'd0;
		else if(rd_en && !rempty && r_ptr == DEPTH -1)
			r_ptr <= 'd0;
		else if(rd_en && !rempty)
			r_ptr <= r_ptr +1;
	end
	
	always@(posedge clk) begin
		if(wr_flag && !wfull)
			mem[w_ptr] <= shift_reg;
	end
	always@(posedge clk) begin
		if(rd_en && !rempty)
			dout <= mem[r_ptr];
	end
	
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			fifo_cnt <= 'd0;
		else if(wr_flag && !wfull && rd_en && !rempty)
			fifo_cnt <= fifo_cnt;
		else if(wr_flag && !wfull)
			fifo_cnt <= fifo_cnt + 1;
		else if(rd_en && !rempty)
			fifo_cnt <= fifo_cnt -1;
	end
	

end
else begin
reg [W_WIDTH -1:0] mem[0: DEPTH];

always@(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		w_ptr <= 'd0;
		r_ptr <= 'd0;
	end
	else begin
		if(wr_en && !wfull && w_ptr == DEPTH -1)
			w_ptr <= 'd0;
		else if(wr_en && !wfull)
			w_ptr <= w_ptr + 1;
		if(rd_en && !rempty && r_ptr == DEPTH -1)	
			r_ptr <= 'd0;
		else if(rd_en && !rempty)
			r_ptr <= r_ptr + 1;
	end
end

always@(posedge clk or negedge rst_n) begin
	if(rst_n && wr_en && !wfull)
		mem[w_ptr] <= din;
end


always@(posedge clk or negedge rst_n) begin
	if(~rst_n)
		dout <= 'd0;
	if(rd_en && !rempty)
		dout <= mem[r_ptr];
end

always @(posedge clk or negedge rst_n) begin
	if(~rst_n)
		fifo_cnt <= 'd0;
	else if(wr_en && !wfull && rd_en && !rempty)
		fifo_cnt <= fifo_cnt;
	else if(wr_en && !wfull)
		fifo_cnt <= fifo_cnt+1;
	else if(rd_en && !rempty)
		fifo_cnt <= fifo_cnt -1;
end

end
endgenerate

assign wfull = fifo_cnt == DEPTH;
assign rempty = fifo_cnt == 0;
	



endmodule