#   Genus synthesis - neuron  |  TECH = ASAP7 , MODEL = CCS
#   library corner: TT (typical)   |   time_unit = 1ps 
#   RVT is selected by the *_RVT_TT_* filenames (ASAP7); 

# ------------------------------------------------------------------ knobs
set design      neuron_syn
set clk_name    clk
set clk_period  3000        ;# in ps 
set in_delay    200
set out_delay   200
#set in_frac    0.30
#set out_frac   0.30
#set in_delay   [expr {$clk_period * $in_frac}]
#set out_delay  [expr {$clk_period * $out_frac}]

# ------------------------------------------------------------------ paths
set base    /projects/CM_BTAP/work/btapuser50ddc
set rtl     $base/rtl/neuron
set outdir  $base/syn/$design
set tag     asap7_ccs
set report_d $outdir/reports/$tag
set output_d $outdir/outputs/$tag
file mkdir $report_d
file mkdir $output_d

# ------------------------------------------------------------------ RTL 
set rtl_files [list \
    $rtl/mac.sv     \
    $rtl/requant_syn.sv \
    $rtl/relu.sv    \
    $rtl/neuron_syn.sv  \
]

# ------------------------------------------------------------------ library (ASAP7 CCS)
set lib_dir /projects/CM_BTAP/work/btapuser50ddc/pdks/asap7/asap7sc7p5t_28/LIB/CCS
set lib_files [list \
    $lib_dir/asap7sc7p5t_AO_RVT_TT_ccs_211120.lib \
    $lib_dir/asap7sc7p5t_INVBUF_RVT_TT_ccs_220122.lib \
    $lib_dir/asap7sc7p5t_OA_RVT_TT_ccs_211120.lib \
    $lib_dir/asap7sc7p5t_SEQ_RVT_TT_ccs_220123.lib \
    $lib_dir/asap7sc7p5t_SIMPLE_RVT_TT_ccs_211120.lib \
]

#==============================================================================
# FLOW
#==============================================================================
set_db library $lib_files

read_hdl -sv $rtl_files
elaborate $design
check_design -unresolved

create_clock -name $clk_name -period $clk_period [get_ports $clk_name]
set in_ports [remove_from_collection [all_inputs] [get_ports $clk_name]]
set_input_delay  -clock $clk_name $in_delay  $in_ports
set_output_delay -clock $clk_name $out_delay [all_outputs]

set_db syn_generic_effort high
set_db syn_map_effort     high
set_db syn_opt_effort     high

syn_generic
syn_map
syn_opt

#==============================================================================
# REPORTS
#==============================================================================
report_timing > $report_d/${design}_${tag}_timing.rpt
report_area   > $report_d/${design}_${tag}_area.rpt
report_power  > $report_d/${design}_${tag}_power.rpt
report_gates  > $report_d/${design}_${tag}_gates.rpt
report_qor    > $report_d/${design}_${tag}_qor.rpt

#==============================================================================
# OUTPUTS
#==============================================================================
write_hdl > $output_d/${design}_${tag}_netlist.v
write_sdc > $output_d/${design}_${tag}.sdc
write_db    $output_d/${design}_${tag}.db

puts "=================================================="
puts " DONE: ASAP7 / CCS   (tag = $tag)"
puts " reports -> $report_d"
puts " netlist -> $output_d/${design}_${tag}_netlist.v"
puts "=================================================="
gui_show
suspend
