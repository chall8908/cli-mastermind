RSpec.describe CLI::Mastermind do
  it "has a version number" do
    expect(CLI::Mastermind::VERSION).not_to be nil
  end

  context 'Plan Lookup' do
    before do
      plans = described_class::ParentPlan.new('top_level', 'plan with children', __FILE__).tap do |plan|
        child = described_class::ExecutablePlan.new('do_thing')
        child.add_alias('dt')
        plan.add_children([child])
      end

      described_class.instance_variable_set('@plans', { plans.name => plans })
    end

    it 'allows an array of strings' do
      actual = described_class['top_level', 'do_thing']

      expect(actual).to be_a described_class::ExecutablePlan
      expect(actual.name).to eq 'do_thing'
    end

    it 'allows a space separated list' do
      actual = described_class['top_level do_thing']

      expect(actual).to be_a described_class::ExecutablePlan
      expect(actual.name).to eq 'do_thing'
    end

    it 'allows a series of hash-like lookups' do
      actual = described_class['top_level']['do_thing']

      expect(actual).to be_a described_class::ExecutablePlan
      expect(actual.name).to eq 'do_thing'
    end

    it 'properly handles planfile aliases' do
      actual = described_class['top_level']['dt']

      expect(actual).to be_a described_class::ExecutablePlan
      expect(actual.name).to eq 'do_thing'
    end
  end
end
