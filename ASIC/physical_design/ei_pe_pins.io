#-------------------------------------------------------------------------------
# Innovus I/O Pin Assignment File for ei_pe
#-------------------------------------------------------------------------------
(globals
    version = 3
    io_order = clockwise
)

(pins
    # --- LEFT SIDE: Control, Clocks, Resets & Control Handshakes ---
    (left 
        (pin name="sys_clk"                       layer=Metal2 width=0.200 height=1.000)
        (pin name="rst"                           layer=Metal2 width=0.200 height=1.000)
        (pin name="en"                            layer=Metal2 width=0.200 height=1.000)
        (pin name="valid_in"                      layer=Metal2 width=0.200 height=1.000)
        (pin name="ready_in"                      layer=Metal2 width=0.200 height=1.000)
        (pin name="residual_en"                   layer=Metal2 width=0.200 height=1.000)
        (pin name="pool_mode[0]"                  layer=Metal2 width=0.200 height=1.000)
        (pin name="pool_mode[1]"                  layer=Metal2 width=0.200 height=1.000)
        (pin name="act_mode[0]"                   layer=Metal2 width=0.200 height=1.000)
        (pin name="act_mode[1]"                   layer=Metal2 width=0.200 height=1.000)
        (pin name="acc_clear"                     layer=Metal2 width=0.200 height=1.000)
        (pin name="final_input_channel"           layer=Metal2 width=0.200 height=1.000)
        (pin name="test_signal"                   layer=Metal2 width=0.200 height=1.000)
    )

    # --- TOP SIDE: Feature Inputs (x0 to x8) ---
    (top 
        (pin name="const_pool[0]"                 layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[1]"                 layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[2]"                 layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[3]"                 layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[4]"                 layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[5]"                 layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[6]"                 layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[7]"                 layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[8]"                 layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[9]"                 layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[10]"                layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[11]"                layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[12]"                layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[13]"                layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[14]"                layer=Metal3 width=1.000 height=0.200)
        (pin name="const_pool[15]"                layer=Metal3 width=1.000 height=0.200)
        
        # Nhóm x0 -> x4 (16-bit mỗi chân được gom gọn bằng pattern hoặc liệt kê cơ bản)
        (pin name="x0[0..15]"                     layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="x1[0..15]"                     layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="x2[0..15]"                     layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="x3[0..15]"                     layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="x4[0..15]"                     layer=Metal3 width=1.000 height=0.200 spacing=0.400)
    )

    # --- RIGHT SIDE: Weight Inputs & Bias (x5-x8, w0-w8, bias) ---
    (right 
        (pin name="x5[0..15]"                     layer=Metal2 width=0.200 height=1.000 spacing=0.400)
        (pin name="x6[0..15]"                     layer=Metal2 width=0.200 height=1.000 spacing=0.400)
        (pin name="x7[0..15]"                     layer=Metal2 width=0.200 height=1.000 spacing=0.400)
        (pin name="x8[0..15]"                     layer=Metal2 width=0.200 height=1.000 spacing=0.400)
        
        (pin name="w0[0..15]"                     layer=Metal2 width=0.200 height=1.000 spacing=0.400)
        (pin name="w1[0..15]"                     layer=Metal2 width=0.200 height=1.000 spacing=0.400)
        (pin name="w2[0..15]"                     layer=Metal2 width=0.200 height=1.000 spacing=0.400)
        (pin name="w3[0..15]"                     layer=Metal2 width=0.200 height=1.000 spacing=0.400)
        
        (pin name="bias[0..15]"                   layer=Metal2 width=0.200 height=1.000 spacing=0.400)
    )

    # --- BOTTOM SIDE: Outputs & Remaining Weights (w4-w8, results) ---
    (bottom 
        (pin name="w4[0..15]"                     layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="w5[0..15]"                     layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="w6[0..15]"                     layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="w7[0..15]"                     layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="w8[0..15]"                     layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        
        # Ngõ ra chính và trạng thái
        (pin name="sum_out[0..15]"                layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="valid_out"                     layer=Metal3 width=1.000 height=0.200)
        (pin name="final_input_channel_valid_out" layer=Metal3 width=1.000 height=0.200)
        (pin name="pe_sum_out[0..15]"             layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        
        # Các ngõ ra residual
        (pin name="residual_valid_out"            layer=Metal3 width=1.000 height=0.200)
        (pin name="residual_out0[0..15]"          layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="residual_out1[0..15]"          layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="residual_out2[0..15]"          layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="residual_out3[0..15]"          layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="residual_out4[0..15]"          layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="residual_out5[0..15]"          layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="residual_out6[0..15]"          layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="residual_out7[0..15]"          layer=Metal3 width=1.000 height=0.200 spacing=0.400)
        (pin name="residual_out8[0..15]"          layer=Metal3 width=1.000 height=0.200 spacing=0.400)
    )
)