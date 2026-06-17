Pod::Spec.new do |s|
  s.name             = 'bulter_sqlite_vec'
  s.version          = '0.1.0'
  s.summary          = 'Bulter vendored sqlite-vec FFI plugin.'
  s.description      = 'Embedded sqlite-vec v0.1.7-alpha.3 sources; build on iOS via src/sqlite-vec.c.'
  s.homepage         = 'https://github.com/asg017/sqlite-vec/tree/v0.1.7-alpha.3'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Bulter' => 'dev@bulter.local' }
  s.source           = { :path => '.' }

  s.ios.deployment_target = '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.source_files = 'Classes/**/*', '../src/sqlite-vec.c'
  s.public_header_files = '../src/sqlite-vec.h'
  s.requires_arc = true
  s.libraries = 'c'
  s.compiler_flags = '-DSQLITE_VEC_STATIC'
end
