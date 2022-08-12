require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class ProjectTest < ActiveSupport::TestCase
    include PrettyInspectable
    include NullValues

    fixtures :custom_fields
    fixtures :custom_fields_projects
    fixtures :custom_fields_trackers
    fixtures :custom_values
    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :projects
    fixtures :projects_trackers
    fixtures :trackers
    fixtures :users

    def test_destroy
      custom_field = ProjectCustomField.generate!(searchable: true)
      project = Project.generate! do |p|
        p.custom_fields = [
          {
            "id" => custom_field.id.to_s,
            "value" => "Hello",
          },
        ]
      end
      project_targets = Target.where(source_id: project.id,
                                     source_type_id: Type.project.id)
      custom_value_targets = Target.where(container_id: project.id,
                                          source_type_id: Type.custom_value.id)
      assert_equal([1, 1],
                   [project_targets.size, custom_value_targets.size])
      project.destroy!
      assert_equal([[], []],
                   [project_targets.to_a, custom_value_targets.to_a])
    end
  end
end
