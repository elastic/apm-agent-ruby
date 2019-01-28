# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Metadata::SystemInfo do
    describe '#initialize' do
      subject { described_class.new(Config.new) }

      it 'has values' do
        %i[hostname architecture platform].each do |key|
          expect(subject.send(key)).to_not be_nil
        end
      end

      context 'hostname' do
        it 'has no newline at the end' do
          expect(subject.hostname).not_to match(/\n\z/)
        end
      end

      context 'containers' do
        context 'with env' do
          it 'reads variables from env' do
            with_env(
              'KUBERNETES_NAMESPACE' => 'my-namespace',
              'KUBERNETES_NODE_NAME' => 'my-node-name',
              'KUBERNETES_POD_NAME' => 'my-pod-name',
              'KUBERNETES_POD_UID' => 'my-pod-uid'
            ) do
              expect(subject.kupernetes[:namespace]).to eq('my-namespace')
              expect(subject.kupernetes[:node_name]).to eq('my-node-name')
              expect(subject.kupernetes[:pod_name]).to eq('my-pod-name')
              expect(subject.kupernetes[:pod_uid]).to eq('my-pod-uid')
            end
          end
        end

        context 'with cgroup' do
          before do
            allow(IO).to receive(:readlines).with('/proc/pid/cgroup') { lines }
          end

          context 'docker info' do
            let(:lines) do
              '1:name=systemd:/kubepods/besteffort/pode9b90526-f47d-11e8-b2a5' \
              '-080027b9f4fb/15aa6e53-b09a-40c7-8558-c6c31e36c88a'
            end
            it 'knows container id and k8s pod uid' do
              expect(subject.container[:id])
                .to eq('15aa6e53-b09a-40c7-8558-c6c31e36c88a')
              expect(subject.kupernetes[:pod_uid])
                .to eq('e9b90526-f47d-11e8-b2a5-080027b9f4fb')
            end
          end
        end
      end
    end
  end
end
