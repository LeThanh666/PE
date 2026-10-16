`timescale 1ns/1ps

module ei_acc9_activation_piso #(
    parameter int ADDER_LATENCY = 5
)(
    input  logic         sys_clk,
    input  logic         rst,
    input  logic         en,
    input  logic [1:0]   act_mode,
    
    input  logic [8:0]   acc_clear,
    input  logic [8:0]   final_ic_in, // Báo hiệu kênh cuối
    input  logic [143:0] bias_in,
    
    input  logic [8:0]   sample_valid,
    output logic [8:0]   sample_ready,
    input  logic [143:0] product_in,
    
    output logic         buffer_overflow, 
    
    output logic [8:0]   result_valid,
    input  logic [8:0]   result_ready,
    output logic [143:0] result_data,
    
    output logic [15:0] piso_data_out,
    output logic        piso_valid_out_export,
    input  logic [15:0] activated_data_in
);

    // ==========================================
    // 1. TẦNG ACCUMULATOR
    // ==========================================
    logic [15:0] acc_sums [0:8];
    logic [8:0]  acc_valids;

    genvar i;
    generate
        for (i = 0; i < 9; i++) begin : gen_acc
            ei_accumulator_fp16 #(
                .LAT(ADDER_LATENCY), 
                .CW(3)
            ) u_acc (
                .sys_clk   (sys_clk),
                .rst       (rst),
                .en        (en),
                .acc_clear (acc_clear[i]),
                .bias      (bias_in[i*16 +: 16]),
                .a_in      (product_in[i*16 +: 16]),
                .valid_in  (sample_valid[i]),
                .sum_out   (acc_sums[i]),
                .valid_out (acc_valids[i]),
                .ready_in  ()
            );
        end
    endgenerate

    assign sample_ready = {9{1'b1}};
    assign buffer_overflow = 1'b0;

    // ==========================================
    // 2. DELAY PIPELINE CHO CỜ FINAL
    // ==========================================
    logic [ADDER_LATENCY:0] final_ic_pipe;
    always_ff @(posedge sys_clk) begin
        if (rst) final_ic_pipe <= '0;
        else if (en) final_ic_pipe <= {final_ic_pipe[ADDER_LATENCY-1:0], final_ic_in[0]};
    end
    
    
    wire is_final_result = final_ic_pipe[ADDER_LATENCY-1]; 

    // ==========================================
    // 3. TẦNG PISO (CHỐNG LỖI ĐÈ DATA)
    // ==========================================
    logic [15:0] piso_reg [0:8];
    logic [3:0]  shift_cnt;
    logic        piso_valid_out;

    always_ff @(posedge sys_clk) begin
        if (rst) begin
            shift_cnt      <= 4'd0;
            piso_valid_out <= 1'b0;
            for (int j=0; j<9; j++) piso_reg[j] <= 16'd0;
        end 
        else if (en) begin
            // CHỈ lấy kết quả vứt vào PISO khi cờ Final báo hiệu kênh cuối cùng
            if (acc_valids[0] && is_final_result) begin
                for (int j=0; j<9; j++) begin
                    piso_reg[j] <= acc_sums[j];
                end
                shift_cnt      <= 4'd8; // Dịch 8 bước = 9 nhịp xả data
                piso_valid_out <= 1'b1;
            end 
            else if (shift_cnt > 0) begin
                for (int j=0; j<8; j++) begin
                    piso_reg[j] <= piso_reg[j+1];
                end
                piso_reg[8]    <= 16'd0;
                shift_cnt      <= shift_cnt - 1'b1;
                piso_valid_out <= 1'b1;
            end 
            else begin
                piso_valid_out <= 1'b0;
            end
        end
    end
    // ==========================================
    // 4. TẦNG ACTIVATION (CỜ VALID ĐỘNG TÙY MODE)
    // ==========================================
    assign piso_data_out = piso_reg[0];
    assign piso_valid_out_export = piso_valid_out;

    logic act_valid_reg_d1;
    logic act_valid_reg_d2;
    
    always_ff @(posedge sys_clk) begin
        if (rst) begin
            act_valid_reg_d1 <= 1'b0;
            act_valid_reg_d2 <= 1'b0;
        end else if (en) begin
            act_valid_reg_d1 <= piso_valid_out;     // Trễ 1 nhịp (Khớp với nhánh Linear)
            act_valid_reg_d2 <= act_valid_reg_d1;   // Trễ 2 nhịp (Khớp với nhánh LUT/Tanh)
        end
    end

    // Dựa vào act_mode được truyền từ ei_pe.sv vào, MUX này sẽ tự động chọn đúng độ trễ
    wire valid_for_sipo = (act_mode == 2'b00) ? act_valid_reg_d1 : act_valid_reg_d2;
    // ==========================================
    // 5. TẦNG SIPO (GOM DATA TỪ MUX CHUNG)
    // ==========================================
    logic [15:0] sipo_reg [0:8];
    logic [3:0]  sipo_cnt;
    logic        final_valid;

    always_ff @(posedge sys_clk) begin
        if (rst) begin
            sipo_cnt    <= 4'd0;
            final_valid <= 1'b0;
            for (int j=0; j<9; j++) sipo_reg[j] <= 16'd0;
        end 
        else if (en) begin
            final_valid <= 1'b0;
            
            // SIPO bắt tín hiệu chính xác tuyệt đối nhờ cờ Valid Động
            if (valid_for_sipo) begin
                sipo_reg[sipo_cnt] <= activated_data_in; 
                
                if (sipo_cnt == 4'd8) begin
                    sipo_cnt    <= 4'd0;
                    final_valid <= 1'b1; 
                end else begin
                    sipo_cnt    <= sipo_cnt + 1'b1;
                end
            end
        end
    end

    assign result_valid = {9{final_valid}};

    // Gắn kết quả SIPO ra result_data
    assign result_data = {
        sipo_reg[8], sipo_reg[7], sipo_reg[6],
        sipo_reg[5], sipo_reg[4], sipo_reg[3],
        sipo_reg[2], sipo_reg[1], sipo_reg[0]
    };
    

endmodule