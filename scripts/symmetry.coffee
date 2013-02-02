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

GitHubApi = require 'node-github'


Array::difference = (arr) ->
  @filter (el) ->
    arr.indexOf(el) < 0

String::trunc = (n) ->
  @substr(0, n - 1) + (if @length > n then '...' else '')


find_missing_tests = (changed_files) ->
  extract = (filename) ->
    /^(app|spec)(\/(?:contexts|models|services)\/(?:.*\.rb))/.exec(filename) || []

  normalize = (filename) ->
    filename.replace '_spec.rb', '.rb'

  app_files  = []
  spec_files = []

  for file in changed_files
    [_, type, cropped] = extract file.filename

    switch type
      when 'app' then app_files.push cropped
      when 'spec' then spec_files.push normalize(cropped)

  app_files.difference(spec_files).map((i) -> "app#{i}")

find_problems = (commits) ->
  get_symmetry = (message) ->
    ///^\[
      s([\w,]+)
      (?:\||:)
      m([\w,]+)
      (?:\||:)
      r([\w,]+)
      \]///i.exec(message.toLowerCase()) || []

  is_merge = (message) ->
    /^Merge (pull request #|remote-tracking branch '|branch ')/.test message

  overall = []
  ls = rs = 0
  for commit in commits
    commit.problems = []
    message = commit.commit.message
    author  = commit.author.login
    continue  if is_merge message

    [_, s, m, r] = get_symmetry message
    unless s? or m? or r?
      commit.problems.push "No symmetry badge found."
      continue

    ls += 1         if s is 'l'
    rs += s.length  if /r+/.test s

    commit.problems.push "Manual testing was postponed"          if m is 'l'
    commit.problems.push "Commit wasn't reviewed by its author"  if r is 'l'

  if ls > rs
    overall.push "There are `#{ls}` specs postponed and only `#{rs}` specs were added later."

  [overall, commits]

format_message = (overall, commits, missings) ->
  to_list = (items) ->
    items.map((i) -> "* #{i}")

  format_commit = (message) ->
    message.replace(/[\n\r]/g, ' ').trunc(80)

  format_fname = (fname) -> "`#{fname}`"

  message = []
  are_there_problems = commits.map((c) -> c.problems?.length).every((x) -> !x? || x == 0)
  if !overall.length and !are_there_problems and !missings.length
    message.push "Good job, no problems were found in this pull request."
  else

    if overall.length
      message.push '#### Overall'
      message = message.concat overall
      message.push ''

    if commits.length
      message.push "#### Commits review"

      for commit in commits
        continue  unless commit.problems?.length
        message.push "#{commit.sha} #{format_commit commit.commit.message}"
        message = message.concat to_list(commit.problems)
        message.push ''

    if missings.length
      message.push "#### Spec-model correspondance"
      message.push "Are you sure you didn't forget to add specs for those files?  "
      message = message.concat to_list(missings.map(format_fname))
      message.push ''

  message.join("\n")


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

      [overall, commits] = find_problems      commits
      missings           = find_missing_tests files

      pr_id.body = format_message overall, commits, missings
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
