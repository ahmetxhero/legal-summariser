# frozen_string_literal: true

require 'pdf-reader'
require 'docx'
require 'logger'

module LegalSummariser
  class TextExtractor
    # Logger for debugging and monitoring
    def self.logger
      @logger ||= Logger.new(STDOUT, level: Logger::WARN)
    end

    def self.logger=(logger)
      @logger = logger
    end
    # Extract text from various document formats
    # @param file_path [String] Path to the document
    # @return [String] Extracted text
    def self.extract(file_path)
      raise DocumentNotFoundError, "File not found: #{file_path}" unless File.exist?(file_path)
      raise DocumentNotFoundError, "File is empty: #{file_path}" if File.zero?(file_path)
      
      logger.info "Extracting text from: #{file_path}"
      
      case File.extname(file_path).downcase
      when '.pdf'
        extract_from_pdf(file_path)
      when '.docx'
        extract_from_docx(file_path)
      when '.txt', '.text'
        extract_from_text(file_path)
      when '.rtf'
        extract_from_rtf(file_path)
      else
        raise UnsupportedFormatError, "Unsupported file format: #{File.extname(file_path)}. Supported formats: .pdf, .docx, .txt, .rtf"
      end
    end

    private

    # Extract text from PDF files
    # @param file_path [String] Path to PDF file
    # @return [String] Extracted text
    def self.extract_from_pdf(file_path)
      logger.debug "Processing PDF: #{file_path}"
      
      reader = PDF::Reader.new(file_path)
      text = ""
      page_count = 0
      
      reader.pages.each do |page|
        page_count += 1
        page_text = page.text
        text += page_text + "\n" if page_text && !page_text.strip.empty?
      end
      
      logger.info "Extracted text from #{page_count} PDF pages"
      
      if text.strip.empty?
        logger.warn "No text extracted from PDF - file may be image-based or encrypted"
        raise Error, "No extractable text found in PDF. File may be image-based or password-protected."
      end
      
      clean_text(text)
    rescue PDF::Reader::MalformedPDFError => e
      raise Error, "Malformed PDF file: #{e.message}"
    rescue PDF::Reader::UnsupportedFeatureError => e
      raise Error, "PDF contains unsupported features: #{e.message}"
    rescue => e
      raise Error, "Failed to extract text from PDF: #{e.message}"
    end

    # Extract text from DOCX files
    # @param file_path [String] Path to DOCX file
    # @return [String] Extracted text
    def self.extract_from_docx(file_path)
      logger.debug "Processing DOCX: #{file_path}"
      
      doc = Docx::Document.open(file_path)
      text = ""
      paragraph_count = 0
      
      doc.paragraphs.each do |paragraph|
        paragraph_text = paragraph.text
        if paragraph_text && !paragraph_text.strip.empty?
          text += paragraph_text + "\n"
          paragraph_count += 1
        end
      end
      
      # Also extract text from tables if present
      doc.tables.each do |table|
        table.rows.each do |row|
          row.cells.each do |cell|
            cell_text = cell.text
            text += cell_text + " " if cell_text && !cell_text.strip.empty?
          end
          text += "\n"
        end
      end
      
      logger.info "Extracted text from #{paragraph_count} DOCX paragraphs"
      
      if text.strip.empty?
        raise Error, "No text content found in DOCX file"
      end
      
      clean_text(text)
    rescue Zip::Error => e
      raise Error, "Invalid DOCX file format: #{e.message}"
    rescue => e
      raise Error, "Failed to extract text from DOCX: #{e.message}"
    end

    # Extract text from plain text files
    # @param file_path [String] Path to text file
    # @return [String] Extracted text
    def self.extract_from_text(file_path)
      logger.debug "Processing text file: #{file_path}"
      
      # Try different encodings
      encodings = ['UTF-8', 'ISO-8859-1', 'Windows-1252']
      
      encodings.each do |encoding|
        begin
          text = File.read(file_path, encoding: encoding)
          logger.info "Successfully read text file with #{encoding} encoding"
          return clean_text(text)
        rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
          logger.debug "Failed to read with #{encoding} encoding, trying next"
          next
        end
      end
      
      raise Error, "Unable to read text file with supported encodings"
    end

    # Extract text from RTF files (basic support)
    # @param file_path [String] Path to RTF file
    # @return [String] Extracted text
    def self.extract_from_rtf(file_path)
      logger.debug "Processing RTF: #{file_path}"
      
      content = File.read(file_path, encoding: 'UTF-8')
      
      # Basic RTF parsing - remove RTF control codes
      text = content.gsub(/\{[^}]*\}/, '') # Remove RTF groups
      text = text.gsub(/\\[a-z]+\d*\s?/, '') # Remove RTF commands
      text = text.gsub(/\\[^a-z]/, '') # Remove RTF escape sequences
      
      clean_text(text)
    rescue => e
      raise Error, "Failed to extract text from RTF: #{e.message}"
    end

    # Clean extracted text
    # @param text [String] Raw extracted text
    # @return [String] Cleaned text
    def self.clean_text(text)
      return "" if text.nil? || text.empty?
      
      # Normalize line breaks first
      text = text.gsub(/\r\n?/, "\n")
      
      # Remove common document artifacts
      text = text.gsub(/\f/, '') # Form feed characters
      text = text.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, '') # Control characters
      text = text.gsub(/\u00A0/, ' ') # Non-breaking spaces
      
      # Remove excessive whitespace but preserve line breaks
      text = text.gsub(/[ \t]+/, ' ')
      
      # Remove excessive newlines
      text = text.gsub(/\n{3,}/, "\n\n")
      
      # Remove leading/trailing whitespace from each line
      text = text.split("\n").map(&:strip).join("\n")
      
      # Remove empty lines at start and end
      text.strip
    end

    # Get document statistics
    # @param text [String] Document text
    # @return [Hash] Document statistics
    def self.get_statistics(text)
      {
        character_count: text.length,
        word_count: text.split(/\s+/).length,
        sentence_count: text.split(/[.!?]+/).length,
        paragraph_count: text.split(/\n\s*\n/).length,
        average_sentence_length: text.split(/\s+/).length.to_f / text.split(/[.!?]+/).length
      }
    end
  end
end
