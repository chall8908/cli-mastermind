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
end
