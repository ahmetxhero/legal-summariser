# frozen_string_literal: true

require 'json'

module LegalSummariser
  class Formatter
    # Format analysis results in specified format
    # @param results [Hash] Analysis results
    # @param format [String] Output format (json, markdown, text)
    # @return [String] Formatted output
    def self.format(results, format)
      case format.to_s.downcase
      when 'json'
        format_json(results)
      when 'markdown', 'md'
        format_markdown(results)
      when 'text', 'txt'
        format_text(results)
      else
        raise Error, "Unsupported format: #{format}"
      end
    end

    private

    # Format results as JSON
    # @param results [Hash] Analysis results
    # @return [String] JSON formatted string
    def self.format_json(results)
      JSON.pretty_generate(results)
    end

    # Format results as Markdown
    # @param results [Hash] Analysis results
    # @return [String] Markdown formatted string
    def self.format_markdown(results)
      md = []
      
      md << "# Legal Document Analysis"
      md << ""
      md << "**Document Type:** #{results[:metadata][:document_type].capitalize}"
      md << "**Word Count:** #{results[:metadata][:word_count]}"
      md << "**Processed:** #{results[:metadata][:processed_at]}"
      md << ""

      # Summary section
      md << "## Summary"
      md << ""
      md << results[:plain_text]
      md << ""

      # Key points
      if results[:key_points] && !results[:key_points].empty?
        md << "## Key Points"
        md << ""
        results[:key_points].each do |point|
          md << "- #{point}"
        end
        md << ""
      end

      # Clauses section
      if results[:clauses] && results[:clauses].any? { |_, clauses| !clauses.empty? }
        md << "## Detected Clauses"
        md << ""
        
        results[:clauses].each do |clause_type, clauses|
          next if clauses.empty?
          
          md << "### #{clause_type.to_s.split('_').map(&:capitalize).join(' ')}"
          md << ""
          
          clauses.each do |clause|
            md << "- **#{clause[:type]}**: #{clause[:content][0..200]}#{'...' if clause[:content].length > 200}"
          end
          md << ""
        end
      end

      # Risks section
      if results[:risks]
        md << "## Risk Analysis"
        md << ""
        
        risk_score = results[:risks][:risk_score]
        md << "**Overall Risk Level:** #{risk_score[:level].upcase} (Score: #{risk_score[:score]})"
        md << ""

        # High risks
        if results[:risks][:high_risks] && !results[:risks][:high_risks].empty?
          md << "### ⚠️ High Risks"
          md << ""
          results[:risks][:high_risks].each do |risk|
            md << "- **#{risk[:type]}**: #{risk[:description]}"
            md << "  - *Recommendation*: #{risk[:recommendation]}"
          end
          md << ""
        end

        # Medium risks
        if results[:risks][:medium_risks] && !results[:risks][:medium_risks].empty?
          md << "### ⚡ Medium Risks"
          md << ""
          results[:risks][:medium_risks].each do |risk|
            md << "- **#{risk[:type]}**: #{risk[:description]}"
            md << "  - *Recommendation*: #{risk[:recommendation]}"
          end
          md << ""
        end

        # Compliance gaps
        if results[:risks][:compliance_gaps] && !results[:risks][:compliance_gaps].empty?
          md << "### 📋 Compliance Gaps"
          md << ""
          results[:risks][:compliance_gaps].each do |gap|
            md << "- **#{gap[:type]}** (#{gap[:regulation]}): #{gap[:description]}"
            md << "  - *Recommendation*: #{gap[:recommendation]}"
          end
          md << ""
        end

        # Unfair terms
        if results[:risks][:unfair_terms] && !results[:risks][:unfair_terms].empty?
          md << "### ⚖️ Potentially Unfair Terms"
          md << ""
          results[:risks][:unfair_terms].each do |term|
            md << "- **#{term[:type]}**: #{term[:description]}"
            md << "  - *Impact*: #{term[:impact]}"
            md << "  - *Recommendation*: #{term[:recommendation]}"
          end
          md << ""
        end
      end

      md.join("\n")
    end

    # Format results as plain text
    # @param results [Hash] Analysis results
    # @return [String] Plain text formatted string
    def self.format_text(results)
      text = []
      
      text << "LEGAL DOCUMENT ANALYSIS"
      text << "=" * 50
      text << ""
      text << "Document Type: #{results[:metadata][:document_type].capitalize}"
      text << "Word Count: #{results[:metadata][:word_count]}"
      text << "Processed: #{results[:metadata][:processed_at]}"
      text << ""

      # Summary
      text << "SUMMARY"
      text << "-" * 20
      text << results[:plain_text]
      text << ""

      # Key points
      if results[:key_points] && !results[:key_points].empty?
        text << "KEY POINTS"
        text << "-" * 20
        results[:key_points].each_with_index do |point, index|
          text << "#{index + 1}. #{point}"
        end
        text << ""
      end

      # Risk analysis
      if results[:risks]
        text << "RISK ANALYSIS"
        text << "-" * 20
        
        risk_score = results[:risks][:risk_score]
        text << "Overall Risk Level: #{risk_score[:level].upcase} (Score: #{risk_score[:score]})"
        text << "Total Issues Found: #{risk_score[:total_issues]}"
        text << ""

        # List all risks
        all_risks = []
        all_risks.concat(results[:risks][:high_risks] || [])
        all_risks.concat(results[:risks][:medium_risks] || [])
        all_risks.concat(results[:risks][:compliance_gaps] || [])
        all_risks.concat(results[:risks][:unfair_terms] || [])

        if !all_risks.empty?
          text << "Issues Found:"
          all_risks.each_with_index do |risk, index|
            severity = risk[:severity] || risk[:regulation] || "concern"
            text << "#{index + 1}. [#{severity.upcase}] #{risk[:type]}: #{risk[:description]}"
          end
        end
        text << ""
      end

      # Clause summary
      if results[:clauses]
        clause_count = results[:clauses].values.flatten.length
        if clause_count > 0
          text << "CLAUSES DETECTED"
          text << "-" * 20
          text << "Total clauses found: #{clause_count}"
          
          results[:clauses].each do |clause_type, clauses|
            next if clauses.empty?
            text << "#{clause_type.to_s.split('_').map(&:capitalize).join(' ')}: #{clauses.length}"
          end
        end
      end

      text.join("\n")
    end
  end
end
