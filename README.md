zzd
===

This is my first complex Zig project.  

zzd will loosely copy the functionality of [xxd](https://github.com/ckormanyos/xxd). It will dump the hex of a given file, or from stdin.  
I got the project idea (and name) from [this video](https://www.youtube.com/watch?v=pnnx1bkFXng).  

This project exists for me to learn about Zig. As such, I may go out of my way to make the program more complicated than necessary to learn about parts of the language.  

## Status

Currently produces same output as `xxd` (with no arguments) when tested on the `ascii_range.txt` file (excluding text color). `ascii_range.txt` contains every 8 bit char.  

Functional help page printed on `zzd --help` or when passed malformed arguments.  

## Next Steps

- Handle invalid arguments (e.g. column length must be >0)  
- Replace the reader/writer situation with a system that returns a file (because stdin/stdout can also be treated as a file) then do reader/writer operations on that.  
- Add color?
