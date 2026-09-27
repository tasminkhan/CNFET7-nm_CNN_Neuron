##############################################################################
# report_cnfet7.tcl  --  STYLUS Innovus, CNFET7
#   Sourced at the end of pnr_cnfet7.tcl (after CTS+route).
#   Mirrors report_legacy.tcl: timing / area / power into a report dir.
#   RC is captable-estimated (mmmc has no qrc) -> these are ESTIMATES.
#   Signoff QRC extraction is intentionally NOT run (it caused the runaway).
#
#   source tcl/report_cnfet7.tcl
##############################################################################

# output directory for this run
set RPT reports
exec mkdir -p $RPT

# --- parasitic extraction --------------------------------------------------
# QRC signoff extraction DISABLED (M* vs MINT* layer-map runaway).
# RC comes from the LEF captable set at init. To enable signoff RC later,
# add a layer map to the RC corner in mmmc_cnfet7.tcl, then uncomment:
# set_db extract_rc_engine post_route
# set_db extract_rc_effort_level high
# extract_rc

# --- timing ----------------------------------------------------------------
report_timing -late  > $RPT/setup_timing.rpt
report_timing -early > $RPT/hold_timing.rpt

# --- area ------------------------------------------------------------------
report_area > $RPT/area.rpt

# --- power -----------------------------------------------------------------
report_power > $RPT/power.rpt

# --- gate/instance count (handy for the area comparison) -------------------
report_gates > $RPT/gates.rpt

puts "=============================================="
puts " Reports written to: $RPT"
puts " (timing/power are captable estimates, no QRC)"
puts "=============================================="
