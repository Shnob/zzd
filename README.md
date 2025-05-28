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

- Allow optional input from files  
- Allow optional output to files  
- Allow arbitrary column width (currently fixed to 16)  
