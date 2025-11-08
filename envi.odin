package envi

import os "core:os/os2"
import "core:sys/posix"

enable_raw_mode :: proc() {
	stdin := posix.fileno(posix.stdin)

	raw: posix.termios
	posix.tcgetattr(stdin, &raw) // get current attributes of terminal

	// modify attributes for our needs
	raw.c_lflag -= { .ECHO } // disable echoing input

	posix.tcsetattr(stdin, .TCSAFLUSH, &raw) // set modified attributes
}

main :: proc() {
	enable_raw_mode()

	nextchar: [1]u8
	len, err := os.read(os.stdin, nextchar[:])
	for len == 1  && nextchar != 'q' {
		len, err = os.read(os.stdin, nextchar[:])
	}
}
