Gem::Specification.new do |s|
  s.name = 'code-snippets'
  s.version = '0.3.2'
  s.summary = 'code-snippets'
    s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('dynarex-usersblog') 
  s.signing_key = '../privatekeys/code-snippets.pem'
  s.cert_chain  = ['gem-public_cert.pem']
end
