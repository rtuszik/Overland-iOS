# Uncomment this line to define a global platform for your project

platform :ios, '26.0'

target 'Overland' do
	pod 'AFNetworking', '4.0.1'
	pod 'FMDB', '2.7.5'
end

# Xcode 16+ rejects AFNetworking 4.0.1's private <netinet6/in6.h> import. Redundant, strip it.
post_install do |installer|
	# FMDB and AFNetworking declare iOS 4.3 and 9.0, below what the SDK supports.
	installer.pods_project.targets.each do |target|
		target.build_configurations.each do |config|
			config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
		end
	end

	af_root = File.join(installer.sandbox.root, 'AFNetworking')
	Dir.glob(File.join(af_root, '**', '*.m')).each do |file|
		text = File.read(file)
		patched = text.gsub(/^#import <netinet6\/in6\.h>\n/, '')
		next if patched == text
		mode = File.stat(file).mode
		File.chmod(0644, file)
		File.write(file, patched)
		File.chmod(mode, file)
	end
end

