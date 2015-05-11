fs = require 'fs'
{print} = require 'util'
{spawn, exec} = require 'child_process'

try
  which = require('which').sync
catch err
  if process.platform.match(/^win/)?
    console.log 'WARNING: the which module is required for windows\ntry: npm install which'
  which = null

launch = (cmd, options=[], callback) ->
  cmd = which(cmd) if which
  app = spawn cmd, options
  app.stdout.pipe(process.stdout)
  app.stderr.pipe(process.stderr)
  app.on 'exit', (status) ->
    if status is 0
      callback()
    else
      process.exit(status);

build = (watch, callback) ->
  if typeof watch is 'function'
    callback = watch
    watch = false

  options = ['-c', '-o', 'dist', 'src']
  options.unshift '-w' if watch
  launch 'coffee', options, callback

task 'build', build
task 'sbuild', build
