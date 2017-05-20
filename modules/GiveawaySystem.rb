require 'cinch'
require 'yaml'
require 'yaml/store'

#TODO: Maybe add functionality so not only the broadcaster can start a giveaway in a channel.

class GiveawaySystem
    include Cinch::Plugin
    set :prefix, /^!/

    # Creates the storage sections for the different channels the
    # bot is in. Automatically called when joining a new channel.
    def self.createStores
        $channels.keys.each do |channel_name|
            @@giveaways[channel_name.to_s] ||= {
                "keyword" => "",
                "enabled" => "false",
                "possibleWinners" => [],
                "winners" => []
            }
        end
    end

    @@giveaways = {}
    GiveawaySystem.createStores

    # Deletes the section of a channel in the database. Automatically
    # called when leaving a channel.
    def self.deleteGiveawayStore channel
        @@giveaways.delete(channel)
    end

    @@giveaways = {}
    GiveawaySystem.createStores

    # Usage: !giveaway
    #
    # If a giveaway is currently going on, returns the keyword to enter the giveaway.
    # Otherwise, let's the user know that there is curerntly no giveaway,
    match /giveaway$/, method: :getKeyword
    def getKeyword m
        if @@giveaways[m.channel.to_s]["enabled"].eql?("true")
            m.reply "Enter the giveaway with \"+#{@@giveaways[m.channel.to_s]["keyword"]}\"."
        else
            m.reply "There is currently no giveaway going on."
        end
    end


    # Usage: !giveaway start <keyword>
    # Usage: !giveaway end
    #
    # Calling with 'start' starts the giveaway, the keyword to enter it
    # will be set to <keyword>. If <keyword> is not given, 'enter' will be set
    # as the default keyword.
    #
    # Calling with 'end' ends the giveaway and clears the 'possibleWinners' array.
    match /giveaway (\w+) ?(.+)?/, method: :startStop
    def startStop m, action, arg
        return unless m.user.nick.eql?(m.channel.name.sub('#',''))
        if action.eql? "start"||@@giveaways[m.channel.to_s]["enabled"].eql?("false")
            if arg
                @@giveaways[m.channel.to_s]["keyword"] = arg
            else
                @@giveaways[m.channel.to_s]["keyword"] = "enter"
            end
            @@giveaways[m.channel.to_s]["enabled"] = "true"
            m.reply "The giveaway has started. Type +#{@@giveaways[m.channel.to_s]["keyword"]} to enter."
        elsif action.eql? "end"
            if @@giveaways[m.channel.to_s]["enabled"].eql?("true")
                m.reply "The giveaway has ended. Congratulations to: #{@@giveaways[m.channel.to_s]["winners"].join(", ")}!"
                @@giveaways[m.channel.to_s]["enabled"] = "false"
                @@giveaways[m.channel.to_s]["possibleWinners"].clear
            end
        end
    end


    # Usage: !drawWinners <n>
    #
    # Draws <n> winners. If <n> is not given, one winner will be drawn.
    match /drawWinners ?(\d+)?/, method: :drawWinners
    def drawWinners m, numberOfWinners
        return unless m.user.nick.eql?(m.channel.name.sub('#',''))&&@@giveaways[m.channel.to_s]["enabled"].eql?("true")
        numberOfWinners ||= 1
        for i in [1..numberOfWinners.to_i]
            winner = @@giveaways[m.channel.to_s]["possibleWinners"].sample
            m.reply "#{winner} has won the giveaway!"
            @@giveaways[m.channel.to_s]["possibleWinners"].delete(winner)
            @@giveaways[m.channel.to_s]["winners"].push(m.user.nick)
            # Making sure it can't draw more winners than there are people in the giveaway.
            break if @@giveaways[m.channel.to_s]["possibleWinners"].length < numberOfWinners.to_i
        end
    end


    # Usage: +<keyword>
    #
    # Enters the user into the giveaway. Each user can only enter the giveaway once.
    match /^\+(\w+)$/, use_prefix: false, method: :enterGiveaway
    def enterGiveaway m, arg
        if @@giveaways[m.channel.to_s]["enabled"].eql?("true")&&(!@@giveaways[m.channel.to_s]["possibleWinners"].include?(m.user.nick))
            if arg.eql?("#{@@giveaways[m.channel.to_s]["keyword"]}")
                # Making sure people who already won the giveaway can't enter again.
                return if @@giveaways[m.channel.to_s]["winners"].include?(m.user.nick)
                @@giveaways[m.channel.to_s]["possibleWinners"].push(m.user.nick)
                m.reply "#{m.user.nick} has entered the giveaway."
            end
        end
    end
end
