Pod::Spec.new do |s|
  s.name             = 'fg_apple_music'
  s.version          = '0.1.0'
  s.summary          = 'Jambatan MusicKit untuk FGMaps.'
  s.description      = 'Carian katalog Apple Music dan main lagu penuh melalui MusicKit (pelanggan sahaja).'
  s.homepage         = 'https://github.com/FaizGusion00/fgmap'
  s.license          = { :type => 'MIT' }
  s.author           = { 'FGMaps' => 'noreply@fgmaps.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'fg_apple_music/Sources/fg_apple_music/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.4'
  s.swift_version    = '5.9'
  s.frameworks       = 'MusicKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
