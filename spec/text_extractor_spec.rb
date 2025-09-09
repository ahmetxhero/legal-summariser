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
  end
end
