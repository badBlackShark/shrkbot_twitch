require 'cinch'
require 'yaml'
require 'yaml/store'

class CommandSystem
    include Cinch::Plugin
    set :prefix, /^!/


    # Refreshes the database to contain seperate storages for each channel
    # the bot is connected to. Will automatically be called when joining a
    # new channel, and when deleting all definitions for a channel.
    def self.createStores
        @@command_store.transaction do
            # Create separate storage for each channel
            $channels.keys.each do |channel_name|
                @@command_store[channel_name.to_s] ||= {
                    "definitions" => {},
                    "commands"    => {}
                }
            end
        end
    end


    #Create the storage for the definitions, and create a seperate partition for each channel.
    @@command_store = YAML::Store.new "commands.store"
    CommandSystem.createStores


    # Usage: !def add <command> <reply>
    # Usage: !def del <command>
    #
    # 'Add' adds a definition to the database, which can then be called
    # with ?<command>, which will return <reply>.
    #
    # 'Del' deletes the definition which can we called with ?<command>
    # from the database.
    #
    # Can only be called by moderators.
    match /def (\w+) (\w+) ?(.+)?/, method: :handleDefinitions
    def handleDefinitions m, action, defname, reply
        return unless $moderators[m.channel.to_s].include?(m.user.nick)
        if action.eql?("add")
            @@command_store.transaction do
                channel_defs = @@command_store[m.channel.to_s]
                channel_defs["definitions"][defname.downcase] = reply
                m.reply "Added definition for \"#{defname}\": #{reply}"
            end
        elsif action.eql?("del")
            @@command_store.transaction do
                definition = @@command_store[m.channel.to_s]["definitions"].delete(defname.downcase)
                if definition
                    m.reply "Definition \"?#{defname}\" was deleted."
                else
                    m.reply "Definition \"?#{defname}\" doesn't exist."
                end
            end
        end
    end


    # Usage: !command add <command> <reply>
    # Usage: !command del <command>
    #
    # 'Add' adds a command to the database, which can then be called
    # with !<command>, which will return <reply>.
    #
    # 'Del' deletes the command which can we called with !<command>
    # from the database.
    #
    # Can only be called by moderators.
    match /command (\w+) (\w+) ?(.+)?/, method: :handleCommands
    def handleCommands m, action, cmdname, reply
        return unless $moderators[m.channel.to_s].include?(m.user.nick)
        if action.eql?("add")
            @@command_store.transaction do
                channel_defs = @@command_store[m.channel.to_s]
                channel_defs["commands"][cmdname.downcase] = reply
                m.reply "Added command \"!#{cmdname}\": #{reply}"
            end
        elsif action.eql?("del")
            @@command_store.transaction do
                command = @@command_store[m.channel.to_s]["commands"].delete(cmdname.downcase)
                if command
                    m.reply "Command \"!#{cmdname}\" was deleted."
                else
                    m.reply "Command \"!#{cmdname}\" doesn't exist."
                end
            end
        end
    end


    # Usage: ?<definition>
    #
    # Returns the definition saved in the database under the name <definition>
    # Since all definitions are saved in all lower case, this is not case-sensitive.
    match /^\?(\w+)$/, use_prefix: false, method: :getDefinition
    def getDefinition m, defname
        if defname.eql?("definitions")
            @@command_store.transaction do
                reply = @@command_store[m.channel.to_s]["definitions"].keys.join(", ")
                unless reply.eql?("")
                    m.reply "All available definitions for this channel: #{reply}."
                else
                    m.reply "There are no custom definitions for this channel."
                end
            end
        else
            @@command_store.transaction do
                definition = @@command_store[m.channel.to_s]["definitions"][defname.downcase]
                if definition
                    m.reply definition
                else
                    m.reply "No definition found for ?#{defname}."
                end
            end
        end
    end


    # Usage: !<command>
    #
    # Returns the command saved in the database under the name <command>
    # Since all commands are saved in all lower case, this is not case-sensitive.
    match /^\!(\w+)$/, use_prefix: false, method: :getCommand
    def getCommand m, cmdname
        if cmdname.eql?("commands")
            @@command_store.transaction do
                reply = @@command_store[m.channel.to_s]["commands"].keys.join(", ")
                unless reply.eql?("")
                    m.reply "All available custom commands for this channel: #{reply}."
                else
                    m.reply "There are no custom commands for this channel."
                end
            end
        else
            @@command_store.transaction do
                command = @@command_store[m.channel.to_s]["commands"][cmdname.downcase]
                if command
                    m.reply command
                end
            end
        end
    end

    # Usage: !commands clear <channel>
    #
    # Clears all definitions and commands for the given channel. If 'channel' is not
    # given, it will clear the definitions and commands for the channel the command was called in.
    #
    # Can be called by the channel- and the botowner, but only the botowner can specify a channel.
    match /commands clear ?(.+)?/, method: :clearCommands
    def clearCommands m, channel
        return unless m.user.nick.eql?($botowner)||m.user.nick.eql?(m.channel.name.sub('#',''))
        @@command_store.transaction do
            if channel
                return unless m.user.nick.eql?($botowner)
                channel.prepend('#')
            else
                channel = m.channel.name
            end
            allCommands = @@command_store.delete(channel)
            if allCommands
                m.reply "Erased all definitions & commands for channel #{channel.sub('#', '')}."
            else
                m.reply "Channel #{channel.sub('#', '')} doesn't exist in the database."
            end
        end
        # Storage partition should only be recreated when the bot is still in the channel.
        CommandSystem.createStores
    end

end
