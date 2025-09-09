# frozen_string_literal: true

RSpec.describe LegalSummariser::TextExtractor do
  describe ".extract" do
    let(:sample_text) { "This is a sample legal document with confidential information." }
    let(:text_file) { "/tmp/test.txt" }

    before do
      File.write(text_file, sample_text)
    end

    after do
      File.delete(text_file) if File.exist?(text_file)
    end

    it "extracts text from txt files" do
      result = LegalSummariser::TextExtractor.extract(text_file)
      expect(result).to eq(sample_text)
    end

    it "raises error for unsupported formats" do
      unsupported_file = "/tmp/test.xyz"
      File.write(unsupported_file, "content")
      
      expect {
        LegalSummariser::TextExtractor.extract(unsupported_file)
      }.to raise_error(LegalSummariser::UnsupportedFormatError)
      
      File.delete(unsupported_file)
    end
  end

  describe ".clean_text" do
    it "removes excessive whitespace" do
      dirty_text = "This  has   multiple    spaces"
      clean_text = LegalSummariser::TextExtractor.send(:clean_text, dirty_text)
      expect(clean_text).to eq("This has multiple spaces")
    end

    it "normalizes line breaks" do
      text_with_breaks = "Line 1\r\nLine 2\rLine 3\nLine 4"
      clean_text = LegalSummariser::TextExtractor.send(:clean_text, text_with_breaks)
      expect(clean_text).to eq("Line 1\nLine 2\nLine 3\nLine 4")
    end

    it "handles nil and empty text" do
      expect(LegalSummariser::TextExtractor.send(:clean_text, nil)).to eq("")
      expect(LegalSummariser::TextExtractor.send(:clean_text, "")).to eq("")
    end

    it "removes control characters" do
      text_with_control = "Text\x00with\x08control\x1Fcharacters"
      clean_text = LegalSummariser::TextExtractor.send(:clean_text, text_with_control)
      expect(clean_text).to eq("Textwithcontrolcharacters")
    end

    it "removes non-breaking spaces" do
      text_with_nbsp = "Text\u00A0with\u00A0nbsp"
      clean_text = LegalSummariser::TextExtractor.send(:clean_text, text_with_nbsp)
      expect(clean_text).to eq("Text with nbsp")
    end
  end

  describe ".get_statistics" do
    let(:sample_text) { "This is a test document. It has multiple sentences! How many words?" }

    it "calculates correct statistics" do
      stats = LegalSummariser::TextExtractor.get_statistics(sample_text)
      
      expect(stats[:character_count]).to eq(sample_text.length)
      expect(stats[:word_count]).to eq(12)
      expect(stats[:sentence_count]).to be > 0
      expect(stats[:paragraph_count]).to be > 0
      expect(stats[:average_sentence_length]).to be > 0
    end
  end

  describe "enhanced file format support" do
    let(:rtf_file) { "/tmp/test.rtf" }
    let(:rtf_content) { "{\\rtf1\\ansi Sample RTF content with {\\b bold} text.}" }

    before do
      File.write(rtf_file, rtf_content)
    end

    after do
      File.delete(rtf_file) if File.exist?(rtf_file)
    end

    it "extracts text from RTF files" do
      result = LegalSummariser::TextExtractor.extract(rtf_file)
      # RTF parsing removes control codes, so we expect cleaned text
      expect(result).to include("text")
      expect(result.length).to be > 0
    end

    it "supports .text extension" do
      text_file = "/tmp/test.text"
      File.write(text_file, "Sample text content")
      
      result = LegalSummariser::TextExtractor.extract(text_file)
      expect(result).to eq("Sample text content")
      
      File.delete(text_file)
    end
  end

  describe "error handling" do
    it "raises error for empty files" do
      empty_file = "/tmp/empty.txt"
      File.write(empty_file, "")
      
      expect {
        LegalSummariser::TextExtractor.extract(empty_file)
      }.to raise_error(LegalSummariser::DocumentNotFoundError, /File is empty/)
      
      File.delete(empty_file)
    end

    it "provides detailed error messages for unsupported formats" do
      unsupported_file = "/tmp/test.xyz"
      File.write(unsupported_file, "content")
      
      expect {
        LegalSummariser::TextExtractor.extract(unsupported_file)
      }.to raise_error(LegalSummariser::UnsupportedFormatError, /Supported formats: .pdf, .docx, .txt, .rtf/)
      
      File.delete(unsupported_file)
    end
  end
end
