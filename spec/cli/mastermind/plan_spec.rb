RSpec.describe CLI::Mastermind::Plan do
  let(:plan) { described_class.new('test', 'test plan', __FILE__) }

  it 'can access the global configuration object' do
    CLI::Mastermind.instance_variable_set('@config', CLI::Mastermind::Configuration.allocate)

    plan.instance_variable_set('@block', proc { config })

    expect { plan.call }.to_not raise_error
  end

  context 'Adding Children' do
    context 'Name Collisions' do
      let(:plan_with_children_1) do
        described_class.new('top_level', 'plan with children 1', __FILE__).tap do |plan|
          plan.add_children([described_class.new('do_thing')])
        end
      end

      let(:plan_with_children_2) do
        described_class.new('top_level', 'plan with children 2', __FILE__).tap do |plan|
          plan.add_children([described_class.new('do_other_thing')])
        end
      end

      let(:plan_without_children) do
        described_class.new('top_level', 'I have no children', __FILE__)
      end

      context 'Only allows one plan with a particular name' do
        [:plan_with_children_1, :plan_with_children_2, :plan_without_children].permutation(2).each do |(plan1, plan2)|
          example "Merging #{plan1} with #{plan2}" do
            plan1 = send(plan1)
            plan2 = send(plan2)

            plan.add_children([plan1, plan2])

            expect(plan.children.count).to eq 1
          end
        end
      end

      context 'Combines the children of plans when both have children' do
        [:plan_with_children_1, :plan_with_children_2].permutation(2) do |plans|
          example "Merging #{plans.join(' into ')}" do
            plans.map!(&method(:send))

            plan.add_children(plans)

            children = plan['top_level'].children

            expect(children.count).to eq 2
            expect(children).to have_key 'do_thing'
            expect(children).to have_key 'do_other_thing'
          end
        end
      end

      context 'Overwrites the existing plan if either plan doesn\'t have children' do
        plans = [:plan_with_children_1, :plan_without_children].permutation(2).to_a +
                [:plan_with_children_2, :plan_without_children].permutation(2).to_a

        plans.each do |plans|
          example "Merging #{plans.join(' into ')}" do
            plans.map!(&method(:send))

            plan.add_children(plans)

            expect(plan.children.values.first).to eq plans.last
          end
        end
      end
    end
  end
end
