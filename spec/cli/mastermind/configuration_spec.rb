RSpec.describe CLI::Mastermind::Configuration do
  context 'custom attributes' do
    before { described_class.add_attribute(:test_attribute) }
    let(:config) { described_class.new }

    it 'creates a getter for the custom attribute' do
      expect(config).to respond_to :test_attribute
    end

    it 'creates a setter for the custom attribute' do
      expect(config).to respond_to :'test_attribute='
    end

    it 'only allows a custom attribute to be set once' do
      config.test_attribute = 'expected'
      config.test_attribute = 'ignored'

      expect(config.test_attribute).to eq 'expected'
    end

    context 'callable values' do
      let(:mock_proc) { Proc.new do; end }

      before { config.test_attribute = mock_proc }

      it 'evaluates callable attributes with instance eval' do
        expect(config).to receive(:instance_eval).and_return('expected')

        expect(config.test_attribute).to eq 'expected'
      end

      it 'caches the value returned by the callable' do
        expect(config).to receive(:instance_eval).once.and_return('expected')

        config.test_attribute
        config.test_attribute
      end
    end
  end

  context 'Plan Loading' do
    let(:config) { described_class.allocate }

    context 'Top-Level name collisions' do
      let(:plan_with_children_1) do
        CLI::Mastermind::Plan.new('top_level', nil, 'configuration_spec.rb').tap do |plan|
          plan.add_children([CLI::Mastermind::Plan.new('do_thing')])
        end
      end


      let(:plan_with_children_2) do
        CLI::Mastermind::Plan.new('top_level', nil, 'configuration_spec.rb').tap do |plan|
          plan.add_children([CLI::Mastermind::Plan.new('do_other_thing')])
        end
      end

      let(:plan_without_children) do
        CLI::Mastermind::Plan.new('top_level', 'I have no children', 'configuration_spec.rb')
      end

      before do
        allow(CLI::Mastermind::Plan).to receive(:load) do |plan|
          case plan
          when 'plan_with_children_1'
            [plan_with_children_1]
          when 'plan_with_children_2'
            [plan_with_children_2]
          when 'plan_without_children'
            [plan_without_children]
          end
        end

        config.instance_variable_set('@plan_files', Set.new)
      end

      it 'merges together plans when both with children' do
        config.add_plans(%w[ plan_with_children_1 plan_with_children_2 ])
        config.load_plans

        actual = config.plans['top_level'].children

        expect(actual.count).to eq 2
        expect(actual).to have_key 'do_thing'
        expect(actual).to have_key 'do_other_thing'
      end

      it 'overwrites plans when one doesn\'t have children' do
        config.add_plans(%w[ plan_with_children_1 plan_without_children ])
        config.load_plans

        actual = config.plans['top_level']

        expect(actual).to_not have_children
        expect(actual.description).to eq plan_without_children.description
      end
    end
  end
end
