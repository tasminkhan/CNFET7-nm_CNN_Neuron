##############################################################################
#  cts_cnfet7_fill.tcl  --  STYLUS Innovus, CNFET7.
#  SAME as cts_cnfet7.tcl but WITH metal fill (density) after routing.
#  Continuation after placement (source this instead of cts_cnfet7.tcl from
#  pnr_cnfet7.tcl if you want density metal fill).
#  Metal fill only on ROUTED layers M1..MINT6 (nothing routes on MINT7/MINT8;
#  those carry only the power stripe, so we don't fill them).
#  NO cell fillers: this PDK ships none (only TIEH/TIEL tie cells).
##############################################################################

##############################################################################
# CTS
##############################################################################
reset_ccopt_config
create_clock_tree -name clock -source clk -no_skew_group
create_skew_group -name clock -source clk -auto_sinks

set_db cts_max_fanout 20
set_db cts_target_max_transition_time 200
set_db cts_target_max_capacitance 0.1

create_route_rule -name CTS_2S2W -spacing_multiplier {M1:MINT8 2} -width_multiplier {M1:MINT8 2}
create_route_type -name clkroute -route_rule CTS_2S2W \
    -bottom_preferred_layer MINT5 -top_preferred_layer MINT6

set_db cts_route_type_trunk clkroute
set_db cts_route_type_leaf  clkroute
set_db cts_route_type_top   clkroute

set_db cts_buffer_cells   {CLKBUF_X1 CLKBUF_X2 CLKBUF_X4 CLKBUF_X8 CLKBUF_X12 CLKBUF_X16}
set_db cts_inverter_cells {INV_X1 INV_X2 INV_X4 INV_X8 INV_X12 INV_X16}

exec mkdir -p CTS
ccopt_design -report_dir CTS

opt_design -post_cts
opt_design -post_cts -hold

write_db DBS/cts.enc

##############################################################################
# ROUTE  (signals MINT1..MINT6, timing + SI driven)
##############################################################################
set_db route_design_bottom_routing_layer MINT1
set_db route_design_top_routing_layer    MINT6
set_db route_design_with_timing_driven true
set_db route_design_with_si_driven     true

route_design

opt_design -post_route
opt_design -post_route -hold

write_db DBS/route.enc

##############################################################################
# METAL FILL  (density) -- only routed layers M1..MINT6
#   Stylus command: add_metal_fill. -timing_aware sta keeps fill off critical
#   nets. If your build errors on a flag, run: add_metal_fill -help
##############################################################################
add_metal_fill -layers {M1 MINT1 MINT2 MINT3 MINT4 MINT5 MINT6 MINT7} \
               -timing_aware sta

write_db DBS/fill.enc

##############################################################################
# POST-ROUTE CHECKS (after fill)
##############################################################################
set RPT reports/cnfet7_final
exec mkdir -p $RPT
check_connectivity -type all -nets {VDD VSS} -report $RPT/conn_postroute.rpt
check_drc -report $RPT/drc_postroute.rpt

write_db DBS/final.enc

puts "=============================================="
puts " CTS + ROUTE + METAL FILL done."
puts "=============================================="
