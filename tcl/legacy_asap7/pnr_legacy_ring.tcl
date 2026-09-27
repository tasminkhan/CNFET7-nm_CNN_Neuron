##############################################################################
#  pnr_neuron_asap7_1x_legacy5.tcl
#  ASAP7 1x  --  LEGACY Innovus UI.  Follows the official ASAP7
#  example_innovus.tcl. Only necessary changes made:
#    - design paths / top cell / mmmc for this design
#    - pin placement uses YOUR side arrangement
#    - dimensions use the 1x tech pitches; row_h = 0.270 (from SITE)
#
#  Launch (NO -stylus):
#    cd /projects/CM_BTAP/work/btapuser50ddc/pnr/neuron
#    innovus -init tcl/pnr_legacy5.tcl
##############################################################################

setLibraryUnit -time 1ps

set pdk /projects/CM_BTAP/work/btapuser50ddc/pdks/asap7/asap7sc7p5t_28
set syn /projects/CM_BTAP/work/btapuser50ddc/syn/neuron_syn/outputs/asap7_ccs

# --- design init (replaces the example's <your_global_init_files>.globals) ---
setDesignMode -process 7

set init_lef_file [list \
    $pdk/techlef_misc/asap7_tech_1x_201209.lef \
    $pdk/LEF/asap7sc7p5t_28_R_1x_220121a.lef ]
set init_verilog   $syn/neuron_syn_asap7_ccs_netlist.v
set init_top_cell  neuron_syn
set init_pwr_net   VDD
set init_gnd_net   VSS
set init_mmmc_file tcl/mmmc_legacy.tcl

init_design

# this is example tcl to make a flexible floorplan size (1x core density flow)

floorPlan -coreMarginsBy die -site asap7sc7p5t \
          -r 1.0 0.60 2.304 2.304 2.304 2.304

# Snap the floorplan so the core edges land on legal site-row / track
# boundaries. This is the clean replacement for the old
# 'changeFloorplan -coreToBottom 1.08' hack: instead of nudging the core by a
# hand-picked amount, we let Innovus align the core box to the row grid so the
# bottom row gets proper routing tracks.
snapFPlan -all

add_tracks -honor_pitch

##############################################################################
# PIN PLACEMENT  (YOUR arrangement)
#   TOP   : w[15:0]
#   LEFT  : clk rst_n en clear result_en  then a[15:0]
#   RIGHT : y_r[15:0] + y_valid
##############################################################################
set pins_top   {w[15] w[14] w[13] w[12] w[11] w[10] w[9] w[8] w[7] w[6] w[5] w[4] w[3] w[2] w[1] w[0]}
set pins_left  {clk rst_n en clear result_en a[15] a[14] a[13] a[12] a[11] a[10] a[9] a[8] a[7] a[6] a[5] a[4] a[3] a[2] a[1] a[0]}
set pins_right {y_r[15] y_r[14] y_r[13] y_r[12] y_r[11] y_r[10] y_r[9] y_r[8] y_r[7] y_r[6] y_r[5] y_r[4] y_r[3] y_r[2] y_r[1] y_r[0] y_valid}

editPin -pin $pins_top   -side TOP   -layer M3 -spreadType SIDE -pinWidth 0.018 -pinDepth 0.5 -spreadDirection clockwise
editPin -pin $pins_left  -side LEFT  -layer M4 -spreadType SIDE -pinWidth 0.018 -pinDepth 0.5 -spreadDirection clockwise
editPin -pin $pins_right -side RIGHT -layer M4 -spreadType SIDE -pinWidth 0.018 -pinDepth 0.5 -spreadDirection clockwise
clearGlobalNets
globalNetConnect VDD -type pgpin -pin VDD -inst * -module {}
globalNetConnect VSS -type pgpin -pin VSS -inst * -module {}

##############################################################################
# POWER RING  (M6 top/bottom horizontal, M5 left/right vertical)
#   Gives the boundary stripes something to terminate on (prevents dangling
#   VDD/VSS wires at the die edge).  Widths use 1x tech min-width multiples.
##############################################################################
# ring widths use the SAME table-legal formulas as the stripes:
#   M6 = 0.032*(5+4*1) = 0.288   |   M5 = 0.024*(5+4*1) = 0.216
# spacings are odd-multiple/on-grid; offsets land on the routing grid.
addRing -nets {VDD VSS} -type core_rings -follow core \
    -layer {top M6 bottom M6 left M5 right M5} \
    -width {top 0.288 bottom 0.288 left 0.216 right 0.216} \
    -spacing {top 0.096 bottom 0.096 left 0.072 right 0.072} \
    -offset {top 0.128 bottom 0.128 left 0.096 right 0.096} \
    -center 1

setAddStripeMode -stacked_via_bottom_layer M1 \
    -stacked_via_top_layer M2 \
    -max_via_size { Stripe 100 100 100 } \
    -via_using_exact_crossover_size true

sroute -connect { blockPin padPin padRing corePin floatingStripe } \
    -layerChangeRange { M1 M7 } \
    -blockPinTarget { nearestTarget } \
    -padPinPortConnect { allPort oneGeom } \
    -padPinTarget { nearestTarget } \
    -corePinTarget { firstAfterRowEnd } \
    -floatingStripeTarget { blockring padring ring stripe ringpin blockpin followpin } \
    -allowJogging 1 \
    -crossoverViaLayerRange { M1 M7 } \
    -nets { VDD VSS } \
    -allowLayerChange 1 \
    -blockPin useLef \
    -targetViaLayerRange { M1 M7 }

### Intervene Here. Manually fix the Top M1 Follow Rail

source "tcl/m2followRail.tcl"

setViaGenMode -viarule_preference { M6_M5widePWR1p152 M5_M4widePWR0p864 M4_M3widePWR0p864 }

# ! VALUES BELOW ADJUSTED FOR 1x TECH (pitches M3=0.036 M4/M5=0.048 M6=0.064)

# has to be 5, 9, 13, ... change the 8 to widen by 4 min widths
set m3pwrwidth [expr 0.018 * (5 + (4 * 2))]
set m3pwrset2settracks  60
set m3pwrset2setdist    [expr $m3pwrset2settracks * 0.036]
print "M3 PWR width and set to set distance: $m3pwrwidth $m3pwrset2setdist"

# must be odd multiple of width and space so we stay on grid
set m3pwrspacing [expr 0.018 * 21]

# the xoffset specifies the left edge of the 1st wire.
set m3pwrxoffset [expr (0.018 * 26) + 0.009]
print "M3 PWR spacing and offset: $m3pwrspacing $m3pwrxoffset"

addStripe -extend_to design_boundary \
    -padcore_ring_top_layer_limit M6 \
    -padcore_ring_bottom_layer_limit M3 \
    -skip_via_on_wire_shape Noshape \
    -max_same_layer_jog_length 0 \
    -set_to_set_distance $m3pwrset2setdist \
    -skip_via_on_pin Standardcell \
    -stacked_via_top_layer M7 \
    -spacing $m3pwrspacing \
    -xleft_offset $m3pwrxoffset \
    -merge_stripes_value 0.04 \
    -layer M3 \
    -width $m3pwrwidth \
    -nets {VDD VSS} \
    -stacked_via_bottom_layer M2

set m4pwrwidth [expr 0.024 * (5 + (4 * 1))]
set m4pwrset2settracks  80
set m4pwrset2setdist    [expr $m4pwrset2settracks * 0.048]
print "M4 PWR width and set to set distance: $m4pwrwidth $m4pwrset2setdist"

set m4pwrspacing [expr 0.048 * 10]
set m4pwrxoffset [expr 0.003 + 0.048 * 13]
print "M4 PWR spacing and offset: $m4pwrspacing $m4pwrxoffset"

setAddStripeMode \
    -max_via_size { Stripe 100 100 100 } \
    -via_using_exact_crossover_size true \
    -stacked_via_bottom_layer M3 \
    -stacked_via_top_layer M4 \
    -trim_antenna_back_to_shape stripe

addStripe -extend_to design_boundary \
    -padcore_ring_top_layer_limit M6 \
    -padcore_ring_bottom_layer_limit M3 \
    -direction horizontal \
    -skip_via_on_wire_shape Noshape \
    -max_same_layer_jog_length 2 \
    -set_to_set_distance $m4pwrset2setdist \
    -skip_via_on_pin Standardcell \
    -spacing $m4pwrspacing \
    -xleft_offset $m4pwrxoffset \
    -merge_stripes_value 0.04 \
    -layer M4 \
    -width $m4pwrwidth \
    -nets {VDD VSS}

set m5pwrwidth [expr 0.024 * (5 + (4 * 1))]
set m5pwrset2settracks  80
set m5pwrset2setdist    [expr $m5pwrset2settracks * 0.048]
print "M5 PWR width and set to set distance: $m5pwrwidth $m5pwrset2setdist"

set m5pwrspacing [expr 0.024 * 21]
set m5pwrxoffset [expr (0.024 * 70) + 0.012]
print "M5 PWR spacing and offset: $m5pwrspacing $m5pwrxoffset"

setAddStripeMode -stacked_via_bottom_layer M4 \
    -stacked_via_top_layer M5 \
    -max_via_size { Stripe 100 100 100 } \
    -via_using_exact_crossover_size true

setViaGenMode -bar_cut_orientation horizontal

addStripe -extend_to design_boundary \
    -padcore_ring_top_layer_limit M6 \
    -padcore_ring_bottom_layer_limit M3 \
    -direction vertical \
    -skip_via_on_wire_shape Noshape \
    -max_same_layer_jog_length 0 \
    -set_to_set_distance $m5pwrset2setdist \
    -skip_via_on_pin Standardcell \
    -spacing $m5pwrspacing \
    -xleft_offset $m5pwrxoffset \
    -merge_stripes_value 0.04 \
    -layer M5 \
    -width $m5pwrwidth \
    -nets {VDD VSS}

set m6pwrwidth [expr 0.032 * (5 + (4 * 1))]
set m6pwrset2settracks  60
set m6pwrset2setdist    [expr $m6pwrset2settracks * 0.064]
print "M6 PWR width and set to set distance: $m6pwrwidth $m6pwrset2setdist"

set m6pwrspacing [expr 0.032 * 21]
set m6pwrxoffset [expr (0.032 * 50) + 0.002]
print "M6 PWR spacing and offset: $m6pwrspacing $m6pwrxoffset"

setAddStripeMode -stacked_via_bottom_layer M5 \
    -stacked_via_top_layer M6 \
    -max_via_size { Stripe 100 100 100 } \
    -via_using_exact_crossover_size true

setViaGenMode -bar_cut_orientation vertical

addStripe -extend_to design_boundary \
    -padcore_ring_top_layer_limit M6 \
    -padcore_ring_bottom_layer_limit M3 \
    -direction horizontal \
    -skip_via_on_wire_shape Noshape \
    -max_same_layer_jog_length 0 \
    -set_to_set_distance $m6pwrset2setdist \
    -skip_via_on_pin Standardcell \
    -spacing $m6pwrspacing \
    -xleft_offset $m6pwrxoffset \
    -merge_stripes_value 0.04 \
    -layer M6 \
    -width $m6pwrwidth \
    -nets {VDD VSS}

##############################################################################
# RING STITCH  --  connect the stripes+rails INTO the M5/M6 ring.
# The example flow has no ring, so it never needed this. Because we added an
# M5/M6 core ring, we run one more via-forcing sroute so every stripe and the
# cell rails tie into the ring (closes the boundary 'Open' VDD/VSS violations).
##############################################################################
setViaGenMode -viarule_preference { M6_M5widePWR1p152 M5_M4widePWR0p864 M4_M3widePWR0p864 }

sroute -connect { corePin floatingStripe } \
    -nets { VDD VSS } \
    -layerChangeRange { M1 M6 } \
    -crossoverViaLayerRange { M1 M6 } \
    -targetViaLayerRange { M1 M6 } \
    -floatingStripeTarget { ring stripe ringpin followpin blockpin } \
    -allowJogging 1 \
    -allowLayerChange 1

timeDesign -prePlace

createBasicPathGroups

setMaxRouteLayer 6
source "tcl/cts_legacy_fill.tcl"
verify_connectivity -nets {VDD VSS} -type special > reports/con.rpt
source "tcl/report_legacy.tcl"
win