# frozen_string_literal: true

RSpec.describe LegalSummariser::PerformanceMonitor do
  let(:monitor) { LegalSummariser::PerformanceMonitor.new }

  describe "#start_timer and #end_timer" do
    it "measures operation duration" do
      monitor.start_timer(:test_operation)
      sleep(0.01) # Small delay for measurable time
      duration = monitor.end_timer(:test_operation)
      
      expect(duration).to be > 0
      expect(duration).to be < 1 # Should be much less than 1 second
    end

    it "handles multiple operations" do
      monitor.start_timer(:op1)
      monitor.start_timer(:op2)
      
      duration1 = monitor.end_timer(:op1)
      duration2 = monitor.end_timer(:op2)
      
      expect(duration1).to be > 0
      expect(duration2).to be > 0
    end

    it "returns nil for non-existent timer" do
      duration = monitor.end_timer(:non_existent)
      expect(duration).to be_nil
    end
  end

  describe "#record" do
    it "records metric values" do
      monitor.record(:test_metric, 10.5)
      monitor.record(:test_metric, 20.3)
      
      stats = monitor.stats
      expect(stats[:test_metric][:count]).to eq(2)
      expect(stats[:test_metric][:total]).to eq(30.8)
    end
  end

  describe "#stats" do
    before do
      monitor.record(:metric1, 10)
      monitor.record(:metric1, 20)
      monitor.record(:metric2, 5)
    end

    it "calculates correct statistics" do
      stats = monitor.stats
      
      expect(stats[:metric1][:count]).to eq(2)
      expect(stats[:metric1][:total]).to eq(30)
      expect(stats[:metric1][:average]).to eq(15)
      expect(stats[:metric1][:min]).to eq(10)
      expect(stats[:metric1][:max]).to eq(20)
      
      expect(stats[:metric2][:count]).to eq(1)
      expect(stats[:metric2][:total]).to eq(5)
    end

    it "handles empty metrics" do
      empty_monitor = LegalSummariser::PerformanceMonitor.new
      expect(empty_monitor.stats).to eq({})
    end
  end

  describe "#reset!" do
    it "clears all metrics and timers" do
      monitor.record(:test_metric, 10)
      monitor.start_timer(:test_timer)
      
      monitor.reset!
      
      expect(monitor.stats).to eq({})
      expect(monitor.end_timer(:test_timer)).to be_nil
    end
  end

  describe "#memory_usage" do
    it "returns memory information when GC is available" do
      memory = monitor.memory_usage
      
      if defined?(GC)
        expect(memory[:object_count]).to be > 0
        expect(memory[:gc_count]).to be >= 0
        expect(memory[:memory_mb]).to be > 0
      else
        expect(memory[:available]).to be false
      end
    end
  end

  describe "#report" do
    before do
      monitor.record(:test_operation, 1.5)
      monitor.record(:test_operation, 2.5)
    end

    it "generates formatted performance report" do
      report = monitor.report
      
      expect(report).to include("Performance Report")
      expect(report).to include("Test operation:")
      expect(report).to include("Count: 2")
      expect(report).to include("Average: 2.0s")
    end
  end
end

RSpec.describe LegalSummariser do
  describe ".performance_monitor" do
    it "returns global performance monitor instance" do
      monitor1 = LegalSummariser.performance_monitor
      monitor2 = LegalSummariser.performance_monitor
      
      expect(monitor1).to be_a(LegalSummariser::PerformanceMonitor)
      expect(monitor1).to be(monitor2) # Same instance
    end
  end
end
