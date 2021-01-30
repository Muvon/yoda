#!/usr/bin/env bash
set -e

# Usage: array_flip [name of index] [value of array]
# Example:
#  array=(one two three four)
#  array_flip array_index "${array[@]}"
array_flip() {
  local index_name=$1
  shift
  local -a value_array=("$@")
  local i
  # -A means associative array, -g means create a global variable:
  declare -g -A "$index_name"
  for i in "${!value_array[@]}"; do
    eval "${index_name}['${value_array[$i]}']=$i"
  done
}

# Usage: array_join [separator] [array]
# Example:
#  array=( a b c )
#  array_join "," "${array[@]}"
array_join() {
  local sep=$1
  shift
  local arr=("$@")
  local result
  result=$(printf "$sep%s" "${arr[@]}")
  echo "${result:${#sep}}"
}
