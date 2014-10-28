# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "socket" # for Socket.gethostname

# Run command line tools and capture the whole output as an event.
#
# Notes:
#
# * The '@source' of this event will be the command run.
# * The '@message' of this event will be the entire stdout of the command
#   as one event.
#
class LogStash::Inputs::Meetup < LogStash::Inputs::Base

  config_name "meetup"
  milestone 1

  default :codec, "json"

  # URLName - the URL name ie "ElasticSearch-Oklahoma-City"
  # Must have one of urlname, venue_id, group_id
  config :urlname, :validate => :string

  # The venue ID
  # Must have one of urlname, venue_id, group_id
  config :venueid, :validate => :string

  # The Group ID, multiple may be specified seperated by commas
  # Must have one of urlname, venue_id, group_id
  config :groupid, :validate => :string

  # Interval to run the command. Value is in seconds.
  config :interval, :validate => :number, :required => true

  # Meetup Key
  config :meetupkey, :validate => :string, :required => true

  # Event Status'
  config :eventstatus, :validate => :string, :default => "upcoming,past"

  public
  def register
    require "faraday"
    @logger.info("Registering meetup Input", :url => @url, :interval => @interval)
  end # def register

  public
  def run(queue)
    url = "https://api.meetup.com/2/events.json?key=#{ @meetupkey }&status=#{ @eventstatus }&group_urlname=#{ @urlname }"
    loop do
      start = Time.now
      @logger.info? && @logger.info("Polling meetup", :url => url)


      # Pull down the RSS feed using FTW so we can make use of future cache functions
      response = Faraday.get url
      result = JSON.parse(response.body)

      result["results"].each do |rawevent| 
        event = LogStash::Event.new(rawevent)
        decorate(event)
        # Convert the timestamps into Ruby times
        event['created'] = Time.at(event['created'] / 1000, (event['created'] % 1000) * 1000).utc
        event['time'] = Time.at(event['time'] / 1000, (event['time'] % 1000) * 1000).utc
        event['group']['created'] = Time.at(event['group']['created'] / 1000, (event['group']['created'] % 1000) * 1000).utc
        event['updated'] = Time.at(event['updated'] / 1000, (event['updated'] % 1000) * 1000).utc
        queue << event
      end

      duration = Time.now - start
      @logger.info? && @logger.info("Command completed", :command => @command,
                                    :duration => duration)

      # Sleep for the remainder of the interval, or 0 if the duration ran
      # longer than the interval.
      sleeptime = [0, @interval - duration].max
      if sleeptime == 0
        @logger.warn("Execution ran longer than the interval. Skipping sleep.",
                     :command => @command, :duration => duration,
                     :interval => @interval)
      else
        sleep(sleeptime)
      end
    end # loop
  end # def run
end # class LogStash::Inputs::Exec