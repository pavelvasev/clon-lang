import * as path from 'node:path';

export function setup( st ) {

	let space = st.space

	// добавляет "экпортируемую сущность" в текущий модуль (пока ток функции)
	space.register_item = ( id, state, strs2 ) => {
		let strs = []
		let export_flag = state.dir === "" ? "export " : ""
		let s = `${export_flag}function create_${id}( initial_values )`
		strs.push(`/// type ${id}`,s,"{")
		strs.push( strs2 )
		strs.push("}")
		state.current.exported ||= []
		state.current.exported.push( id )
		return strs
	}

	let module_var_names = {} // srcfile -> name
	let module_counter = 0

	function path_to_var( srcfile ) {
		let p1 = path.basename(srcfile,".cl")
		let p2 = p1.replace( /[^a-z0-9\-\_]/i,"_")
		let p3 = p2 + "_" + (module_counter++).toString()
		return p3
	}

	space.register_import_outer = ( src, resolved_file ) =>
	{
		let module_var_name = path_to_var( resolved_file )
		module_var_names[ resolved_file ] = module_var_name
		let strs = []
		return [ `import * as ${module_var_name} from '${src}'` ]
	}

    // вносим модуль в списки импортов. один и тот же модуль 2 раза вносить не надо.
	space.register_import = ( tgt, srcfile, substate,code ) => {
		let strs = []
		/// используется метод https://habr.com/ru/articles/583130/
		//let names = Object.keys(substate.current).map(n => `create_${n}`).join(",")
		substate.current.exported ||= []
		let names = substate.current.exported.map(n => `create_${n}`).join(",")

		let module_var_name = path_to_var( srcfile )
		module_var_names[ srcfile ] = module_var_name
		
	    let exportvar = `var ${module_var_name} = {${names}}`
	    //let exportvar = `var ${module_var_name} = self`
		// let js_import_path = "./" +  src + ".js"
		// strs.push(`import * as ${tgt} from '${js_import_path}'`)
		strs.push( "////////////////////////////////////////" )
		strs.push( `//////////////////////////////////////// module from ${srcfile}` )
		strs.push( "////////////////////////////////////////" )
		strs.push( "{")
		strs.push( "let self = {}" )
		strs.push( code )
		strs.push( exportvar )
		strs.push( "}")
		strs.push( `//////////////////////////////////////// finished module from ${srcfile}` )		
		
		return strs
	}

	// используем модуль из внесенных ранее в список
	space.register_import_use = ( tgt, srcfile, substate ) => {

		let module_var_name = module_var_names[ srcfile ]

		let exportvar = `var ${tgt} = ${module_var_name}`

		let strs = []
		strs.push( `//////////////////////////////////////// using module ${srcfile} as ${tgt}` )
		strs.push( exportvar )
		
		return strs
	}	

}