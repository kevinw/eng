# TODO

- footsteps with reverb - going to need a way to do dynamic sound in this game about sound
- tab key enters edit mode
- in edit mode, sprites still appear on screen.
    - a major question: should the concept of "scenes" exist?
    - or should scenes be implemented in code only? (I suppose one answer is that they first have to be code anyways, so might as well start there) 
- in edit mode, a toolbar appears on the left side with icon buttons in a grid

## general Jai research projects

- A function for collecting the local variables of a function up until a certain AST node. this will be useful for two things:
    - a generator macro which can turn a function with `yield()` statements into an equivalent state machine. the locals need to be turned into a struct that can be passed into the function, and stored for later re-entry.
    - a `loglocals()` function which would be a quick way to throw local variables onto the screen.