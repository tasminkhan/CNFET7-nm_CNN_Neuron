##############################################################################
#  cts_cnfet7.tcl  --  STYLUS Innovus, CNFET7.  CTS -> route -> multi-opt.
#  Continuation after placement (sourced by pnr_cnfet7.tcl).
#  Cell names verified against CNFET7_Cell.lef (X1/X2/X4/X8/X12/X16).
#  NO metal fill here (see cts_cnfet7_fill.tcl for the fill variant).
#  NO filler/decap/tap: this PDK ships none (only TIEH/TIEL).
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

#write_db DBS/cts.enc

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

#write_db DBS/route.enc

##############################################################################
# POST-ROUTE CHECKS
##############################################################################
set RPT reports/cnfet7_final
exec mkdir -p $RPT
check_connectivity -type all -nets {VDD VSS} -report $RPT/conn_postroute.rpt
check_drc -report $RPT/drc_postroute.rpt

#write_db DBS/final.enc

puts "=============================================="
puts " CTS + ROUTE done (no metal fill)."
puts "=============================================="
