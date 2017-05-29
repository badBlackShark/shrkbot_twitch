class ChannelSystem
    include Cinch::Plugin
    set :prefix, /^!/

    @@channel_store = YAML::Store.new('.channels')

    # Making sure the bot always joins the bot-owners channel.
    @@channel_store.transaction do
        @@channel_store["##{$botowner}"] = nil
    end


    # The '#' symbol is usually prepended, because twitch irc channels always start with a '#',
    # so all channels are already stored that way. However, having to call the methods like that
    # would be inconvenient, so they're automatically added.


    # !join <channel>
    #
    # Will join the given channel. Can only be called by the bot owner.
    match /join (.+)/, method: :joinChannel
    def joinChannel m, channelName
        return unless m.user.nick.eql?($botowner)
        channelName.prepend('#')

        # Making sure the bot isn't already in the channel.
        if $channels.include?(channelName)
            m.reply "I'm already in channel twitch.tv/#{channelName[1..-1]}"
            return
        end

        # Putting the channel in the database and actually joining the channel.
        @@channel_store.transaction do
            @@channel_store["#{channelName}"] = nil
        end
        $channels = YAML.load_file('.channels')
        bot.irc.send ("JOIN #{channelName}")

        # Sending out confirmations and requesting the modlist for that channel.
        m.reply "Joining channel twitch.tv/#{channelName[1..-1]}"
        Channel("#{channelName}").send("Connected!")
        Channel("#{channelName}").send("/mods")

        # Creating the sections for the now joined channel for the seperate modules.
        QuoteSystem.createStores
        CommandSystem.createStores
        GiveawaySystem.createStores
        TournamentSystem.createStores
    end

    # !leave <channel>
    #
    # Leaves the given channel. If 'channel' is not given, it will leave
    # the channel the command was used in.
    # Can be called by the channel- and the botowner, but only the botowner can specify a channel.
    match /leave ?(.+)?/, method: :leaveChannel
    def leaveChannel m, channelName
        return unless m.user.nick.eql?($botowner)||m.user.nick.eql?(m.channel.name.sub('#',''))

        if channelName
            return unless m.user.nick.eql?($botowner)
            m.reply "Leaving channel twitch.tv/#{channelName}"
            channelName.prepend('#')
        else
            channelName = m.channel
        end

        # Making sure the bot is actually connected to the channel.
        unless $channels.include?("#{channelName}")
            m.reply "I'm not connected to channel #{channelName}."
            return
        end

        @@channel_store.transaction do
            @@channel_store.delete(channelName)
            $channels.delete(channelName)
        end

        Channel(channelName).send("Goodbye o/")
        bot.irc.send ("PART #{channelName}")

        # Deleting the section in the giveaway database. The sections in the other databases are preserved,
        # in case the bot will join them later. They can be manually deleted with their respective clear methods.
        GiveawaySystem.deleteGiveawayStore(channelName)

        # Adjusting the modlist, so it only contains the mods for the remaining channels.
        $moderators.clear
        $channels.keys.each do |channel|
            Channel(channel).send("/mods")
        end
    end
end
