/*
 *  term_c.c -- the raw-terminal shim under Turbo.Term.
 *
 *  Everything platform-specific about the console lives here, behind six
 *  calls: put the terminal in raw mode (and back), read bytes with a timeout,
 *  write bytes, and ask the size.  Above this line the IDE only ever sees a
 *  VT/xterm byte stream, on every platform:
 *
 *    POSIX    termios raw mode; poll() for the timeout; SIGWINCH for resize.
 *    Windows  ENABLE_VIRTUAL_TERMINAL_PROCESSING on output and
 *             ENABLE_VIRTUAL_TERMINAL_INPUT on input (Windows 10 1809+, i.e.
 *             conhost and Windows Terminal), so keys and mouse arrive as the
 *             same escape sequences an xterm sends.  The code page is set to
 *             UTF-8 both ways.
 */

#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#endif
#ifndef ENABLE_VIRTUAL_TERMINAL_INPUT
#define ENABLE_VIRTUAL_TERMINAL_INPUT 0x0200
#endif
#ifndef DISABLE_NEWLINE_AUTO_RETURN
#define DISABLE_NEWLINE_AUTO_RETURN 0x0008
#endif

static HANDLE h_in, h_out;
static DWORD saved_in_mode, saved_out_mode;
static UINT saved_in_cp, saved_out_cp;
static int raw_active = 0;
static volatile int resized = 0;

/* A key event's UTF-16 unit may be half of a surrogate pair. */
static WCHAR pending_high = 0;

int tada_term_init (void)
{
    DWORD in_mode, out_mode;

    h_in  = GetStdHandle (STD_INPUT_HANDLE);
    h_out = GetStdHandle (STD_OUTPUT_HANDLE);
    if (!GetConsoleMode (h_in, &saved_in_mode)
        || !GetConsoleMode (h_out, &saved_out_mode))
        return -1;                       /* not a console */

    saved_in_cp  = GetConsoleCP ();
    saved_out_cp = GetConsoleOutputCP ();
    SetConsoleCP (CP_UTF8);
    SetConsoleOutputCP (CP_UTF8);

    out_mode = saved_out_mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING
               | DISABLE_NEWLINE_AUTO_RETURN;
    if (!SetConsoleMode (h_out, out_mode))
        return -2;                       /* console too old for VT output */

    in_mode = ENABLE_VIRTUAL_TERMINAL_INPUT | ENABLE_WINDOW_INPUT
              | ENABLE_EXTENDED_FLAGS;   /* no QUICK_EDIT: it eats the mouse */
    if (!SetConsoleMode (h_in, in_mode))
        return -3;

    raw_active = 1;
    return 0;
}

void tada_term_restore (void)
{
    if (!raw_active)
        return;
    SetConsoleMode (h_in, saved_in_mode);
    SetConsoleMode (h_out, saved_out_mode);
    SetConsoleCP (saved_in_cp);
    SetConsoleOutputCP (saved_out_cp);
    raw_active = 0;
}

static int put_utf8 (unsigned char *buf, int room, unsigned long cp)
{
    if (cp < 0x80 && room >= 1) {
        buf[0] = (unsigned char) cp;
        return 1;
    } else if (cp < 0x800 && room >= 2) {
        buf[0] = (unsigned char) (0xC0 | (cp >> 6));
        buf[1] = (unsigned char) (0x80 | (cp & 0x3F));
        return 2;
    } else if (cp < 0x10000 && room >= 3) {
        buf[0] = (unsigned char) (0xE0 | (cp >> 12));
        buf[1] = (unsigned char) (0x80 | ((cp >> 6) & 0x3F));
        buf[2] = (unsigned char) (0x80 | (cp & 0x3F));
        return 3;
    } else if (room >= 4) {
        buf[0] = (unsigned char) (0xF0 | (cp >> 18));
        buf[1] = (unsigned char) (0x80 | ((cp >> 12) & 0x3F));
        buf[2] = (unsigned char) (0x80 | ((cp >> 6) & 0x3F));
        buf[3] = (unsigned char) (0x80 | (cp & 0x3F));
        return 4;
    }
    return 0;
}

int tada_term_read (unsigned char *buf, int max, int timeout_ms)
{
    INPUT_RECORD rec[64];
    DWORD got, i;
    int n = 0;
    DWORD start = GetTickCount ();

    for (;;) {
        DWORD elapsed = GetTickCount () - start;
        DWORD wait = (timeout_ms < 0) ? INFINITE
                     : (elapsed >= (DWORD) timeout_ms ? 0
                        : (DWORD) timeout_ms - elapsed);

        if (WaitForSingleObject (h_in, wait) != WAIT_OBJECT_0)
            return n;                    /* timeout */

        /* Never read more records than could fit as UTF-8 in buf. */
        DWORD want = (DWORD) ((max - n) / 4);
        if (want == 0)
            return n;
        if (want > 64)
            want = 64;
        if (!ReadConsoleInputW (h_in, rec, want, &got))
            return -1;

        for (i = 0; i < got; i++) {
            if (rec[i].EventType == WINDOW_BUFFER_SIZE_EVENT) {
                resized = 1;
            } else if (rec[i].EventType == KEY_EVENT
                       && rec[i].Event.KeyEvent.bKeyDown) {
                WCHAR wc = rec[i].Event.KeyEvent.uChar.UnicodeChar;
                WORD rep = rec[i].Event.KeyEvent.wRepeatCount;
                unsigned long cp;

                if (wc == 0)
                    continue;            /* a bare modifier key */
                if (wc >= 0xD800 && wc <= 0xDBFF) {
                    pending_high = wc;
                    continue;
                }
                if (wc >= 0xDC00 && wc <= 0xDFFF && pending_high) {
                    cp = 0x10000 + (((unsigned long) pending_high - 0xD800) << 10)
                         + ((unsigned long) wc - 0xDC00);
                    pending_high = 0;
                } else {
                    cp = wc;
                }
                if (rep == 0)
                    rep = 1;
                while (rep-- > 0)
                    n += put_utf8 (buf + n, max - n, cp);
            }
        }
        if (n > 0 || resized)
            return n;
    }
}

int tada_term_write (const char *buf, int len)
{
    DWORD done = 0;
    while (len > 0) {
        if (!WriteFile (h_out, buf, (DWORD) len, &done, NULL))
            return -1;
        buf += done;
        len -= (int) done;
    }
    return 0;
}

void tada_term_size (int *rows, int *cols)
{
    CONSOLE_SCREEN_BUFFER_INFO info;
    if (GetConsoleScreenBufferInfo (h_out, &info)) {
        *cols = info.srWindow.Right - info.srWindow.Left + 1;
        *rows = info.srWindow.Bottom - info.srWindow.Top + 1;
    } else {
        *cols = 80;
        *rows = 25;
    }
}

int tada_term_take_resized (void)
{
    int r = resized;
    resized = 0;
    return r;
}

int tada_is_windows (void) { return 1; }

#else  /* POSIX */

#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <string.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

static struct termios saved;
static int raw_active = 0;
static volatile sig_atomic_t resized = 0;

static void on_winch (int sig)
{
    (void) sig;
    resized = 1;
}

int tada_term_init (void)
{
    struct termios raw;
    struct sigaction sa;

    if (!isatty (STDIN_FILENO) || tcgetattr (STDIN_FILENO, &saved) != 0)
        return -1;

    raw = saved;
    raw.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR
                     | ICRNL | IXON);
    raw.c_oflag &= ~OPOST;
    raw.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    raw.c_cflag &= ~(CSIZE | PARENB);
    raw.c_cflag |= CS8;
    raw.c_cc[VMIN] = 1;
    raw.c_cc[VTIME] = 0;
    if (tcsetattr (STDIN_FILENO, TCSAFLUSH, &raw) != 0)
        return -2;

    /* A child that dies (the language server) must not take the IDE with
       it: a write to its closed pipe returns EPIPE instead of killing us. */
    signal (SIGPIPE, SIG_IGN);

    /* No SA_RESTART: a resize should cut the poll() short. */
    memset (&sa, 0, sizeof sa);
    sa.sa_handler = on_winch;
    sigemptyset (&sa.sa_mask);
    sigaction (SIGWINCH, &sa, NULL);

    raw_active = 1;
    return 0;
}

void tada_term_restore (void)
{
    if (!raw_active)
        return;
    tcsetattr (STDIN_FILENO, TCSAFLUSH, &saved);
    raw_active = 0;
}

int tada_term_read (unsigned char *buf, int max, int timeout_ms)
{
    struct pollfd p;
    ssize_t r;

    p.fd = STDIN_FILENO;
    p.events = POLLIN;
    p.revents = 0;

    r = poll (&p, 1, timeout_ms);
    if (r < 0)
        return (errno == EINTR) ? 0 : -1;
    if (r == 0)
        return 0;

    r = read (STDIN_FILENO, buf, (size_t) max);
    if (r < 0)
        return (errno == EINTR || errno == EAGAIN) ? 0 : -1;
    return (int) r;
}

int tada_term_write (const char *buf, int len)
{
    while (len > 0) {
        ssize_t w = write (STDOUT_FILENO, buf, (size_t) len);
        if (w < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }
        buf += w;
        len -= (int) w;
    }
    return 0;
}

void tada_term_size (int *rows, int *cols)
{
    struct winsize ws;
    if (ioctl (STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0) {
        *rows = ws.ws_row;
        *cols = ws.ws_col;
    } else {
        *rows = 25;
        *cols = 80;
    }
}

int tada_term_take_resized (void)
{
    int r = resized;
    resized = 0;
    return r;
}

int tada_is_windows (void) { return 0; }

#endif
