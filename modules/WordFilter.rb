require 'cinch'
require 'yaml'
require 'yaml/store'

class WordFilter
    include Cinch::Plugin

    @@bannedWords = []

    match /(.+)/,       use_prefix: false, method: :filterWords
    match /ban (.+)/,   method: :addBan
    match /unban (.+)/, method: :removeBan

    def filterWords(m)
        @@bannedWords.each do |word|
            if m.message.include?(word)
                m.reply "/p #{m.user.nick}"
            end
        end

    def addBan(m, arg)
        if $moderators.include?(m.user.nick)
            @@bannedWords.push(arg)
            m.reply "Added #{arg} to the list of banned phrases."
        end
    end

    def removeBan(m, arg)
        if $moderators.include?(m.user.nick)
            @@bannedWords.delete(arg)
            m.reply "Phrase #{arg} is no longer banned."
        end
    end
end
