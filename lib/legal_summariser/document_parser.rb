# frozen_string_literal: true

module LegalSummariser
  # Legacy compatibility - DocumentParser is now handled by TextExtractor
  class DocumentParser
    def self.parse(file_path)
      TextExtractor.extract(file_path)
    end
  end
end
