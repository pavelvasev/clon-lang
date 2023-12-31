// paste "import {spawn} from 'node:child_process'"

import childprocess="node:child_process"
import path="node:path"
import fs='node:fs/promises'

/* todo:
  в таск-режиме spawn создаст задачу которая вернет 1-ю запись из stdout и на этом завершится.
  надо понять что с таким делать.
  вообще там задача это запустить процесс и.. работать с этим процессом т.е. надо бы вернуть объект spawn
  но тогда что означает запись в таск режиме? сам процесс. а в объектном режиме - поток stdout. это же странно все.
  d := spawn ....
  см также 2023-09-07 про os exec.txt
  
*/

// idea создать прокси-объект на папку.
// типа d: dir "path" и далее d["init.js"] или типа того, d.fetch("init.js")

// возвращает путь текущий рабочий каталог
// возвращает путь текущий рабочий каталог + указанный подкаталог/файл
func "cwd" {: subpath |
  return path.resolve( path.join( process.cwd(),subpath || '' ) )
:}

func "join" {: ...parts |
  return path.join(...parts)
:}

func "exist" {: path |
  //console.log('exist',path,process.cwd())
  let mmm0 = fs.access(path, fs.constants.R_OK)
  // мы же работаем в режиме каналов а там надо что-то записать
  // запишем false
  return mmm0.then(result => path).catch( (err) => false )
:}

func "env" {: return process.env :}

func "argv" {: return process.argv.slice(1) :}

// https://nodejs.org/api/fs.html#fspromisescpsrc-dest-options
func "cp" {: src tgt opts| 
  console.log("cp src=",src,"tgt=",tgt)
  opts ||= {recursive:true,errorOnExist:true,force:false}
  return fs.cp( src,tgt, opts )
:}

// os.spawn "ls" stdio="inherit"
obj "spawn" {
  in {
    cmd_args*: cell
    stdio: cell 'pipe'
    dir: cell '' 
  }
  output: channel
  stderr: channel
  stdin: channel
  stdout: channel
  exitcode: cell
  
  bind @stdout @output

/*
  args := extract @cmd_args
  print "spawn args=" @args
  print "spawn dir=" @dir
  print "spawn std=" @stdio
*/  

  rr: react (list @cmd_args @stdio @dir) {: values |
    let args = values[0]
    //console.log("os.spawn spawning",JSON.stringify(values))
    rr.destroy() // больше чтобы не запускать
    // т.е. этот процесс у нас символизирует один запуск
    
     // фича - добавить путь к cl-tool
     // но выяснилось что это не работает если cl-tool r
     // поэтому модифицируем PATH из скрипта cl-tool
     //let tool_dir = path.resolve( path.dirname( process.argv[1] ),"../.." )
     //console.log("computed tool_dir",tool_dir, "due to", process.argv)
     //let s_env = {...process.env}
     //s_env.PATH = s_env.PATH + ":" + tool_dir
    //let child = cp.spawn( args[0], args.slice(1), {env: s_env} )
    let opts = { stdio: self.stdio.get() }
    if (self.dir.is_set) {
      let d = self.dir.get()
      if (d && d.length > 0)
         opts.cwd = d
    }
    // todo мб лучше прямо опции передать да и все. но тогда это несовместимость с др платформами ;-)
    //console.log("spawning args=",args,"opts=",opts)
    
    let child = childprocess.spawn( args[0], args.slice(1),opts )

    // https://stackoverflow.com/questions/14332721/node-js-spawn-child-process-and-get-terminal-output-live
    if (child.stdout) {
      child.stdout.setEncoding('utf8');
      child.stdout.on('data', function(data) {
        // data = data.toString() ?
        // console.log('data',data)
        self.stdout.submit( data )
      })
    }
    if (child.stderr) {
      child.stderr.setEncoding('utf8');
      child.stderr.on('data', function(data) {
        // data = data.toString() ?
        self.stderr.submit( data )
      })    
    }

    child.on('close', function(code) {
      self.exitcode.submit(code)
    })    
    
  :}
}

func "stop" {: code |
  process.exit( code ) 
:}

// чтение файла
func "read" {: url opts |
  // todo приделать сюда таки мб http и прочее
  return fs.readFile(url, 'utf8')
:}

// запись файла
func "write" {: url content |
  // todo если тут урль прям реально? post делать?
  // todo а еще надо бы file:// отрабатывать
  return fs.writeFile( url, content )
:}

obj "watch" { 

  in {
    path: cell
    once: cell false
  }

  output: channel

  react (list @path @once) {:
    let path = self.path.get()
    let once = self.once.get()
  
    //console.log("iter=",iter, iter.next)
    const ac = new AbortController();
    const { signal } = ac;
    
    // что-то вотч рекурсивно не работает.. рекомендуют
    // https://github.com/paulmillr/chokidar
    // https://github.com/nodejs/node/pull/45098 вроде с ноды 19.1
    let iter = fs.watch( path, {recursive: true, signal, persistent: true} )  

    let my_id = Math.random()*10000

    //console.log("started watch",path, once, my_id)

    function process_once() {
      let nx = iter.next()
      // console.log({nx})
      nx.then( rec => {
        //console.log("nx then! my_id=",my_id,rec)
        //console.log("submitting")
        self.output.submit( rec.value )
        if (once) {
          //console.log("after watch, stopping")
          ac.abort(); 
        } else {
          //console.log("after watch, restarting")
          process_once()
        }  
      })
      nx.catch( err => {
        console.log("watch nx err",err)
      })
    }
    process_once()

    //return CL2.create_cell( ch )
  :}

}

func "chmod" {: file perm |
   return fs.chmod( file, perm )
:}


/* вроде бы оно по духу и функция.. но должно вернуть объект..
func "exec" {: ...args |
:}
*/

/*
obj "spawn_stdout" {
  in {
    cmd_args*: cell
  }
  output: cell
  
  p: spawn *cmd_args

  s := reduce_events @p.stdout '' {: val acc | 
    process.stdout.write('>> ' + val); 
    return acc+val :}
    
  react @p.exitcode {:
    output.set( s.get() )
  :}
}
*/