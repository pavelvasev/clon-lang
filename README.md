# Язык CLON

<img src="dev-docs/clon.jpg" width="256px">

Язык CLON (читается как СЛОН). Состоит из трёх уровней:
1. Координирующий язык программирования. 
2. Уровень реактивных вычислений.
3. Уровень обычных вычислений.

Уровни 1-2 решают задачу описания динамических процессов. Аналоги: React, Kotlin Compose, Lingua Franca, QML и т.п.
Уровень 3 это попытка построить универсальный язык программирования.

## Координирующий язык
Содержит модель описания и вычисления процессов. При этом действия процессов задаются на базовом языке (сейчас Javascript). Понятия модели:
* Примитив синхронизации: канал, ячейка (в будущем еще обещание, поток) получает и раздаёт информацию.
* Действие - обычный программный код, например функция.
* Реакция - связывает примитив синхронизации и действие, запуская действие каждый раз когда появляется сигнал от примитива синхронизации.
* Связь - связывает примитивы синхронизации между собой.
* Процесс - структурная единица, состоящая из примитивов синхронизации, реакций, связей, подпроцессов.

Пример:
```
obj "compute1" {
  in { // задает входные параметры
     input: cell
     coef: cell
  }
  output: cell

  t: timer period=100 // подпроцесс таймера

  react (when_all @input @x @t) {: // реакция на примитивы синхронизации input x t
     // пишем на javascript
     let y = self.input.get() * self.coef.get() + @t.count.get()
     self.output.submit( y )
  :}
}

obj "print1" {
  in {
     input: cell
  }
  react @input {: val |
    console.log(val)
  :}
}

pr1: print1
cmp1: compute1 20 2

bind @cmp1.output @pr1.input
```
Результат - процесс печатающий 
```
40
41
42
...
```

## Уровень реактивных вычислений
На языке возможно описание выражений, состоящих из процессов. Эти выражения соединяют процессы по входам и выходам (ячейкам с именами input и output). Например, в описании
```
someobject alfa=(compute1 (compute2 @x @y) @z | compute3 @w)
```
будут созданы и соединены процессы compute1,2,3, а результат работы выражения будет записываться в канал alfa процесса someobject.
При этом если значения в каналах x,y,z,w меняются, то они пересылаются соответствующим процессам, и выражение может поменять свой результат.
Это есть т.н. реактивные вычисления.

## Уровень обычных вычислений
На языке возможно описание не только процессов и их композиций, но и обычных действий (функций).
Пример описания и вызова функции:
```
func "foo" { x y |       // задает функцию foo с двумя аргументами
  return (@x * (@y + 10))
}
print "foo is" (foo 10 20) // вызывает процесс вычисления foo
```

Используемая вычислительная модель предполагает частичный порядок выполнения операций, а не последовательный как обычно.
Пример порядка выполнения шагов:
```
a := @b + 1                        // шаг 3
b := math.sin (@x) + math.cos (@x) // шаг 2
print @a                           // шаг 4
x := os.fetch "http://current.x"   // шаг 1
return @a                          // шаг 4.1 после шага 4
```
Иногда все-же требуется задать последовательный порядок выполнения действий, для этого введен оператор `=======` (4 или более символов =) который передает управление операторам описанным после него только по завершению всех предыдущих операторов:
```
compute1 ...
compute2 ...
====
print "all done"
```

## Как пользоваться
* Файлы на языке CLON имеют расширение `.cl`. Рекомендуемый порядок работы - размещать каждую программу в отдельном каталоге в файле с именем `main.cl`.
* После написания программы запускается транслятор `clon` (см. далее установка и запуск) который транслирует файл в базовый язык (сейчас только javascript для nodejs и для браузеров).
* Полученный файл можно использовать обычным образом, например запускать из nodejs или подключать в программы для браузера.

## Примеры
В каталоге [tests.official](tests.official) приведены тесты разных возможностей языка.

## Быстрый запуск CLON
Транслятор языка работает в Линукс с установленной Nodejs.
* Зайдите в каталог программы с файлом main.cl
* Выполните команду `npx clon-lang run` которая:
  - скачивает транслятор языка CLON в Javascript
  - транслирует файл `main.cl` в `main.cl.mjs`
  - запускает команду `node main.cl.mjs`.

## Установка и запуск CLON
* Установите пакет `npm install clon-lang -g`. После установки интерпретатор станет доступен по команде `clon`.
* Зайдите в каталог с файлом программы main.cl
* Выполните команду `clon run`.

## Команды CLON
* `clon [main.cl]` - транслирует указанную программу в базовый язык.
* `clon run [main.cl]` - транслирует и запускает указанную программу.
* `clon nest` - скачивает пакеты необходимые программе.
* `clon test` - запускает тесты программы.

## Лицензия
Типа MIT.
2023 Павел Васёв. 

## Благодарности
Значимое участие в обсуждении и выработке идей принимает Михаил Бахтерев.
