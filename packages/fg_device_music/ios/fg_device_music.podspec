Pod::Spec.new do |s|
  s.name             = 'fg_device_music'
  s.version          = '0.1.0'
  s.summary          = 'Senarai lagu pada peranti untuk FGMaps.'
  s.description      = 'Membaca metadata lagu pada iPhone (MPMediaLibrary) selepas pengguna memberi kebenaran.'
  s.homepage         = 'https://github.com/FaizGusion00/fgmap'
  s.license          = { :type => 'MIT' }
  s.author           = { 'FGMaps' => 'noreply@fgmaps.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'fg_device_music/Sources/fg_device_music/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.4'
  s.swift_version    = '5.9'
  s.frameworks       = 'MediaPlayer'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
