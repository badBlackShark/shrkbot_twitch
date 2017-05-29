require 'cinch'
require 'yaml'
require 'yaml/store'

# WORK IN PROGRESS
# TODO: Include challonge integration (requires API v2 for what I want to do).

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


    # Usage: !tournament start <name>
    #
    # Starts a tournament called <name>, sets the caller as the tournament admin and adds him to the staff list.
    # Can only be called by the channel- and bot owner.
    match /tournament start (\S+)/, method: :createTournament
    def createTournament m, tournamentName
        return unless m.user.nick.eql?($botowner)||m.user.nick.eql?(m.channel.name.sub('#',''))
        @@tournament_store.transaction do
            @@tournament_store[m.channel.to_s][tournamentName]||={
                bracket:  nil,
                schedule: nil,
                rules:    nil,
                upnext:   nil,
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
                allTournaments = @@tournament_store[m.channel.to_s].keys.join(", ")
                m.reply "This tournament doesn't exist or isn't available in this channel. Remember that tournament names are case sensitive!"
                if allTournaments
                    m.reply "All available tournaments for this channel: #{allTournaments}."
                else
                    m.reply "There are no active tournaments in this channel."
                end

                return
            end

            return unless checkPermissions(m, tournamentName, :admin)

            channel.prepend('#')
            unless $channels.include?(channel.downcase)
                m.reply "I'm not connected to channel #{channel[1..-1]}."
                return
            end

            if @@tournament_store[tournamentName][:runsIn].include?(channel.downcase)
                m.reply "Tournament #{tournamentName} is already running in channel #{channel[1..-1]}."
                return
            end

            @@tournament_store[channel.downcase][tournamentName]=@@tournament_store[m.channel.to_s][tournamentName]
            @@tournament_store[tournamentName][:runsIn].push(channel.downcase)
        end

        m.reply "All commands for tournament #{tournamentName} will now also be available in channel #{channel[1..-1]}."
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
                m.reply "Tournament #{tournamentName} doesn't exist."
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


    # Usage: !bracket <name>
    #
    # Returns the bracket for the tournament <name>. If <name> is not given, and there's only one
    # active tournament in the channel the command was called in, then the bracket for that tournament will be returned.
    match /bracket ?(\w+)?$/, method: :getBracket
    def getBracket m, tournamentName
        @@tournament_store.transaction do
            if tournamentName
                unless validateTournamentName(m, tournamentName)
                    allTournaments = @@tournament_store[m.channel.to_s].keys.join(", ")
                    m.reply "This tournament doesn't exist or isn't available in this channel. Remember that tournament names are case sensitive!"
                    unless allTournaments.eql?("")
                        m.reply "All available tournaments for this channel: #{allTournaments}."
                    else
                        m.reply "There are no active tournaments in this channel."
                    end

                    return
                end
                return unless @@tournament_store[tournamentName][:runsIn].include?(m.channel.to_s)
                bracket = @@tournament_store[m.channel.to_s][tournamentName][:bracket]
            elsif @@tournament_store[m.channel.to_s].keys.length==1
                tournamentName = @@tournament_store[m.channel.to_s].keys[0]
                bracket = @@tournament_store[m.channel.to_s][tournamentName][:bracket]
            else
                return if @@tournament_store[m.channel.to_s].keys.length==0
                m.reply "Please specify a tournament. All available tournaments for this channel: #{@@tournament_store[m.channel.to_s].keys.join(", ")}."
                return
            end

            if bracket
                m.reply "Bracket for #{tournamentName}: #{bracket}"
            else
                m.reply "There's no bracket set for this tournament."
            end
        end
    end


    # Usage: !bracket set <name> "<reply>"
    #
    # Sets the bracket for the tournament <name> to <reply>. If <name> is not given, and there's only one
    # active tournament in the channel the command was called in, then the bracket for that tournament will
    # be set to <reply>. The quotation marks around <reply> are to distinguish the reply from the tournament name,
    # if tournament name is not given and the reply contains a space. The quotation marks won't be saved as part of the reply.
    # Can only be called by tournament staff.
    match /bracket set ?(\S+)? "(.+)"$/, method: :setBracket
    def setBracket m, tournamentName=nil, bracket
        @@tournament_store.transaction do
            if tournamentName
                unless validateTournamentName(m, tournamentName)
                    allTournaments = @@tournament_store[m.channel.to_s].keys.join(", ")
                    m.reply "This tournament doesn't exist or isn't available in this channel. Remember that tournament names are case sensitive!"
                    if allTournaments
                        m.reply "All available tournaments for this channel: #{allTournaments}."
                    else
                        m.reply "There are no active tournaments in this channel."
                    end

                    return
                end
                return unless checkPermissions(m, tournamentName, :staff)
                @@tournament_store[m.channel.to_s][tournamentName][:bracket] = bracket
            elsif @@tournament_store[m.channel.to_s].keys.length==1
                tournamentName = @@tournament_store[m.channel.to_s].keys[0]
                return unless checkPermissions(m, tournamentName, :staff)
                @@tournament_store[m.channel.to_s][tournamentName][:bracket] = bracket
            else
                return if @@tournament_store[m.channel.to_s].keys.length==0
                m.reply "Please specify a tournament with \"!bracket set <name> <bracket>\".
                All available tournaments for this channel: #{@@tournament_store[m.channel.to_s].keys.join(", ")}."
                return
            end
            m.reply "Set bracket for tournament #{tournamentName} to \"#{bracket}\"."
        end
    end



    private

    # These must always be called within a transaction block!

    def validateTournamentName m, tournamentName
        @@tournament_store[m.channel.to_s].keys.include?(tournamentName) ? true : false
    end

    def checkPermissions m, tournamentName, permissionLevel
        @@tournament_store[m.channel.to_s][tournamentName][permissionLevel].include?(m.user.nick) ? true : false
    end
end
