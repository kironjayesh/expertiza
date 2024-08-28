class TimeBetweenTagsVisitor < TagsVisitor
    # implementation of the tag_intervals method
    # calculates time intervals between successive tag updates
    def tag_intervals(tags)
      tag_updated_times = tags.map(&:updated_at).sort.reverse
      
      tag_update_intervals = []
      1.upto(tag_updated_times.size - 1).each do |i|
        tag_update_intervals.append(tag_updated_times[i] - tag_updated_times[i - 1])
      end
  
      tag_update_intervals
    end
  end
  