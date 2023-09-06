// F-DEFAULT-CL

// таки мысли что надо сделать Cl2.create_reaction( comm, code )
obj "react" {
  in {
    input: channel
    action: cell
    children_action&: cell
    // вопрос - а как указать что чилдренов надо компилировать в вычислительном режиме?

  }
  // output: channel
  // нам надо биндится к результатам тасков.. таски выражаются react-ами.. поэтому надо ячейки
  // потому что вот таска сработала, это вызывает другую таску, та создает процесс, а 
  // технология такова что тот процесс начинает зачитывать output-ы вот реакций.. и ничего не прочитает
  // хотя формально если нам надо таски, так и надо делать таски
  //output: cell is_changed={: new old | return true :}
  // теперь можно и канал - т.к. таски сделаны отдельно внешним образом
  // но вообще - в ЛФ вот порт хранит значение.. может и нам хранить? что такого.. (ну gc.. а ну и еще копии промежуточных данных в памяти.. ну посмотрим)
  output: channel

  init "(obj) => {
    //console.channel_verbose('------------- react: ',self+'','listening',input+'')
    let unsub = input.on( (value) => {
      let fn = action.get()      
      //console.log('react input changed. scheduling!',self+'','value=',value)
      CL2.schedule( () => { // принципиальный момент - чтобы реакция не срабатывала посреди другой реакции
        //console.log('react invoking scheduled action.',self+'')
        //console.log('react scheduled call !!!!!!!!!!!!',fn,self+'')
        let result
        if (fn.is_block_function)
          result = fn( self, CL2.create_cell(value) )
        else  
          result = fn( value )
        //console.log('react result=',result+'')

        if (result instanceof CL2.Comm) {
          // console.log('see channel, subscribing once')
          // вернули канал? слушаем его дальше.. такое правило для реакций
          // но вообще это странно.. получается мы не можем возвращать каналы..
          // но в целом - а зачем такое правило для реакций? может его оставить на уровне apply это правило?
          let unsub = result.once( (val) => {
            // console.log('once tick',val,output+'')
            output.submit( val )
          })
        }
        else {
          //console.log('submitting result to output',output+'')
          output.submit( result )
        }
      })
    })

    self.release.on( () => unsub() )
  }"
}

/* // реакция в стиле ЛФ
obj "react" {
  in {
    input: channel
    action: cell
    children_action&: cell
  }
  input_d: channel
  output: channel

  bind @children_action @action

  init "(obj) => {
    //console.channel_verbose('------------- react: ',self+'','listening',input+'')
    CL2.create_binding_delayed( input, input_d)
    input_d.on( (value) => {
      let fn = action.get()
      let result
      if (fn.is_block_function)
        result = fn( self, CL2.create_cell(value) )
      else  
        result = fn( value )
      output.emit( result )
    })
  }"
}
*/

// в extract складывается массив ячеек, а на выходе он дает массив значений этих ячеек..
obj "extract" {
  in {
    input: cell // можно channel но монитору нужна ячейка
  }
  
  output: cell

    o2: channel
    bind @o2 @output

    init "(obj) => {
  let p = CL2.monitor_rest_values( input, o2 )
  obj.release.on( p )
    }"
}

obj "print" { 
  in {
    rest* : cell
  }

  /*
  x: func {: values | console.log(...values) :}
  print_vals: extract @rest
  b: react @print_vals.output @x
  */
  b: react (extract @rest) {: values | console.log(...values) :}

  // ну типа.. напечатали.. пошлем об этом сообщение.. можно даже значения вернуть если что
  output: channel
  bind @b.output @output

  /*
  reaction (extract @rest) {: values |
    console.log(values)
  :}*/

}

// if @cond (block { }) (block { })

obj "else" {
  in {
    value: cell
    else_block&:cell
  }
  bind @else_block @value
}

obj "if"
  {
  in {
    condition: cell // если канал то тогда константы не получается подставлять..
    then_value: cell
    else_value: cell

    then_block&: cell

    _else~: cell

    //debuglog: cell {: :}
    debug: cell false
  }
  output: cell
  current_state: cell 0 // 0 uninited, 1 then case, 2 else case
  current_parent: cell

  // режим if @cond {}
  bind @then_block @then_value

  //bind @_else.value @else_value  
  // _else является ячейкой, содержащей объект
  // мы в выражениях пока не умеем обратиться к значению этой ячейки, увы
  // да и bind является статической вещью. т.е. это не объект, который отслеживает свои аргументы
  // но он мог бы быть таким, если ввести модификатор для параметра - что надо не связывать,
  // а класть сам синхро-канал в значение
  // но в целом получается что выражение типа cellname.a.b.c является процессом
  // типа geta cellname a b c
  /*
  react @_else { |_else_obj|
    bind @_else_obj.value @else_value
  }
  */

  r_else_obj: react @_else {: val |
    //if (debug)
    //console.log("r1")
    let s1 = val.value.subscribe( (ev) => {
      //console.log("r2",ev)
      else_value.set( ev )
    })
  :}

  cleanup_current_parent: func {:
    //console.log("cleanup_current_parent",current_parent.get())
      if (current_parent.is_set) {
          let cp = current_parent.get()
          cp.destroy()
          current_parent.set( null )
        }
    :}

  activate_branch: func {: branch_value arg |
        cleanup_current_parent()

        //console.log("activate-branch: ",branch_value)

        if (branch_value?.is_block_function) {
          //console.log("activate-branch: is-block-function",branch_value)
          let cp = CL2.create_item()
          self.append( cp )
          current_parent.set( cp )

          let arg_cell = CL2.create_cell( arg )
          CL2.attach_anonymous( cp, arg_cell )

          let res = branch_value( cp, arg_cell )
          //output.set( res )
          // ну вроде как там теперь return должен срабатывать
          // т.е это забота ветки - находить output
        } else {
          //console.log("activate-branch: not block-function",branch_value)
          output.set( branch_value )
        }
  :}

  r_on_then_val: react @then_value {: value |
    if (current_state.get() == 1) {
      activate_branch( then_value.get(), condition.get() )
    }
  :}

  r_on_else_val: react @else_value {: value |
    //console.log("else_value changed:",else_value.get(),"current_state.get()=",current_state.get(),"condition=",condition.get())
    if (current_state.get() == 2) {
      //console.
      activate_branch( else_value.get(), condition.get() )
    }
  :}

  r_on_cond: react @condition {: value |
    //console.log("if react on condition",value + "",current_state.get(),"self=",self+"")
    //console.trace()
    if (value) {
      if (current_state.get() != 1) {
        //console.log("if activating branch then",value,"then-value=",then_value.get(),"then-block=",then_block.get())
        activate_branch( then_value.get(), value )
        current_state.set( 1 )
      }
    } else {
      if (current_state.get() != 2) {
        // ну пока так..
        //let els_value = _else.get() ? _else.get().value.get() : else_value.get()
        activate_branch( else_value.get(), value )
        //activate_branch( else_value.get(), value )
        current_state.set( 2 )
      }
    }
  :}
}

// ну посмотреть на его поведение.. сейчас странная цепочка
// мб вернуться к parent-у и реакцию на parent
obj "return" {
  in {
    value: cell
  }

    // ну тут история что value сразу срабатывает. а может быть имеет смысл delayed сделать..
    // тогда парент-а проверять не придется т.к. он как правило есть
    // но вообще хорошо бы парента просто в обязательные параметры
    react @value {: value |
      // надо добраться до некотого блока возвращающего значения.. и передать его туда
      //let p = self.attached_to
      // спорная реализация.. я тут не проверяю parent на изменение
      // но впрочем как и всю цепочку.. будем посмотреть
      let p = self.parent && self.parent.is_set ? self.parent.get() : self.attached_to
      //console.log('============ return acting',self+"",self)
      //console.log("============ return reacting", p+"")
//      console.trace()
      while (p) {
        //console.log("=========== return checking p=",p+"")
        if (p.output) {
          //console.log("================== return found output", value,p.output + "")
          p.output.set( value )
          return "return_found_output"
        }
        //console.log("it has no ouytput",JSON.stringify(p))
        p = p.parent ? p.parent.get() : p.attached_to
      }
      console.error("return: failed to find output cell!",self+"")
      return "return_not_found_output"
    :}
}

/*
obj "return" {
  in {
    value: cell
  }

  if @self.parent { 
    print "OK RETURN HAVE PARENT"

    // ну тут история что value сразу срабатывает. а может быть имеет смысл delayed сделать..
    // тогда парент-а проверять не придется т.к. он как правило есть
    // но вообще хорошо бы парента просто в обязательные параметры
    react @value {: value |
      // надо добраться до некотого блока возвращающего значения.. и передать его туда
      let p = self.parent.get()
      //console.log("============ return reacting", p+"")
      //console.trace()
      while (p) {
        //console.log("=========== return checking p=",p+"")
        if (p.output) {
          //console.log("================== return found output")
          p.output.set( value )
          return {return_found_output:true}
        }
        p = p.parent.get()
      }
      return {return_found_output:false}
    :}

  } else {
    print "OK RETURN HAVE NO PARENT"
    react @value {: value |
      console.log("============ return reacting, no-parent mode")
    :}
  }
}
*/

obj "block" {
  in {
    output&: cell
  }
}

/*
obj "task" {
  in {
    basis_func: cell
    bindings: cell
    consts: cell
  }
  output: cell

  incoming_vals: extract @bindings

  react @incoming_vals.output {: vals |
    // .. merge_vals_to_consts
    let obj = basis_func( consts )
    obj.output.subscribe( (result) => {
      self.output.set( result )
    })
  :}
}
*/

obj "when_all" {
  in {
    rest*: cell
  }
  output: channel
  init {: 
    let unsub = () => {}
    rest.subscribe( (list) => {      
      unsub()
      let q = CL2.when_all( list )
      // вот все-таки порты LF и наши каналы это разное. 
      // ибо порты их держат сооощение 1 такт. и это прикольно.
      // а нас пока спасает что там внутри - delayed стоит.
      let b = CL2.create_binding( q, output )
      unsub = () => { q.destroy(); b.destroy() }
    })
    self.release.subscribe( () => unsub() )
  :}
}

obj "apply" {
  in {
    action: cell
    rest*: cell
  }
  u: extract @rest
  output: cell

  xx: react (when_all @action @u.output) {:
      
      let f = action.get()
      let args = u.output.get()
      //console.log("x-apply",f,args)

      if (f && args) {
        let res = f( ...args )
        //console.log("apply res=",res,"f=",f)
        // типа если вернули канал - то зацепку за его значение нам обеспечит react
        return res
        /*
        
        //if (f.awaitable) res.then(val => output.set( val ))
        // console.log("CCC f.is_task_function=",f.is_task_function,"f=",f)
        if (f.is_task_function && res instanceof CL2.Comm) {
          console.log("task fn!",res + "")
          // вернули канал? слушаем его дальше..
          let unsub = res.once( (val) => {
            console.log("once",val)
            output.set( val )
          })
        }
        else
          output.set( res )
        */  

      } 
    :}

  bind @xx.output @output
}

//// арифметика

func "plus" {: ...values |    
  let sum = values[0]
  for (let i=1; i<values.length; i++)
      sum = sum + values[i]      
  return sum
:}

alias "plus" "+"

func "minus" {: ...values |  
  let sum = values[0]
  for (let i=1; i<values.length; i++)
      sum = sum - values[i]      
  return sum
:}

alias "minus" "-"