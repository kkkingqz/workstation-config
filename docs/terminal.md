title: ws-terminal
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# Ghostty + Fish — краткий справочник текущей конфигурации

Дата: 2026-09-21

Этот файл описывает функциональность, которая должна работать в текущей конфигурации Ubuntu workstation.

## 1. Общая схема

```text
Ghostty
├── Desert theme
├── 0.90 background opacity
├── tabs / splits / scrollback / search
├── physical layout-independent hotkeys
└── shell integration
     ↓
Fish 4.9.3
├── syntax highlighting
├── autosuggestions
├── contextual completion
├── history
├── fzf
├── zoxide
├── eza
└── custom prompt / directory browser
```

Wave Terminal остаётся отдельным более тяжёлым workspace terminal.

## 2. Ghostty — базовое управление

### Tabs

```text
Ctrl+T                  новый tab
Ctrl+Shift+W            закрыть tab
Ctrl+Tab                следующий tab
Ctrl+Shift+Tab          предыдущий tab
Ctrl+Shift+PageUp       переместить tab влево
Ctrl+Shift+PageDown     переместить tab вправо
Option+1 ... Option+9   перейти к tab 1 ... 9
Option+0                перейти к tab 10
```

На Mac-клавиатуре `Option` используется как `Alt`.

### Windows / surfaces

```text
Ctrl+Shift+N            новое окно
Ctrl+Shift+X            закрыть текущую surface
Ctrl+Shift+Q            закрыть окно
```

### Splits

```text
Option+-                split вниз
Option+\                split вправо

Option+H                перейти в split слева
Option+J                перейти в split снизу
Option+K                перейти в split сверху
Option+L                перейти в split справа

Ctrl+Shift+←/↓/↑/→      альтернативная навигация по splits

Ctrl+Shift+Option+←     изменить размер split влево
Ctrl+Shift+Option+→     изменить размер split вправо
Ctrl+Shift+Option+↑     изменить размер split вверх
Ctrl+Shift+Option+↓     изменить размер split вниз

Ctrl+Shift+Option+Space zoom/unzoom текущего split
Ctrl+Shift+Option+E     выровнять размеры splits
```

### Clipboard

```text
Ctrl+Shift+C            copy
Ctrl+Shift+V            paste
Shift+Insert            paste
```

Буквенные shortcuts привязаны к физическим клавишам, поэтому работают независимо от текущей раскладки.

Clipboard для приложений внутри terminal защищён настройками Ghostty:

- чтение clipboard через terminal protocol требует подтверждения;
- запись разрешена;
- paste protection включена.

### Search и scrollback

```text
Ctrl+Shift+F            поиск в terminal scrollback

Shift+PageUp            страница вверх
Shift+PageDown          страница вниз
Option+PageUp           небольшой шаг вверх
Option+PageDown         небольшой шаг вниз

Ctrl+Shift+Home         начало scrollback
Ctrl+Shift+End          конец scrollback

Ctrl+Option+Home        предыдущий shell prompt
Ctrl+Option+End         следующий shell prompt
```

Ghostty shell integration и Fish prompt marking используются для перехода между prompt'ами.

### Font size

```text
Ctrl+=                  увеличить font
Ctrl+-                  уменьшить font
Ctrl+0                  reset font size
```

### Ghostty service keys

```text
Ctrl+Shift+P            command palette
Ctrl+Shift+Delete       clear screen
Ctrl+Option+R           reload Ghostty config
Ctrl+Shift+Option+,     открыть Ghostty config
```

### URL

Ghostty распознаёт URL и OSC8 links.

URL можно открывать стандартным modifier-click для платформы.

Для OSC8 link включён preview адреса.

## 3. Независимость shortcuts от раскладки

В Ghostty используются physical key bindings (`KeyA`, `KeyC`, `KeyR` и т. п.).

Это значит, что сочетания продолжают работать одинаково при:

```text
English
Українська
Русская
```

Для shell-level сочетаний Ghostty преобразует физическую клавишу в стандартную terminal sequence.

Примеры:

```text
Ctrl+R      → ASCII Ctrl-R
Option+C    → ESC c / Alt-C
Ctrl+A      → ASCII Ctrl-A
Ctrl+E      → ASCII Ctrl-E
Option+B    → Alt-B
Option+F    → Alt-F
```

Отдельное правило:

```text
Ctrl+Enter  → Alt+Enter terminal sequence
```

Оно используется пользовательским directory browser.

## 4. Fish — базовый функционал

Версия:

```text
fish 4.9.3
```

### Syntax highlighting

Fish подсвечивает вводимую command line ещё до запуска.

Существующая команда и несуществующая команда визуально отличаются.

### Autosuggestions

Fish предлагает серым текстом продолжение команды из history и других источников.

Пример:

```text
ввод:
doc

предложение:
docker compose up -d ...
```

Полностью принять autosuggestion:

```text
→
Ctrl+F
Ctrl+E
End
```

Принять следующий token:

```text
Ctrl+→
```

### Completion

Обычный `Tab` использует contextual completion Fish.

Примеры:

```text
git <Tab>
systemctl <Tab>
ssh <Tab>
cd ~/Do<Tab>
```

Fish понимает options, subcommands, paths и completions для многих стандартных CLI tools.

### Редактирование command line

```text
Ctrl+A                  начало строки
Ctrl+E                  конец строки
Ctrl+B / Ctrl+F         символ назад / вперёд
Option+B / Option+F     слово назад / вперёд
Ctrl+← / Ctrl+→         перемещение по shell token'ам

Ctrl+U                  удалить к началу строки
Ctrl+K                  удалить до конца строки
Ctrl+W                  удалить предыдущий компонент
Option+Backspace        удалить предыдущее слово
```

Часть поведения зависит от текущих стандартных Fish Emacs-style bindings.

## 5. История — Ctrl+R

```text
Ctrl+R
```

открывает fuzzy search по history через `fzf`.

Внутри:

```text
печать текста     → фильтрация истории
↑ / ↓             → выбрать запись
Enter             → принять запись
Esc               → отменить
```

Стандартный `fzf Ctrl+T` отключён, так как `Ctrl+T` используется Ghostty для нового tab.

## 6. Directory browser — Option+C

```text
Option+C
```

открывает пользовательский `fzf` browser каталогов.

Он показывает только каталоги текущего уровня.

Пример:

```text
./
../
.config/
.local/
Desktop/
Documents/
Downloads/
...
```

Управление:

```text
Enter на каталоге       открыть его и остаться в browser
../ + Enter             перейти на уровень вверх
./ + Enter              выбрать текущий отображаемый каталог и выйти
Ctrl+Enter              выбрать highlighted каталог и выйти
Esc                     отменить и вернуться в shell
```

Пример:

```text
Option+C
Downloads/ + Enter
project/ + Enter
./ + Enter
```

результат:

```text
cwd = ~/Downloads/project
```

Или:

```text
Option+C
Downloads/ + Ctrl+Enter
```

сразу возвращает shell в `~/Downloads`.

## 7. zoxide

`zoxide` запоминает часто посещаемые каталоги.

### Быстрый jump

```text
z NAME
```

Примеры:

```text
z down
z project
z docker
```

### Интерактивный выбор

```text
zi
```

После открытия:

```text
печатать текст          фильтровать базу zoxide
↑ / ↓                   выбрать
Enter                   перейти
Esc                     отменить
```

Разница:

```text
Option+C    браузер реального текущего дерева каталогов
z NAME      быстрый jump по ранее посещённым каталогам
zi          интерактивный поиск по базе zoxide
```

## 8. eza

`eza` заменяет основной пользовательский workflow `ls`.

```text
ls    компактный список
ll    long listing + Git status
la    long listing + hidden files + Git status
lt    tree depth=2
```

Используются:

- icons;
- hyperlinks;
- directories first;
- Git metadata в `ll` / `la`.

Если terminal font не содержит нужный icon glyph, вместо иконки может отображаться пустой квадрат.

## 9. Prompt

Prompt имеет примерно такой вид:

```text
king@MacBookPro-k ~/project (main *) ❯
```

Показывается:

- user;
- host;
- cwd;
- Git branch/state;
- код ошибки предыдущей команды, если он ненулевой.

Например:

```text
king@MacBookPro-k ~/project [127] ❯
```

Если команда выполнялась дольше примерно 2 секунд, справа отображается duration:

```text
12.7s
```

## 10. Пользовательские scripts и wrappers

Единое место:

```text
~/.local/bin
```

Примеры будущих tools:

```text
~/.local/bin/uectl
~/.local/bin/app-install
~/.local/bin/backup-now
```

Правило:

```text
executable       ~/.local/bin/<tool>
config           ~/.config/<tool>/...
additional data  ~/.local/share/<tool>/...
```

Предпочтительные shebang:

```text
#!/usr/bin/env fish
#!/usr/bin/env bash
#!/usr/bin/env python3
```

## 11. dotgit

Конфигурационные файлы, которые правятся вручную, хранятся в bare Git repository:

```text
Git dir:   ~/.local/share/dotfiles.git
Work tree: $HOME
Wrapper:   ~/.local/bin/dotgit
```

Основные команды:

```text
dotgit status
dotgit diff
dotgit diff --cached
dotgit add <file>
dotgit commit -m "message"
```

Branch:

```text
main
```

В repository применяется whitelist-подход.

Не использовать:

```text
dotgit add .
```

из `$HOME`.

Добавлять только конкретные вручную поддерживаемые файлы.

Текущий tracked set включает Fish, Ghostty и `dotgit` wrapper.

## 12. Основные пути конфигурации

### Ghostty

```text
~/.config/ghostty/config.ghostty
~/.config/ghostty/behavior.ghostty
~/.config/ghostty/keybinds.ghostty
~/.config/ghostty/shell-keys.ghostty
```

### Fish

```text
~/.config/fish/config.fish
~/.config/fish/conf.d/eza.fish
~/.config/fish/conf.d/fzf-options.fish
~/.config/fish/conf.d/git-prompt.fish
~/.config/fish/conf.d/user-bin.fish
~/.config/fish/functions/fish_prompt.fish
~/.config/fish/functions/fish_right_prompt.fish
~/.config/fish/functions/fzf_cd_browser.fish
```

### User tools

```text
~/.local/bin
```

### Dotfiles Git

```text
~/.local/share/dotfiles.git
```

## 13. Быстрая диагностика

### Fish config syntax

```fish
fish -n ~/.config/fish/config.fish

for f in ~/.config/fish/conf.d/*.fish
    fish -n $f
end

for f in ~/.config/fish/functions/*.fish
    fish -n $f
end
```

### Ghostty config

```fish
ghostty +show-config >/tmp/ghostty-effective.conf
```

### Проверка клавиши

```fish
fish_key_reader
```

Полезно для проверки того, что физические hotkeys правильно преобразуются независимо от раскладки.

### Versions

```fish
fish --version
ghostty --version
fzf --version
zoxide --version
eza --version
```

## 14. Что намеренно не добавлено в terminal stack

- Starship;
- Oh My Fish;
- Fisher как обязательный plugin manager;
- Neovim;
- Kitty;
- XWayland workaround для window decorations;
- отдельный shell framework поверх Fish.

Цель текущего setup — быстрый, максимально нативный и небольшой стек, где Ghostty отвечает за terminal/window layer, Fish — за interactive shell, а `fzf`, `zoxide` и `eza` добавляют только конкретные функции.
