#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Batch processing multiple legal documents
require 'legal_summariser'

# Configure for batch processing
LegalSummariser.configure do |config|
  config.enable_caching = true
  config.logger = Logger.new(STDOUT, level: Logger::INFO)
end

# Example file paths (replace with your actual files)
file_paths = [
  'contracts/nda_company_a.pdf',
  'contracts/service_agreement_b.docx',
  'contracts/employment_contract_c.txt',
  'policies/privacy_policy.pdf'
]

puts "=== Batch Processing Legal Documents ==="
puts "Processing #{file_paths.length} documents..."

# Batch process all documents
results = LegalSummariser.batch_summarise(file_paths, {
  format: 'json',
  max_sentences: 4
})

# Analyze results
successful = results.select { |r| r[:success] }
failed = results.reject { |r| r[:success] }

puts "\nBatch Processing Results:"
puts "✓ Successful: #{successful.length}"
puts "✗ Failed: #{failed.length}"

# Process successful results
if successful.any?
  puts "\n=== Successful Analyses ==="
  
  successful.each do |result|
    analysis = JSON.parse(result[:result], symbolize_names: true)
    
    puts "\nFile: #{File.basename(result[:file_path])}"
    puts "Type: #{analysis[:metadata][:document_type]}"
    puts "Words: #{analysis[:metadata][:word_count]}"
    puts "Risk Level: #{analysis[:risks][:risk_score][:level].upcase}"
    
    # Show key risks
    high_risks = analysis[:risks][:high_risks]
    if high_risks.any?
      puts "High Risks: #{high_risks.map { |r| r[:type] }.join(', ')}"
    end
  end
  
  # Generate summary report
  puts "\n=== Summary Report ==="
  
  # Document type distribution
  doc_types = successful.map do |result|
    JSON.parse(result[:result], symbolize_names: true)[:metadata][:document_type]
  end
  
  type_counts = doc_types.group_by(&:itself).transform_values(&:count)
  puts "Document Types:"
  type_counts.each { |type, count| puts "  #{type}: #{count}" }
  
  # Risk level distribution
  risk_levels = successful.map do |result|
    JSON.parse(result[:result], symbolize_names: true)[:risks][:risk_score][:level]
  end
  
  risk_counts = risk_levels.group_by(&:itself).transform_values(&:count)
  puts "Risk Levels:"
  risk_counts.each { |level, count| puts "  #{level}: #{count}" }
  
  # Average processing metrics
  word_counts = successful.map do |result|
    JSON.parse(result[:result], symbolize_names: true)[:metadata][:word_count]
  end
  
  avg_words = word_counts.sum.to_f / word_counts.length
  puts "Average Document Size: #{avg_words.round} words"
end

# Show failed analyses
if failed.any?
  puts "\n=== Failed Analyses ==="
  failed.each do |result|
    puts "✗ #{File.basename(result[:file_path])}: #{result[:error]}"
  end
end

# Export results to files
puts "\n=== Exporting Results ==="
require 'fileutils'

output_dir = 'analysis_results'
FileUtils.mkdir_p(output_dir)

successful.each do |result|
  filename = File.basename(result[:file_path], '.*')
  output_file = File.join(output_dir, "#{filename}_analysis.json")
  
  File.write(output_file, result[:result])
  puts "Exported: #{output_file}"
end

# Generate consolidated report
consolidated_report = {
  processed_at: Time.now.iso8601,
  total_files: file_paths.length,
  successful: successful.length,
  failed: failed.length,
  results: results
}

report_file = File.join(output_dir, 'batch_report.json')
File.write(report_file, JSON.pretty_generate(consolidated_report))
puts "Consolidated report: #{report_file}"

puts "\nBatch processing completed!"
