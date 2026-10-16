`timescale 1ns/1ps

module ei_pe #(
  parameter int LATENCY_MUL   = 4,
  parameter int LAT_TREE      = 16,
  parameter int LAT_TOTAL     = 29,
  parameter int WIDTH         = 16,
  parameter int DEPTH         = 8,

  parameter int ACC_LAT       = 5,
  parameter int ACC_CW        = 3,
  parameter int RES_VALID_LAT = 4
)(
  input  logic        sys_clk,
  input  logic        rst,
  input  logic        en,

  input  logic        valid_in,
  output logic        ready_in,

  input  logic        residual_en,

  input  logic [1:0]  pool_mode,
  input  logic [15:0] const_pool,
  input  logic [1:0]  act_mode,

  input  logic [15:0] bias,

  input  logic [15:0] x0,x1,x2,x3,x4,x5,x6,x7,x8,
  input  logic [15:0] w0,w1,w2,w3,w4,w5,w6,w7,w8,

  input  logic        acc_clear,
  input  logic        final_input_channel,
  
  input  logic        ctrl_rnn_cross_mul, // 0 = Chạy chuẩn, 1 = Bật Nhân chéo
  input  logic [15:0] cross_a0, cross_a1, cross_a2, cross_a3, cross_a4, cross_a5, cross_a6, cross_a7, cross_a8,
  input  logic [15:0] cross_b0, cross_b1, cross_b2, cross_b3, cross_b4, cross_b5, cross_b6, cross_b7, cross_b8,       

  output logic [15:0] sum_out,
  output logic        valid_out,
  output logic        final_input_channel_valid_out,
  output logic [15:0] pe_sum_out,

  output logic [15:0] residual_out0, residual_out1, residual_out2,
  output logic [15:0] residual_out3, residual_out4, residual_out5,
  output logic [15:0] residual_out6, residual_out7, residual_out8,
  output logic        residual_valid_out,
  output              test_signal,
  
  // Ngõ ra nhánh FC
  output logic [15:0] fc_out0, fc_out1, fc_out2,
  output logic [15:0] fc_out3, fc_out4, fc_out5,
  output logic [15:0] fc_out6, fc_out7, fc_out8,
  output logic        fc_valid_out,
  
  // Multiplier
  output logic [15:0] fc_mult_out0, fc_mult_out1, fc_mult_out2,
  output logic [15:0] fc_mult_out3, fc_mult_out4, fc_mult_out5,
  output logic [15:0] fc_mult_out6, fc_mult_out7, fc_mult_out8
);

  localparam logic [1:0] PE_MODE_CONV = 2'b00;
  localparam logic [1:0] ACT_LINEAR   = 2'b00;

  // ==========================================
  // KHAI BÁO SỚM CÁC TÍN HIỆU LOOPBACK (Tránh lỗi Implicit Wire 1-bit)
  // ==========================================
  logic [15:0] act_sum_out; 
  wire  [15:0] fc_piso_data_out;
  wire         fc_piso_valid_out_export;

  // -----------------------------
  // 1) Launch routing
  // -----------------------------
  wire launch_fire      = valid_in && ready_in;
  wire conv_launch_fire = launch_fire; 
  wire res_launch_fire  = launch_fire;

  // -----------------------------
  // 1b) Robust Tag FIFO cho MUXPOOL
  // -----------------------------
  logic [63:0] mux_tag_fifo_final;
  logic [63:0] mux_tag_fifo_clear;
  logic [5:0]  mux_tag_wr_ptr;
  logic [5:0]  mux_tag_rd_ptr;

  logic        pe_valid_out_conv;

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      mux_tag_wr_ptr     <= '0;
      mux_tag_rd_ptr     <= '0;
      mux_tag_fifo_final <= '0;
      mux_tag_fifo_clear <= '0;
    end else if (en) begin
      if (conv_launch_fire) begin
        mux_tag_fifo_final[mux_tag_wr_ptr] <= final_input_channel;
        mux_tag_fifo_clear[mux_tag_wr_ptr] <= acc_clear;
        mux_tag_wr_ptr <= mux_tag_wr_ptr + 1'b1;
      end
      if (pe_valid_out_conv) begin
        mux_tag_rd_ptr <= mux_tag_rd_ptr + 1'b1;
      end
    end
  end

  wire pe_final_input_channel = mux_tag_fifo_final[mux_tag_rd_ptr];
  wire pe_acc_clear           = mux_tag_fifo_clear[mux_tag_rd_ptr]; 
  assign test_signal = final_input_channel;
  
  logic [15:0] muxed_x0, muxed_x1, muxed_x2, muxed_x3, muxed_x4, muxed_x5, muxed_x6, muxed_x7, muxed_x8;
  logic [15:0] muxed_w0, muxed_w1, muxed_w2, muxed_w3, muxed_w4, muxed_w5, muxed_w6, muxed_w7, muxed_w8;

  // MUX cho ngõ A (Data)
  ei_muxN #(.WIDTH(16)) m_x0 (.d0(x0), .d1(cross_a0), .s(ctrl_rnn_cross_mul), .y(muxed_x0));
  ei_muxN #(.WIDTH(16)) m_x1 (.d0(x1), .d1(cross_a1), .s(ctrl_rnn_cross_mul), .y(muxed_x1));
  ei_muxN #(.WIDTH(16)) m_x2 (.d0(x2), .d1(cross_a2), .s(ctrl_rnn_cross_mul), .y(muxed_x2));
  ei_muxN #(.WIDTH(16)) m_x3 (.d0(x3), .d1(cross_a3), .s(ctrl_rnn_cross_mul), .y(muxed_x3));
  ei_muxN #(.WIDTH(16)) m_x4 (.d0(x4), .d1(cross_a4), .s(ctrl_rnn_cross_mul), .y(muxed_x4));
  ei_muxN #(.WIDTH(16)) m_x5 (.d0(x5), .d1(cross_a5), .s(ctrl_rnn_cross_mul), .y(muxed_x5));
  ei_muxN #(.WIDTH(16)) m_x6 (.d0(x6), .d1(cross_a6), .s(ctrl_rnn_cross_mul), .y(muxed_x6));
  ei_muxN #(.WIDTH(16)) m_x7 (.d0(x7), .d1(cross_a7), .s(ctrl_rnn_cross_mul), .y(muxed_x7));
  ei_muxN #(.WIDTH(16)) m_x8 (.d0(x8), .d1(cross_a8), .s(ctrl_rnn_cross_mul), .y(muxed_x8));

  // MUX cho ngõ B (Weight)
  ei_muxN #(.WIDTH(16)) m_w0 (.d0(w0), .d1(cross_b0), .s(ctrl_rnn_cross_mul), .y(muxed_w0));
  ei_muxN #(.WIDTH(16)) m_w1 (.d0(w1), .d1(cross_b1), .s(ctrl_rnn_cross_mul), .y(muxed_w1));
  ei_muxN #(.WIDTH(16)) m_w2 (.d0(w2), .d1(cross_b2), .s(ctrl_rnn_cross_mul), .y(muxed_w2));
  ei_muxN #(.WIDTH(16)) m_w3 (.d0(w3), .d1(cross_b3), .s(ctrl_rnn_cross_mul), .y(muxed_w3));
  ei_muxN #(.WIDTH(16)) m_w4 (.d0(w4), .d1(cross_b4), .s(ctrl_rnn_cross_mul), .y(muxed_w4));
  ei_muxN #(.WIDTH(16)) m_w5 (.d0(w5), .d1(cross_b5), .s(ctrl_rnn_cross_mul), .y(muxed_w5));
  ei_muxN #(.WIDTH(16)) m_w6 (.d0(w6), .d1(cross_b6), .s(ctrl_rnn_cross_mul), .y(muxed_w6));
  ei_muxN #(.WIDTH(16)) m_w7 (.d0(w7), .d1(cross_b7), .s(ctrl_rnn_cross_mul), .y(muxed_w7));
  ei_muxN #(.WIDTH(16)) m_w8 (.d0(w8), .d1(cross_b8), .s(ctrl_rnn_cross_mul), .y(muxed_w8));
  // -----------------------------
  // 2) Normal PE mux/pool path
  // -----------------------------
  logic [15:0] pe_sum_out_conv;
  
  logic [15:0] fc_mult_raw0, fc_mult_raw1, fc_mult_raw2;
  logic [15:0] fc_mult_raw3, fc_mult_raw4, fc_mult_raw5;
  logic [15:0] fc_mult_raw6, fc_mult_raw7, fc_mult_raw8;

  ei_pe_muxpool #(
    .LATENCY_MUL(LATENCY_MUL),
    .LAT_TREE   (LAT_TREE),
    .LAT_TOTAL  (20)
  ) u_pe_muxpool (
    .sys_clk   (sys_clk),
    .rst       (rst),
    .en        (en),
    .valid_in  (conv_launch_fire),

    .pool_mode (pool_mode),
    .const_pool(const_pool),

    .x0(muxed_x0),.x1(muxed_x1),.x2(muxed_x2),.x3(muxed_x3),.x4(muxed_x4),.x5(muxed_x5),.x6(muxed_x6),.x7(muxed_x7),.x8(muxed_x8),
    .w0(muxed_w0),.w1(muxed_w1),.w2(muxed_w2),.w3(muxed_w3),.w4(muxed_w4),.w5(muxed_w5),.w6(muxed_w6),.w7(muxed_w7),.w8(muxed_w8),

    .pool0(muxed_x0),.pool1(muxed_x1),.pool2(muxed_x2),
    .pool3(muxed_x3),.pool4(muxed_x4),.pool5(muxed_x5),
    .pool6(muxed_x6),.pool7(muxed_x7),.pool8(muxed_x8),

    .data_out  (pe_sum_out_conv),
    .valid_out (pe_valid_out_conv),
    
    .fc_mult_out0(fc_mult_raw0), .fc_mult_out1(fc_mult_raw1), .fc_mult_out2(fc_mult_raw2),
    .fc_mult_out3(fc_mult_raw3), .fc_mult_out4(fc_mult_raw4), .fc_mult_out5(fc_mult_raw5),
    .fc_mult_out6(fc_mult_raw6), .fc_mult_out7(fc_mult_raw7), .fc_mult_out8(fc_mult_raw8)
  );

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      pe_sum_out <= 16'h0000;
    end else if (en) begin
      pe_sum_out <= pe_sum_out_conv;
    end
  end

  // -----------------------------
  // 2.5) PISO FC/1x1 architecture
  // -----------------------------
  logic [LATENCY_MUL:0] fc_valid_pipe;
  logic [LATENCY_MUL:0] fc_clear_pipe;
  logic [LATENCY_MUL:0] fc_final_pipe;
  
  always_ff @(posedge sys_clk) begin
    if(rst) begin
        fc_valid_pipe <= '0;
        fc_clear_pipe <= '0;
        fc_final_pipe <= '0;
    end
    else if(en) begin
        fc_valid_pipe <= {fc_valid_pipe[LATENCY_MUL-1:0], conv_launch_fire && (pool_mode == 2'b01)};
        fc_clear_pipe <= {fc_clear_pipe[LATENCY_MUL-1:0], conv_launch_fire && (pool_mode == 2'b01) && acc_clear};
        fc_final_pipe <= {fc_final_pipe[LATENCY_MUL-1:0], conv_launch_fire && (pool_mode == 2'b01) && final_input_channel};
    end
  end
  
  wire fc_mac_valid   = fc_valid_pipe[LATENCY_MUL - 1];
  wire fc_final_valid = fc_final_pipe[LATENCY_MUL - 1];
  wire fc_clear_valid = fc_clear_pipe[LATENCY_MUL - 1];
  
  wire [143:0] fc_product_bus;
  assign fc_product_bus = {
      fc_mult_raw8, fc_mult_raw7, fc_mult_raw6, 
      fc_mult_raw5, fc_mult_raw4, fc_mult_raw3, 
      fc_mult_raw2, fc_mult_raw1, fc_mult_raw0
  };
  
  wire [8:0]   fc_result_valid_bus;
  wire [143:0] fc_result_data_bus;
  
  ei_acc9_activation_piso #(
      .ADDER_LATENCY  (5)
  ) u_fc_acc_system (
      .sys_clk        (sys_clk),
      .rst            (rst),
      .en             (en),
      .act_mode       (act_mode),
      .acc_clear      ({9{fc_clear_valid}}), 
      .final_ic_in    ({9{fc_final_valid}}),
      .bias_in        ({9{bias}}), // <--- Đã sửa chỗ này thành {9{bias}}
      
      .sample_valid   ({9{fc_mac_valid}}),
      .sample_ready   (),                    
      .product_in     (fc_product_bus),
      .buffer_overflow(),
      
      .result_valid   (fc_result_valid_bus),
      .result_ready   ({9{1'b1}}),            
      .result_data    (fc_result_data_bus),

      .piso_data_out         (fc_piso_data_out),
      .piso_valid_out_export (fc_piso_valid_out_export),
      .activated_data_in     (act_sum_out) 
  );
  
  assign fc_out0 = fc_result_data_bus[15:0];
  assign fc_out1 = fc_result_data_bus[31:16];
  assign fc_out2 = fc_result_data_bus[47:32];
  assign fc_out3 = fc_result_data_bus[63:48];
  assign fc_out4 = fc_result_data_bus[79:64];
  assign fc_out5 = fc_result_data_bus[95:80];
  assign fc_out6 = fc_result_data_bus[111:96];
  assign fc_out7 = fc_result_data_bus[127:112];
  assign fc_out8 = fc_result_data_bus[143:128];
  
  assign fc_mult_out0 = fc_mult_raw0;
  assign fc_mult_out1 = fc_mult_raw1;
  assign fc_mult_out2 = fc_mult_raw2;
  assign fc_mult_out3 = fc_mult_raw3;
  assign fc_mult_out4 = fc_mult_raw4;
  assign fc_mult_out5 = fc_mult_raw5;
  assign fc_mult_out6 = fc_mult_raw6;
  assign fc_mult_out7 = fc_mult_raw7;
  assign fc_mult_out8 = fc_mult_raw8;
  
  assign fc_valid_out = fc_result_valid_bus[0];

  // -----------------------------
  // 3) Residual connector
  // -----------------------------
  logic [15:0] res_s0, res_s1, res_s2, res_s3, res_s4, res_s5, res_s6, res_s7, res_s8;
  logic        res_core_valid_out;
  logic        res_pending;

  ei_residual_connector #(
    .VALID_LAT(RES_VALID_LAT)
  ) u_residual (
    .sys_clk  (sys_clk),
    .rst      (rst),
    .en       (en),
    .valid_in (res_launch_fire),
    .valid_out(res_core_valid_out),

    .a0(x0), .a1(x1), .a2(x2), .a3(x3), .a4(x4), .a5(x5), .a6(x6), .a7(x7), .a8(x8),
    .b0(w0), .b1(w1), .b2(w2), .b3(w3), .b4(w4), .b5(w5), .b6(w6), .b7(w7), .b8(w8),
    .s0(res_s0), .s1(res_s1), .s2(res_s2), .s3(res_s3), .s4(res_s4), .s5(res_s5), .s6(res_s6), .s7(res_s7), .s8(res_s8)
  );

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      res_pending         <= 1'b0;
      residual_valid_out  <= 1'b0;
      residual_out0 <= '0; residual_out1 <= '0; residual_out2 <= '0;
      residual_out3 <= '0; residual_out4 <= '0; residual_out5 <= '0;
      residual_out6 <= '0; residual_out7 <= '0; residual_out8 <= '0;
    end else if (en) begin
      residual_valid_out <= 1'b0;
      if (res_launch_fire) res_pending <= 1'b1;

      if (res_core_valid_out) begin
        residual_out0 <= res_s0; residual_out1 <= res_s1; residual_out2 <= res_s2;
        residual_out3 <= res_s3; residual_out4 <= res_s4; residual_out5 <= res_s5;
        residual_out6 <= res_s6; residual_out7 <= res_s7; residual_out8 <= res_s8;
        residual_valid_out <= 1'b1;
        res_pending        <= 1'b0;
      end
    end
  end

  // -----------------------------
  // 4) Shift buffer
  // -----------------------------
  wire [WIDTH+1:0] sb_in_data  = {pe_acc_clear, pe_final_input_channel, pe_sum_out_conv};
  wire             sb_in_valid = pe_valid_out_conv;
  wire             sb_in_ready;
  wire [WIDTH+1:0] sb_out_data;
  wire             sb_out_valid;
  wire             sb_out_ready;

  ei_shift_buffer #(.WIDTH(WIDTH+2), .DEPTH(DEPTH)) u_buf (
    .clk       (sys_clk),
    .rst       (rst),
    .en        (en),
    .in_data   (sb_in_data),
    .in_valid  (sb_in_valid),
    .in_ready  (sb_in_ready),
    .out_data  (sb_out_data),
    .out_valid (sb_out_valid),
    .out_ready (sb_out_ready)
  );

  // -----------------------------
  // 5) Holding reg
  // -----------------------------
  logic [15:0] mid_data;
  logic        mid_valid;
  logic        mid_final_input_channel;
  logic        mid_acc_clear;

  wire acc_ready_in;
  wire acc_fire = en && mid_valid && acc_ready_in;

  assign sb_out_ready = en && (!mid_valid || acc_fire);
  wire sb_pop = en && sb_out_valid && sb_out_ready;

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      mid_valid               <= 1'b0;
      mid_data                <= 16'b0;
      mid_final_input_channel <= 1'b0;
      mid_acc_clear           <= 1'b0;
    end else if (en) begin
      case ({sb_pop, acc_fire})
        2'b10, 2'b11: begin 
          mid_data                <= sb_out_data[WIDTH-1:0];
          mid_final_input_channel <= sb_out_data[WIDTH];
          mid_acc_clear           <= sb_out_data[WIDTH+1];
          mid_valid               <= 1'b1;
        end
        2'b01: begin
          mid_valid <= 1'b0;
        end
        default: ;
      endcase
    end
  end

  // -----------------------------
  // 6) Accumulator 
  // -----------------------------
  logic [15:0] acc_sum_out;
  logic        acc_valid_out;

  ei_accumulator_fp16 #(.LAT(ACC_LAT), .CW(ACC_CW)) u_acc (
    .sys_clk   (sys_clk),
    .rst       (rst),
    .en        (en),
    .a_in      (mid_data),
    .valid_in  (mid_valid),
    .bias      (bias),
    .acc_clear (mid_acc_clear), 
    .sum_out   (acc_sum_out),
    .valid_out (acc_valid_out),
    .ready_in  (acc_ready_in)
  );

  logic [31:0] acc_tag_fifo;
  logic [4:0]  acc_tag_wr_ptr;
  logic [4:0]  acc_tag_rd_ptr;

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      acc_tag_wr_ptr <= '0;
      acc_tag_rd_ptr <= '0;
      acc_tag_fifo   <= '0;
    end else if (en) begin
      if (acc_fire) begin
        acc_tag_fifo[acc_tag_wr_ptr] <= mid_final_input_channel;
        acc_tag_wr_ptr <= acc_tag_wr_ptr + 1'b1;
      end
      if (acc_valid_out) begin
        acc_tag_rd_ptr <= acc_tag_rd_ptr + 1'b1;
      end
    end
  end

  wire acc_final_input_channel_synced = acc_tag_fifo[acc_tag_rd_ptr];

  // -----------------------------
  // 7) Activation Dùng Chung (PIPELINED)
  // -----------------------------
  logic [1:0]  act_mode_eff_raw;
  logic [15:0] shared_act_in_raw;
  
  logic [1:0]  act_mode_eff_reg;
  logic [15:0] shared_act_in_reg;

  wire is_fc_mode = (pool_mode == 2'b01);

  always_comb begin
    shared_act_in_raw = is_fc_mode ? fc_piso_data_out : acc_sum_out;

    if (residual_en || pool_mode == 2'b10 || pool_mode == 2'b11)
      act_mode_eff_raw = 2'b00; // ACT_LINEAR
    else
      act_mode_eff_raw = act_mode;
  end

  always_ff @(posedge sys_clk) begin
      if (en) begin
          shared_act_in_reg <= shared_act_in_raw;
          act_mode_eff_reg  <= act_mode_eff_raw;
      end
  end

  logic [15:0] act_lut_out;
  
  (* dont_touch = "true" *)
  ei_activation_selector u_activation (
    .sys_clk (sys_clk),
    .rst     (rst),
    .en      (en),
    .mode    (act_mode_eff_reg),
    .data_in (shared_act_in_reg),
    .data_out(act_lut_out)
  );

  assign act_sum_out = (act_mode_eff_reg == 2'b00) ? shared_act_in_reg : act_lut_out;

  // Đồng bộ Valid
  logic shared_valid_raw;
  logic shared_valid_reg;
  logic valid_out_d;
  logic final_input_channel_valid_out_d;
  
  assign shared_valid_raw = is_fc_mode ? fc_piso_valid_out_export : acc_valid_out;

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      shared_valid_reg                <= 1'b0;
      valid_out_d                     <= 1'b0;
      valid_out                       <= 1'b0;
      final_input_channel_valid_out_d <= 1'b0;
      final_input_channel_valid_out   <= 1'b0;
    end else if (en) begin
      shared_valid_reg <= shared_valid_raw;
      
      valid_out_d      <= shared_valid_reg;
      valid_out        <= valid_out_d;

      final_input_channel_valid_out_d <= shared_valid_reg && acc_final_input_channel_synced;
      final_input_channel_valid_out   <= final_input_channel_valid_out_d;
    end
  end

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      sum_out <= 16'h0000;
    end else if (en) begin
      sum_out <= act_sum_out; 
    end
  end

  // -----------------------------
  // 8) Credit control
  // -----------------------------
  localparam int LVW = (DEPTH <= 1) ? 1 : $clog2(DEPTH+1);
  logic [LVW-1:0] buf_level;
  logic [LVW-1:0] pending_cnt;

  wire push = en && sb_in_valid && sb_in_ready;
  wire pop  = en && sb_out_valid && sb_out_ready;
  logic ready_next;
  wire conv_ready_raw = (buf_level + pending_cnt < DEPTH);

  always_comb begin
   if (residual_en)
     ready_next = !res_pending;
   else
     ready_next = conv_ready_raw;
  end

  always_ff @(posedge sys_clk) begin
    if (rst) ready_in <= 1'b0;
    else if (en) ready_in <= ready_next;
  end

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      buf_level   <= '0;
      pending_cnt <= '0;
    end else if (en) begin
      case ({push, pop})
        2'b10: if (buf_level < DEPTH[LVW-1:0]) buf_level <= buf_level + 1'b1;
        2'b01: if (buf_level != 0)             buf_level <= buf_level - 1'b1;
        default: ;
      endcase

      case ({conv_launch_fire, push})
        2'b10: pending_cnt <= pending_cnt + 1'b1;
        2'b01: pending_cnt <= pending_cnt - 1'b1;
        default: ;
      endcase
    end
  end

endmodule