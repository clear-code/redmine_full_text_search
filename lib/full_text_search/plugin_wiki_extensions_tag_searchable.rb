# The MIT License (MIT)
#
# Copyright (c) 2024 Abe Tomoaki <abe@clear-code.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

module FullTextSearch
  module PluginWikiExtensionsTagSearchable
    # Wiki Extensions tags
    # https://github.com/haru/redmine_wiki_extensions

    extend ActiveSupport::Concern

    included do
      after_create :fts_after_create
      after_destroy :fts_after_destroy
    end

    private

    def fts_after_create
      fts_target = Target.find_by(
        source_id: self.wiki_page_id,
        source_type_id: Type.wiki_page.id)
      tag_id = Tag.label(self.tag.name).id
      fts_target.tag_ids = fts_target.tag_ids.concat([tag_id])
      fts_target.save!
    end

    def fts_after_destroy
      fts_target = Target.find_by(
        source_id: self.wiki_page_id,
        source_type_id: Type.wiki_page.id)
      tag_ids = fts_target.tag_ids - [Tag.label(self.tag.name).id]
      fts_target.tag_ids = tag_ids
      fts_target.save!
    end
  end
end

