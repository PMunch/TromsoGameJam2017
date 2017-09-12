# Hold the line

This game was created as part of the [Tromsø Game Jam](https://itch.io/jam/tromso-game-jam) which ran during the weekend 8-10th september.

The game, with all the story, graphics, sounds, and coding was created during that time period. The code was written in Nim by using my other project SDLGamelib, partially to test it in a real world scenario. It's messy and a bit strange, but that's true for most game jam games.

All code created by me in this project is open source MIT licensed. If you want to reuse the arts and or sounds please make contact and I'll relay your interest to those who made it.

Note that the nakefile in this project is probably dated and likely to not work properly. To run the code first install Nim and SDL2 (with mixer, ttf, and image plugins). Then run `nimble install sdl2` and then `nim c --noMain --threads:on -o:holdtheline main`. This compiles the program into the executable named `holdtheline` so simply execute this and it should play.
