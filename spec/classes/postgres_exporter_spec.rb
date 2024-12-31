# frozen_string_literal: true

require 'spec_helper'

describe 'prometheus::postgres_exporter' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts.merge(os_specific_facts(facts))
      end

      context 'with version specified' do
        let(:params) do
          {
            version: '0.4.6',
            arch: 'amd64',
            os: 'linux',
            bin_dir: '/usr/local/bin',
            install_method: 'url',
            postgres_user: 'username',
            postgres_pass: 'password'
          }
        end

        describe 'with all defaults' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/usr/local/bin/postgres_exporter').with('target' => '/opt/postgres_exporter_v0.4.6_linux-amd64/postgres_exporter') }
          it { is_expected.to contain_prometheus__daemon('postgres_exporter') }
          it { is_expected.to contain_user('postgres-exporter') }
          it { is_expected.to contain_group('postgres-exporter') }
          it { is_expected.to contain_service('postgres_exporter') }
        end

        context 'with tls set in web-config.yml' do
          let(:params) do
            super().merge(
              web_config_content: {
                tls_server_config: {
                  cert_file: '/etc/postgres_exporter/foo.cert',
                  key_file: '/etc/postgres_exporter/foo.key'
                }
              }
            )
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/etc/postgres_exporter_web-config.yml').with(ensure: 'file') }
          it { is_expected.to contain_prometheus__daemon('postgres_exporter').with(options: '--web.config.file=/etc/postgres_exporter_web-config.yml') }
        end
      end
    end
  end
end
