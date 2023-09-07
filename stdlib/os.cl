// paste "import {spawn} from 'node:child_process'"

import cp="node:child_process"
import path="node:path"

/* todo:
  в таск-режиме spawn создаст задачу которая вернет 1-ю запись из stdout и на этом завершится.
  надо понять что с таким делать.
  вообще там задача это запустить процесс и.. работать с этим процессом т.е. надо бы вернуть объект spawn
  но тогда что означает запись в таск режиме? сам процесс. а в объектном режиме - поток stdout. это же странно все.
  d := spawn ....
  см также 2023-09-07 про os exec.txt
  
*/

obj "spawn" {
  in {
    cmd_args*: cell
  }
  output: channel
  stderr: channel
  stdin: channel
  stdout: channel
  exitcode: cell
  
  bind @stdout @output

  rr: react (extract @cmd_args) {: args |
    // console.log("os.spawn spawning",JSON.stringify(args))
    rr.destroy() // больше чтобы не запускать
    
     // фича - добавить путь к cl-tool
     let tool_dir = path.resolve( path.dirname( process.argv[1] ),"../.." )
     //console.log("computed tool_dir",tool_dir )
     let s_env = {...process.env}
     s_env.PATH = s_env.PATH + ":" + tool_dir
    let child = cp.spawn( args[0], args.slice(1), {env: s_env} )
    // https://stackoverflow.com/questions/14332721/node-js-spawn-child-process-and-get-terminal-output-live
    child.stdout.setEncoding('utf8');
    child.stdout.on('data', function(data) {
      // data = data.toString() ?
      // console.log('data',data)
      self.stdout.submit( data )
    })
    child.stderr.setEncoding('utf8');
    child.stderr.on('data', function(data) {
      // data = data.toString() ?
      self.stderr.submit( data )
    })    
    child.on('close', function(code) {
      self.exitcode.submit(code)
    })
    //let s = spawn( args[0], args.slice(1),{ stdio: 'inherit' })
  :}
}

/* вроде бы оно по духу и функция.. но должно вернуть объект..
func "exec" {: ...args |
:}
*/