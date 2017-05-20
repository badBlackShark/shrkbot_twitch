require 'cinch'
require 'yaml'
require 'yaml/store'

class ModSystem
    include Cinch::Plugin
    set :prefix, /^!/

    # Reacts to twitch's response to '/mods', and sets the internal modlist for
    # the channel to the modlist twitch returns.
    match /The moderators of this room are: (.*)/, react_on: :notice, method: :updateModlist, use_prefix: false
    def updateModlist m, modlist
        $moderators[m.channel.to_s] = modlist.split(", ")
    end

    # Regrabs the modlist for a channel when someone gains / loses mod status. Takes up to a few minutes to trigger.
    match /(.+)/, react_on: :mode, method: :autoRefresh, use_prefix: false
    def autoRefresh m
        Channel(m.channel).send("/mods")
    end

    # Manually regrabs the modlist, in case you don't want to wait for 'MODE'.
    match "getmods", method: :manualRefresh
    def manualRefresh m
        m.reply "/mods"
        m.reply "Mod list refreshed."
    end
end
