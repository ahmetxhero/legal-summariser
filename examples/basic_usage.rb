#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Basic usage of Legal Summariser gem
require 'legal_summariser'

# Configure the gem (optional)
LegalSummariser.configure do |config|
  config.language = 'en'
  config.enable_caching = true
  config.max_file_size = 10 * 1024 * 1024 # 10MB
end

# Example 1: Basic document analysis
puts "=== Basic Document Analysis ==="
begin
  # Analyze a document (replace with your actual file path)
  result = LegalSummariser.summarise('sample_contract.pdf')
  
  puts "Document Type: #{result[:metadata][:document_type]}"
  puts "Word Count: #{result[:metadata][:word_count]}"
  puts "\nSummary:"
  puts result[:plain_text]
  
  puts "\nKey Points:"
  result[:key_points].each_with_index do |point, index|
    puts "#{index + 1}. #{point}"
  end
  
rescue LegalSummariser::DocumentNotFoundError => e
  puts "Error: #{e.message}"
rescue LegalSummariser::UnsupportedFormatError => e
  puts "Error: #{e.message}"
end

# Example 2: Analysis with custom options
puts "\n=== Custom Analysis Options ==="
options = {
  max_sentences: 3,
  format: 'markdown'
}

begin
  result = LegalSummariser.summarise('sample_contract.pdf', options)
  puts result
rescue => e
  puts "Error: #{e.message}"
end

# Example 3: Risk analysis focus
puts "\n=== Risk Analysis ==="
begin
  result = LegalSummariser.summarise('sample_contract.pdf')
  
  risks = result[:risks]
  puts "Overall Risk Level: #{risks[:risk_score][:level].upcase}"
  puts "Risk Score: #{risks[:risk_score][:score]}"
  
  if risks[:high_risks].any?
    puts "\nHigh Risks Found:"
    risks[:high_risks].each do |risk|
      puts "- #{risk[:type]}: #{risk[:description]}"
      puts "  Recommendation: #{risk[:recommendation]}"
    end
  end
  
  if risks[:compliance_gaps].any?
    puts "\nCompliance Gaps:"
    risks[:compliance_gaps].each do |gap|
      puts "- #{gap[:type]} (#{gap[:regulation]}): #{gap[:description]}"
    end
  end
  
rescue => e
  puts "Error: #{e.message}"
end

# Example 4: Clause detection
puts "\n=== Clause Detection ==="
begin
  result = LegalSummariser.summarise('sample_contract.pdf')
  
  result[:clauses].each do |clause_type, clauses|
    next if clauses.empty?
    
    puts "\n#{clause_type.to_s.split('_').map(&:capitalize).join(' ')} Clauses:"
    clauses.each_with_index do |clause, index|
      puts "#{index + 1}. #{clause[:content][0..100]}..."
    end
  end
  
rescue => e
  puts "Error: #{e.message}"
end

# Example 5: Performance monitoring
puts "\n=== Performance Statistics ==="
stats = LegalSummariser.stats
puts "Performance: #{stats[:performance]}"
puts "Cache: #{stats[:cache]}"
puts "Memory: #{stats[:memory]}"
