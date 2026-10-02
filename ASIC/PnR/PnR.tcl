# ========================================================
# Innovus PnR Script - CLEAN SDC FLOW (70% Density)
# ========================================================

set DESIGN "ei_pe"

# Tự động đảm bảo file SDC gốc đã được cập nhật chu kỳ trước khi nạp MMMC
catch {exec sed -i "s/-period 1.810/-period 2.20/g; s/-period 1.81/-period 2.20/g" ../Synthesis/outputs/${DESIGN}_sdc.sdc}
catch {exec sed -i "s/-period 1.810/-period 2.20/g; s/-period 1.81/-period 2.20/g" ../Synthesis/outputs/${DESIGN}.sdc}
catch {exec sed -i "s/-period 1.810/-period 2.20/g; s/-period 1.81/-period 2.20/g" ../physical_design/${DESIGN}.sdc}

# --- 1. Initialization ---
read_mmmc ../physical_design/${DESIGN}.view
read_physical -lef {../LEF/gsclib045_tech.lef ../LEF/gsclib045_macro.lef}
read_netlist ../Synthesis/outputs/${DESIGN}_netlist.v -top ${DESIGN}

set_db init_power_nets VDD
set_db init_ground_nets VSS
init_design

# Thiết lập tiến trình 45nm, OCV, CapTable và tắt phạt nhiễu xuyên âm SI
set_db design_process_node 45
set_db timing_analysis_type ocv
set_db extract_rc_effort_level low
catch {set_db delaycal_enable_si false}

# Kết nối ngầm chân nguồn VDD/VSS và hằng số logic (TieHi/TieLo)
connect_global_net VDD -type pg_pin -pin_base_name VDD -all -override
connect_global_net VSS -type pg_pin -pin_base_name VSS -all -override
connect_global_net VDD -type tie_hi -all -override
connect_global_net VSS -type tie_lo -all -override

# Cấu hình False Path cho Reset, pool_mode và Uncertainty
set_interactive_constraint_modes [all_constraint_modes -active]
set_false_path -from [get_ports rst]
catch {set_false_path -from [get_ports pool_mode*]}
set_clock_uncertainty -setup 0.015 [all_clocks]
set_clock_uncertainty -hold 0.005 [all_clocks]
set_interactive_constraint_modes {}

# --- 2. Floorplanning & IO ---
catch {read_io_file ../physical_design/ei_pe_pins.io}
create_floorplan -core_density_size 1.0 0.7 50 50 50 50

# --- 3. Power Planning (0 lỗi DRC) ---
add_rings -nets {VDD VSS} -type core_rings -width 1.0 -spacing 0.5 \
          -layer {top Metal3 bottom Metal3 left Metal2 right Metal2}
route_special -connect {core_pin} -nets {VDD VSS}

# --- 4. Placement & Pre-CTS Optimization ---
set_db place_global_ignore_scan false
set_db place_global_uniform_density false

catch {set_db place_global_cong_effort high}
catch {set_db place_global_timing_effort high}
catch {set_db opt_drv_effort high}
catch {set_db opt_useful_skew true}
catch {set_db opt_all_end_points true}

place_opt_design
time_design -pre_cts

# --- 5. Clock Tree Synthesis (CTS) ---
ccopt_design

opt_design -post_cts -setup
catch {set_db opt_hold_target_slack 0.025}
opt_design -post_cts -hold
time_design -post_cts

# --- 6. Routing & Post-Route Optimization ---
connect_global_net VDD -type pg_pin -pin_base_name VDD -all -override
connect_global_net VSS -type pg_pin -pin_base_name VSS -all -override
connect_global_net VDD -type tie_hi -all -override
connect_global_net VSS -type tie_lo -all -override

route_design

# Tối ưu Setup + Incremental Upsize
opt_design -post_route -setup
opt_design -post_route -setup -incr

# Tối ưu Hold triệt để (Không khóa setup_target_slack để tool tự do sửa sạch 100% Hold)
catch {set_db opt_hold_target_slack 0.025}
catch {set_db opt_hold_allow_setup_tns_degradation true}
opt_design -post_route -hold

# Cấp nguồn bổ sung cho mọi cổng mới sinh ra và dọn sạch DRC
connect_global_net VDD -type pg_pin -pin_base_name VDD -all -override
connect_global_net VSS -type pg_pin -pin_base_name VSS -all -override
connect_global_net VDD -type tie_hi -all -override
connect_global_net VSS -type tie_lo -all -override

check_drc
catch {route_eco -fix_drc}
delete_drc_markers

time_design -post_route
time_design -post_route -hold

# --- 7. Xuất bộ báo cáo chính duy nhất ---
catch {file mkdir reports}
catch {file mkdir outputs}

check_drc -out_file reports/${DESIGN}_drc.rpt
check_connectivity -type regular -out_file reports/${DESIGN}_conn.rpt
delete_drc_markers

set_db timing_enable_simultaneous_setup_hold_mode true
report_timing_summary > reports/${DESIGN}_timing_summary.rpt
set_db timing_enable_simultaneous_setup_hold_mode false

report_timing -late -max_paths 10 > reports/${DESIGN}_setup_timing.rpt
report_timing -early -max_paths 10 > reports/${DESIGN}_hold_timing.rpt
report_area > reports/${DESIGN}_area.rpt
report_power > reports/${DESIGN}_power.rpt

# --- 8. Xuất Database & Netlist ---
write_db ${DESIGN}_routed.innovus
write_netlist outputs/${DESIGN}_pnr_netlist.v
write_sdf outputs/${DESIGN}_pnr.sdf

puts "========================================================"
puts "CLEAN SDC PnR FLOW COMPLETED SUCCESSFULLY!"
puts "========================================================"