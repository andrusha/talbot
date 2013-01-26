# Description:
#   Allows Hubot to show where his sources are.
#
# Commands:
#   hubot where are you

module.exports = (robot) ->
  robot.respond /where are you\??/i, (msg) ->
    msg.send "https://github.com/p0deje/talbot"
