#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Advanced configuration and customization
require 'legal_summariser'
require 'logger'

puts "=== Advanced Legal Summariser Configuration ==="

# Example 1: Custom logging configuration
puts "\n1. Custom Logging Setup"
custom_logger = Logger.new('legal_analysis.log')
custom_logger.level = Logger::DEBUG
custom_logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
end

LegalSummariser.configure do |config|
  config.logger = custom_logger
  config.language = 'en'
  config.max_file_size = 20 * 1024 * 1024 # 20MB
  config.timeout = 60 # 60 seconds
  config.enable_caching = true
  config.cache_dir = './custom_cache'
end

puts "Configuration applied successfully!"

# Example 2: Multi-language support
puts "\n2. Multi-language Configuration"
LegalSummariser.configure do |config|
  config.language = 'tr' # Turkish
end

puts "Language set to Turkish (TR)"
puts "Supported languages: #{LegalSummariser.configuration.supported_languages.join(', ')}"

# Example 3: Performance monitoring
puts "\n3. Performance Monitoring"
monitor = LegalSummariser.performance_monitor

# Simulate some operations for demonstration
monitor.start_timer(:demo_operation)
sleep(0.1) # Simulate work
monitor.end_timer(:demo_operation)

monitor.record(:demo_metric, 42.5)
monitor.record(:demo_metric, 38.2)

puts "Performance Report:"
puts monitor.report

# Example 4: Cache management
puts "\n4. Cache Management"
cache = LegalSummariser::Cache.new

# Show cache statistics
cache_stats = cache.stats
puts "Cache Status: #{cache_stats[:enabled] ? 'Enabled' : 'Disabled'}"

if cache_stats[:enabled]
  puts "Cache Directory: #{cache_stats[:cache_dir]}"
  puts "Cached Files: #{cache_stats[:file_count]}"
  puts "Cache Size: #{cache_stats[:total_size_mb]} MB"
end

# Example 5: Error handling and validation
puts "\n5. Configuration Validation"
begin
  LegalSummariser.configure do |config|
    config.language = 'invalid_language'
  end
rescue LegalSummariser::Error => e
  puts "Configuration error caught: #{e.message}"
end

# Reset to valid configuration
LegalSummariser.configure do |config|
  config.language = 'en'
end

# Example 6: Custom analysis workflow
puts "\n6. Custom Analysis Workflow"
def analyze_with_custom_workflow(file_path)
  puts "Starting custom analysis workflow for: #{file_path}"
  
  # Start performance monitoring
  monitor = LegalSummariser.performance_monitor
  monitor.start_timer(:custom_workflow)
  
  begin
    # Step 1: Basic analysis
    puts "Step 1: Performing basic analysis..."
    result = LegalSummariser.summarise(file_path)
    
    # Step 2: Custom risk assessment
    puts "Step 2: Custom risk assessment..."
    risk_score = result[:risks][:risk_score][:score]
    
    custom_risk_level = case risk_score
                       when 0..5 then 'Very Low'
                       when 6..15 then 'Low'
                       when 16..30 then 'Medium'
                       when 31..50 then 'High'
                       else 'Critical'
                       end
    
    # Step 3: Generate custom report
    puts "Step 3: Generating custom report..."
    custom_report = {
      file_path: file_path,
      analysis_timestamp: Time.now.iso8601,
      document_info: {
        type: result[:metadata][:document_type],
        word_count: result[:metadata][:word_count],
        processing_time: result[:metadata][:extraction_time_seconds]
      },
      summary: result[:plain_text],
      risk_assessment: {
        standard_score: risk_score,
        custom_level: custom_risk_level,
        high_priority_issues: result[:risks][:high_risks].length,
        compliance_gaps: result[:risks][:compliance_gaps].length
      },
      recommendations: generate_custom_recommendations(result)
    }
    
    workflow_time = monitor.end_timer(:custom_workflow)
    custom_report[:workflow_time_seconds] = workflow_time.round(3)
    
    puts "Custom workflow completed in #{workflow_time.round(3)}s"
    return custom_report
    
  rescue => e
    monitor.end_timer(:custom_workflow)
    puts "Workflow failed: #{e.message}"
    return nil
  end
end

def generate_custom_recommendations(analysis_result)
  recommendations = []
  
  # Risk-based recommendations
  high_risks = analysis_result[:risks][:high_risks]
  if high_risks.any?
    recommendations << "URGENT: Address #{high_risks.length} high-risk issues before signing"
    high_risks.each { |risk| recommendations << "- #{risk[:recommendation]}" }
  end
  
  # Compliance recommendations
  compliance_gaps = analysis_result[:risks][:compliance_gaps]
  if compliance_gaps.any?
    recommendations << "COMPLIANCE: Review #{compliance_gaps.length} regulatory gaps"
    compliance_gaps.each { |gap| recommendations << "- #{gap[:recommendation]}" }
  end
  
  # Document type specific recommendations
  doc_type = analysis_result[:metadata][:document_type]
  case doc_type
  when 'nda'
    recommendations << "NDA: Verify confidentiality scope and duration"
  when 'employment_contract'
    recommendations << "EMPLOYMENT: Check termination clauses and benefits"
  when 'service_agreement'
    recommendations << "SERVICE: Review deliverables and payment terms"
  end
  
  recommendations
end

# Example usage of custom workflow
puts "\n7. Custom Workflow Example"
# Replace with actual file path
sample_file = '/tmp/sample_contract.txt'
File.write(sample_file, "Sample contract content for demonstration purposes.")

custom_result = analyze_with_custom_workflow(sample_file)
if custom_result
  puts "\nCustom Analysis Result:"
  puts JSON.pretty_generate(custom_result)
end

# Cleanup
File.delete(sample_file) if File.exist?(sample_file)

# Example 8: System statistics and monitoring
puts "\n8. System Statistics"
system_stats = LegalSummariser.stats
puts "System Performance Overview:"
puts "- Performance Metrics: #{system_stats[:performance].keys.join(', ')}"
puts "- Cache Status: #{system_stats[:cache][:enabled] ? 'Active' : 'Inactive'}"
puts "- Memory Usage: #{system_stats[:memory][:memory_mb]} MB" if system_stats[:memory][:available]

puts "\nAdvanced configuration examples completed!"
