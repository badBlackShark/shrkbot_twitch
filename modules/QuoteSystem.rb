require 'cinch'
require 'yaml'
require 'yaml/store'

#TODO: Implement special case for when a channel doesn't have any quotes.

class QuoteSystem
    include Cinch::Plugin
    set :prefix, /^!/

    # Refreshes the database to contain seperate storages for each channel
    # the bot is connected to. Will automatically be called when joining a
    # new channel, and when deleting all quotes for a channel.
    def self.createStores
        @@quote_store.transaction do
            # Create separate storage for each channel
            $channels.keys.each do |channel_name|
                @@quote_store[channel_name.to_s] ||= {
                    next_id: 1,
                    quotes:  {}
                }
            end
        end
    end

    @@quote_store = YAML::Store.new('quotes.store')
    QuoteSystem.createStores
    # Used so no quote is randomly returned twice in a row.
    @@lastquote = 0


    # Usage: !quote add <quote>
    #
    # Adds a quote to the database.
    # Only usable by mods.
    match /quote add (.+)/, method: :addQuote
    def addQuote m, arg
        return unless $moderators[m.channel.to_s].include?(m.user.nick)
        @@quote_store.transaction do
            channel_quotes = @@quote_store[m.channel.to_s]
            id = channel_quotes[:next_id].to_i
            channel_quotes[:quotes][id] = arg
            channel_quotes[:next_id]+=1
            m.reply "Added quote ##{id}: #{arg}"
        end
    end


    # Usage: !quote del(ete) <quote>
    #
    # Deletes a quote from the database.
    # Only usable by mods.
    match /quote (?:del|delete) (.+)/, method: :deleteQuote
    def deleteQuote m, arg
        return unless $moderators[m.channel.to_s].include?(m.user.nick)
        @@quote_store.transaction do
            quote = @@quote_store[m.channel.to_s][:quotes].delete(arg.to_i)
            if quote
                m.reply "Quote ##{arg} deleted."
            else
                m.reply "Quote ##{arg} doesn't exist."
            end
        end
    end




    # Usage: !quote <id>
    #
    # Calls the quote for the given id. If no id was specified,
    # a random quote will be returned. @@lastquote ensures that
    # a quote isn't randomly returned multiple times in a row.
    match /quote ?(\d+)?$/, method: :getQuote
    def getQuote m, quote_id=nil
        @@quote_store.transaction do
            channel_quotes = @@quote_store[m.channel.to_s]
            unless quote_id
                loop do
                    quote_id = channel_quotes[:quotes].keys.sample
                    # Prevents an infinite loop if there are not enough quotes in the database.
                    break if channel_quotes[:quotes].length<2
                    break unless quote_id.eql?(@@lastquote)
                end
                @@lastquote = quote_id.to_i
            end
            quote = channel_quotes[:quotes][quote_id.to_i]
            if quote
                m.reply "[##{quote_id}]: #{quote}"
            else
                m.reply "Quote ##{quote_id} doesn't exist"
            end
        end
    end



    # Usage: !quotes clear <channel>
    #
    # Clears all quotes of a specific channel. If channel is not given,
    # it will clear the quotes for the channel the command was called in.
    #
    # Can be called by the channel- and the botowner, but only the botowner can specify a channel.
    match /quotes clear ?(.+)?/, method: :clearQuotes
    def clearQuotes m, channel
        return unless m.user.nick.eql?($botowner)||m.user.nick.eql?(m.channel.name.sub('#',''))
        @@quote_store.transaction do
            if channel
                return unless m.user.nick.eql?($botowner)
                channel.prepend('#')
            else
                channel = m.channel.name
            end
            allQuotes = @@quote_store.delete(channel)
            if allQuotes
                m.reply "Erased all quotes for channel #{channel.sub('#', '')}."
            else
                m.reply "Channel #{channel.sub('#', '')} doesn't exist in the database."
            end
        end
        QuoteSystem.createStores
    end
end
