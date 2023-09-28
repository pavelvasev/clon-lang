CLON-программы одновременно являются и модулями (слон-пакетами).
Их можно запускать как самостоятельно, так и использовать в других слон-проектах.
Все определения, которые заданы в файле `main.cl` становятся доступны при импорте.

Пример
======

1. Создайте проект `myproj` с файлом `main.cl` следующего содержания:
```
obj "foo" {
  in {
    a: cell
    b: cell
    c: cell
    d: cell
  }
  print "hello" @a @b @c @d
}
```

2. Создайте другой проект и используйте myproj как внешний модуль, см. далее.

Подключение внешних модулей
===========================
Чтобы добавить внешний модуль в проект:

1. Отредактируйте файл clon.mjs и добавьте ссылки нужные на модули
```
export var modules={
  myproj: {git:'https://github.com/name/proj'},
  other: '../my/dir'
}
```
Ссылки на модуль можно указывать 2х видов:
* ссылки на гит-хранилища вида {git:'https://github.com/name/proj'},
* ссылки на папки на диске вида './path/to/dir'

2. Установите модули командой `clon nest`

Затем импортируйте модули в слон-файлах:
```
import my='myproj' other='other'
```
и используйте:
```
my.foo 1 2 3 (other.goo 4 5)
```

Использование проекта как модуля
================================
Чтобы использовать этот проект в других проектах как под-модуль
1. Опубликуйте его в виде гит-хранилища в Интернете или в виде папки на диске. 
2. Добавьте на него ссылки в других проектах согласно инструкции выше.