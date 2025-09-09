# frozen_string_literal: true

require_relative "lib/legal_summariser/version"

Gem::Specification.new do |spec|
  spec.name = "legal_summariser"
  spec.version = LegalSummariser::VERSION
  spec.authors = ["Legal Summariser Team"]
  spec.email = ["info@legal-summariser.com"]

  spec.summary = "AI-powered legal document summarisation and analysis toolkit"
  spec.description = "A Ruby gem that summarises legal documents, extracts key clauses, flags risks, and converts legal jargon into plain English. Supports PDF/Word documents with offline processing capabilities."
  spec.homepage = "https://github.com/legal-summariser/legal_summariser"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/legal-summariser/legal_summariser"
  spec.metadata["changelog_uri"] = "https://github.com/legal-summariser/legal_summariser/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z 2>/dev/null`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies for document processing
  spec.add_dependency "pdf-reader", "~> 2.11"
  spec.add_dependency "docx", "~> 0.8"
  spec.add_dependency "nokogiri", "~> 1.13"
  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "json", "~> 2.6"

  # Development dependencies
  spec.add_development_dependency "bundler", ">= 1.17"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "yard", "~> 0.9"
end
