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
#
# URLS:
#   /symmetry/pull_request
#
# Acquire token:
#   curl -u '' -d '{"client_id": "", "client_secret": "", "scopes": "repo"}' https://api.github.com/authorizations
#

symmetry = require '../lib/symmetry'
GitHubApi = require 'node-github'


review_pull_request = (owner, repo, pr_number) ->
  github = new GitHubApi
    version: "3.0.0"

  github.authenticate
    type: 'oauth'
    token: process.env.HUBOT_GITHUB_TOKEN

  pr_id =
    user:   owner
    repo:   repo
    number: pr_number

  console.log pr_id

  github.pullRequests.getCommits pr_id, (err, commits) ->
    return console.log err  if err
    github.pullRequests.getFiles pr_id, (err, files) ->
      return console.log err  if err

      [overall, commits] = symmetry.find_problems      commits
      missings           = symmetry.find_missing_tests files

      pr_id.body = symmetry.format_message overall, commits, missings
      github.issues.createComment pr_id, (err) ->
        console.log err  if err


module.exports = (robot) ->
  robot.router.post "/symmetry/pull_request", (req, res) ->

    if req.body.action is 'opened'
      repo = req.body.pull_request.base.repo
      review_pull_request repo.owner.login, repo.name, req.body.number

    res.end 'Done motherfuckers'

  robot.respond /review pull request ([^\s]+) ([^\s]+) (\d+)/i, (msg) ->
    msg.send "Thank you, pull request is scheduled for review"
    review_pull_request msg.match[1], msg.match[2], msg.match[3]
