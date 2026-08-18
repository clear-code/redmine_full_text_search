# For auto load
FullTextSearch::Migration

class UpdateChangeFtsTargetTitlesWithRevision < ActiveRecord::Migration[6.1]
  def up
    return unless table_exists?(:fts_targets)

    change_type = FtsType.find_by(name: "Change")
    return unless change_type

    if Redmine::Database.mysql?
      execute(<<-SQL)
UPDATE fts_targets
JOIN changes ON fts_targets.source_id = changes.id
JOIN changesets ON changesets.id = changes.changeset_id
JOIN repositories ON repositories.id = changesets.repository_id
SET fts_targets.title = CONCAT(
  changes.path, '@',
  CASE
    WHEN repositories.type IN ('Repository::Git', 'Repository::Mercurial')
    THEN changesets.scmid
    ELSE changesets.revision
  END
)
WHERE fts_targets.source_type_id = #{change_type.id}
  AND fts_targets.title = changes.path
      SQL
    else
      execute(<<-SQL)
UPDATE fts_targets
SET title = changes.path || '@' ||
  CASE
    WHEN repositories.type IN ('Repository::Git', 'Repository::Mercurial')
    THEN changesets.scmid
    ELSE changesets.revision::text
  END
FROM changes
JOIN changesets ON changesets.id = changes.changeset_id
JOIN repositories ON repositories.id = changesets.repository_id
WHERE fts_targets.source_id = changes.id
  AND fts_targets.source_type_id = #{change_type.id}
  AND fts_targets.title = changes.path
      SQL
    end
  end

  def down
    return unless table_exists?(:fts_targets)

    change_type = FtsType.find_by(name: "Change")
    return unless change_type

    if Redmine::Database.mysql?
      execute(<<-SQL)
UPDATE fts_targets
JOIN changes ON fts_targets.source_id = changes.id
JOIN changesets ON changesets.id = changes.changeset_id
JOIN repositories ON repositories.id = changesets.repository_id
SET fts_targets.title = changes.path
WHERE fts_targets.source_type_id = #{change_type.id}
  AND fts_targets.title = CONCAT(
    changes.path, '@',
    CASE
      WHEN repositories.type IN ('Repository::Git', 'Repository::Mercurial')
      THEN changesets.scmid
      ELSE changesets.revision
    END
  )
      SQL
    else
      execute(<<-SQL)
UPDATE fts_targets
SET title = changes.path
FROM changes
JOIN changesets ON changesets.id = changes.changeset_id
JOIN repositories ON repositories.id = changesets.repository_id
WHERE fts_targets.source_id = changes.id
  AND fts_targets.source_type_id = #{change_type.id}
  AND fts_targets.title = changes.path || '@' ||
    CASE
      WHEN repositories.type IN ('Repository::Git', 'Repository::Mercurial')
      THEN changesets.scmid
      ELSE changesets.revision::text
    END
      SQL
    end
  end

  private

  class FtsType < ActiveRecord::Base
  end
end
