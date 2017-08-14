# shrkbot
A bot for the twitch channel twitch.tv/trueblackshark, created using the [cinch](https://github.com/cinchrb/cinch) IRC bot framework.


### Setting up

Requires a YAML file called '.login', containing the name of your bot as well as your name on twitch, and your bot's oauth token. Your final file should look something like this:

>---
>"botname": "shrkbot"  
>"botowner": "trueblackshark"  
>"oauth": "oauth:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  



# Available commands
There are four permission levels, always specified behind each command.
(o) = botowner (The person running the bot)
(c) = channel owner (The broadcaster)
(m) = moderators
(e) = everyone
These are in descending order, and each tier always includes all the ones below it (so the channel owner can call (c), (m) and (e) commands), except in the giveaway system. Parameters are specified with '[]'. Optional parameters are specified with '{}'. For more details, check the code of the respective modules.

*****

### Joining / leaving channels (ChannelSystem.rb)
!join [channel] (o)
>Joins [channel]

!leave (c)
>Leaves the channel the command was called in.

!leave [channel] (o)
>Leaves [channel]

*****

### Giveaways (GiveawaySystem.rb)
Note: Commands marked with (c) can ***not*** be called by the botowner.

!giveaway (e)
>Returns the keyword for the current giveaway.

!giveaway start {keyword} (c)
>Starts a giveaway. People can enter using +{keyword}. If {keyword} is not given, it defaults to 'enter'.

!giveaway end (c)
>Ends the current giveaway.

!drawWinners {n} (c)
>Draws {n} winners. If {n} is not given, one winner is drawn.

+[keyword] (e)
>Enters the user into the giveaway.

*****

### Quotes (QuoteSystem.rb)
!quote add [quote] (m)
>Adds [quote] to the database. Each quote gets a unique id to call it with.

!quote del [id] (m)
>Deletes the quote with id [id].

!quote {id} (e)
>Returns the quote with id {id}. If {id} is not given, a random quote will be returned.

!quotes clear (c)
>Clears all the quotes for the channel the command was called in.

!quotes clear [channel] (o)
>Clears all the quotes for [channel].

*****

### Custom commands (CommandSystem.rb)
!command add [name]  [response] (m)
>Adds the command [name] in the database. Will return [response] when called with ![name]

!def add [name]  [response] (m)
>Adds the definition [name] in the database. Will return [response] when called with ?[name]

!command del [name] (m)
>Deletes the command saved under [name].

!def del [name] (m)
>Deletes the definition saved under [name].

![name]  (e)
>Returns the response of the command saved under [name].
>>!commands returns all the available custom commands for the current channel.

?[name]  (e)
>Returns the response of the definition saved under [name].
>>?definitions returns all the available custom definitions for the current channel.

!commands clear (c)
>Clears the commands and definitions for the current channel.

!commands clear [channel] (o)
>Clears the commands and definitions for [channel].
