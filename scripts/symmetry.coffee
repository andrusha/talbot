# Description:
#   Checks if your pull requests are complain to Symmetry notion
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot review pull request <github user> <repository name> <pull request id> - checks pull rqeuest against Symmetry heuristics
#   hubot leave <name> alone! <command> - ignore specific thing in PR reviews by <name>
#   hubot forget about <name> -
#
# URLS:
#   /symmetry/pull_request
#
# Acquire token:
#   curl -u '' -d '{"client_id": "", "client_secret": "", "scopes": "repo"}' https://api.github.com/authorizations
#

require '../lib/core_ext'
symmetry = require '../lib/symmetry'
GitHubApi = require 'node-github'


review_pull_request = (owner, repo, pr_number, ignores = []) ->
  github = new GitHubApi
    version: "3.0.0"

  github.authenticate
    type: 'oauth'
    token: process.env.HUBOT_GITHUB_TOKEN

  pr_id =
    user:   owner
    repo:   repo
    number: pr_number

  github.pullRequests.getCommits pr_id, (err, commits) ->
    return console.log err  if err
    github.pullRequests.getFiles pr_id, (err, files) ->
      return console.log err  if err

      [overall, commits] = symmetry.find_problems      commits, ignores
      missings           = symmetry.find_missing_tests files

      pr_id.body = symmetry.format_message overall, commits, missings
      github.issues.createComment pr_id, (err) ->
        console.log err  if err


module.exports = (robot) ->
  robot.router.post "/symmetry/pull_request", (req, res) ->

    if req.body.action is 'opened'
      pr   = req.body.pull_request
      repo = pr.base.repo
      author = pr.user.login

      if robot.brain.data.untouchables? and author in robot.brain.data.untouchables
        return res.end "He's untouchable, nothing to do here."

      ignores = robot.brain.data.ignores?[author] || []
      review_pull_request repo.owner.login, repo.name, req.body.number, ignores

    res.end 'Done motherfuckers'

  robot.respond /review pull request ([^\s]+) ([^\s]+) (\d+)/i, (msg) ->
    msg.send "Thank you, pull request is scheduled for review"
    review_pull_request msg.match[1], msg.match[2], msg.match[3]

  robot.respond /leave ([^\s]+) alone!(.*)?/i, (msg) ->
    allowed = ["", "symmetry badge"]

    who  = msg.match[1]
    what = (msg.match[2] || "").strip()

    unless what in allowed
      return msg.send "I don't know what #{what} mean."

    unless what
      robot.brain.data.untouchables ?= []
      robot.brain.data.untouchables.push who
    else
      robot.brain.data.ignores      ?= {}
      robot.brain.data.ignores[who] ?= []
      robot.brain.data.ignores[who].push what

    for_what = if what then " about #{what}." else "."
    msg.send "Yes, my master. I'll never bother #{who} again#{for_what}"

  robot.respond /forget about ([^\s]+)/i, (msg) ->
    who = msg.match[1]

    if robot.brain.data.untouchables? and who in robot.brain.data.untouchables
      robot.brain.data.untouchables.splice robot.brain.data.untouchables.indexOf(who), 1

    if robot.brain.data.ignores? and who in robot.brain.data.ignores
      delete robot.brain.data.ignores[who]

    msg.send "This guy #{who} I think I saw him, but I completely forgot about him."
