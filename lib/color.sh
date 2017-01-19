#!/usr/bin/env bash
# This scripts export c_ prefixed colors that can be used
# in echo comand
# For example: echo "${c_green}${c_bold}hello${c_normal}"
set -e

if test -t 1; then
  color_cnt=$(tput colors)

  if [[ -n "$color_cnt" && $color_cnt -ge 8 ]]; then
    c_bold="$(tput bold)"
    c_underline="$(tput smul)"
    c_standout="$(tput smso)"
    c_normal="$(tput sgr0)"
    c_black="$(tput setaf 0)"
    c_red="$(tput setaf 1)"
    c_green="$(tput setaf 2)"
    c_yellow="$(tput setaf 3)"
    c_blue="$(tput setaf 4)"
    c_magenta="$(tput setaf 5)"
    c_cyan="$(tput setaf 6)"
    c_white="$(tput setaf 7)"

    export c_bold c_underline c_standout c_normal c_black c_red c_green c_yellow c_blue c_magenta c_cyan c_white
  fi
fi
