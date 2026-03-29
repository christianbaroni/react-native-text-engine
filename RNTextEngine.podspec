require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

worklets_podspec_paths = [
  File.expand_path("node_modules/react-native-worklets/RNWorklets.podspec", __dir__),
  File.expand_path("../react-native-worklets/RNWorklets.podspec", __dir__),
  File.expand_path("../node_modules/react-native-worklets/RNWorklets.podspec", __dir__),
]

has_worklets_pod = worklets_podspec_paths.any? { |path| File.exist?(path) }

Pod::Spec.new do |s|
  s.name         = "RNTextEngine"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "13.0" }
  s.source       = { :git => "https://github.com/christianbaroni/react-native-text-engine.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm}"

  install_modules_dependencies(s)
  s.dependency "React-debug"
  s.dependency "React-rendererdebug"
  s.dependency "RNWorklets" if has_worklets_pod
end
