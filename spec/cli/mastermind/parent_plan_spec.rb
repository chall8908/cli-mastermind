RSpec.describe CLI::Mastermind::ParentPlan do
  let(:plan) { described_class.new('test', 'test plan', __FILE__) }

  context 'Adding Children' do
    context 'Name Collisions' do
      let(:plan_with_children_1) do
        described_class.new('top_level', 'plan with children 1', __FILE__).tap do |plan|
          plan.add_children([CLI::Mastermind::ExecutablePlan.new('do_thing')])
        end
      end

      let(:plan_with_children_2) do
        described_class.new('top_level', 'plan with children 2', __FILE__).tap do |plan|
          plan.add_children([CLI::Mastermind::ExecutablePlan.new('do_other_thing')])
        end
      end

      let(:plan_without_children) do
        # A ParentPlan is always considered to have children
        # So we use a generic ExecutablePlan here
        CLI::Mastermind::ExecutablePlan.new('top_level', 'I have no children', __FILE__)
      end

      context 'Only allows one plan with a particular name' do
        [:plan_with_children_1, :plan_with_children_2, :plan_without_children].permutation(2).each do |(plan1, plan2)|
          example "Merging #{plan1} with #{plan2}" do
            # Load all the plans
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
            # Load all the plans
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
            # Load all the plans
            plans.map!(&method(:send))

            plan.add_children(plans)

            expect(plan.children.values.first).to eq plans.last
          end
        end
      end
    end
  end

  context 'Children with Aliases' do
    let(:plan) do
      described_class.new('top_level', 'plan with alias', __FILE__).tap do |plan|
        plan.add_children([child_plan])
      end
    end

    let(:child_plan) do
      CLI::Mastermind::ExecutablePlan.new('do_thing').tap do |plan|
        plan.add_alias 'dt'
      end
    end

    it 'can be accessed via the name' do
      expect(plan['do_thing']).to eq child_plan
    end

    it 'can be accessed via the alias' do
      expect(plan['dt']).to eq child_plan
    end
  end
end
