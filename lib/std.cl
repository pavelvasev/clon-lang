




obj "timer" {

  //cells interval=1000 output=0
  in {  interval: cell 1000 }

  output: channel

    init "(obj) => {
    obj.interval.changed.subscribe( f )
    let existing
    function stop() {
	if (existing) clearTimeout( existing )
	    existing = null
    }
    function f() {
	stop()
	existing = setInterval( () => {
	    obj.output.emit()
	}, obj.interval.get() )
    }
    obj.release.on( stop )
    f()
  }"
}

obj "counter" {
  in {
    input: channel
    value: cell 0
  }  
    //output: cell
    output: channel

    x: func {: 
	     self.value.set( self.value.get()+1 )
	     return self.value.get()
    :}

    react @input @x
    bind @value @output
}

/*
obj "js_func" {
  in {
    code: cell    
  }
  output: cell

  m: method "(value) => {
      let js_func = eval(value)
      return js_func
    }"

  bind @code @m
  bind @m @output
}

// но так-то это очень круто если мы реакцию выражаем через связи
obj "reaction" {
  in {
    input: channel
    func: cell
  }
  m: method @func
  bind @input @m
}
*/




obj "add" {
  // rest* : cell
  // output: channel
    in {
      rest*: cell
    }

    output: cell

    x: func {: values |
	    let sum = values[0]
	    for (let i=1; i<values.length; i++)
		    sum = sum + values[i]
	    return sum
    :}

    u: extract @rest

    xx: react @u.output @x /// было @u
    bind @xx.output @output /// было @xx

    //bind @rest @output   
}

obj "apply" {
  in {
    action: cell
    rest*: cell
  }
  u: extract @rest
  output: cell

    x: func {:
      let f = action.get()
      let args = u.output.get()
      if (f && args) {
        let res = f( ...args )
        output.set( res )
      }
    :}

  any: cell
  
  bind @action @any
  bind @u @any

  xx: react @any @x

  //bind @xx @output
}



/*
  // вот тебе три сразу записи.. и for их должен поймать
  for i in (range 0 100) {
  }
  // но кстати
  for (range 0 100) { |i|
  }
*/

/*
compile "let" check_params={: params | return true :} {: obj state |
  let base = { main: [], bindings: [] }

  //  и фичеры.. это у нас дети которые не дети 
  if (obj.features_list) {
    let mod_state = C.modify_parent(state,obj.$name)
    for (let f of obj.features_list) {
      let o = C.one_obj2js_sp( f, mod_state )
      base.main.push( o.main )
      //bindings.push("// bindings from feature-list")
      base.bindings.push( o.bindings )
    }
  }
  
  let strs = []
  for (let k in obj.params) {
    let val = obj.params[k]
    //let s = `let ${k} = ${val.toString()}`
    let val_str = val?.from ? "CL2.NOVALUE" : C.objToString(val)
    let s = `let ${k} = CL2.create_cell( ${val_str} )`
    strs.push( s )
    if (val?.from) {
      //let q = `let ${name} = CL2.create_binding(${obj.params[0].from},${obj.params[1].from})`
      let q = `CL2.create_binding(${val.from},${k}) // from let expr`
      base.bindings.push( q )
    }
  }
  base.main.push( strs )

  return base  
:}
*/

/*
form "if" {: record records index |
    let next = records[index+1]
    if (next.basis == "else") {
      let obj = records[index+1]
      let if_record = record
      records[index+1] = null      
      if (obj.params.hasOwnProperty('0')) {     
        if_record.params.else_value = obj.params[0] // вариант else const
        if (obj.links.hasOwnProperty('0')) { // вариант else (some-expr) и else @link
          /// ето ссылка
          if_record.links.else_value = obj.links[0]
          if_record.links.else_value.to = "else_value"
          if_record.features_list ||= []
          if_record.features_list.push( obj.features_list[0] )
        }
      } else { // вариант else {}        
        let v = Object.values( obj.children )
        v.this_is_env_list = true
        v.env_args = obj.children_env_args
        // todo сделать чилдренов такими же как значение параметров
        // т.е. это массив вот с ключами дополнительными
        if_record.params.else_value = v
      }
    }
    record.basis = "do_if"
    return true // restart
:}
*/
