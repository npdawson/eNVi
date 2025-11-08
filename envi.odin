package envi

import "core:c/libc"
import "core:fmt"
import os "core:os/os2"
import "core:sys/posix"

orig_termios: posix.termios

die :: proc(msg: cstring) {
	libc.perror(msg)
	exit(1)
}

enable_raw_mode :: proc() -> posix.termios {
	stdin := posix.fileno(posix.stdin)

	// get current attributes of terminal
	if posix.tcgetattr(stdin, &orig_termios) == .FAIL {
		die("tcgetattr")
	}

	// keep copy of current attributes to reset to after our program exits
	new_termios := orig_termios

	// modify attributes for our needs
	// input flags
	new_termios.c_iflag -= {.BRKINT, .INPCK, .ISTRIP}
	new_termios.c_iflag -= {.ICRNL} // disable ctrl-m being the same as ctrl-j
	new_termios.c_iflag -= {.IXON} // disable flow control (ctrl-s & ctrl-q)
	// output flags
	new_termios.c_oflag -= {.OPOST} // disable output processing
	// control flags
	new_termios.c_cflag += {.CS8} // Character Size 8 bits
	// local flags
	new_termios.c_lflag -= {.ECHO} // disable echoing input
	new_termios.c_lflag -= {.ICANON} // disable canonical mode
	new_termios.c_lflag -= {.ISIG} // disable signals (e.g. ctrl-c, ctrl-z)
	new_termios.c_lflag -= {.IEXTEN} // disable ctrl-v

	// read timeout
	new_termios.c_cc[.VMIN] = 0 // minimum bytes to read before returning
	new_termios.c_cc[.VTIME] = 1 // timeout in tenths of a second

	// set modified attributes
	if posix.tcsetattr(stdin, .TCSAFLUSH, &new_termios) == .FAIL {
		die("tcsetattr")
	}

	return orig_termios
}

disable_raw_mode :: proc(orig_termios: ^posix.termios) {
	stdin := posix.fileno(posix.stdin)
	if posix.tcsetattr(stdin, .TCSAFLUSH, orig_termios) == .FAIL {
		die("tcsetattr")
	}
}

is_control_char :: proc(char: u8) -> bool {
	// ASCII 0-31 and 127 are control characters
	return char < 32 || char == 127
}

ctrl_key :: proc(char: u8) -> u8 {
	return char & 0x1f
}

editor_read_key :: proc() -> (c: u8) {
	for {
		nextchar: [1]u8
		nread, err := os.read(os.stdin, nextchar[:])
		c = nextchar[0]

		if err != nil && err != .EOF {
			fmt.print(err)
			fmt.print("\r\n")
			die("read")
		}

		// loop until we read a character
		if nread == 1 do break
	}

	return c
}

editor_process_keypress :: proc() {
	c := editor_read_key()

	switch c {
	case ctrl_key('q'):
		exit(0)
	}
}

editor_refresh_screen :: proc() {
	clear_screen := "\x1b[2J"
	os.write(os.stdout, transmute([]u8)clear_screen)
	cursor_top_left := "\x1b[H"
	os.write(os.stdout, transmute([]u8)cursor_top_left)
}

exit :: proc(err: int) {
	disable_raw_mode(&orig_termios)
	os.exit(err)
}

main :: proc() {
	orig_termios = enable_raw_mode()

	for {
		editor_refresh_screen()
		editor_process_keypress()
	}

	exit(0)
}
