require "json"

svs = JSON.load(ENV["VCAP_SERVICES"])

ENV["SENDGRID_DOMAIN"]   = svs["sendgrid"][0]["credentials"]["hostname"]
ENV["SENDGRID_USERNAME"] = svs["sendgrid"][0]["credentials"]["username"]
ENV["SENDGRID_PASSWORD"] = svs["sendgrid"][0]["credentials"]["password"]
ENV["KEEN_PROJECT_ID"]   = svs["user-provided"][0]["credentials"]["project_id"]
ENV["KEEN_READ_KEY"]     = svs["user-provided"][0]["credentials"]["read_key"]

require "pushpop-keen"
require "pushpop-sendgrid"
require "roadie"

job "keen email" do
  every 1.week, :at => 'Sunday 01:00'

  step do
    Keen.count("Loaded a Page", 
               timeframe: "previous_week", 
               group_by: "title", 
               filters: [{
                 "property_name" => "parsed_page_url.path",
                 "operator" => "contains",
                 "property_value" => "/post/"
               }])
  end

  step "top-pages" do |response, step_responses|
    response.sort do |this, that|
      that["result"].to_i <=> this["result"].to_i
    end.first(10)
  end

  step "traffic-last-week" do
    Keen.count("Loaded a Page", timeframe: "previous_week")
  end

  step "referrers" do
    Keen.count("Loaded a Page", timeframe: "previous_week", group_by: "referrer_info.source").sort do |this, that|
      that["result"].to_i <=> this["result"].to_i
    end.first(10)
  end

  if ENV["DRYRUN"]
    step "write-to-file" do |response, step_responses|
      open("/tmp/keen-#{$$}.html", "w") do |f|
        f.puts(Roadie::Document.new(template("email.html.erb", response, step_responses)).transform)
      end
      `open /tmp/keen-#{$$}.html`
    end
  else
    sendgrid do |response, step_responses|
      to        "Engineering Blog <engineering-blog@pivotal.io>"
      from      "Blog Stats <engineering-blog@pivotal.io>"
      subject   "Engineering Blog Weekly Traffic Report"
      body      Roadie::Document.new(template("email.html.erb", response, step_responses)).transform
    end
  end

end


