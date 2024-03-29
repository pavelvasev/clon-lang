/*
  PARTS - кусочки.

  Назначение: формирование программ аддитивным образом.

  Программа (или компонента) собирается из набора "фич". 
  Каждая фича содержит кусочки.

  Программа берет фичи, в требуемых местах выбирает из фич 
  кусочки с одинаковым идентификатором, и применяет их.

  Функции (процессы):
    parts.get: массив-фич, идентификатор -> массив кусочков.
    parts.create: массив-функций -> процесс создания объектов описанных в функциях
    parts.func_chain: массив функций -> функция, которая построена по принципу цепочки (см ниже)
*/

/* пример кусочка:

   process "some_feature" {
     top_gui_panel := { dom.button "Привет" dom.element "span" "Нажмите кнопку" }
     output := @self
   }

   features_list := list (some_feature) ... 
*/


// добывает кусочки из списка объектов
// сделано процессом, это позволяет кусочкам меняться во времени
// требование - каждый кусочек должен быть ячейкой (или каналом)
/*
   пример:

   import parts="std/parts.cl"

   items := parts.get @features_list "top_gui_panel"
*/
// примечание. на самом деле это процесс map-get. просто наш map он не процесс, увы.
// ну вообще-то тут еще и чистка - убираем пустые записи.
process "get" {
  in {
    features: cell
    id: cell
  }

  incoming_cells := apply {: f id | return f.map( x => x[id] ).flat().filter( v => v) :} @features @id
  output := xtract @incoming_cells | compact
  //list **incoming_cells | compact  

  react @output {: v |
      if (v.length == 0)
        console.warn("parts.get: найдено 0 частей для ",self.id.get())
  :}
}

/* Создает объекты указанные в кусочках. Кусочки должны быть функциями.

   пример:

   import parts="std/parts.cl"

   dom.element "div" {
     parts.create @items
     parts.create (parts.get @features_list "some_feature")
   }

   todo: добавить rest-значений
*/
mixin "tree_lift"
process "create"
{
  in {
    parts: cell
    arg: cell false
  }
  repeater @parts { c |
    apply_children @c @arg
  }
  //print "parts created called. parts=" @parts
}

// возвращает функцию построенную из кусочков
/*
  замысел - чтобы строить большую функцию из набора маленьких функций, определенных в разных контекстах (см. get_parts)
  что позволяет собирать функционал из разных "фич".

  функции-участнику первым параметром передается указатель на функцию next(args)
  это позволяет каждой функции:
  - остановить работу цепочки, например по ошибке
  - заменить аргументы для цепочки
  - заменить результат цепочки.
  в целом получается это довольно полный контроль в стиле prepend - переопределения функции.

  возможно это излишне. и достаточно просто вызывать по цепочке.
  а сделать pre_action и от них потребовать возврата true если все хорошо.
  т.о. мы часть только можем сделать. но этого мб и достаточно.
  а результат например это результат последней.
  или массив результатов если это применимо.

  пример:

  react @channel (parts.func_chain (parts.get @features "important_action"))
  
  idea: next передавать мб в this проще, а не 1м аргументом.

*/
func "func_chain" {: funcs |

  function invoke( num, ...i_args ) {
    if (num >= funcs.length) return true;
    let next_fn = ( ...new_args ) => invoke( num+1, ...new_args )                  
    return funcs[num]( next_fn, ...i_args )
  }

  //if (funcs.length == 0) console.warn("func_chain: 0 функция в цепочке.")

  return (...args) => invoke( 0, ...args)
:}