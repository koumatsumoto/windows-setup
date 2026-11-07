require 'tmpdir'
require 'fileutils'
require_relative '../../scripts/site/verify'

Dir.mktmpdir('verify-site-test-') do |root|
  site = File.join(root, '_site')
  FileUtils.mkdir_p(File.join(site, 'docs'))
  File.write(File.join(site, 'docs/index.html'), '<h1 id="日本語">Title</h1>')
  File.write(File.join(site, 'asset.css'), '')
  valid = '<a href="/windows-setup/docs/?q=1#%E6%97%A5%E6%9C%AC%E8%AA%9E">ok</a>' \
          '<a href="docs/#日本語">relative</a><a href="#home">self</a><h1 id="home">Home</h1>' \
          '<link href="asset.css"><a href="https://invalid.example/">external</a>' \
          '<a href="mailto:test@example.com">mail</a><img src="//invalid.example/a.png">'
  check = lambda do |html, expected|
    File.write(File.join(site, 'index.html'), html)
    errors = SiteVerification.verify(site, root, '/windows-setup')
    raise "unexpected result: #{errors.inspect}" unless expected ? errors.empty? : !errors.empty?
  end
  check.call(valid, true)
  ['docs/missing/', 'docs/#missing', '/docs/', '../outside.html', 'missing.png'].each do |link|
    check.call("<a href=\"#{link}\">bad</a>", false)
  end
  ['windows-setup-2026', '@openai/codex', '@anthropic-ai/claude-code', 'Qwen Code',
   'Antigravity', 'gh-copilot', 'gh-markdown-preview', '7-Zip', 'Git.Git',
   '~/work', '~/work/windows-setup', '$HOME/work/windows-setup',
   '/home/kou/work/windows-setup'].each do |text|
    check.call("<code>#{text}</code>", false)
  end
  check.call('<code>~/windows-setup ~/workflow ~/work-project</code>', true)
  check.call('<a href="https://example.com/windows-setup-2026/">old</a>', false)
  check.call(valid, true)
  FileUtils.mkdir_p(File.join(root, 'scripts/windows'))
  File.write(File.join(root, 'scripts/windows/SetupConfig.psd1'), "'7zip.7zip'")
  raise 'source regression missed' if SiteVerification.verify(site, root, '/windows-setup').empty?
  raise 'empty build passed' if SiteVerification.verify(File.join(root, 'absent'), root).empty?
end
puts 'Site regression tests PASS'
