# frozen_string_literal: true

require 'pdf-reader'
require 'docx'

module LegalSummariser
  class TextExtractor
    # Extract text from various document formats
    # @param file_path [String] Path to the document
    # @return [String] Extracted text
    def self.extract(file_path)
      case File.extname(file_path).downcase
      when '.pdf'
        extract_from_pdf(file_path)
      when '.docx'
        extract_from_docx(file_path)
      when '.txt'
        File.read(file_path, encoding: 'UTF-8')
      else
        raise UnsupportedFormatError, "Unsupported file format: #{File.extname(file_path)}"
      end
    end

    private

    # Extract text from PDF files
    # @param file_path [String] Path to PDF file
    # @return [String] Extracted text
    def self.extract_from_pdf(file_path)
      reader = PDF::Reader.new(file_path)
      text = ""
      
      reader.pages.each do |page|
        text += page.text + "\n"
      end
      
      # Clean up common PDF artifacts
      clean_text(text)
    rescue => e
      raise Error, "Failed to extract text from PDF: #{e.message}"
    end

    # Extract text from DOCX files
    # @param file_path [String] Path to DOCX file
    # @return [String] Extracted text
    def self.extract_from_docx(file_path)
      doc = Docx::Document.open(file_path)
      text = ""
      
      doc.paragraphs.each do |paragraph|
        text += paragraph.text + "\n"
      end
      
      clean_text(text)
    rescue => e
      raise Error, "Failed to extract text from DOCX: #{e.message}"
    end

    # Clean extracted text
    # @param text [String] Raw extracted text
    # @return [String] Cleaned text
    def self.clean_text(text)
      # Normalize line breaks first
      text = text.gsub(/\r\n?/, "\n")
      
      # Remove common PDF artifacts
      text = text.gsub(/\f/, '') # Form feed characters
      text = text.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, '') # Control characters
      
      # Remove excessive whitespace but preserve line breaks
      text = text.gsub(/[ \t]+/, ' ')
      
      # Remove excessive newlines
      text = text.gsub(/\n{3,}/, "\n\n")
      
      text.strip
    end
  end
end
