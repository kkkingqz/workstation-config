title: ws-terminal
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# TERMINAL WORKSTATION

**Ghostty + Fish — рабочий справочник**  
**Baseline:** 2026-09-21

> Этот документ — краткая практическая справка по текущей терминальной среде.
> Для полного состояния workstation используй `helpws workstation`.

---

## БЫСТРЫЙ СТАРТ

### Основные команды

```console
helpws                 # этот справочник
helpws workstation     # полный baseline workstation
helpws man ws-terminal
helpws man ws-workstation
```

### Главные сочетания

```text
Ctrl+T                  новый tab Ghostty
Ctrl+Shift+C / V        copy / paste
Ctrl+R                  fuzzy history Fish
Option+C                directory browser
Ctrl+Shift+F            поиск в scrollback
Esc                     выход из helpws / Micro
```

---

# GHOSTTY

## Визуальный baseline

```ini
theme = Desert
background-opacity = 0.90
```

- Тема **Desert** используется без ручной коррекции палитры.
- Оконное оформление — нативное GTK4/libadwaita под GNOME.
- Буквенные hotkeys привязаны к **physical keys**, поэтому не зависят от текущей раскладки.

## Tabs

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

## Windows / surfaces

```text
Ctrl+Shift+N            новое окно
Ctrl+Shift+X            закрыть текущую surface
Ctrl+Shift+Q            закрыть окно
```

## Splits

```text
Option+-                split вниз
Option+\                split вправо

Option+H                split слева
Option+J                split снизу
Option+K                split сверху
Option+L                split справа

Ctrl+Shift+←/↓/↑/→      альтернативная навигация

Ctrl+Shift+Option+←     resize влево
Ctrl+Shift+Option+→     resize вправо
Ctrl+Shift+Option+↑     resize вверх
Ctrl+Shift+Option+↓     resize вниз

Ctrl+Shift+Option+Space zoom / unzoom split
Ctrl+Shift+Option+E     выровнять splits
```

## Clipboard

```text
Ctrl+Shift+C            copy
Ctrl+Shift+V            paste
Shift+Insert            paste
```

Ghostty настроен так, что буквенные shortcuts используют физические клавиши. Поэтому `Ctrl+Shift+C/V` работают одинаково в English / Українська / Русская раскладках.

### Clipboard security

- чтение clipboard через terminal protocol — с подтверждением;
- запись разрешена;
- paste protection включена;
- `copy-on-select` включён.

## Search и scrollback

```text
Ctrl+Shift+F            поиск в scrollback
Shift+PageUp            страница вверх
Shift+PageDown          страница вниз
Option+PageUp           небольшой шаг вверх
Option+PageDown         небольшой шаг вниз
Ctrl+Shift+Home         начало scrollback
Ctrl+Shift+End          конец scrollback
Ctrl+Option+Home        предыдущий shell prompt
Ctrl+Option+End         следующий shell prompt
```

## Font size

```text
Ctrl+=                  увеличить
Ctrl+-                  уменьшить
Ctrl+0                  reset
```

## Service keys

```text
Ctrl+Shift+P            command palette
Ctrl+Shift+Delete       clear screen
Ctrl+Option+R           reload Ghostty config
Ctrl+Shift+Option+,     открыть Ghostty config
```

## URL

Ghostty распознаёт обычные URL и OSC8 links. Для OSC8 включён preview реального адреса.

---

# PHYSICAL HOTKEYS

Ghostty преобразует physical key в стандартную terminal sequence. Это делает shell hotkeys независимыми от раскладки.

```text
Ctrl+R      → ASCII Ctrl-R
Option+C    → ESC c / Alt-C
Ctrl+A      → ASCII Ctrl-A
Ctrl+E      → ASCII Ctrl-E
Option+B    → Alt-B
Option+F    → Alt-F
Ctrl+Enter  → Alt+Enter
```

`Ctrl+Enter → Alt+Enter` используется directory browser на `fzf`.

---

# FISH 4.9.3

## Что работает штатно

- syntax highlighting;
- autosuggestions;
- contextual `Tab` completion;
- command history;
- Emacs-style line editing;
- shell integration с Ghostty.

## Autosuggestions

Пример:

```text
ввод:
doc

предложение:
docker compose up -d ...
```

Принять всё:

```text
→
Ctrl+F
Ctrl+E
End
```

Принять следующий shell token:

```text
Ctrl+→
```

## Completion

```console
git <Tab>
systemctl <Tab>
ssh <Tab>
cd ~/Do<Tab>
helpws wo<Tab>
```

`helpws wo<Tab>` должен дополниться до `helpws workstation`.

## Редактирование command line

```text
Ctrl+A                  начало строки
Ctrl+E                  конец строки
Ctrl+B / Ctrl+F         символ назад / вперёд
Option+B / Option+F     слово назад / вперёд
Ctrl+← / Ctrl+→         переход по shell token'ам
Ctrl+U                  удалить к началу строки
Ctrl+K                  удалить до конца строки
Ctrl+W                  удалить предыдущий компонент
Option+Backspace        удалить предыдущее слово
```

---

# HISTORY — CTRL+R

`Ctrl+R` открывает fuzzy history через `fzf`.

```text
печатать                фильтровать
↑ / ↓                   выбрать
Enter                   принять запись
Esc                     отменить
```

Стандартный `fzf Ctrl+T` отключён, потому что `Ctrl+T` занят Ghostty новым tab.

---

# DIRECTORY BROWSER — OPTION+C

`Option+C` открывает браузер **только текущего уровня**, а не всё рекурсивное дерево.

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
Enter на каталоге       войти и остаться в browser
../ + Enter             уровень вверх
./ + Enter              принять текущий каталог и выйти
Ctrl+Enter              принять выделенный каталог и выйти
Esc                     отменить
```

Пример:

```text
Option+C
Downloads/ + Enter
project/ + Enter
./ + Enter
```

Результат:

```text
cwd = ~/Downloads/project
```

---

# ZOXIDE

## Быстрый jump

```console
z down
z project
z docker
```

## Интерактивный выбор

```console
zi
```

Разделение ролей:

```text
Option+C    browser текущего дерева
z NAME      быстрый jump по ранее посещённым каталогам
zi          fuzzy search по базе zoxide
```

---

# EZA

```console
ls      # компактный список
ll      # long + Git
la      # hidden + long + Git
lt      # tree depth=2
```

Используются:

- icons;
- hyperlinks;
- directories first;
- Git metadata для `ll` / `la`.

---

# PROMPT

Пример:

```text
king@MacBookPro-k ~/project (main *) ❯
```

Prompt показывает:

- user / host;
- cwd;
- Git branch/state;
- ненулевой exit status.

После долгой команды справа показывается duration:

```text
12.7s
```

---

# HELPWS

`helpws` открывает Markdown в **Micro read-only**.

```console
helpws
helpws terminal
helpws ghostty
helpws fish
helpws keys
helpws workstation
helpws man ws-terminal
helpws man ws-workstation
```

### Навигация в helpws

```text
стрелки / PgUp / PgDn   навигация
мышь / wheel            прокрутка
Ctrl+F                  поиск
Ctrl+C                  copy
Esc                     выход
Ctrl+Q                  альтернативный выход
```

Micro для `helpws` использует отдельную конфигурацию и не меняет настройки обычного Micro.

---

# USER SCRIPTS / WRAPPERS

Единое место пользовательских executable:

```text
~/.local/bin
```

Правило:

```text
executable       ~/.local/bin/<tool>
config           ~/.config/<tool>/...
data             ~/.local/share/<tool>/...
```

Предпочтительные shebang:

```sh
#!/usr/bin/env fish
#!/usr/bin/env bash
#!/usr/bin/env python3
```

---

# WORKSTATION CONFIG GIT

Единый обычный Git repository:

```text
~/.local/share/workstation-config
```

Структура:

```text
workstation-config/
├── bin/
│   ├── dotgit
│   ├── helpws
│   └── ws-doc-build
├── config/
│   ├── fish/
│   ├── ghostty/
│   └── micro-help/
├── docs/
│   ├── terminal.md
│   └── workstation.md
└── man/man1/
    ├── ws-terminal.1
    └── ws-workstation.1
```

Реальные пути в `$HOME` используют symlink'и на repository.

```console
dotgit status
dotgit diff
dotgit add <file>
dotgit commit -m "message"
```

`dotgit` — wrapper вокруг:

```console
git -C ~/.local/share/workstation-config
```

---

# ДОКУМЕНТАЦИЯ

Markdown — источник истины:

```text
docs/terminal.md
docs/workstation.md
```

Man pages генерируются:

```console
ws-doc-build
```

Просмотр:

```console
helpws
helpws workstation
man ws-terminal
man ws-workstation
```

---

# ОСНОВНЫЕ ПУТИ

## Ghostty

```text
~/.config/ghostty/config.ghostty
~/.config/ghostty/behavior.ghostty
~/.config/ghostty/keybinds.ghostty
~/.config/ghostty/shell-keys.ghostty
```

## Fish

```text
~/.config/fish/config.fish
~/.config/fish/conf.d/eza.fish
~/.config/fish/conf.d/fzf-options.fish
~/.config/fish/conf.d/git-prompt.fish
~/.config/fish/conf.d/user-bin.fish
~/.config/fish/functions/fish_prompt.fish
~/.config/fish/functions/fish_right_prompt.fish
~/.config/fish/functions/fzf_cd_browser.fish
~/.config/fish/completions/helpws.fish
```

## Help viewer

```text
~/.local/share/workstation-config/config/micro-help/
```
