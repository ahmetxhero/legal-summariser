# frozen_string_literal: true

require_relative "legal_summariser/version"
require_relative "legal_summariser/document_parser"
require_relative "legal_summariser/text_extractor"
require_relative "legal_summariser/summariser"
require_relative "legal_summariser/clause_detector"
require_relative "legal_summariser/risk_analyzer"
require_relative "legal_summariser/formatter"

module LegalSummariser
  class Error < StandardError; end
  class DocumentNotFoundError < Error; end
  class UnsupportedFormatError < Error; end

  # Main entry point for the legal summariser
  # @param file_path [String] Path to the legal document
  # @param options [Hash] Configuration options
  # @return [Hash] Summary results
  def self.summarise(file_path, options = {})
    raise DocumentNotFoundError, "File not found: #{file_path}" unless File.exist?(file_path)

    # Extract text from document
    text = TextExtractor.extract(file_path)
    
    # Perform analysis
    summary = Summariser.new(text, options).generate
    clauses = ClauseDetector.new(text).detect
    risks = RiskAnalyzer.new(text).analyze
    
    # Format results
    result = {
      plain_text: summary[:plain_text],
      key_points: summary[:key_points],
      clauses: clauses,
      risks: risks,
      metadata: {
        document_type: detect_document_type(text),
        word_count: text.split.length,
        processed_at: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z")
      }
    }

    # Apply formatting if requested
    if options[:format]
      Formatter.format(result, options[:format])
    else
      result
    end
  end

  # Detect the type of legal document
  # @param text [String] Document text
  # @return [String] Document type
  def self.detect_document_type(text)
    case text.downcase
    when /non.?disclosure|nda|confidentiality/
      "nda"
    when /service agreement|terms of service|tos/
      "service_agreement"
    when /employment|job|position/
      "employment_contract"
    when /privacy policy|data protection|gdpr|kvkk/
      "privacy_policy"
    when /license|licensing/
      "license_agreement"
    else
      "general_contract"
    end
  end
end
