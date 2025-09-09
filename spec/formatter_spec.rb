# frozen_string_literal: true

RSpec.describe LegalSummariser::Formatter do
  let(:sample_results) do
    {
      plain_text: "This is a sample legal document summary.",
      key_points: ["Contains confidentiality requirements", "Duration: 2 years"],
      clauses: {
        confidentiality: [
          { type: "Confidentiality", content: "All information shall remain confidential", position: 1, keywords: ["confidential"] }
        ],
        termination: [
          { type: "Termination", content: "Agreement may be terminated with 30 days notice", position: 2, keywords: ["terminated"] }
        ]
      },
      risks: {
        high_risks: [
          { type: "Unlimited Liability", description: "May expose to unlimited liability", severity: "high", recommendation: "Add liability caps" }
        ],
        medium_risks: [],
        compliance_gaps: [
          { type: "Missing GDPR", description: "No GDPR compliance", regulation: "GDPR", recommendation: "Add GDPR clauses" }
        ],
        unfair_terms: [],
        risk_score: { score: 15, level: "medium", total_issues: 2 }
      },
      metadata: {
        document_type: "nda",
        word_count: 150,
        character_count: 800,
        sentence_count: 8,
        paragraph_count: 3,
        processed_at: "2024-01-01T12:00:00+00:00"
      }
    }
  end

  describe ".format" do
    it "formats as JSON" do
      result = LegalSummariser::Formatter.format(sample_results, 'json')
      
      expect(result).to be_a(String)
      parsed = JSON.parse(result)
      expect(parsed['plain_text']).to eq(sample_results[:plain_text])
      expect(parsed['metadata']['document_type']).to eq('nda')
    end

    it "formats as markdown" do
      result = LegalSummariser::Formatter.format(sample_results, 'markdown')
      
      expect(result).to include("# Legal Document Analysis")
      expect(result).to include("## Summary")
      expect(result).to include("**Document Type:** Nda")
      expect(result).to include("**Word Count:** 150")
      expect(result).to include("## Key Points")
      expect(result).to include("- Contains confidentiality requirements")
      expect(result).to include("## Detected Clauses")
      expect(result).to include("### Confidentiality")
      expect(result).to include("## Risk Analysis")
      expect(result).to include("**Overall Risk Level:** MEDIUM")
      expect(result).to include("### ⚠️ High Risks")
      expect(result).to include("### 📋 Compliance Gaps")
    end

    it "formats as plain text" do
      result = LegalSummariser::Formatter.format(sample_results, 'text')
      
      expect(result).to include("LEGAL DOCUMENT ANALYSIS")
      expect(result).to include("Document Type: Nda")
      expect(result).to include("Word Count: 150")
      expect(result).to include("SUMMARY")
      expect(result).to include("KEY POINTS")
      expect(result).to include("1. Contains confidentiality requirements")
      expect(result).to include("RISK ANALYSIS")
      expect(result).to include("Overall Risk Level: MEDIUM")
      expect(result).to include("Total Issues Found: 2")
    end

    it "handles 'md' format alias" do
      result = LegalSummariser::Formatter.format(sample_results, 'md')
      expect(result).to include("# Legal Document Analysis")
    end

    it "handles 'txt' format alias" do
      result = LegalSummariser::Formatter.format(sample_results, 'txt')
      expect(result).to include("LEGAL DOCUMENT ANALYSIS")
    end

    it "raises error for unsupported format" do
      expect {
        LegalSummariser::Formatter.format(sample_results, 'unsupported')
      }.to raise_error(LegalSummariser::Error, /Unsupported format/)
    end
  end

  describe "markdown formatting edge cases" do
    it "handles empty key points" do
      results_without_points = sample_results.dup
      results_without_points[:key_points] = []
      
      result = LegalSummariser::Formatter.format(results_without_points, 'markdown')
      expect(result).not_to include("## Key Points")
    end

    it "handles empty clauses" do
      results_without_clauses = sample_results.dup
      results_without_clauses[:clauses] = { confidentiality: [], termination: [] }
      
      result = LegalSummariser::Formatter.format(results_without_clauses, 'markdown')
      expect(result).not_to include("## Detected Clauses")
    end

    it "truncates long clause content" do
      long_content = "A" * 300
      results_with_long_clause = sample_results.dup
      results_with_long_clause[:clauses][:confidentiality][0][:content] = long_content
      
      result = LegalSummariser::Formatter.format(results_with_long_clause, 'markdown')
      expect(result).to include("A" * 200 + "...")
    end
  end

  describe "text formatting edge cases" do
    it "handles missing risks section" do
      results_without_risks = sample_results.dup
      results_without_risks.delete(:risks)
      
      result = LegalSummariser::Formatter.format(results_without_risks, 'text')
      expect(result).not_to include("RISK ANALYSIS")
    end

    it "handles empty clauses in text format" do
      results_without_clauses = sample_results.dup
      results_without_clauses[:clauses] = {}
      
      result = LegalSummariser::Formatter.format(results_without_clauses, 'text')
      expect(result).not_to include("CLAUSES DETECTED")
    end
  end
end
