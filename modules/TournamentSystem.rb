require 'cinch'
require 'yaml'
require 'yaml/store'

class TournamentSystem
    include Cinch::Plugin

    @@bracket, @@schedule, @@rules, @@upnext = "", "", "", ""
    @@tournament_store = YAML::Store.new "tournament.store"

    @@tournament_store.transaction do
        @@bracket  = @@tournament_store["bracket"]
        @@schedule = @@tournament_store["schedule"]
        @@rules    = @@tournament_store["rules"]
        @@upnext   = @@tournament_store["upnext"]
        unless @@bracket||@@schedule||@@rules||@@upnext
            @@bracket, @@schedule, @@rules, @@upnext = "", "", "", ""
        end
    end

    match /clear$/,         method: :clearAll
    match /rules$/,         method: :getRuleset
    match /upnext$/,        method: :getUpnext
    match /bracket$/,       method: :getBracket
    match /schedule$/,      method: :getSchedule
    match /set (\w+) (.+)/, method: :updateCommands

    def clearAll(m)
        if m.user.nick.eql?("trueblackshark")
            @@bracket, @@schedule, @@rules, @@upnext = "", "", "", ""
            @@tournament_store.transaction do
                @@tournament_store.delete("rules")
                @@tournament_store.delete("upnext")
                @@tournament_store.delete("bracket")
                @@tournament_store.delete("schedule")
            end
            m.reply "Tournament commands cleared."
        end
    end

    def getRuleset(m)
        unless @@rules.eql?("")
            m.reply "You can find the rules here: #{@@rules}"
        else
            m.reply "There's currently no ruleset set."
        end
    end

    def getUpnext(m)
        unless @@upnext.eql?("")
            m.reply "The next match will be #{@@upnext}."
        else
            m.reply "There's currently no next match set."
        end
    end

    def getBracket(m)
        unless @@bracket.eql?("")
            m.reply "You can find the bracket here: #{@@bracket}"
        else
            m.reply "There's currently no bracket set."
        end
    end

    def getSchedule(m)
        unless @@schedule.eql?("")
            m.reply "You can find the schedule here: #{@@schedule}"
        else
            m.reply "There's currently no schedule set."
        end
    end

    def updateCommands(m, command, arg)
        if $moderators.include?(m.user.nick)

            if command.eql?("bracket")
                @@bracket = arg
                @@tournament_store.transaction do
                    @@tournament_store["bracket"] = @@bracket
                end
                m.reply "Bracket set to #{@@bracket}"

            elsif command.eql?("schedule")
                @@schedule = arg
                @@tournament_store.transaction do
                    @@tournament_store["schedule"] = @@schedule
                end
                m.reply "Schedule set to #{@@schedule}"

            elsif command.eql?("rules")
                @@rules = arg
                @@tournament_store.transaction do
                    @@tournament_store["rules"] = @@rules
                end
                m.reply "Rules set to #{@@rules}"

            elsif command.eql?("upnext")
                opponents = arg.split(',')
                opponents.each do |name|
                    name.strip
                end
                @@upnext = opponents.join(" vs ")
                @@tournament_store.transaction do
                    @@tournament_store["upnext"] = @@upnext
                end
                m.reply "Set upcoming opponents to #{opponents.join(', ')}."
            end
        end
    end
end
