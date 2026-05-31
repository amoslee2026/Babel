# KLayout GDS export script
require 'layout'

# Create new layout
layout = Layout::Layout.new
layout.read_lef("/home/lxx/wrk/libs/asap7_reference_design/techlef/asap7_tech_4x_201209.lef")
layout.read_lef("/home/lxx/wrk/libs/asap7_reference_design/lef/asap7sc7p5t_28_L_1x_220121a.lef")

# Read DEF
if File.exists?("/home/lxx/wrk/Babel/designs/NPU_top/pd/placed_20260522_004334.def")
  layout.read_def("/home/lxx/wrk/Babel/designs/NPU_top/pd/placed_20260522_004334.def")
end

# Write GDS
layout.write("/home/lxx/wrk/Babel/designs/NPU_top/gdsii/NPU_top_20260522_004337.gds")
puts "GDS exported: /home/lxx/wrk/Babel/designs/NPU_top/gdsii/NPU_top_20260522_004337.gds"
