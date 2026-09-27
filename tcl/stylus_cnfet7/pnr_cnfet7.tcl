##############################################################################
#  pnr_cnfet7.tcl  --  STYLUS (common UI) Innovus, CNFET7 unscaled
#  NO rings, stripes-only mesh (MINT6 vertical + MINT7 horizontal).
#  Floorplan: uniform 1.152 margin (= 3 * row_h 0.384), util 0.60.
#  Pins: ASAP7-style division (w top, a+ctrl left, y_r right) on MINT4/MINT5.
#  MMMC has NO qrc (mmmc_cnfet7.tcl) so init_design won't run away.
#  This PDK ships NO filler/decap/tap cells (only TIEH/TIEL) -> no add_fillers.
#
#  At the end this sources CTS and REPORT so ONE call runs the whole flow:
#    source tcl/pnr_cnfet7.tcl
#  For the metal-fill variant, edit the source line to cts_cnfet7_fill.tcl.
##############################################################################

set_db init_power_nets  VDD
set_db init_ground_nets VSS

set pdk /projects/CM_BTAP/work/btapuser50ddc/pdks/CNFET-OCL/CNFET7
set syn /projects/CM_BTAP/work/btapuser50ddc/syn/neuron_syn/outputs/cnfet7_ccs

read_mmmc tcl/mmmc_cnfet7.tcl

read_physical -lef [list \
    $pdk/LEF/CNFET7_Tech.lef \
    $pdk/LEF/CNFET7_Cell.lef ]

read_netlist $syn/neuron_syn_cnfet7_ccs_netlist.v -top neuron_syn

init_design
write_db DBS/init.enc

##############################################################################
# FLOORPLAN  (util 0.60, uniform 1.152 margin = 3 * row_h 0.384)
##############################################################################
create_floorplan -site CORE_TypTyp_0p4_25 -match_to_site \
                 -core_density_size 1.0 0.60 1.152 1.152 1.152 1.152
gui_fit

##############################################################################
# PIN PLACEMENT  (SAME division as ASAP7)
#   TOP   : w[15:0]                              -> MINT4
#   LEFT  : clk rst_n en clear result_en a[15:0] -> MINT5
#   RIGHT : y_r[15:0] + y_valid                  -> MINT5
##############################################################################
set_db assign_pins_edit_in_batch true

set pins_top   {w[15] w[14] w[13] w[12] w[11] w[10] w[9] w[8] w[7] w[6] w[5] w[4] w[3] w[2] w[1] w[0]}
set pins_left  {clk rst_n en clear result_en a[15] a[14] a[13] a[12] a[11] a[10] a[9] a[8] a[7] a[6] a[5] a[4] a[3] a[2] a[1] a[0]}
set pins_right {y_r[15] y_r[14] y_r[13] y_r[12] y_r[11] y_r[10] y_r[9] y_r[8] y_r[7] y_r[6] y_r[5] y_r[4] y_r[3] y_r[2] y_r[1] y_r[0] y_valid}

edit_pin -layer MINT4 -pin $pins_top   -side TOP   -spread_type SIDE -pin_depth 0.3 -pin_width 0.024
edit_pin -layer MINT5 -pin $pins_left  -side LEFT  -spread_type SIDE -pin_depth 0.3 -pin_width 0.024
edit_pin -layer MINT5 -pin $pins_right -side RIGHT -spread_type SIDE -pin_depth 0.3 -pin_width 0.024

set_db assign_pins_edit_in_batch false
puts "placed: TOP=[llength $pins_top] LEFT=[llength $pins_left] RIGHT=[llength $pins_right]"

##############################################################################
# GLOBAL NET CONNECT  (PG pins + tie cells)
##############################################################################
connect_global_net VDD -type pg_pin -pin_base_name VDD -inst_base_name * -verbose
connect_global_net VSS -type pg_pin -pin_base_name VSS -inst_base_name * -verbose
connect_global_net VDD -type tie_hi -inst_base_name * -verbose
connect_global_net VSS -type tie_lo -inst_base_name * -verbose

##############################################################################
# POWER STRIPES  (NO rings)  -- MINT6 vertical + MINT7 horizontal = real mesh
##############################################################################
set p6 0.080
set p7 0.080

# --- MINT6 vertical (stack down to M1 rails) ---
set_db add_stripes_stacked_via_bottom_layer M1
set_db add_stripes_stacked_via_top_layer    MINT6
add_stripes -nets {VDD VSS} \
            -layer MINT6 \
            -direction vertical \
            -width 0.080 \
            -spacing 0.080 \
            -set_to_set_distance [expr $p6 * 30] \
            -start_offset        [expr $p6 * 8] \
            -extend_to design_boundary \
            -snap_wire_center_to_grid grid

# --- MINT7 horizontal (lands on MINT6) ---
set_db add_stripes_stacked_via_bottom_layer MINT6
set_db add_stripes_stacked_via_top_layer    MINT7
add_stripes -nets {VDD VSS} \
            -layer MINT7 \
            -direction horizontal \
            -width 0.080 \
            -spacing 0.080 \
            -set_to_set_distance [expr $p7 * 30] \
            -start_offset        [expr $p7 * 8] \
            -extend_to design_boundary \
            -snap_wire_center_to_grid grid

##############################################################################
# SPECIAL ROUTE  (rails + stripes; full stack M1..MINT8)
##############################################################################
route_special -connect core_pin -nets {VDD VSS} \
    -layer_change_range {M1 MINT8} \
    -allow_jogging 1 -allow_layer_change 1

route_special -connect {core_pin floating_stripe} -nets {VDD VSS} \
    -layer_change_range {M1 MINT8} \
    -crossover_via_layer_range {M1 MINT8} \
    -floating_stripe_target {stripe followpin} \
    -allow_jogging 1 -allow_layer_change 1

check_connectivity -type special -nets {VDD VSS}
check_drc

##############################################################################
# PLACEMENT + PRE-CTS OPT
##############################################################################
place_opt_design

# reconnect PG for cells placement added, then re-stitch rails
connect_global_net VDD -type pg_pin -pin_base_name VDD -inst_base_name *
connect_global_net VSS -type pg_pin -pin_base_name VSS -inst_base_name *
route_special -connect core_pin -nets {VDD VSS} \
    -layer_change_range {M1 MINT8} -allow_jogging 1 -allow_layer_change 1

check_connectivity -type special -nets {VDD VSS}

write_db DBS/place.enc
gui_fit

puts "=============================================="
puts " PLACEMENT DONE -> continuing into CTS + REPORT"
puts "=============================================="

##############################################################################
# CONTINUE THE FLOW  (one call does everything)
#   swap cts_cnfet7.tcl -> cts_cnfet7_fill.tcl for the metal-fill variant
##############################################################################
source tcl/cts_cnfet7.tcl
source tcl/report_cnfet7.tcl
