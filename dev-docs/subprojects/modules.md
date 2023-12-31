# Модули
F-MODULES

Существует потребность в следующем:
- размещать фичи в компиляторе (cl-tool)
- добавлять в проект библиотеки, доступные для импорта пользовательскими кодами (оператор import).
- задавать карту импорта, то есть таблицу соответсвия имен импорта и фактическому размещению этих библиотек
(когда пишем import a="alfa" то чему соответствует alfa?)
- устанавливать библиотеки и модули из внешних источников в локальные каталоги

Эти потребности решено закрыть с помощью т.н. модулей.
Модуль это папка, в которой есть файл init.js. 
Этот файл может (но не обязан) содержать следующее:
* функцию `init( state,tool)` которая вызывается на старте компилятора и может добавлять в него фичи, в том числе операторы для языка.
* переменную `modules` с описанием карты импорта текущего модуля, которая будет использоваться при компиляции всех файлов модуля.

Например:
```
// запускается на старте компилятора
export function init( state, tool ) {
	// добавим команду к cl-tool, чтобы запускать cl-tool help
	tool.add_command("help",() => {
		console.log("help is.")
	})
	// добавим оператор beep, доступное во всех файлах при компиляции
	state.env["beep"] = {
		check_params: () => true,
		make_code: ( obj ) => {
			play_sound( obj.params[0] || 0 )			
			// ничего не добавлять в генерацию кодов
			return { main: [], bindings: [] }
		}
	}
}

// карта используемых модулей
export var modules = { 
	 "alfa": { dir: "./modules/alfa-lib" },
	 "lib3d": { git: "github.com/bla/bla", dir: "lib3d" }
}
```

Предлагается считать, что пользовательские проекты это тоже модули, 
в смысле порядка обработки файла `init.js`.

При старте компилятора загружается `init.js` из текущего каталога (считается что это файл проекта).
* Процедура рекурсивно повторяется для всех модулей, перечисленных в переменной modules.
* Имена словаря modules запоминаются для карты импорта текущего модуля.
* Вызывается init.js.

Таким образом вышеобозначенные потребности решаются, и причем рекурсивно.
При передаче управления модулю, оно передается дальше исходя из модулей используемых им, и т.д.

Аналогичная рекурсивная ситуация и при установке модулей из внешних источников. 
При этом считается, что все модули в итоге должны быть загружены в некий каталог 
в линейном порядке, а не в древовидном.