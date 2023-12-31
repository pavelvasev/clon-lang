Платформа C++

Полезные вещи

Есть какое-то any и даже пример работы map-ы с ней:
https://www.cppstories.com/2018/06/any/

Функции произвольного кол-ва аргументов
https://en.cppreference.com/w/cpp/language/parameter_pack
https://stackoverflow.com/questions/1657883/variable-number-of-arguments-in-c

Насчет миксинов если вдруг захочется. Но если что мы их проэмулируем
базовыми классами или макросами (просто припиской)
https://gist.github.com/de-passage/0a608fe426b2fb29f50c38a7761aafc7
https://github.com/atomgalaxy/libciabatta

Дизайн-решения
==============

Объекты генерировать как классы. Потому что динамически не получится добавлять
в объект поля. Поэтому всякие входные каналы и параметры и т.д. и т.п. 
надо добавлять как члены класса.
Соответственно получается что у нас все происходит как бы в классе,
все ячейки и т.п. тоже.
Ну либо вариант, что все происходит динамически, но тогда в кодах придется
писать вещи вида obj['output'].set... ну и это нам просадит сразу
производительность. Поэтому пробуем в классах.

Используем bindings чтобы выполнять вещи в конструкторе. А main - идет 
в определение класса в члены его. Хотя наверное стоило ввести что-то типа members.

Видимо каналы и ячейки должны быть типизированные.. Ну а иначе как с++ узнает
сколько памяти например выделять на хранение значения.. и какие типы у каллбеков..

Видимо novalue в этом смысле приедтся отказаться, потому что не понятно каким
оно должно быть для разных типов.

Хранить ссылки на подписчиков что-то не получилось. Оно не умеет хранить ссылки на функции с замыканиями
просто как функции. А может через std::function. Но последние не умеют сравниваться.
Поэтому найти в подписчиках эти функции не получается.
Решено поэтому идти другим путем - подписка это указатель на объект типа receiver и у него метод submit.
Так все яснее и работает. Но посмотрим как получится сделать реакции.

Оказалось что binding если удаляется то он вызывает объекты метод unsibsribe а если эти объекты
созданы на стеке - то они уже удалены раньше binding-а. Впрочем так будет и с динамикой.
Правильное решение, видимо, это что объект при удалении - удаляет себя сам из всех кто его помнит,
в частности из биндингов.
Ну а и тема про статические вещи - раз у меня все построено на идее что вызвали функцию и она
организовала процесс - то видимо вещи внутри надо делать динамическими все..
Хотя может это и не обязательно..

Идеи
====
Как вариант - мб не стоит передавать initial values - пусть их внешним образом
все шпарят да и все. Так всем проще будет. Ну.

===
что воодушевляет что у LF получилось и более того глядя на их реакторы
понятно что делать.

----
осознается вещь что генерировать процессы из функций - это бонус.

и проще видимо их будет сделать с указанием аргументов а не через сборку rest..

генерация дерева объектов (attach) и их имен (title=) это тоже видимо бонус.

---
передавать по ссылке & значения - тоже бонус.

а главное что возврат значения из реакции похоже тоже бонус..

изменяемое действие у реакций похоже тоже бонус..

/////
https://en.cppreference.com/w/cpp/language/list_initialization