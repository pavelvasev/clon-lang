export var NOVALUE = {novalue: true}

// todo переделать bind. надо bind на target-object. и это зависит как бы от нас
// а нас подписать - это просто нам send послать.
// и тогда не надо будет делать проверку типов (кто нам посылает? надо знать на что у него подписаться).
// это позволит в частнои реализовать Н-модель. Раз на вход send - универсальный протокол.
// хотя можно и по-другному как сейчас, но это не удобно.
// окей а что выдает пропагатор? ответ? интервал? если интервал - как он идет в ячейку?

var global_thing_counter = 0

/* в браузере стек не видно
let orig_cons = console.log
console.log = (...args) => {
	orig_cons(performance.now(),...args)
}
*/

console.channel_verbose = (...args) => {}

if (process.env.VERBOSE)
console.channel_verbose = (...args) => {
	console.log(...args)
	//return true
}

export class Comm {
	constructor() {
		this.$cl_id = (global_thing_counter++)
	}
	toString() {
		return `${this.constructor.name}:${get_title( this )}`
	}
}

export class Channel extends Comm {
	constructor() {
		super()
	}
	submit( value ) {
		this.emit( value )
	}
	// провести сигнал
	emit( value ) {
		console.channel_verbose( "Channel emit:",this+"","value=",value+"" )
		//console.log(this.subscribers)
		this.subscribers.forEach( fn => fn(value) )
		//this.is_cell = true
	}
	subscribers = new Set()
	// подписаться к этому каналу. cb - код
	on( cb ) {
		this.subscribers.add( cb )
		let unsub = () => {
			this.subscribers.delete( cb )
		}
		return unsub
	}
	subscribe( cb ) { // синоним
		return this.on( cb )
	}
	// подписать этот канал на другой канал
	// если были подписки на другие каналы они сохраняются.
	// мб connect_source?
	connect_to( source_channel ) {
		let unsub = source_channel.on( (val) => {
			console.channel_verbose("src",source_channel + "","==>",this+"")
			this.emit(val)
			} )
		return unsub
	}

	// связывание с другими примитивами синхронизации
	bind( source_object ) {
		if (source_object instanceof Channel)
			return this.connect_to( source_object )

		// дают ячейку?
		// ну будем слушать для интереса assigned. а если мало - уточняйте что слушать
		// надо ли установить начальное значение?
		// кстати вообще идея.. если есть set и есть get то сделать всегда set( get() )
		// и может быть - метода get это его значение.. хотя это дорого
		if (source_object instanceof Cell) {
			// проба интересного
			/*
			console.channel_verbose("Channel: schedule copy data from cell (if set)",source_object+"","-->",this+"")
			schedule( () => {
			if (source_object.is_set) {
				console.channel_verbose("Channel: performing scheduled copy data from cell (if set)",source_object+"","-->",this+"")
				//console.log("source cell is set, passing to channel. this=",this+"","src=",source_object+"","value=",source_object.get())
				//console.trace()
				this.emit( source_object.get() )
			}})
			*/
			return this.connect_to( source_object.assigned ) 
		}
		// нам дают на вход реакцию - значит мы слушаем её результаты
		if (source_object instanceof Reaction )
			return this.connect_to( source_object.output )

		//console.log("source_object instanceof ClObject:",source_object instanceof ClObject)
		if (source_object instanceof ClObject) {
			if (source_object.output)
				return this.bind( source_object.output )
			throw new Error(`Channel: do not know how to bind source_object=${source_object}. It has no .output field!`)
		}

		throw new Error(`Channel: do not know how to bind source_object=${source_object}`)
	}
}

export function create_channel() {
	let channel = new Channel()
	return channel
}

export class Reaction extends Comm { // Code?
	constructor( fn ) {
		super()
		// ну вот можно будет так сделать
		//attach( this, "func", create_channel())
		attach( this, "input", create_channel())
		attach( this, "action", create_cell())
		attach( this, "output", create_channel())
		//this.call = create_channel()
		//this.result = create_channel()
		this.input.on( (arg) => {
			let result = this.eval(arg)
			// todo 1 ожидать результатов в процессном режиме, 2 мб посылать промисы а не сами результаты..
			this.output.emit( result ) 
		})

		//this.func.on( (code) => this.set(code))

		if (fn) this.action.set(fn)
	}

	eval( ...args ) {
		let fn = this.action.get()
		return fn.apply( this, args )
	}

	// связывание с другими примитивами синхронизации
	bind( source_object ) {
		// дают на вход канал - значит мы слушаем канал и вызываем метод
		//console.log("method connected to input from",source_object)
		if (source_object instanceof Channel)
			return this.input.connect_to( source_object )
		if (source_object instanceof Cell) {
			let res = this.input.connect_to( source_object.changed )
			if (source_object.is_set) {
				this.input.emit( source_object.get() )
			}
			return res
		}

		if (source_object instanceof ClObject || source_object instanceof Comm) {
			if (source_object.output)
				return this.bind( source_object.output )
			throw new Error(`Reaction: do not know how to bind source_object=${source_object}. It has no .output field!`)
		}

		throw new Error(`Reaction: do not know how to bind source_object=${source_object}`)
	}


}

export function create_reaction(x) {
	let k = new Reaction(x)
	return k
}


export class Cell extends Comm {
	value = null
	constructor( initial_value=NOVALUE ) {
		super()
		attach( this,"changed_emit",create_channel())
		// idea: this.changed_emit = attach( create_channel(),this )
		
		attach( this,"changed",create_channel())
		//this.changed = create_channel(`${title}.changed`)
		// создает процесс передачи на следующий такт с поеданием дублей
		create_binding_delayed( this.changed_emit, this.changed )
		attach( this,"assign",create_channel())
		attach( this,"assigned",create_channel())
		//this.assign = create_channel(`${title}.assign`)
		//this.assigned = create_channel(`${title}.assigned`)
		this.assign.on( (value) => this.set(value))
		// this.set( initial_value )
		// надо еще создавать ячейки без значений.
		// например для вычислений. пока не вычислено же нет результата
		// ну и промисы например - они тоже таковы.
		// но пока это завязано на синтаксис..

		if (initial_value !== NOVALUE) {
			this.value = initial_value
			this.is_set = true
		}
		// вроде как нет смысла вызывать set - в ячейке все-равно еще никто не прицепился
		//this.assigned.emit( initial_value )

		// была идея сделать раздельно assign это для приема, и assigned для уведомлений
	}
	/* вопрос.. метод set как соотносится с каналом assigned?
	   т.е запись в канал вызывает set
	   или вызов set вызывает уведомление канала, что что-то было?

	   update можно сделать assign и то будет запись в assigned
	*/

	submit( value ) {
		//console.log("called submit of this",this)
		this.set( value )
	}
	subscribe( fn ) {
	  if (this.is_set) 
	  	 fn( this.get() )
	  return this.changed.subscribe( fn )
	}

	set( new_value ) {
		console.channel_verbose( "Cell set:",this+"","value=",new_value+"" )
		//console.trace()
		this.is_set = (new_value !== NOVALUE)
		if (new_value != this.value) {
			let old_value = this.value
			this.value = new_value
			//console.log("changed-emit:",new_value)
			//console.trace()
			this.changed_emit.emit( new_value, old_value )
			// вот тут вопрос - а что если ну общее значение emit это кортеж
			// но он же всегда пусть и передается во все on да и все?
		}
		// уже прописано this.value - геттер сработает
		this.assigned.emit( new_value )
	}
	get() {
		return this.value
	}
	// связывание с другими примитивами синхронизации
	bind( source_object ) {
		// дают на вход канал - значит мы слушаем канал и вызываем метод
		//console.log("cell connecting to input from",source_object,"source_object instanceof Method=",source_object instanceof Method)
		if (source_object instanceof Channel)
			return this.assign.connect_to( source_object )
		if (source_object instanceof Cell) {
			let res = this.assign.connect_to( source_object.changed )
			// todo xxx продолжить здесь. идея - проверять что присвоено.
			// ну а если не присвоено ничего не делать. и аналогично в monitor_rest_any проверять..
			// проверять важно. потому что иначе мы нулл начинаем гонять
			if (source_object.is_set)
				this.set( source_object.get() ) // а если там ничего нет?
			else this.is_set = false
			// вообще идея - прогонять этот set с non-set по всей глубине, вышибывая значения
			// и отдельно функции - is_changed проверялка ( а не != ) т.е. пользователь может задать
			// и is_nonset - проверялка что значение несетовое.. хотя его можно в отдельную константу просто..
			// а так пока получается что мы вводим состояние для ячейки - установлена она или нет
			// и дополнительно правила распространения этого состояния
			// ну пока они распространяются на 1 шаг..
			return res
		}
		if (source_object instanceof Reaction) {
			return this.assign.connect_to( source_object.output )
			// надо ли его вызывать?
			//this.set( source_object.get() ) // а если там ничего нет?
		}
		//console.log("source_object instanceof ClObject:",source_object instanceof ClObject)
		// очень большой вопрос. а хорошо ли это. потому что получается, что тепреь в ячейку
		// сам объект то и не положить. вероятно это очень даже не фонтан.
		// очередная удобняшка.
		if (source_object instanceof ClObject) {
			if (source_object.output)
				return this.bind( source_object.output )
			throw new Error(`Channel: do not know how to bind source_object=${source_object}. It has no .output field!`)
		}

		//if (source_object instanceof Function) {
		//	}
		throw new Error(`Cell: do not know how to bind source_object=${source_object} type=${typeof(source_object)}`)
	}
	
}

export function create_cell(value) {
	let k = new Cell(value)
	return k
}

export class ClObject extends Comm {
	constructor() {
		super()
		attach( this,"release",create_channel())
		//this.release = create_channel(`${title}.release`)

		this.release.subscribe( () => {
			// удалим объекты прикрепленные к этому...
			if (this.subobjects) {
				this.subobjects.forEach( obj => {
					if (obj.destroy) obj.destroy()
				})
			}
		})
	}
	destroy() {
		this.release.emit()
	}
	
}

// embed_list массив вида имя, объект, имя, объект..
export function create_object( title, embed_list ) {
	let k = new Object(title)
	return k
}

export class Item extends ClObject {
	constructor(parent, children=[]) {		
		super()
		attach( this,"parent",create_cell(parent))
		//this.parent = create_cell(parent)
		this.parent.changed.subscribe( (val) => {
			// изменили parent
			if (val)
				val.append( this )
		})
		attach( this,"children",create_cell(new Set()))
		//this.children = create_cell(new Set(),`${title}.children`)
		attach( this,"appended",create_channel() ) // добавили ребенка
		attach( this,"removed",create_channel() ) // удалили ребенка
		//this.appended = create_channel()
		//this.removed = create_channel()

		for (let k of children)
			this.append( k )

		this.release.subscribe( () => {
			let parent = this.parent.get()
			if (parent)
				parent.remove( this )
		})
	}
	append( child ) {
		//console.log("append this=",this+"","child=",child+"")
		if (!(child instanceof Item)) return

		this.children.get().add( child )
		if (child.parent.get() != this)
			child.parent.set( this )		
		this.children.changed.emit( this.children.get() )
		this.appended.emit( child ) 
	}
	remove( child ) {
		if (!(child instanceof Item)) return

		let chldrn = this.children.get()
		//if (!chldrn.delete) console.error("chldrn is strange,",chldrn)
		chldrn.delete( child )

		child.parent.set( null )
		this.children.changed.emit( this.children.get() )
		this.removed.emit( child )
	}
}

export function create_item(parent,children=[]) {
	let k = new Item(parent,children)
	return k
}

// а вообще это надо если мы просто через a.b = ... работаем?
// но чилдрены опять же анонимны.. точнее они другое отношение..

// вопрос а надо ли удалять прицепленные объекты?

// вопрос а надо ли имя для подцепляемго объекта? ну пусть там будет анонимный
// список. биндинги так можно хранить. но это начинает напоминать children
// но чилдрен больше для визуальных объектов. ну стало быть можно ввести
// вторую иерархию. по аналогии как .host было. либо сделать как в QML
// что встраивается масса объектов, а некоторые из них еще и дети.
export function attach( target_object, name, embedded_object )
{
	if (target_object.hasOwnProperty(name))
		throw new Error(`target_object already has element name = '${name}'`)
	target_object[name] = embedded_object
	embedded_object.attached_to = target_object
	embedded_object.$title = name
	//embedded_object.title = 
	// todo: имя может тут кстати?
	// добавим еще в список подобъектов зачем-то
	// согласен, список подобъектов надо - чтобы спокойно удалять потом при удалении этого
	attach_anonymous( target_object, embedded_object )
}

export function get_title( obj ) {
	if (!obj.$title) {
		//console.error("get_title: title is not assigned to obj",obj)
		//console.trace()
	}
	if (obj.attached_to)
		return get_title( obj.attached_to ) + "." + (obj.$title || "unknown")
	if (obj.parent && obj.parent.get())
		return get_title( obj.parent.get() ) + "." + (obj.$title || "unknown")	
	return obj.$title || "unknown"
}

export function attach_anonymous( target_object, embedded_object )
{
	target_object.subobjects ||= []
	target_object.subobjects.push( embedded_object )	
}

// зачем нам объект связывания непонятно до конца
// но из компаланга-1 мы вынесли понимание что есть объекты, а есть связи между ними
// и это равноправные вещи. И поэтому binding вынесен в объект
export class Binding {
	constructor( src,tgt ) {
		//if (tgt instanceof Function)
		if (!src.subscribe)
			console.error("binding src have no subscribe method", src + "")

		this.unsub = src.subscribe( tgt.submit.bind(tgt) )

		//this.unsub = tgt.bind( src )
	}
	destroy() {
		this.unsub()
		this.unsub = null
	}
}

export function create_binding( src, tgt ) {
	console.channel_verbose("create_binding:",src+"","~~>",tgt+"")
	let k = new Binding( src,tgt )
	return k
}

// src - ячейка со списком примитивов синхронизации
// tgt - целевой примитив
// при изменении значения src или при срабатывании ячеек-каналов из src
// вызывается tgt
// итого any тут в смысле "любое из"
export function create_binding_any( src, tgt ) {
	if (!(src instanceof Cell))
		throw new Error(`create_binding_any: not cell! ${src+''}`)

	let unsub = () => {}
	let dtgt = create_channel()
	dtgt.$title = "create_binding_any(dtgt)"
	dtgt.attached_to = src
	create_binding_delayed( dtgt, tgt )
	//console.log("create_binding_any src=",src)
	///tgt.on( () => console.log("see tgt event",tgt))
	function f() {
		unsub()
		let cells = src.get()
		unsub = create_binding_when_any( cells, dtgt )
	}
	
	//src.changed.on( () => console.log("src is changed!",src) )
	src.changed.on( f )
	let b2 = create_binding( src.changed, dtgt )
	return { destroy: () => { unsub.destroy(); b2.destroy() } }
}

// создает массив биндингов.. или групповой биндинг? ну к списку
// надо понять
// list - список примитивов
export function create_binding_when_any( list, q ) {
	//let q = create_channel()
	//SSconsole.log("create_binding_when_any, list=",list)
	let barr = []
	for (let k of list) {
		//console.log("connnecting ",k,"to",q)
		let b = create_binding( k, q )
		barr.push( b )
		//k.changed.on( () => console.log("k is changed ",k.get()) )
	}
	let unsub = () => {
		//console.log("unsub called")
		for (let b of barr) b.destroy()
	}
	return { destroy: unsub }
	//return unsub
}

// по списку примитивов синхронизации выдает список из ячеек, привязанных к этому списку
export function create_bound_cells( list ) {
	let barr = []
	let carr = []
	let index
	for (let k of list) {
		//console.log("connnecting ",k,"to",q)
		let c = k instanceof Cell ? k : create_cell()
		let b = create_binding( k, c )
		barr.push( b )
		carr.push( c )
	}
	let unsub = () => {
		//console.log("unsub called")
		for (let b of barr) b.destroy()
	}
	carr.destroy = unsub
	//return { destroy: unsub }
	return carr
}

/*
export class BindingAny {
	constructor( src_list,tgt ) {
		let barr = []
		for (let src of src_list)
			this.unsub = tgt.bind( src )
	}
	destroy() {
		this.unsub()
		this.unsub = null
	}	
}*/

///////////////////////////////////////
// F-DELAYED-EATER
// src, tgt - каналы
// неудобно конечно что это каналы..
// вообще подумать таки над emit который логический
export function create_binding_delayed( src, tgt ) {

	//return create_binding( src, tgt )

	let res = { scheduled: false, destroy: () => unsub() }
	let unsub = src.on( (value) => {
		//console.log("delayed-binding on src=",src+"",". value",value+"","scheduling..")
		//if (value == null) console.trace()
		// console.log("delayed-binding emit",value,"to",tgt)
		// tgt.emit( value ) 
		// return

		if (!res.scheduled) {
			res.scheduled = true
			schedule( () => { 
				res.scheduled = false; 
				console.channel_verbose("delayed-binding real pass",src+""," ---> ",tgt+"")
				//console.channel_verbose("delayed-binding real pass",src+""," ---> ",tgt+"","value",res.value+"")
				tgt.emit( res.value ) 
			})
		} //else console.log("delayed-binding shield! not scheduling")
		res.value = value
	})
	return res
}

let next_tick = []
export function schedule( fn ) {
	next_tick.push( fn )
	if (next_tick.length == 1)
		setImmediate( perform_scheduled )
}

function perform_scheduled() {
	//console.log( "perform_scheduled",next_tick)
	let my = next_tick
	next_tick = []
	for (let k of my)
		k()
}

/*
export class DelayedEater() {
	constructor( src, tgt ) {
		this.src = src
		this.tgt = tgt
	}
}
*/

// src - источник массивов ячеек
// tgt - целевой канал куда слать
// что делает. считывает src рассчитывая увидеть там массив ячеек
// и при изменении значений этих ячеек - собирает их в массив
// и кладет его в tgt
// проблема - если в src не ячейки а другие примитивы, то сборка ломается
export function monitor_rest_values( src,tgt ) {

	let unsub = () => {}

	let dtgt = create_channel()
	dtgt.$title = "create_binding_any(dtgt)"
	dtgt.attached_to = src
	let db = create_binding_delayed( dtgt, tgt )	

		src.changed.subscribe( f )
		f()
		function f() {
			unsub()

			if (!src.is_set) return

			let comms = src.get()
			let cells = create_bound_cells( comms )

			let all = create_channel()
			///attach_anonymous( this, "")
			all.attached_to = src; all.$title = "monitor_rest_values.all"
			
			//consoleА.log("all - subscribing")
			all.subscribe( () => {
				//console.log("all.subscribe ticked")
				let have_not_setted = false
				let values = cells.map( x => x.is_set ? x.get() : have_not_setted = x+"" )
				if (have_not_setted) {
					console.channel_verbose("monitor_rest_values: have non-setted values, exiting. src=",src+"","last non setted:",have_not_setted)
					return
				}
				//console.log("monitor_rest_values: collected",values,"from",src.get())
				console.channel_verbose("monitor_rest_values: collected values from",src+"","emitting to",tgt+"","values=",values,"cells was",src.get() + "")
				dtgt.emit( values )
			})

			let b = create_binding_when_any( cells, all )

			//console.log("eeee this.release",this.release)
			unsub = () => {
				b.destroy()
				cells.destroy()
				unsub = () => {}
			}
	}

	return () => { unsub(); db.destroy() }
}

export function mark_block_function( fn ) {
	fn.is_block_function = true
	return fn
}