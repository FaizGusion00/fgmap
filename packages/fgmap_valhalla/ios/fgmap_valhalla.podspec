Pod::Spec.new do |s|
  s.name             = 'fgmap_valhalla'
  s.version          = '0.0.1'
  s.summary          = 'Sandaran CocoaPods untuk fgmap_valhalla (tanpa enjin offline; gunakan Swift Package Manager).'
  s.description      = 'Enjin offline iOS memerlukan Swift Package Manager (valhalla-mobile). Pod ini hanya stub.'
  s.homepage         = 'https://github.com/fguniversalempire/fgmap'
  s.license          = { :type => 'Proprietary', :text => 'FG Universal Empire Company' }
  s.author           = { 'FG Universal Empire Company' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.4'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
