#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

# Look up facilities given a zip code and type
def lookup_facilities(zip_code)
  log "Looking for ballot boxes in zip code #{zip_code}..."

  # This looks complicated, but I'm just building the hash that I'll convert to
  # JSON in order to run a dynamic filter against the Socrata API.
  query = {
    # The 4-4 view ID of the ID I want to filter against
    "originalViewId" => "gmze-t76h",

    # A temporary name for my filter
    "name" => "Ballot Boxes",

    # The heart of the matter - our filter hash
    "query" => {
      "filterCondition" => {
        "type" => "operator",

        "value" => "AND",
        "children" => [ {
          # The filter condition checks that the "Zip Code" column matches the
          # zip code that was passed in
          "type" => "operator",
          "value" => "STARTS_WITH",
          "children" => [ {
            "columnId" => 2574261,
            "type" => "column"
          }, {
            "type" => "literal",
            "value" => zip_code
          } ]
        } ]
      }
    }
  }

  # Here we just set up a simple Net::HTTP POST request including our query and
  # a content-type
  request = Net::HTTP::Post.new("/api/views/INLINE/rows.json?method=index")
  request.body = query.to_json
  request.content_type = "application/json"
  response = Net::HTTP.start("data.oregon.gov", 80){ |http| http.request(request) }

  # Check our response code and output our results
  if response.code != "200"
    log "Error code: #{response.code}"
    log "Body: #{response.body}"
    say "An error has occurred. I\'m very sorry. Please don\'t hate me."
  else
    results = JSON::parse(response.body)["data"]
    if results.size <= 0
      say "Sorry, I did not find any results for your search."
    else
      say "I found #{results.size} matches. I'll read them to you now."
      say results.map{|r| "#{r[14]} at #{r[10]}" }.join(" or, ")
    end
  end
end

answer
sleep(2)
say "Welcome to the State of Oregon Ballot Box Locator Line."

# Setting up our options for "ask". We accept 5 digits, either spoken or entered
# by DTMF, and time out after 10 seconds.
zipcode_options = { :choices     => "[5 DIGITS]",
                    :repeat      => 3,
                    :timeout     => 10,
                    :onBadChoice => lambda { say 'Invalid entry, please try again.' },
                    :onTimeout   => lambda { say 'Timeout, please try again.' },
                    :onChoice    => lambda { |zip| lookup_facilities(zip.value) }
                  }

ask 'Enter or say your ZIP code to find a ballot box in your area.', zipcode_options
say 'Thank you for using the State of Oregon Ballot Box Locator Line. Goodbye.'

hangup
