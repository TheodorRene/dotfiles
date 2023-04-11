# Based on:
# ZSH Theme - Preview: https://gyazo.com/8becc8a7ed5ab54a0262a470555c3eed.png
local return_code="%(?..%{$fg[red]%}%?❗%{$reset_color%})"

local user='%{$terminfo[bold]$fg[green]%}%n'
local at='%{$terminfo[bold]$fg[yellow]%}@'
local host='%{$terminfo[bold]$fg[red]%}%m %{$reset_color%}'
local user_symbol='>'

local current_dir='%{$terminfo[bold]$fg[blue]%}%~ %{$reset_color%}'
local git_branch='$(git_prompt_info)'
local venv_prompt='$(virtualenv_prompt_info)'

local vim_prompt='$(vim_prompt_info)'
local vault_prompt='$(aws_vault_prompt)'

PROMPT="${venv_prompt}${current_dir}${git_branch}${vim_prompt}${vault_prompt}${return_code}
%B${user_symbol}%b "
RPROMPT="%B[%*]%b"

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[yellow]%}|"
ZSH_THEME_GIT_PROMPT_SUFFIX="| %{$reset_color%}"

ZSH_THEME_VIRTUAL_ENV_PROMPT_PREFIX="%{$fg[green]%}‹"
ZSH_THEME_VIRTUAL_ENV_PROMPT_SUFFIX="› %{$reset_color%}"
ZSH_THEME_VIRTUALENV_PREFIX=$ZSH_THEME_VIRTUAL_ENV_PROMPT_PREFIX
ZSH_THEME_VIRTUALENV_SUFFIX=$ZSH_THEME_VIRTUAL_ENV_PROMPT_SUFFIX
