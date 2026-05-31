# KLayout DEF-to-GDS Export Script for NPU_top
# Generated: 2026-05-21T22:35:00+08:00

require 'RBA'

# Configuration
lef_file = "/home/lxx/wrk/libs/asap7_reference_design/lef/asap7sc7p5t_28_L_1x_220121a.lef"
def_file = "/home/lxx/wrk/Babel/designs/NPU_top/pd/placed_20260521_223540.def"
gds_file = "/home/lxx/wrk/Babel/designs/NPU_top/gdsii/NPU_top_20260521.gds"

puts "=== KLayout DEF-to-GDS Export ==="
puts "LEF: #{lef_file}"
puts "DEF: #{def_file}"
puts "GDS: #{gds_file}"

# Create layout
layout = RBA::Layout::new

# Load LEF file (defines cell geometries)
puts "Loading LEF..."
begin
  lef_reader = RBA::LEFReader::new
  lef_reader.read(lef_file, layout)
  puts "LEF loaded: #{layout.cells} cells defined"
rescue => e
  puts "LEF load error: #{e.message}"
  puts e.backtrace
  exit 1
end

# Load DEF file (defines placement and netlist)
puts "Loading DEF..."
begin
  def_reader = RBA::DEFReader::new
  def_reader.read(def_file, layout)
  puts "DEF loaded"
rescue => e
  puts "DEF load error: #{e.message}"
  puts e.backtrace
  exit 1
end

# Set database units
layout.dbu = 0.001  # 1nm precision for ASAP7

# Report layout info
puts "Cell count: #{layout.cells}"
puts "Layer count: #{layout.layers}"

# Get top cell
top_cell = layout.top_cell
if top_cell
  puts "Top cell: #{top_cell.name}"
  puts "Top cell bounding box: #{top_cell.bbox}"
end

# Write GDS
puts "Writing GDS..."
begin
  layout.write(gds_file)
  puts "GDS written: #{gds_file}"
  puts "File size: #{File.size(gds_file)} bytes"
rescue => e
  puts "GDS write error: #{e.message}"
  exit 1
end

puts "=== Export complete ==="
exit 0