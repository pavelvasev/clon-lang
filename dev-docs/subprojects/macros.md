Макросы-трансформеры.

Потребности:
- реализовать if xxx then xxx else xxx
- реализовать лаконичное обозначение что процесс может строить древовидные структуры.
т.е. надо что-то типа миксина или приписки, аля %tree

Решение.

подумалось что-то вроде декораторов, например

%mixin "source1" 
%mixin "source2"
obj "name" { .... }

или

%tree
obj "name" { .... }

------
Насчет декораторов Миша проговорил что внутри - как-то понятнее

obj "name" {
	%tree
	%mixin "other"
}

и т.д. и т.п. и это даже красиво. но это не сработает для функций например, а для них нам бы тоже хотелось декораторы.

======
Варианты решения
- для if можно было бы сделать особую форму на уровне парсера pegjs и не мучиться. т.к. для пайп например сделали же.

	но вдруг еще захочется.. for там какой-нибудь.. или return например кстати вполне мог бы возвращать просто следующий объект...

  update: ну и сделать там фор.. и что угодно.. Мишина идея что если разрешать делать какие угодно синтаксисы на уровне пользователя.. то это скользкая дорожка.

- для декораторов можно было бы просто отлавливать записи вида %name и класть его в атрибут decorators у obj и func, а дальше они там сами пусть.

Решение 2
- давно была идея что делать транслятору 2 прогона.
1 преобразующий 2 кодогенерирующий
и преоразующий меняет узлы, а кодогенерирующий генерирует как обычно.

причем менять узлы надо так чтобы не только текущий узел смотреть а и следующий например.

ну в итоге приходит идея обобщения что пусть вообще весь список смотрит а мы идем по нему по очереди, и вызываем подходящие трансформеры-макросы и передаем весь список и номер элемента. а эта штука должна вернуть.. новое значение всего списка ну и счетчик уж заодно кстати.

а то мало ли она там удалит то что до нее было - надо и счетчик тогда сдвигать. (удалить до нее - это например xxx if yyyy - тут if по идее удалит)

---------------
о названиях. Как назвать варианты
- декоратор, но декоратор по идее в рантайме обычно работает
- траснформер, подходит но долго ну и обобщение какое-то.. у нас так-то все трансформером является.. любые вычисления...
да и трансы.. зачем это..
- макрос, мило но непонятно. но мило.
  с ним засада что по анлгийски надо писать macro
  а по русски звучит "макрос"
  да и название так-то дебильное (вот ребенку такое объясни.. слово..)
- helper, convertor.. ?
- генератор?
  но он занят в js и питон это другое
- хобот! trunk.. )))
  trunk "if", trunk "mixin"
  но оно как панк..
  кстати идея - максимально коротко..
  а если ma? не вашим не нашим )))
  ma "mixin" {

  }
  это даже троллинг такой ))))

- сахар, штамп, желудь, дескриптор  

надо как-то назвать а там видно будет. ну пусть макрос будет, нам не жалко. ну засада с языком, ну внимание будет включать.

update - по опросу населения слово макрос это глупое слово и непонятно с чем ассоциируется.
поэтому трансформ.

---------------

итого реализация в macros.cl и оно дефолтом пусть подгружается.

F-MACRO F-TRANSFORM

transform "tree" {: i objs state C |
  ... тут как угодно меняем objs
  return {i,objs}
:}

а ну и еще - эти макросы делают понятие "формы" ненужным.
ну потому что форма это частный вид макроса, такой простой который вместо себя подставляет paste-вызов..

----

update работаю с этими трансформами. и пока вижу что реально можно было бы кажется обойтись без них. ну т.е. по сути они - продолжение темы синтаксиса. просто появился еще один уровнень, доп слой так сказать.
- if ... else .... - утащить таки на уровень синтаксиса да и всё.
- imixin, base_class это формы.. paste_file в принципе делается через форму тоже..
- mixin в форме mixin name1 name2 { objs } - делается формой
- выражать вещи в виде декораторов - да реально так-то, но через синтаксис можно их отловить было бы. а так обычная функция..

ну т.е. я действительно похоже посчитал уровень pegjs перегруженным и решил выделить часть его логики вот на уровне т.н. трансформеров..

-----
вот. но макросы, которые = трансформации 1 выражения = формы, надо оставить.
формы нужны. а макросы интересны. просто макрос отвечает например за конвертацию в текст в итоге - т.е. пусть что угодно генерирует но потом дает текст.

а ну и макросы-конверторы=декораторы, перенести в синтаксис. а так он тоже функция которые имеют параметры и целевой объект.. и кстати идея Мишина о группировке целей в {} думаю можно реализовать.

но надо понимать, что полезно таки, чтобы эти односложные макросы-декораторы.. оставались макросами, то есть трансформерами с 1 аргументом. пока до 1 аргумента это еще макрос. 
а больше 1 это уже трансформер от которого мы и чувствуем что надо  отказаться.

-----
итого новая идея такая:

1 macroname 1 2 3 { .. } -- обычная форма. делает что хочет, хоть компилятор повторно вызывает, должна вернуть исходник сгенерированный текст.
2.1. %macroname 1 2 3 %macroname2 4 5 somerecord - тоже форма, но - получает последующее выражение в качестве параметра некоторого имени. если несколько %macro указано то вызываются по цепочке.
таким образом мы получаем внешний вид декораторов. но работают они в момент компиляции. являются формами. и визуально отличимы.
2.2 %macroname 1 2 3 %macroname2 4 5 { somerecord somerecord2 }
- то же самое что п. 2.1. но для группы записей. то ли они поштучно применяются, то ли что - тут разобраться, но выглядит как возможность не дублировать макросы. 
хотя их можно определить и тогда ну вроде как не сильное дублирование.