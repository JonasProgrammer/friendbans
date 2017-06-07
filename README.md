# Friendbans
_Simple ugly ruby script to check the friend list of one or more steam profiles for
VAC/game bans._

## Usage
*Linux (and probably other \*NIX):*
```shell
STEAM_API_KEY=12342134asdfasdf ./friendbans.rb -o asc -p 765612341234
```
*Windows:*
```
set STEAM_API_KEY=12342134asdfasdf
ruby friendbans.rb -o asc -p 765612341234
```

### Multiple profiles
In order to scan multiple profiles, provide the -p flag more than once. Profiles can be
given as steam IDs, steam community URLs (both _/profiles/12341234_ and _/id/asdfasdf_
format) or vanity URL names (the the part behind _/asdf_).

### Detail
```
Usage: firendbans.rb -p profile [-o order]
    -p, --profile PROFILE            Specifies which profile(s) to check
    -c, --combine X                  Combine X (1..200, def. 50) steam IDs per call
    -o, --order [ASC|DESC]           Specifies the order of ban dates to print
    -h, --help                       Prints help
```

## Dependencies
_friendbans_ depends on the following gems:
* colorize
* json
* restclient

## FAQ
#### It always says `LoadError: cannot load such file`
Make sure all required gems are installed.
#### I'm getting an _Error getting friends_ message
Likely one of the checked profiles is private. Friends cannot be retrieved for private
profiles, not even with the API. Remove the profile from the list to check and go on.
#### Can I mix various profile/ID formats in one call?
Yes, it should work fine.
