load ../helpers
source "$YODA_ROOT/lib/version.sh"

@test "version_normalize adds a .0 patch to x.y versions only" {
  [ "$(version_normalize 2.5)" = "2.5.0" ]
  [ "$(version_normalize 2.5.1)" = "2.5.1" ]
  [ "$(version_normalize 2.6.0-beta.1)" = "2.6.0-beta.1" ]
}

@test "version_key orders versions numerically" {
  [ "$(version_key 2.5)" = "$(version_key 2.5.0)" ]
  [[ "$(version_key 2.10.0)" > "$(version_key 2.9.1)" ]]
  [[ "$(version_key 3.0.0)" > "$(version_key 2.99.99)" ]]
  [ "$(version_key 2.6.0-beta.1)" = "$(version_key 2.6.0)" ]
}
