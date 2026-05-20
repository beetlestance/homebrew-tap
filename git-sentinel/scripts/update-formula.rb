#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

options = {
  formula: "Formula/git-sentinel.rb"
}

OptionParser.new do |parser|
  parser.banner = "Usage: update-formula.rb --url URL --sha256 SHA256 --version VERSION [--formula PATH]"

  parser.on("--formula PATH", "Formula path") { |value| options[:formula] = value }
  parser.on("--url URL", "Release archive URL") { |value| options[:url] = value }
  parser.on("--sha256 SHA256", "Release archive SHA256") { |value| options[:sha256] = value }
  parser.on("--version VERSION", "Release version") { |value| options[:version] = value }
end.parse!

missing = %i[url sha256 version].select { |key| options[key].nil? || options[key].empty? }
unless missing.empty?
  warn "Missing required option(s): #{missing.map { |key| "--#{key}" }.join(", ")}"
  exit 1
end

formula_path = options[:formula]
formula = File.read(formula_path)
stable_block = %(  url "#{options[:url]}"\n  sha256 "#{options[:sha256]}"\n  version "#{options[:version]}"\n)

updated =
  if formula.match?(/^  url "/)
    formula.sub(/^  url ".*"\n  sha256 ".*"\n  version ".*"\n/, stable_block)
  else
    formula.sub(/^  head /, "#{stable_block}  head ")
  end

if updated == formula
  warn "Formula was not updated; expected a stable block or head line in #{formula_path}"
  exit 1
end

File.write(formula_path, updated)
