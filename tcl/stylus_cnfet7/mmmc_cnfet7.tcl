##############################################################################
## mmmc_cnfet7.tcl  --  STYLUS format, CNFET7 unscaled, TT, 0.4V, 25C
## QRC REMOVED: the qrcTechFile auto-layer-map (M* vs MINT*) runs away to
## tens of GB at init_design. Without -qrc_tech, RC falls back to the LEF
## captable. Timing/power become estimates (fine for placement/route/area).
## To restore signoff-accurate RC later, add -qrc_tech back WITH a layer map.
##############################################################################

set pdk /projects/CM_BTAP/work/btapuser50ddc/pdks/CNFET-OCL/CNFET7
set syn /projects/CM_BTAP/work/btapuser50ddc/syn/neuron_syn/outputs/cnfet7_ccs

create_library_set -name typical_lib \
    -timing [list $pdk/LIB/CCS/CNFET7_ccs_calibred_TT.lib]

# RC corner WITHOUT qrc_tech (captable-based RC, no runaway)
create_rc_corner -name rc_typical \
    -temperature 25

create_opcond -name typical_op -process 1 -voltage 0.4 -temp 25

create_timing_condition -name typical_time -library_sets [list typical_lib]

create_delay_corner -name typical_delay \
    -timing_condition typical_time \
    -rc_corner rc_typical

create_constraint_mode -name constraint \
    -sdc_files [list $syn/neuron_syn_cnfet7_ccs.sdc]

create_analysis_view -name typical_view \
    -constraint_mode constraint \
    -delay_corner typical_delay

set_analysis_view -setup { typical_view } -hold { typical_view }
