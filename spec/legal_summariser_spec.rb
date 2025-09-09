# frozen_string_literal: true

RSpec.describe LegalSummariser do
  it "has a version number" do
    expect(LegalSummariser::VERSION).not_to be nil
  end

  describe ".summarise" do
    let(:sample_text_file) { "/tmp/test_legal_doc.txt" }
    let(:sample_content) do
      <<~TEXT
        NON-DISCLOSURE AGREEMENT

        This Non-Disclosure Agreement establishes confidentiality obligations between Company ABC and John Doe.
        The Receiving Party agrees to hold confidential information in strict confidence for two years.
        The Receiving Party shall be liable for any breach of this Agreement.
        This Agreement may be terminated by either party with thirty days written notice.
        This Agreement shall be governed by the laws of England and Wales.
      TEXT
    end

    before do
      File.write(sample_text_file, sample_content)
    end

    after do
      File.delete(sample_text_file) if File.exist?(sample_text_file)
    end

    it "summarises a legal document" do
      result = LegalSummariser.summarise(sample_text_file)
      
      expect(result).to be_a(Hash)
      expect(result).to have_key(:plain_text)
      expect(result).to have_key(:key_points)
      expect(result).to have_key(:clauses)
      expect(result).to have_key(:risks)
      expect(result).to have_key(:metadata)
    end

    it "detects document type correctly" do
      result = LegalSummariser.summarise(sample_text_file)
      expect(result[:metadata][:document_type]).to eq("nda")
    end

    it "raises error for non-existent file" do
      expect {
        LegalSummariser.summarise("/non/existent/file.txt")
      }.to raise_error(LegalSummariser::DocumentNotFoundError)
    end

    it "formats output when format option is provided" do
      result = LegalSummariser.summarise(sample_text_file, format: 'json')
      expect(result).to be_a(String)
      expect { JSON.parse(result) }.not_to raise_error
    end
  end

  describe ".detect_document_type" do
    it "detects NDA documents" do
      text = "This non-disclosure agreement establishes confidentiality"
      expect(LegalSummariser.detect_document_type(text)).to eq("nda")
    end

    it "detects service agreements" do
      text = "This service agreement defines the terms for service delivery"
      expect(LegalSummariser.detect_document_type(text)).to eq("service_agreement")
    end

    it "detects employment contracts" do
      text = "This employment contract outlines the job position"
      expect(LegalSummariser.detect_document_type(text)).to eq("employment_contract")
    end

    it "defaults to general contract" do
      text = "This is some random legal text"
      expect(LegalSummariser.detect_document_type(text)).to eq("general_contract")
    end
  end
end
