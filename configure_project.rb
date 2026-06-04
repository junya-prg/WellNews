require 'xcodeproj'

project_path = 'WellNews.xcodeproj'
puts "Opening project: #{project_path}"
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == 'WellNews' }
if main_target.nil?
  puts "Error: Main target 'WellNews' not found."
  exit 1
end

# 1. Create or find the Widget target
widget_target = project.targets.find { |t| t.name == 'WellNewsWidget' }
if widget_target.nil?
  puts "Creating WellNewsWidget target..."
  widget_target = project.new_target(:app_extension, 'WellNewsWidget', :ios, '17.0', nil, :swift)
else
  puts "WellNewsWidget target already exists."
end

# 2. Find or create group safely (avoiding find_subpath due to Xcode 16 folder sync)
widget_group = project.main_group.children.find { |c| c.isa == 'PBXGroup' && c.name == 'WellNewsWidget' }
if widget_group.nil?
  widget_group = project.main_group.new_group('WellNewsWidget', 'WellNewsWidget')
  puts "Created WellNewsWidget group."
end

# 3. Create or find file references
widget_swift_ref = widget_group.files.find { |f| f.path =~ /WellNewsWidget\.swift$/ }
if widget_swift_ref.nil?
  widget_swift_ref = widget_group.new_file('WellNewsWidget.swift')
  puts "Created reference for WellNewsWidget.swift"
end

widget_plist_ref = widget_group.files.find { |f| f.path =~ /Info\.plist$/ }
if widget_plist_ref.nil?
  widget_plist_ref = widget_group.new_file('Info.plist')
  puts "Created reference for Info.plist"
end

# We also need a file reference for Article.swift in the main group to compile in the widget target
article_ref = project.main_group.files.find { |f| f.path =~ /Article\.swift$/ }
if article_ref.nil?
  article_ref = project.main_group.new_file('WellNews/Models/Article.swift')
  puts "Created reference for Article.swift"
end

# Ensure swift files are in the compile sources build phase of the widget target
source_phase = widget_target.source_build_phase
[widget_swift_ref, article_ref].each do |file_ref|
  build_file = source_phase.files.find { |f| f.file_ref == file_ref }
  if build_file.nil?
    puts "Adding #{file_ref.path} to Widget compilation sources..."
    source_phase.add_file_reference(file_ref)
  end
end

# 4. Configure Build Settings
puts "Configuring build settings..."

widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'WellNewsWidget'
  config.build_settings['WRAPPER_EXTENSION'] = 'appex'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'jp.junya.WellNews.WellNewsWidget'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'WellNewsWidget/WellNewsWidget.entitlements'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = 'WellNewsWidget/Info.plist'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
end

main_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'WellNews/WellNews.entitlements'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
end

# 5. Set target dependencies
puts "Establishing target dependency..."
unless main_target.dependencies.any? { |d| d.target && d.target.name == 'WellNewsWidget' }
  main_target.add_dependency(widget_target)
  puts "Added dependency: WellNews depends on WellNewsWidget"
end

# 6. Embed App Extension in main bundle copy files phase
puts "Embedding App Extension..."
embed_phase = main_target.copy_files_build_phases.find { |phase| phase.dst_subfolder_spec == '13' }
if embed_phase.nil?
  embed_phase = main_target.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.dst_subfolder_spec = '13'
  puts "Created Embed App Extensions build phase"
end

widget_product = widget_target.product_reference
unless embed_phase.files.any? { |file| file.file_ref == widget_product }
  build_file = embed_phase.add_file_reference(widget_product)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  puts "Embedded WellNewsWidget.appex in main app PlugIns copy phase"
end

# 7. Ensure WidgetAssets.xcassets is in WellNewsWidget resources build phase
puts "Checking WidgetAssets.xcassets in Widget resources..."
assets_ref = widget_group.files.find { |f| f.path =~ /WidgetAssets\.xcassets$/ }
if assets_ref.nil?
  puts "Creating reference for WidgetAssets.xcassets..."
  assets_ref = widget_group.new_file('WidgetAssets.xcassets')
end

resources_phase = widget_target.resources_build_phase
build_file = resources_phase.files.find { |f| f.file_ref == assets_ref }
if build_file.nil?
  puts "Adding WidgetAssets.xcassets to Widget resources build phase..."
  resources_phase.add_file_reference(assets_ref)
else
  puts "WidgetAssets.xcassets is already in Widget resources build phase."
end



# Save project
puts "Saving project..."
project.save
puts "Xcode project configured successfully!"

