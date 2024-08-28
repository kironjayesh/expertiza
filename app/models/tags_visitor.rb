class TagsVisitor
    # this method will be implemented by concrete visitors
    def tag_intervals(tags)
      raise NotImplementedError, 'You must implement the tag_intervals method'
    end
  end
  