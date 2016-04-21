require 'json'

svs = JSON.load(ENV["VCAP_SERVICES"])

ENV["SENDGRID_DOMAIN"]   = svs["sendgrid"][0]["credentials"]["hostname"]
ENV["SENDGRID_USERNAME"] = svs["sendgrid"][0]["credentials"]["username"]
ENV["SENDGRID_PASSWORD"] = svs["sendgrid"][0]["credentials"]["password"]
ENV["KEEN_PROJECT_ID"]   = svs["user-provided"][0]["credentials"]["project_id"]
ENV["KEEN_READ_KEY"]     = svs["user-provided"][0]["credentials"]["read_key"]

require 'pushpop-keen'
require 'pushpop-sendgrid'

# Define our job and name it
job 'keen email' do

  every 24.hours, at: '00:00'
  # every 1.hours, at: '**:00'

  step "page-loads-by-url" do
    Keen.count('Loaded a Page', timeframe: 'last_30_days', group_by:  'parsed_page_url.path')
  end

  step "traffic-over-last-30-days" do
    Keen.count('Loaded a Page', timeframe: 'last_30_days')
  end

  sendgrid do |response, step_responses|
    to        "tsaleh@pivotal.io"
    from      "tsaleh@pivotal.io"
    subject   "Pivotal Eng Blog daily hit count"
    body      template('email.html.erb', response, step_responses)
  end

end


