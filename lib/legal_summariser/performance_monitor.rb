# frozen_string_literal: true

module LegalSummariser
  # Performance monitoring and metrics collection
  class PerformanceMonitor
    def initialize
      @metrics = {}
      @start_times = {}
    end

    # Start timing an operation
    # @param operation [String] Operation name
    def start_timer(operation)
      @start_times[operation] = Time.now
    end

    # End timing an operation
    # @param operation [String] Operation name
    def end_timer(operation)
      return unless @start_times[operation]
      
      duration = Time.now - @start_times[operation]
      @metrics[operation] ||= []
      @metrics[operation] << duration
      @start_times.delete(operation)
      duration
    end

    # Record a metric value
    # @param metric [String] Metric name
    # @param value [Numeric] Metric value
    def record(metric, value)
      @metrics[metric] ||= []
      @metrics[metric] << value
    end

    # Get performance statistics
    # @return [Hash] Performance statistics
    def stats
      stats = {}
      
      @metrics.each do |metric, values|
        next if values.empty?
        
        stats[metric] = {
          count: values.length,
          total: values.sum.round(4),
          average: (values.sum / values.length).round(4),
          min: values.min.round(4),
          max: values.max.round(4)
        }
      end
      
      stats
    end

    # Reset all metrics
    def reset!
      @metrics.clear
      @start_times.clear
    end

    # Get current memory usage (if available)
    # @return [Hash] Memory usage information
    def memory_usage
      if defined?(GC)
        {
          object_count: GC.stat[:heap_live_slots],
          gc_count: GC.count,
          memory_mb: (GC.stat[:heap_live_slots] * 40 / 1024.0 / 1024.0).round(2) # Rough estimate
        }
      else
        { available: false }
      end
    end

    # Generate performance report
    # @return [String] Formatted performance report
    def report
      report = ["Performance Report", "=" * 50, ""]
      
      stats.each do |metric, data|
        report << "#{metric.to_s.tr('_', ' ').capitalize}:"
        report << "  Count: #{data[:count]}"
        report << "  Total: #{data[:total]}s"
        report << "  Average: #{data[:average]}s"
        report << "  Min: #{data[:min]}s"
        report << "  Max: #{data[:max]}s"
        report << ""
      end
      
      memory = memory_usage
      if memory[:available] != false
        report << "Memory Usage:"
        report << "  Objects: #{memory[:object_count]}"
        report << "  GC Count: #{memory[:gc_count]}"
        report << "  Estimated Memory: #{memory[:memory_mb]} MB"
      end
      
      report.join("\n")
    end
  end

  # Global performance monitor
  def self.performance_monitor
    @performance_monitor ||= PerformanceMonitor.new
  end
end
