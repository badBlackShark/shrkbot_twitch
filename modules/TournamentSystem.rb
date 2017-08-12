require 'cinch'
require 'yaml'
require 'yaml/store'

# WORK IN PROGRESS
# TODO: Include challonge integration (requires API v2 for what I want to do).

# TODO: Fix that staff members can be deleted multiple times!


class TournamentSystem
    include Cinch::Plugin
    set :prefix, /^!/

    def self.createStores
        $channels.keys.each do |channel_name|
            @@tournament_store.transaction do
                @@tournament_store[channel_name]||={}
            end
        end
    end


    @@tournament_store = YAML::Store.new "tournament.store"
    TournamentSystem.createStores

# General tournament stuff

    # Usage: !tournament start <name>
    #
    # Starts a tournament called <name>, sets the caller as the tournament admin and adds him to the staff list.
    # Can only be called by the channel- and bot owner.
    match /tournament start (\S+)/, method: :createTournament
    def createTournament m, tournamentName
        return unless m.user.nick.eql?($botowner)||m.user.nick.eql?(m.channel.name.sub('#',''))
        @@tournament_store.transaction do
            @@tournament_store[m.channel.to_s][tournamentName]||={
                "bracket"  => nil,
                "schedule" => nil,
                "rules"    => nil,
                upnext:   [],
                admin:    m.user.nick,
                staff:    [m.user.nick]
            }

            @@tournament_store[tournamentName]||={
                runsIn: [m.channel.to_s]
            }
        end
        m.reply "Created tournament with name \"#{tournamentName}\"."
    end


    match /tournament (\S+) include (.+)/, method: :includeInChannel
    def includeInChannel m, tournamentName, channel
        @@tournament_store.transaction do
            unless validateTournamentName(m, tournamentName)
                invalidTournament(m)
                return
            end

            return unless checkPermissions(m, tournamentName, :admin)

            if channel
                channel.prepend('#')
                channel.downcase!
            else
                channel = m.channel.to_s
            end

            unless $channels.include?(channel)
                m.reply "I'm not connected to channel #{channel[1..-1]}."
                return
            end

            if @@tournament_store[tournamentName][:runsIn].include?(channel)
                m.reply "Tournament #{tournamentName} is already running in channel #{channel[1..-1]}."
                return
            end

            @@tournament_store[channel][tournamentName]=@@tournament_store[m.channel.to_s][tournamentName]
            @@tournament_store[tournamentName][:runsIn].push(channel.downcase)
        end

        m.reply "All commands for tournament #{tournamentName} will now also be available in channel #{channel[1..-1]}."
    end


    match /tournament (\S+) exclude ?(.+)?/, method: :excludeInChannel
    def excludeInChannel m, tournamentName, channel
        @@tournament_store.transaction do
            unless validateTournamentName(m, tournamentName)
                invalidTournament(m)
                return
            end

            return unless checkPermissions(m, tournamentName, :admin)

            if channel
                channel.prepend('#')
                channel.downcase!
            else
                channel = m.channel.to_s
            end

            if @@tournament_store[tournamentName][:runsIn].include?(channel)
                @@tournament_store[channel].delete(tournamentName)
                @@tournament_store[tournamentName][:runsIn].delete(channel)
            else
                m.reply "Tournament #{tournamentName} isn't running in channel #{channel[1..-1]}."
                return
            end
        end

        m.reply "The commands for tournament #{tournamentName} are no longer available in channel #{channel[1..-1]}."
    end


    # Usage: !tournament end <name>
    #
    # Ends the tournament called <name>, and deletes it from the database.
    # Can only be called by the tournament admin.
    match /tournament end (\S+)/, method: :endTournament
    def endTournament m, tournamentName
        @@tournament_store.transaction do
            return unless checkPermissions(m, tournamentName, :admin)
            unless validateTournamentName(m, tournamentName)
                invalidTournament(m)
                return
            end

            @@tournament_store[tournamentName][:runsIn].each do |channel_name|
                Channel(channel_name).send("The tournament #{tournamentName} has ended.")
                @@tournament_store[channel_name].delete(tournamentName)
            end

            @@tournament_store.delete(tournamentName)

            m.reply "Tournament #{tournamentName} was succesfully deleted."
        end
    end
#end



# Getter / Setter

    # Usage: !<variable> <name>
    #
    # Returns the <variable> for the tournament <name>. If <name> is not given, and there's only one
    # active tournament in the channel the command was called in, then the <variable> for that tournament will be returned.
    match /(rules|schedule|bracket) ?(\w+)?$/, method: :getTournamentProperty
    def getTournamentProperty m, variable, tournamentName
        @@tournament_store.transaction do
            if tournamentName
                unless validateTournamentName(m, tournamentName)
                    m.reply "got here somehow"
                    invalidTournament(m)
                    return
                end
                return unless @@tournament_store[tournamentName][:runsIn].include?(m.channel.to_s)
                reply = @@tournament_store[m.channel.to_s][tournamentName][variable]
            elsif @@tournament_store[m.channel.to_s].keys.length==1
                tournamentName = @@tournament_store[m.channel.to_s].keys[0]
                reply = @@tournament_store[m.channel.to_s][tournamentName][variable]
            else
                return if @@tournament_store[m.channel.to_s].keys.length==0
                m.reply "Please specify a tournament. All available tournaments for this channel: #{@@tournament_store[m.channel.to_s].keys.join(", ")}."
                return
            end

            if reply
                m.reply "The #{variable} for #{tournamentName}: #{reply}"
            else
                m.reply "There's no #{variable} for this tournament."
            end
        end
    end


    # Usage: !<variable> <name> set <reply>
    #
    # Sets the <variable> for the tournament <name> to <reply>. If <name> is not given, and there's only one
    # active tournament in the channel the command was called in, then the <variable> for that tournament will
    # be set to <reply>.
    # Can only be called by tournament staff.
    match /(rules|schedule|bracket) ?(\S+)? set (.+)$/, method: :setTournamentProperty
    def setTournamentProperty m, variable, tournamentName, reply
        @@tournament_store.transaction do
            if tournamentName
                unless validateTournamentName(m, tournamentName)
                    invalidTournament(m)
                    return
                end
                return unless checkPermissions(m, tournamentName, :staff)
                @@tournament_store[m.channel.to_s][tournamentName][variable] = reply
            elsif @@tournament_store[m.channel.to_s].keys.length==1
                tournamentName = @@tournament_store[m.channel.to_s].keys[0]
                return unless checkPermissions(m, tournamentName, :staff)
                @@tournament_store[m.channel.to_s][tournamentName][variable] = reply
            else
                return if @@tournament_store[m.channel.to_s].keys.length==0
                m.reply "Please specify a tournament with \"!#{variable} <tournament> set <reply>\".
                All available tournaments for this channel: #{@@tournament_store[m.channel.to_s].keys.join(", ")}."
                return
            end
            m.reply "Set #{variable} for tournament #{tournamentName} to \"#{reply}\"."
        end
    end


    # Usage: !upnext <name>
    #
    # Returns the upcoming match for the tournament with name <name>. If <name> is not given, and there's only
    # one active tournament in the channel, then the upcoming match for that tournament will be returned.
    match /upnext ?(\w+)?$/, method: :getUpnext
    def getUpnext m, tournamentName
        @@tournament_store.transaction do
            if tournamentName
                unless validateTournamentName(m, tournamentName)
                    m.reply "Tournament name; #{tournamentName}"
                    invalidTournament(m)
                    return
                end
                return unless @@tournament_store[tournamentName][:runsIn].include?(m.channel.to_s)
                reply = @@tournament_store[m.channel.to_s][tournamentName][:upnext].join(" vs ")
            elsif @@tournament_store[m.channel.to_s].keys.length==1
                tournamentName = @@tournament_store[m.channel.to_s].keys[0]
                reply = @@tournament_store[m.channel.to_s][tournamentName][:upnext].join(" vs ")
            else
                return if @@tournament_store[m.channel.to_s].keys.length==0
                m.reply "Please specify a tournament. All available tournaments for this channel: #{@@tournament_store[m.channel.to_s].keys.join(", ")}."
                return
            end

            if reply
                m.reply "The next match in #{tournamentName} will be #{reply}."
            else
                m.reply "There's no next match planned at the moment."
            end
        end
    end


    # Usage: !upnext <name> set <opponent1>, <opponent2>, <opponent3>, ...
    #
    # Sets the opponents for the upcoming match for the tournament with the name <name>. If <name> is not given, and
    # there's only one active tournament in the channel, the opponents for the upcoming match of that tournament
    # will be set.
    # You can set an unlimited amount of opponents, separated by ", ".
    # Can only be called by tournament staff.
    match /upnext ?(\S+)? set (.+)$/, method: :setUpnext
    def setUpnext m, tournamentName, reply
        @@tournament_store.transaction do
            if tournamentName
                unless validateTournamentName(m, tournamentName)
                    invalidTournament(m)
                    return
                end
                return unless checkPermissions(m, tournamentName, :staff)
                @@tournament_store[m.channel.to_s][tournamentName][:upnext] = reply.split(", ")
            elsif @@tournament_store[m.channel.to_s].keys.length==1
                tournamentName = @@tournament_store[m.channel.to_s].keys[0]
                return unless checkPermissions(m, tournamentName, :staff)
                @@tournament_store[m.channel.to_s][tournamentName][:upnext] = reply.split(", ")
            else
                return if @@tournament_store[m.channel.to_s].keys.length==0
                m.reply "Please specify a tournament with \"!upnext <tournament> set <reply>\".
                All available tournaments for this channel: #{@@tournament_store[m.channel.to_s].keys.join(", ")}."
                return
            end
            m.reply "Set the opponents for the next match in #{tournamentName} to: \"#{reply}\"."
        end
    end


    match /staff ?(\S+)? add (.+)$/, method: :addStaff
    def addStaff m, tournamentName, staffName
        @@tournament_store.transaction do
            if tournamentName
                unless validateTournamentName(m, tournamentName)
                    invalidTournament(m)
                    return
                end
                return unless checkPermissions(m, tournamentName, :admin)
                @@tournament_store[m.channel.to_s][tournamentName][:staff].push(staffName.downcase)
            elsif @@tournament_store[m.channel.to_s].keys.length==1
                tournamentName = @@tournament_store[m.channel.to_s].keys[0]
                return unless checkPermissions(m, tournamentName, :admin)
                @@tournament_store[m.channel.to_s][tournamentName][:staff].push(staffName.downcase)
            else
                return if @@tournament_store[m.channel.to_s].keys.length==0
                m.reply "Please specify a tournament with \"!staff <tournament> add <name>\".
                All available tournaments for this channel: #{@@tournament_store[m.channel.to_s].keys.join(", ")}."
                return
            end
            m.reply "Added \"#{staffName}\" to the list of staff members."
        end
    end


    match /staff ?(\S+)? remove (.+)$/, method: :removeStaff
    def removeStaff m, tournamentName, staffName
        @@tournament_store.transaction do
            if tournamentName
                unless validateTournamentName(m, tournamentName)
                    invalidTournament(m)
                    return
                end
                return unless checkPermissions(m, tournamentName, :admin)
                staffMember = @@tournament_store[m.channel.to_s][tournamentName][:staff].delete(staffName.downcase)
            elsif @@tournament_store[m.channel.to_s].keys.length==1
                staffMember = tournamentName = @@tournament_store[m.channel.to_s].keys[0]
                return unless checkPermissions(m, tournamentName, :admin)
                @@tournament_store[m.channel.to_s][tournamentName][:staff].delete(staffName.downcase)
            else
                return if @@tournament_store[m.channel.to_s].keys.length==0
                m.reply "Please specify a tournament with \"!staff <tournament> add <name>\".
                All available tournaments for this channel: #{@@tournament_store[m.channel.to_s].keys.join(", ")}."
                return
            end
            if staffMember
                m.reply "Deleted #{staffName} from the list of staff members."
            else
                m.reply "There is no staff member called \"#{staffName}\"."
            end
        end
    end


#end

    private

    # These must always be called within a transaction block of @@tournament_store!

    def invalidTournament m
        allTournaments = @@tournament_store[m.channel.to_s].keys.join(", ")
        m.reply "This tournament doesn't exist or isn't available in this channel. Remember that tournament names are case sensitive!"
        unless allTournaments.eql?("")
            m.reply "All available tournaments for this channel: #{allTournaments}."
        else
            m.reply "There are no active tournaments in this channel."
        end
    end

    def validateTournamentName m, tournamentName
        @@tournament_store[m.channel.to_s].keys.include?(tournamentName) ? true : false
    end

    def checkPermissions m, tournamentName, permissionLevel
        @@tournament_store[m.channel.to_s][tournamentName][permissionLevel].include?(m.user.nick) ? true : false
    end
end
