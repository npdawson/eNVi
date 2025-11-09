package envi

import "core:c/libc"
import "core:fmt"
import "core:strings"
import os "core:os/os2"
import "core:sys/linux"
import "core:sys/posix"

ENVI_VERSION :: "0.0.1"

editor_config :: struct {
	screen_rows: int,
	screen_cols: int,
	orig_termios: posix.termios,
}

config: editor_config

editor_init :: proc() {
	config.screen_rows, config.screen_cols = get_window_size()
}

enable_raw_mode :: proc() {
	stdin := posix.fileno(posix.stdin)

	// get current attributes of terminal
	if posix.tcgetattr(stdin, &config.orig_termios) == .FAIL {
		die("tcgetattr")
	}

	// keep copy of current attributes to reset to after our program exits
	new_termios := config.orig_termios

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
}

disable_raw_mode :: proc() {
	if posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &config.orig_termios) == .FAIL {
		die("tcsetattr")
	}
}

get_window_size :: proc() -> (rows: int, cols: int) {
	winsize :: struct {
		rows: u16,
		cols: u16,
		unused: u32,
	}

	ws: winsize

	if linux.ioctl(linux.STDOUT_FILENO, linux.TIOCGWINSZ, uintptr(&ws)) == uintptr(-1) || ws.cols == 0 {
		die("get window size")
	} else {
		rows = int(ws.rows)
		cols = int(ws.cols)
	}

	return
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
	builder := strings.builder_make()
	// editor_clear_screen()
	strings.write_string(&builder, "\x1b[?25l") // hide the cursor
	strings.write_string(&builder, "\x1b[H") // move cursor to top left
	editor_draw_rows(&builder)
	strings.write_string(&builder, "\x1b[H") // move cursor to top left
	strings.write_string(&builder, "\x1b[?25h") // show the cursor
	os.write(os.stdout, builder.buf[:])
	strings.builder_destroy(&builder)
}

editor_clear_screen :: proc() {
	clear_screen := "\x1b[2J\x1b[H"
	os.write(os.stdout, transmute([]u8)clear_screen)
}

editor_draw_rows :: proc(builder: ^strings.Builder) {
	for y := 0; y < config.screen_rows; y += 1 {
		if y == config.screen_rows / 3 {
			welcome := fmt.tprintf("eNVi editor -- version %s", ENVI_VERSION)
			welcome_len := size_of(welcome)
			if welcome_len > config.screen_cols {
				welcome_len = config.screen_cols
			}
			padding := (config.screen_cols - welcome_len) / 2
			if padding > 0 {
				strings.write_string(builder, "~")
				padding -= 1
			}
			for ; padding > 0; padding -= 1 {
				strings.write_string(builder, " ")
			}
			strings.write_string(builder, welcome)
		} else {
			strings.write_rune(builder, '~')
		}

		strings.write_string(builder, "\x1b[K") // clear to end of line
		if y < config.screen_rows - 1 {
			strings.write_string(builder, "\r\n")
		}
	}
}

die :: proc(msg: cstring) {
	editor_clear_screen()
	disable_raw_mode()
	libc.perror(msg)
	os.exit(1)
}

exit :: proc(err: int) {
	editor_clear_screen()
	disable_raw_mode()
	os.exit(err)
}

main :: proc() {
	enable_raw_mode()
	editor_init()

	for {
		editor_refresh_screen()
		editor_process_keypress()
	}

	exit(0)
}
