`timescale 1ns/1ps
module sync_fifo_sp_tb;

  // Parameters matching DUT for 32-bit write, 8-bit read
  parameter W_WIDTH = 32;
  parameter R_WIDTH = 8;
  parameter DEPTH   = 16;
  localparam SP_CNT     = W_WIDTH / R_WIDTH;
  localparam NUM_WORDS  = 8;
  localparam TOTAL_BYTES = NUM_WORDS * SP_CNT;

  // Testbench signals
  reg                  clk;
  reg                  rst_n;
  reg                  wr_en;
  reg                  rd_en;
  reg [W_WIDTH-1:0]    din;
  wire [R_WIDTH-1:0]   dout;
  wire                 wfull;
  wire                 rempty;
  wire [$clog2(DEPTH):0] fifo_cnt;

  // Expected data model
  reg [R_WIDTH-1:0] exp_mem [0:TOTAL_BYTES-1];
  integer exp_wr_index;
  integer exp_rd_index;
  integer i, b;

  // For one-cycle latency handling
  reg rd_en_d;
  reg [R_WIDTH-1:0] exp_expect;

  // Instantiate DUT
  sync_fifo_sp #(
    .W_WIDTH(W_WIDTH),
    .R_WIDTH(R_WIDTH),
    .DEPTH(DEPTH)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(wr_en),
    .din(din),
    .rd_en(rd_en),
    .dout(dout),
    .wfull(wfull),
    .rempty(rempty),
    .fifo_cnt(fifo_cnt)
  );

  // Clock generation: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  // Initialize and reset
  initial begin
    rst_n        = 0;
    wr_en        = 0;
    rd_en        = 0;
    din          = 0;
    exp_wr_index = 0;
    exp_rd_index = 0;
    rd_en_d      = 0;
    exp_expect   = 0;
    #20;
    rst_n = 1;
  end

  // Write sequence: NUM_WORDS writes
  initial begin
    @(posedge rst_n);
    for (i = 0; i < NUM_WORDS; i = i + 1) begin
      @(posedge clk);
      if (!wfull) begin
        wr_en = 1;
        din   = $random;
      end else begin
        wr_en = 0;
      end
    end
    @(posedge clk);
    wr_en = 0;
    din   = 0;
  end

  // Read sequence: assert rd_en until all bytes read
  initial begin
    @(posedge rst_n);
    // wait writes to complete
    repeat (NUM_WORDS + 2) @(posedge clk);

    // Start continuous read
    rd_en = 1;
    while (exp_rd_index < TOTAL_BYTES) begin
      @(posedge clk);
    end
    // one extra cycle to capture last dout
    @(posedge clk);
    rd_en = 0;

  end

  // Model and check behavior with one-cycle read latency
  always @(posedge clk) begin
    // Delay rd_en
    rd_en_d <= rd_en;

    // On write, decompose din into bytes
    if (wr_en && !wfull) begin
      for (b = 0; b < SP_CNT; b = b + 1) begin
        exp_mem[exp_wr_index*SP_CNT + b] = din[b*R_WIDTH +: R_WIDTH];
      end
      exp_wr_index = exp_wr_index + 1;
    end

    // On read assertion, fetch expected byte
    if (rd_en && !rempty) begin
      exp_expect = exp_mem[exp_rd_index];
      exp_rd_index = exp_rd_index + 1;
    end

    // One cycle later, compare dout against expected
    if (rd_en_d) begin
      if (dout !== exp_expect) begin
        $error("%0t: Mismatch! dout = %h, expected = %h", $time, dout, exp_expect);
      end
    end
  end

  // Monitor
  initial $display("Time  clk wr_en din       rd_en dout    cnt");
  always @(posedge clk) begin
    $display("%0t  %b   %b   %h  %b   %h   %0d", $time, clk, wr_en, din, rd_en, dout, fifo_cnt);
  end

endmodule