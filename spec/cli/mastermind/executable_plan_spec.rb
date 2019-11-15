RSpec.describe CLI::Mastermind::ExecutablePlan do
  let(:plan) { described_class.new('test', 'test plan', __FILE__) }

  it 'can access the global configuration object' do
    CLI::Mastermind.instance_variable_set('@config', CLI::Mastermind::Configuration.allocate)

    plan.instance_variable_set('@block', proc { config })

    expect { plan.call }.to_not raise_error
  end
end
