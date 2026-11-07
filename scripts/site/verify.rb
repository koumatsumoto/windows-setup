require 'nokogiri'
require 'uri'

# Deliberately narrow regression rules, not a general tool allowlist.
module SiteVerification
  FORBIDDEN = {
    '旧リポジトリ名' => /windows-setup-2026/i,
    '旧 AI CLI npm パッケージ' => /@(?:openai\/codex|anthropic-ai\/claude-code)\b/i,
    '廃止ツール' => /\b(?:qwen(?:-code)?|antigravity(?:-ai)?|gh-copilot|gh-markdown-preview|7-zip|7zip\.7zip|Oracle\.MySQLWorkbench|Logitech\.GHUB|Discord\.Discord|Microsoft\.Edit)\b/i,
    'Windows 開発 CLI 導入' => /\b(?:Git\.Git|GitHub\.cli|Schniz\.fnm|Python\.Python\.\d+)\b/i,
    '旧 WSL 作業パス' => %r{(?:~|\$HOME|/home/kou)/work(?:/|\z|[\s`"'<>])}
  }.freeze

  def self.content_errors(text, label)
    FORBIDDEN.filter_map { |name, pattern| "#{label}: #{name}" if text.match?(pattern) }
  end

  def self.verify(site, source, baseurl = '')
    root = File.expand_path(site)
    baseurl = '/' + baseurl.split('/').reject(&:empty?).join('/')
    baseurl = '' if baseurl == '/'
    files = Dir.glob("#{root}/**/*.html")
    errors = []
    errors << "#{site}: HTML がありません。先に Jekyll build を実行してください。" if files.empty?
    documents = files.to_h { |file| [file, Nokogiri::HTML(File.read(file))] }
    documents.each do |file, doc|
      errors.concat(content_errors(doc.text, file))
      # Inspect attributes too: retired repository names can survive only in URLs.
      doc.css('[href], [src]').each do |node|
        %w[href src].each do |attribute|
          link = node[attribute]
          next unless link
          errors.concat(content_errors(link, file))
          next if link.match?(/\A(?:[a-z][a-z0-9+.-]*:|\/\/)/i)

          path, fragment = link.split('#', 2)
          path = URI::DEFAULT_PARSER.unescape(path.split('?', 2).first.to_s)
          if path.start_with?('/') && !baseurl.empty?
            unless path == baseurl || path.start_with?(baseurl + '/')
              errors << "#{file}: baseurl 外の内部リンク #{link}"
              next
            end
            path = path.delete_prefix(baseurl)
            path = '/' if path.empty?
          end
          target = if path.empty?
                     file
                   elsif path.start_with?('/')
                     File.expand_path('.' + path, root)
                   else
                     File.expand_path(path, File.dirname(file))
                   end
          target = File.join(target, 'index.html') if File.directory?(target)
          unless target.start_with?(root + '/') && File.file?(target)
            errors << "#{file}: 内部リンク切れ #{link}"
            next
          end
          next if fragment.nil? || fragment.empty? || !documents.key?(target)

          anchor = URI::DEFAULT_PARSER.unescape(fragment)
          found = documents[target].css('[id], a[name]').any? { |n| n['id'] == anchor || n['name'] == anchor }
          errors << "#{file}: アンカー切れ #{link}" unless found
        end
      end
    end
    # Keep tests and the rule definitions out of the scanned installation surface.
    patterns = %w[README.md index.md docs/**/*.md scripts/wsl/*.sh scripts/shell/*.sh scripts/windows/*]
    patterns.flat_map { |pattern| Dir.glob(File.join(source, pattern)) }.each do |file|
      errors.concat(content_errors(File.read(file), file)) if File.file?(file)
    end
    errors.uniq
  end
end

if $PROGRAM_NAME == __FILE__
  abort 'usage: bin/verify-site [site-directory [baseurl]]' if ARGV.length > 2
  errors = SiteVerification.verify(ARGV[0] || '_site', Dir.pwd, ARGV[1] || '')
  abort errors.join("\n") unless errors.empty?
  puts 'Site verification PASS'
end
