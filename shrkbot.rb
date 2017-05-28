require 'cinch'
require 'yaml'
require 'yaml/store'

$login = YAML.load_file(".login")
$botowner = $login['botowner']

require_relative 'modules/ChannelSystem'

$channels = YAML.load_file('.channels')
$moderators = {} #Used for all the mod-only commands in the plugins. Automatically updated.
$channels.keys.each do |channel_name|
    $moderators[channel_name.to_s] ||= {}
end

require_relative 'modules/ModSystem'
require_relative 'modules/QuoteSystem'
require_relative 'modules/CommandSystem'
require_relative 'modules/GiveawaySystem'
require_relative 'modules/TournamentSystem'

# TODO: Put hardcoded commands in their own module, implement a word filter, implement tournament system, make code more readable.

bot = Cinch::Bot.new do
    configure do |c|
        c.server = "irc.chat.twitch.tv"
        c.nick = $login['botname']
        c.password = $login['oauth']
        c.channels = $channels.keys
        c.plugins.plugins = [
            QuoteSystem,
            CommandSystem,
            GiveawaySystem,
            ChannelSystem,
            ModSystem,
            TournamentSystem
        ]
    end

    on :connect do
        #Requests twitch capabilities needed e.g. for the automatic modlist update.
        bot.irc.send ("CAP REQ :twitch.tv/membership")
        bot.irc.send ("CAP REQ :twitch.tv/commands")

        # Confirms in each channel it connected successfully and requests the modlist.
        $channels.keys.each do |channel|
            Channel(channel).send("Connected!")
            Channel(channel).send("/mods")
        end
    end


    # Hardcoded commands. Will be moved to a separate module soon.

    on :message, "!vanish" do |m|#Selfpurge
        m.reply "/p #{m.user.nick}"
        m.reply "Voilá"
    end

    on :message, "!mylife" do |m|#Requires !ffz for full effect.
       m.reply "#{m.user.nick}'s life: BertLife"
    end

    on :message, "PB pace?" do |m|
        m.reply "PB pace!"
    end

    on :message, "ping" do |m|
        return unless $moderators[m.channel.to_s].include?(m.user.nick)
        m.reply "I'm busy."
    end

    on :message, /Warum so ist?/ do |m|
        return unless m.user.nick.eql?("trueblackshark")
        m.reply "Keiner weiß!"
    end
end

bot.start
