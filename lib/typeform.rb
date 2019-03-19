require "typeform/version"

# module Typeform
#   # Your code goes here...
# end


module Evs

  class Typeform

    AVAILABLE_CMDS = %w(RESPONSES)
    TYPEFORM_API_BASE = 'https://api.typeform.com/forms'
    TYPEFORM_API_V1_BASE = 'https://api.typeform.com/v1/form'

    def initialize(form_id)
      @form_id = form_id
      @access_token = ENV['TYPEFORM_API_TOKEN']
      @api_key = ENV['TYPEFORM_API_KEY']
    end

    def get_responses options = {}
      result = request(build_url(:responses, options))
      response = result["items"].first
      questions = fetch_questions
      merge_questions_response(questions, response)
    end

    def extract_reponses_from_hook payload
      response = payload['form_response']
      questions = response['definition']
      merge_questions_response(questions, response)
    end

    def extract_uid_from_hook payload
      response = payload["form_response"]
      hidden_value = response['hidden'] unless response.nil?
      hidden_value['uid'] unless hidden_value.nil?
    end

    def extract_submission_date_from_hook payload
      response = payload["form_response"]
      DateTime.parse(response['submitted_at']) unless response.nil?
    end

    def fetch_questions
      request(build_url(:questions))
    end

    def get_submission_date
      result = request(build_url(:responses))
      response = result["items"].first
      DateTime.strptime(response["submitted_at"], '%Y-%m-%dT%H:%M:%S').to_time unless response.nil?
    end

    private

    def request url
      headers = {Authorization: "Bearer #{@access_token}"}
      @response = JSON.parse(RestClient.get(url, headers))
    end

    def build_url cmd, options = {}
      url = "#{TYPEFORM_API_BASE}/#{@form_id}"

      case cmd
      when :responses
        url = add_options_to_url(url + '/responses', options)
        return url
      when :questions
        return url
      when :token
        url = "#{TYPEFORM_API_V1_BASE}/#{@form_id}?key=#{ENV['TYPEFORM_API_KEY']}&token=#{token}"
        return url
      else
        raise 'Unexpected Typeform request'
      end
    end

    def add_options_to_url url, options = {}
      url += '?' unless url.last == '?'
      opts = []
      opts.push("completed=#{options[:completed]}") if !!options[:completed]
      opts.push("fields=#{options[:fields]}") if !!options[:fields]
      opts.push("query=#{options[:query]}") if !!options[:query]
#      opts.push("token=#{options[:token]}") if !!options[:token]

      url += opts.join('&').to_s
      return url
    end


    def merge_questions_response questions, response
      resp = []
      questions['fields'].each do |question|
        answer = extract_answer_by_id(response['answers'], question["id"])
        next if answer.nil?
        answer_txt = extract_answer_from answer
        resp.push({question: question['title'], answer: answer_txt})
      end
      return resp
    end

    def extract_question_by_id(questions, id)
      questions["fields"].select {|k| k["id"] == id.to_s}.first
    end

    def extract_answer_from answer
      case answer["type"]
      when 'date'
        return DateTime.parse answer['date']
      when 'boolean'
        return answer['boolean']
      when 'choice'
        return answer['choice']['label']
      when 'text'
        return answer['text']
      when 'email'
        return answer['email']
      when 'choices'
        return answer['choices']
      when 'number'
        return answer['number']
      when 'payment'
        return answer['payment']
      else
        raise "Unknow type #{answer['type']}"
      end
    end

    def extract_answer_by_id(answers, id)
      answers.select {|k, v| k['field']['id'] == id.to_s }.first
    end

  end
end