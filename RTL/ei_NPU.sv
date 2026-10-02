`timescale 1ns / 1ps

module ei_NPU#(
    parameter NUM_PE = 16
)(
    input  logic sys_clk,
    input  logic rst,

    // ==========================================
    // 1. CPU / System Control Interface (MMIO Bus)
    // ==========================================
    input  logic        bus_write_en,
    input  logic [31:0] bus_addr,
    input  logic [31:0] bus_write_data,
    output logic        done,

    // ==========================================
    // 2. Memory Interface: Feature Map (Read)
    // ==========================================
    output logic        fm_mem_read_en,
    output logic [31:0] fm_mem_addr,
    input  logic [255:0] fm_mem_read_data, // Đọc 1 lần 16 phần tử 16-bit = 256 bits
    input  logic        fm_mem_valid,      

    // ==========================================
    // 3. Memory Interface: Weights & Bias (Read)
    // ==========================================
    output logic        w_mem_read_en,
    output logic [31:0] w_mem_addr,
    input  logic [159:0] w_mem_read_data,
    input  logic        w_mem_valid,       

    // ==========================================
    // 4. Memory Interface: Output Feature Map (Write)
    // ==========================================
    output logic [31:0] out_mem_write_en,
    output logic [31:0] out_mem_write_addr, 
    output logic [255:0] out_mem_write_data  
);

    // =========================================================================
    // KHAI BÁO DÂY KẾT NỐI NỘI BỘ (INTERNAL WIRES)
    // =========================================================================
    
    // Dây tín hiệu từ CSR Block
    logic npu_start_wire;
    logic is_pooling_op_wire;
    logic is_residual_op_wire; 
    logic [1:0]  csr_pool_mode_wire;
    logic [1:0]  csr_act_mode_wire;
    logic [15:0] reg_max_x_wire, reg_max_y_wire, reg_max_c_wire, reg_max_k_wire;

    // Dây từ Controller -> Các khối khác
    logic [NUM_PE-1:0] valid_in_wire;
    logic [NUM_PE-1:0] acc_clear_wire;
    logic [NUM_PE-1:0] final_ic_wire;
    logic feed_done;
    logic writeback_done;
    
    // Dây cấu hình động cấp cho PE Array
    logic [1:0]  pool_mode_wire [0:NUM_PE-1];
    logic [15:0] const_pool_wire [0:NUM_PE-1];
    logic [1:0]  act_mode_wire [0:NUM_PE-1];
    logic [0:NUM_PE-1]  ready_all_wire;

    // Dây Datapath
    logic [15:0] x_to_pe [0:NUM_PE-1][0:8];
    logic [15:0] w_to_pe [0:NUM_PE-1][0:8];
    logic [15:0] b_to_pe [0:NUM_PE-1];
    logic [15:0]       pe_sum_wire [0:NUM_PE-1];
    logic [NUM_PE-1:0] conv_valid_out_wire;
    logic [NUM_PE-1:0] pool_valid_out_wire;
    logic [NUM_PE-1:0] pe_valid_out_wire;
    logic [15:0]       pe_conv_out [0:NUM_PE-1];
    logic [15:0]       pe_pool_out [0:NUM_PE-1];

    // Dây chứa Window Data (3x3) từ Controller mới xuất ra
    logic [15:0] pe_fm_data_wire [0:NUM_PE-1][0:2][0:2];

    // Dây kết nối Residual Data từ PE Array
    logic [15:0]       pe_res_out_array [0:NUM_PE-1][0:8];
    logic [NUM_PE-1:0] pe_res_valid_array;

    // Dây phụ trợ cắt bus dữ liệu Weight
    logic [15:0] parsed_weight [0:8];
    
    genvar i;
    generate
        for (i = 0; i < 9; i++) begin : PARSE_WEIGHTS
            assign parsed_weight[i] = w_mem_read_data[i*16 +: 16];
        end
    endgenerate

    // =========================================================================
    // KHỞI TẠO CÁC MODULE CON (INSTANTIATIONS)
    // =========================================================================

    // ---------------------------------------------------------
    // 0. Control & Status Register (CSR Block)
    // ---------------------------------------------------------
    npu_csr_block u_csr (
        .sys_clk       (sys_clk),
        .sys_rst       (rst),
        
        .bus_write_en  (bus_write_en),
        .bus_addr      (bus_addr),
        .bus_write_data(bus_write_data),
        
        .npu_start     (npu_start_wire),
        .pool_mode     (csr_pool_mode_wire),
        .act_mode      (csr_act_mode_wire),
        .is_pooling_op (is_pooling_op_wire),
        .is_residual_op(is_residual_op_wire), 
        
        .reg_max_x     (reg_max_x_wire),
        .reg_max_y     (reg_max_y_wire),
        .reg_max_c     (reg_max_c_wire),
        .reg_max_k     (reg_max_k_wire),
        
        .npu_done      (done)
    );

    // ---------------------------------------------------------
    // 1. Controller (Bộ Não - Tích hợp Data Router mới)
    // ---------------------------------------------------------
    ei_pe_controller #(
        .NUM_PE(NUM_PE) 
    ) u_controller (
        .sys_clk             (sys_clk),
        .rst                 (rst),
        
        // Tín hiệu từ CSR
        .start               (npu_start_wire),
        .reg_max_x           (reg_max_x_wire),
        .reg_max_y           (reg_max_y_wire),
        .reg_max_c           (reg_max_c_wire),
        .reg_max_k           (reg_max_k_wire),
        .csr_act_mode        (csr_act_mode_wire),
        .csr_pool_mode       (csr_pool_mode_wire),
        
        // [CẬP NHẬT: Đấu dây cờ Pure Pooling từ CSR sang Controller]
        .is_pooling_op       (is_pooling_op_wire), 
        
        .done                (feed_done),
        
        // Giao tiếp hệ thống & BRAM
        .ready_all           (ready_all_wire[0]), 
        .fm_mem_read_en      (fm_mem_read_en),
        .fm_mem_addr         (fm_mem_addr),
        .fm_bram_read_data   (fm_mem_read_data),
        .fm_data_valid       (fm_mem_valid),      
        
        .w_mem_read_en       (w_mem_read_en),
        .w_mem_addr          (w_mem_addr),
        .w_data_valid        (w_mem_valid),       
        
        // Điều khiển luồng nội bộ
        .valid_in            (valid_in_wire),
        .acc_clear           (acc_clear_wire),
        .final_input_channel (final_ic_wire),
        
        // Cấu hình xuất ra PE
        .pool_mode           (pool_mode_wire),
        .const_pool          (const_pool_wire),
        .act_mode            (act_mode_wire),
        
        // Dữ liệu cấp trực tiếp cho PE (Data Router)
        .pe_fm_data          (pe_fm_data_wire)
    );

    // ---------------------------------------------------------
    // 2. Data Muxing & Broadcast Logic
    // ---------------------------------------------------------
    always_comb begin
        for (int p = 0; p < NUM_PE; p++) begin
            // Broadcast Bias cho tất cả các PE
            b_to_pe[p] = w_mem_read_data[159:144];
            
            // Flatten mảng 3x3 Feature Map từ Router thành mảng 1D [0:8] cho PE 
            // và Broadcast Weight [0:8]
            for (int r = 0; r < 3; r++) begin
                for (int c = 0; c < 3; c++) begin
                    x_to_pe[p][r*3 + c] = pe_fm_data_wire[p][r][c];
                    w_to_pe[p][r*3 + c] = parsed_weight[r*3 + c];
                end
            end
        end
    end

    // ---------------------------------------------------------
    // 3. PE Array (Bộ Cơ Bắp - Tính toán)
    // ---------------------------------------------------------
    ei_pe_array #(
        .NUM_PE(NUM_PE)
    ) u_pe_array (
        .sys_clk             (sys_clk),
        .rst                 (rst),
        .en                  (1'b1), 
        
        .valid_in            (valid_in_wire),
        .residual_en         ({NUM_PE{is_residual_op_wire}}), 
        .pool_mode           (pool_mode_wire),
        .const_pool          (const_pool_wire),
        .act_mode            (act_mode_wire),
        .acc_clear           (acc_clear_wire),
        .final_input_channel (final_ic_wire),
        
        .bias_in             (b_to_pe),
        .x_in                (x_to_pe),
        .w_in                (w_to_pe),
        
        .sum_out             (pe_conv_out),
        .valid_out           (pool_valid_out_wire),
        
        .ready_in_per_pe     (), 
        .ready_all           (ready_all_wire[0]),
        .final_input_channel_valid_out (conv_valid_out_wire),
        .pe_sum_out          (pe_pool_out),

        .residual_out        (pe_res_out_array),
        .residual_valid_out  (pe_res_valid_array)
    );

    // ---------------------------------------------------------
    // 4. RESIDUAL SERIALIZER (Parallel 9x16 -> Serial 1x16)
    // ---------------------------------------------------------
    logic [15:0] res_shift_reg [0:NUM_PE-1][0:8];
    logic [3:0]  res_shift_cnt;
    logic        res_busy;
    
    logic [15:0] serialized_res_out [0:NUM_PE-1];
    logic        serialized_res_valid;

    always_ff @(posedge sys_clk) begin
        if (rst) begin
            res_shift_cnt <= '0;
            res_busy      <= 1'b0;
            serialized_res_valid <= 1'b0;
        end else begin
            if (pe_res_valid_array[0]) begin 
                for (int p = 0; p < NUM_PE; p++) begin
                    for (int k = 0; k < 9; k++) begin
                        res_shift_reg[p][k] <= pe_res_out_array[p][k];
                    end
                end
                res_shift_cnt <= 4'd8; 
                res_busy      <= 1'b1;
                serialized_res_valid <= 1'b1;
            end 
            else if (res_busy) begin
                for (int p = 0; p < NUM_PE; p++) begin
                    for (int k = 0; k < 8; k++) begin
                        res_shift_reg[p][k] <= res_shift_reg[p][k+1]; 
                    end
                end
                
                if (res_shift_cnt == 4'd0) begin
                    res_busy <= 1'b0;
                    serialized_res_valid <= 1'b0;
                end else begin
                    res_shift_cnt <= res_shift_cnt - 1'b1;
                end
            end
        end
    end

    always_comb begin
        for (int p = 0; p < NUM_PE; p++) begin
            serialized_res_out[p] = res_shift_reg[p][0];
        end
    end

    // ---------------------------------------------------------
    // 5. FINAL OUTPUT MUX (Chọn Data gửi xuống Write-back)
    // ---------------------------------------------------------
    always_comb begin
        for(int p = 0; p < NUM_PE; p++) begin
            if (is_residual_op_wire) begin
                pe_sum_wire[p]       = serialized_res_out[p];
                pe_valid_out_wire[p] = serialized_res_valid;
            end 
            else if (csr_pool_mode_wire[1]) begin
                pe_sum_wire[p]       = pe_pool_out[p];
                pe_valid_out_wire[p] = pool_valid_out_wire[p];
            end 
            else begin
                pe_sum_wire[p]       = pe_conv_out[p];
                pe_valid_out_wire[p] = conv_valid_out_wire[p];
            end
        end
    end

    // ---------------------------------------------------------
    // 6. Write-Back Controller (Bộ Ghi Dữ Liệu)
    // ---------------------------------------------------------
    logic [15:0] out_max_x_wire;
    logic [15:0] out_max_y_wire;

    // Nếu là Convolution (pool_mode == 00): Kích thước giữ nguyên (Để Testbench tự Crop Valid)
    // Nếu là Pooling (pool_mode == 1x): Kích thước giảm một nửa (Dịch phải 1 bit)
    assign out_max_x_wire = (csr_pool_mode_wire == 2'b00) ? reg_max_x_wire : (reg_max_x_wire >> 1);
    assign out_max_y_wire = (csr_pool_mode_wire == 2'b00) ? reg_max_y_wire : (reg_max_y_wire >> 1);

    ei_pe_write_back_controller #(
        .NUM_PE(NUM_PE)
    ) u_write_back (
        .sys_clk             (sys_clk),
        .rst                 (rst),
        .start               (npu_start_wire), 
        
        // [SỬA TẠI ĐÂY]: Cấp kích thước Output thực tế thay vì Input
        .reg_max_x           (out_max_x_wire),  
        .reg_max_y           (out_max_y_wire),  
        .reg_max_k           (reg_max_k_wire),
        
        .pe_valid_out        (pe_valid_out_wire[0]), 
        .pe_sum_out          (pe_sum_wire),
        
        .write_enable        (out_mem_write_en),
        .write_base_address  (out_mem_write_addr),
        .write_data_bus      (out_mem_write_data),
        .done                (writeback_done)
    );
    
    always_comb begin
        done = writeback_done;
    end

    always @(posedge sys_clk) begin
        if(pe_valid_out_wire[0]) 
            $display("[ei_NPU] pe_fm_data_wire: %h: %h %h %h %h %h %h %h %h %h", out_mem_write_addr, pe_fm_data_wire[0][0][0],  pe_fm_data_wire[0][0][1],  pe_fm_data_wire[0][0][2],  pe_fm_data_wire[0][1][0],  pe_fm_data_wire[0][1][1],  pe_fm_data_wire[0][1][2],  pe_fm_data_wire[0][2][0],  pe_fm_data_wire[0][2][1],  pe_fm_data_wire[0][2][2]);
    end

    always @(posedge sys_clk) begin
        if(valid_in_wire[0]) 
            $display("[ei_NPU] x_to_pe: %h %h %h %h %h %h %h %h %h", x_to_pe[0][0],  x_to_pe[0][1],  x_to_pe[0][2],  x_to_pe[0][3],  x_to_pe[0][4],  x_to_pe[0][5],  x_to_pe[0][6],  x_to_pe[0][7],  pe_fm_data_wire[0][8]);
    end

endmodule