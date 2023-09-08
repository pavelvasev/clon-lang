import { access, constants } from 'node:fs/promises';

import {spawn} from 'node:child_process'

export function init( state, tool ) {

	tool.add_command( "run", (file="main.cl") => {

		tool.get_command("compile")( file ).then( (out_file) => {
			console.log("spawning")
			let node_path = process.execPath // "node"
			let s = spawn( node_path, [out_file],{ stdio: 'inherit' })
			// также можно запускать через import...
		})

	})
	tool.add_command("r", tool.get_command("run"))
}
