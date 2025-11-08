package envi

import os "core:os/os2"
import "core:sys/posix"

enable_raw_mode :: proc() -> posix.termios {
	stdin := posix.fileno(posix.stdin)

	// get current attributes of terminal
	orig_termios: posix.termios
	posix.tcgetattr(stdin, &orig_termios)

	// keep copy of current attributes to reset to after our program exits
	new_termios := orig_termios

	// modify attributes for our needs
	new_termios.c_lflag -= { .ECHO } // disable echoing input
	new_termios.c_lflag -= { .ICANON } // disable canonical mode

	posix.tcsetattr(stdin, .TCSAFLUSH, &new_termios) // set modified attributes

	return orig_termios
}

disable_raw_mode :: proc(orig_termios: ^posix.termios) {
	stdin := posix.fileno(posix.stdin)
	posix.tcsetattr(stdin, .TCSAFLUSH, orig_termios)
}

main :: proc() {
	orig_termios := enable_raw_mode()
	defer disable_raw_mode(&orig_termios)

	nextchar: [1]u8
	len, err := os.read(os.stdin, nextchar[:])
	for len == 1  && nextchar != 'q' {
		len, err = os.read(os.stdin, nextchar[:])
	}
}
