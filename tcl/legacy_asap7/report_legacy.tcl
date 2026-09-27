##############################################################################
# report_legacy.tcl  --  LEGACY Innovus UI
#
#   source tcl/report_legacy.tcl
##############################################################################

# output directory for this run
set RPT reports/asap7_final
exec mkdir -p $RPT

# --- parasitic extraction (post-route, signoff-quality) ---------------------
#setExtractRCMode -engine postRoute -effortLevel high
#extractRC

# --- timing -----------------------------------------------------------------
report_timing -late   > $RPT/setup_timing.rpt
report_timing -early  > $RPT/hold_timing.rpt
#report_timing_summary > $RPT/timing_summary.rpt

# --- area -------------------------------------------------------------------
report_area  > $RPT/area.rpt

# --- power ------------------------------------------------------------------
report_power > $RPT/power.rpt

puts "=============================================="
puts " Reports written to: $RPT"
puts "=============================================="
