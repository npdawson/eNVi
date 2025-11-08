package envi

import "core:fmt"
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
	// input flags
	new_termios.c_iflag -= { .BRKINT, .INPCK, .ISTRIP }
	new_termios.c_iflag -= { .ICRNL } // disable ctrl-m being the same as ctrl-j
	new_termios.c_iflag -= { .IXON } // disable flow control (ctrl-s & ctrl-q)
	// output flags
	new_termios.c_oflag -= { .OPOST } // disable output processing
	// control flags
	new_termios.c_cflag += { .CS8 } // Character Size 8 bits
	// local flags
	new_termios.c_lflag -= { .ECHO } // disable echoing input
	new_termios.c_lflag -= { .ICANON } // disable canonical mode
	new_termios.c_lflag -= { .ISIG } // disable signals (e.g. ctrl-c, ctrl-z)
	new_termios.c_lflag -= { .IEXTEN } // disable ctrl-v

	// read timeout
	new_termios.c_cc[.VMIN] = 0 // minimum bytes to read before returning
	new_termios.c_cc[.VTIME] = 1 // timeout in tenths of a second

	posix.tcsetattr(stdin, .TCSAFLUSH, &new_termios) // set modified attributes

	return orig_termios
}

disable_raw_mode :: proc(orig_termios: ^posix.termios) {
	stdin := posix.fileno(posix.stdin)
	posix.tcsetattr(stdin, .TCSAFLUSH, orig_termios)
}

is_control_char :: proc(char: u8) -> bool {
	// ASCII 0-31 and 127 are control characters
	return char < 32 || char == 127
}

main :: proc() {
	orig_termios := enable_raw_mode()
	defer disable_raw_mode(&orig_termios)

	for {
		nextchar: [1]u8
		_, err := os.read(os.stdin, nextchar[:])

		if err != nil {}

		if is_control_char(nextchar[0]) {
			fmt.printf("%d\r\n", nextchar[0])
		} else {
			fmt.printf("%d ('%c')\r\n", nextchar[0], nextchar[0])
		}

		if nextchar[0] == 'q' do break
	}
}
