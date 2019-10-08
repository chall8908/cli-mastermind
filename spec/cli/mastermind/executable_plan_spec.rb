RSpec.describe CLI::Mastermind::ExecutablePlan do
  let(:plan) { described_class.new('test', 'test plan', __FILE__) }

  it 'can access the global configuration object' do
    CLI::Mastermind.instance_variable_set('@config', CLI::Mastermind::Configuration.allocate)

    plan.instance_variable_set('@block', proc { config })

    expect { plan.call }.to_not raise_error
  end

  context 'Adding Aliases' do
    let(:config) { CLI::Mastermind::Configuration.allocate }

    before do
      config.instance_variable_set('@aliases', {})
      CLI::Mastermind.instance_variable_set('@config', config)
    end

    it 'adds the alias to the global alias map' do
      plan.add_alias('alias')

      # Aliases are always stored as arrays, even when they're from a plan
      expect(config.map_alias('alias')).to eq [plan.name]
    end
  end
end
