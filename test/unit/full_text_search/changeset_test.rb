require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class ChangesetTest < ActiveSupport::TestCase
    include PrettyInspectable
    include NullValues
    include TimeValue

    fixtures :enabled_modules
    fixtures :projects
    fixtures :repositories
    fixtures :users
    fixtures :roles

    def test_save
      changeset = Changeset.generate! do |generating_changeset|
        generating_changeset.comments = "Fix a memory leak\n\nThis is critical."
        generating_changeset.committer = User.find(2).login
      end
      changeset.reload
      targets = Target.where(source_id: changeset.id,
                             source_type_id: Type.changeset.id)
      assert_equal([
                     {
                       "project_id" => changeset.repository.project_id,
                       "source_id" => changeset.id,
                       "source_type_id" => Type.changeset.id,
                       "last_modified_at" => changeset.committed_on,
                       "is_private" => null_boolean,
                       "title" => "Fix a memory leak",
                       "content" => "This is critical.",
                       "custom_field_id" => null_number,
                       "container_id" => null_number,
                       "container_type_id" => null_number,
                       "tag_ids" => [
                         Tag.user(changeset.user.id).id,
                       ],
                     },
                   ],
                   targets.all.collect {|target| target.attributes.except("id")})
    end

    def test_destroy
      changeset = Changeset.generate!
      targets = Target.where(source_id: changeset.id,
                             source_type_id: Type.changeset.id)
      assert_equal(1, targets.size)
      changeset.destroy!
      assert_equal([], targets.reload.to_a)
    end
  end
end
