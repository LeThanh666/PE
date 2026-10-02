set_db init_lib_search_path ../LIB/
set_db init_hdl_search_path ../RTL/

# LUU Ý K? THU?T: B?n dang dùng thu vi?n SLOW (worst-case). 
# N?u trong thu m?c ../LIB/ có file fast_*.lib ho?c typical_*.lib, hãy d?i sang nó d? d? d?t 400MHz hon.
read_libs slow_vdd1v0_basiccells.lib

# Source have .v and .sv
read_hdl -sv [glob ../RTL/*.sv ../RTL/*.v]

elaborate ei_pe

# Ð?m b?o file SDC này dã du?c s?a chu k? (period) xu?ng 2.5ns nhu mình th?o lu?n
read_sdc ../Constraints/ei_pe_constraints_top.sdc

# ========================================================
# CHI?N THU?T ÉP FMAX T?I ÐA (THÊM M?I)
# ========================================================
# 1. Cho phép tool t? d?ng d?i Flip-Flop d? cân b?ng tr?
set_db design:ei_pe .retime true

# 2. Phá v? ranh gi?i các module con (nhu mac_fp16, accumulator) d? di dây t?i uu nh?t
set_db / .auto_ungroup both

# 3. Nâng n? l?c t?ng h?p t? medium lên HIGH d? kích ho?t các thu?t toán m?nh nh?t
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high
# ========================================================

syn_generic
syn_map
syn_opt

# reports
report_timing > reports/ei_report_timing.rpt
report_power  > reports/ei_report_power.rpt
report_area   > reports/ei_report_area.rpt
report_qor    > reports/ei_report_qor.rpt

# Outputs
write_hdl > outputs/ei_pe_netlist.v
write_do_lec -revised_design outputs/ei_pe_netlist.v -logfile lec.log -tmp_dir lec_data
write_sdc > outputs/ei_pe_sdc.sdc
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge  -setuphold split > outputs/delays.sdf