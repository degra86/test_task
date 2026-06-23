# test_task
Тетсовое задание

# Навигация
./data - файл с данными

./docs - задание

./lib - модули

./scripts - скрипты запуска

./tests - тесты

./old - старое решение

.env.example - пример файла с конфигами

# Запуск

1. perl ./scripts/load_data.pl    - запуск загрузки данных
2. perl ./scripts/start_server.pl - запуск простого веб-сервиса

      Форма поиска данных доступна по адресу http://localhost:8080/

# TODO

- дописать тесты
- больше комментариев богу комментариев


# Требуемые библиотеки Perl

HTTP::Server::Simple::CGI

HTML::Entities

DBI

JSON

FindBin
