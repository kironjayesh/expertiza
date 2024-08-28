class TagPromptDeployment < ApplicationRecord
  belongs_to :tag_prompt
  belongs_to :assignment
  belongs_to :questionnaire
  has_many :answer_tags, dependent: :destroy

  require 'time'

  def tag_prompt
    TagPrompt.find(tag_prompt_id)
  end

  def get_number_of_taggable_answers(user_id) #taggable answers are those answers (given by reviewer) that are eligible (passing the length threshold) to
    # be tagged by the reviewee

    # fetches the team associated with the user/reviewee (user_id) by filtering teams to include matching assignment_id 
    # and the specified user_id
    team = Team.joins(:teams_users).where(team_users: { parent_id: assignment_id }, user_id: user_id)
    # retrieves the responses matched with response and response_map
    responses = Response.joins(:response_maps).where(response_maps: { reviewed_object_id: assignment.id, reviewee_id: team.id })
    # retreives the question based on question type
    questions = Question.where(questionnaire_id: questionnaire.id, type: question_type)

    # if both responses and questions are available, response ids and question ids are fetched
    unless responses.empty? || questions.empty?
      responses_ids = responses.map(&:id)
      questions_ids = questions.map(&:id)
      
      # answers of the respective questions_ids and responses_ids are fetched
      answers = Answer.where(question_id: questions_ids, response_id: responses_ids)

      answers = answers.where(conditions: "length(comments) > #{answer_length_threshold}") unless answer_length_threshold.nil?
      return answers.count
    end
    0
  end

  def track_assignment_tagging
    # get all teams and questions related to the assignment
    teams = Team.where(parent_id: assignment_id)
    questions = Question.where(questionnaire_id: questionnaire.id, type: question_type)
    questions_ids = questions.map(&:id)

    answer_tagging_analytics = [] #could be answer_tagging_analytics
    
    unless teams.empty? || questions.empty?
      teams.each do |team|
        # get all the responses for the teams
        responses = ReviewResponseMap.assessments_for(team)
        responses_ids = responses.map(&:id)

        # retrieve answers from the responses
        answers = Answer.where(question_id: questions_ids, response_id: responses_ids)
        answers = answers.select { |answer| answer.comments.length > answer_length_threshold } unless answer_length_threshold.nil?
        answers_ids = answers.map(&:id)
        
        # find user associated with the teams
        teams_users = TeamsUser.where(team_id: team.id)
        users = teams_users.map { |teams_user| User.find(teams_user.user_id) }

        users.each do |user|
          tags = AnswerTag.where(tag_prompt_deployment_id: id, user_id: user.id, answer_id: answers_ids)
          tagged_answers_ids = tags.map(&:answer_id)
          
          visitor = TimeBetweenTagsVisitor.new
          tag_update_intervals = visitor.tag_intervals(tags)

          percentage = answers.count.zero? ? '-' : format('%.1f', tags.count.to_f / answers.count * 100)
          not_tagged_answers = answers.reject { |answer| tagged_answers_ids.include?(answer.id) }

          # create a new object to store the tagging information for the user
          answer_tagging = VmUserAnswerTagging.new(user, percentage, tags.count, not_tagged_answers.count, answers.count, tag_update_intervals)

          # append the tagging info to the result array
          user_answer_tagging.append(answer_tagging)
        end
      end
    end
    user_answer_tagging
  end
end
