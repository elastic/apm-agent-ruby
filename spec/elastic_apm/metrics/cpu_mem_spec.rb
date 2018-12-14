# frozen_string_literal: true

module ElasticAPM
  class Metrics
    RSpec.describe CpuMem do
      let(:config) { Config.new }

      subject { described_class.new config }

      context 'Linux' do
        before { allow(Metrics).to receive(:platform) { :linux } }

        describe 'sample' do
          it 'gets a sample of relevant info' do
            mock_proc_files

            sample = subject.sample

            expect(sample.system_cpu_total).to eq 338_876_168
            expect(sample.system_cpu_usage).to eq 9_817_780
            expect(sample.system_memory_total).to eq 4_042_711_040
            expect(sample.system_memory_free).to eq 2_750_062_592
            expect(sample.process_cpu_usage).to eq 7
            expect(sample.process_memory_size).to eq 53_223_424
            expect(sample.process_memory_rss).to eq 3110
          end
        end

        describe 'collect' do
          it 'collects a metric set' do
            mock_proc_files(user: 0, idle: 0, utime: 0, stime: 0)
            expect(subject.collect).to be_nil

            mock_proc_files(
              user: 400_000,
              idle: 600_000,
              utime: 100_000,
              stime: 100_000
            )
            set = subject.collect
            expect(set).to match(
              'system.cpu.total.norm.pct' => 0.4,
              'system.process.cpu.total.norm.pct' => 0.2,

              'system.memory.total' => 4_042_711_040,
              'system.memory.actual.free' => 2_750_062_592,

              'system.process.memory.rss.bytes' => 12_738_560,
              'system.process.memory.size' => 53_223_424
            )
          end
        end
      end

      # rubocop:disable Metrics/MethodLength
      def mock_proc_files(
        user: 6_410_558,
        idle: 329_434_672,
        utime: 7,
        stime: 0
      )
        {
          '/proc/stat' =>
            ['proc_stat', { user: user, idle: idle }],
          '/proc/self/stat' =>
            ['proc_self_stat', { utime: utime, stime: stime }],
          '/proc/meminfo' =>
            ['proc_meminfo', {}]
        }.each do |file, (fixture, updates)|
          allow(IO).to receive(:readlines).with(file) do
            text = File.read("spec/fixtures/#{fixture}")
            updates.each { |key, val| text.gsub!("{#{key}}", val.to_s) }
            text.split("\n")
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
