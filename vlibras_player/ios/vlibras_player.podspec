Pod::Spec.new do |s|
  s.name             = 'vlibras_player'
  s.version          = '0.1.0'
  s.summary          = 'VLibras Flutter plugin — text-to-Libras avatar translation.'
  s.description      = <<-DESC
    Flutter plugin that wraps VLibras (Brazilian Sign Language translation service)
    via WKWebView on iOS, exposing a MethodChannel + EventChannel to Dart.
  DESC
  s.homepage         = 'https://vlibras.gov.br'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Org' => 'dev@yourorg.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'
end
