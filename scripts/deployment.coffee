# Description:
#   Deploys repository to specified env
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot deploy <user>/<repo> to <environment> - deploys ruby repository via rake:<env> command
#

require '../lib/core_ext'
exec = require('child_process').exec


tmp_dir = (repo = null) ->
  "/tmp/talbot" + (if repo then "/#{repo}" else "")

# each command runs in its own environment and since heroku doesn't have bundler
# we have to made up our own directory for gems and also take in account that
# each terminal is virtual and without real locale
exec_in_env = (cmd, cb) ->
  exec """export LANG="en_US.UTF-8" && export GEM_HOME=#{tmp_dir '.gems'} && export PATH=#{tmp_dir '.gems/bin'}:$PATH && #{cmd}""", cb

reponame = (user, repo, env) ->
  "#{user}/#{repo}@#{env}"


init = (cb) ->
  # heroku doesn't have bundler inside of it by-default so we have to install it manually
  exec "mkdir -p #{tmp_dir()}", (error, stdout, stderr) ->
    return cb(error, stdout, stderr)  if error

    exec_in_env "gem install bundler", cb

cleanup = (repo, cb) ->
  exec "rm -rf #{tmp_dir repo} #{tmp_dir repo}.tar #{tmp_dir '.gems'}", cb

# because we can't clone repo by api token and setting up ssh keys is too much of a hassle
# also this gurantees that we don't commit or otherwise fuck up our repo and
# download only what we actually need instead of full history
fetch_repo = (user, repo, cb) ->
  exec """curl -H "Authorization: token #{process.env.HUBOT_GITHUB_TOKEN}" -L -o #{tmp_dir repo}.tar.gz https://api.github.com/repos/#{user}/#{repo}/tarball""", (error, stdout, stderr) ->
    return cb(error, stdout, stderr)  if error

    exec "tar -xzf #{tmp_dir repo}.tar.gz -C #{tmp_dir()}", (error, stdout, stderr) ->
      return cb(error, stdout, stderr)  if error

      exec """tar -tf #{tmp_dir repo}.tar.gz | head -1 | sed "s/\\/$//" """, (error, stdout, stderr) ->
        return cb(error, stdout, stderr)  if error || stderr

        path = stdout.lines()[0]
        exec "mv #{tmp_dir path} #{tmp_dir repo}", cb


bundle_install = (repo, cb) ->
  exec_in_env "cd #{tmp_dir repo} && #{tmp_dir '.gems/bin'}/bundle install", cb

deploy = (repo, env, cb) ->
  exec_in_env "cd #{tmp_dir repo} && rake deploy:#{env}", cb

handle_error_constructor = (msg, user, repo, env) ->
  (step, cb) ->
    (err, stdout, stderr) ->
      if err || stderr
        console.log "Deployment error #{step}: `#{err}`, `#{stdout}`, `#{stderr}`"
        msg.send "There was a problem during #{step} of #{reponame user, repo, env}, which resulted in :\n\n#{err}.\n\nSTDOUT:\n#{stdout}\n\nSTDERR:\n#{stderr}"
        cleanup repo
      else
        console.log "Deployment success #{step}: `#{stdout}`"
        cb()


module.exports = (robot) ->
  robot.respond /deploy ([^\s\/]+)\/([^\s]+) to ([^\s]+)/i, (msg) ->
    [_, user, repo, env] = msg.match

    msg.send "Deployment of #{reponame user, repo, env} is in progress, it might take awhile"
    handle_error = handle_error_constructor msg, user, repo, env

    init handle_error "initialization", ->
      fetch_repo user, repo, handle_error "repo download", ->
        bundle_install repo, handle_error "bundle install", ->
          deploy repo, env, handle_error "deployment", ->
            cleanup repo, handle_error "cleanup", ->
              msg.send "#{reponame user, repo, env} was successfully deployed"
