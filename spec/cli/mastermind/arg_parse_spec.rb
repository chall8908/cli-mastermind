RSpec.describe CLI::Mastermind::ArgParse do
  let(:parser) { described_class.new [] }

  context 'Alias Expansion' do
    let(:config) { CLI::Mastermind::Configuration.allocate }

    before do
      config.instance_variable_set('@aliases', Hash.new { |_,k| k })
      config.define_alias('sao', 'shorter argument option')
      config.define_alias('ssao', 'shorter sao')
      config.define_alias('swa', 'shorter with -- arguments')
      config.define_alias('sswa', 'swa -- another')
    end

    it 'expands aliases from the command line' do
      parser.instance_variable_set('@mastermind_arguments', ['sao'])

      parser.do_command_expansion! config

      actual = parser.instance_variable_get('@mastermind_arguments')

      expect(actual).to eq %w[ shorter argument option ]
    end

    it 'recursively expands aliases' do
      parser.instance_variable_set('@mastermind_arguments', ['ssao'])

      parser.do_command_expansion! config

      actual = parser.instance_variable_get('@mastermind_arguments')

      expect(actual).to eq %w[ shorter shorter argument option ]
    end

    it 'expands arguments' do
      parser.instance_variable_set('@mastermind_arguments', ['swa'])

      parser.do_command_expansion! config

      actual = parser.instance_variable_get('@plan_arguments')

      expect(actual).to eq %w[ arguments ]
    end

    it 'prepends alias arguments' do
      parser.instance_variable_set('@mastermind_arguments', ['swa'])
      parser.instance_variable_set('@plan_arguments', ['second'])

      parser.do_command_expansion! config

      actual = parser.instance_variable_get('@plan_arguments')

      expect(actual).to eq %w[ arguments second ]
    end

    it 'prepends alias arguments in the order their expanded' do
      parser.instance_variable_set('@mastermind_arguments', ['sswa'])

      parser.do_command_expansion! config

      actual = parser.instance_variable_get('@plan_arguments')

      expect(actual).to eq %w[ arguments another ]
    end
  end
end
