main: *anyopaque,
edit: *anyopaque,
font: fonts.HFONT,
zoom: u32,
color: u32,
background: u32,
fullscreen: bool,
path: [32767:0]u8,
placement: WINDOWPLACEMENT,
default_proc: WNDPROC,

var runtime_state: @This() = undefined;
var default_heap = std.heap.HeapAllocator.init();
var accel_table = accel.default;

pub fn main() void {
    default_heap.heap_handle = win.peb().ProcessHeap;
    var init_path: [32767:0]u8 = undefined;
    const have_path: ?[:0]u8 = init: {
        var cli = std.process.argsWithAllocator(default_heap.allocator()) catch break :init null;
        defer cli.deinit();
        _ = cli.next() orelse break :init null;
        const arg = cli.next() orelse break :init null;
        const attr = GetFileAttributesA(arg.ptr);
        if (attr == ~@as(u32, 0)) return; // behavior of launching with invalid path should be silent exit
        defer {
            while (cli.next()) |p| {
                fork(p);
            }
        }
        if (0 == attr & 16) {
            @memcpy(init_path[0..arg.len], arg);
            init_path[arg.len] = 0;
            break :init init_path[0..arg.len :0];
        }
        return; // behavior of launching with invalid path should be silent exit
    };

    const atom = RegisterClassExA(&.{
        .lpfnWndProc = wndProc,
        .hInstance = win.peb().ImageBaseAddress,
        .hIcon = LoadIconA(win.peb().ImageBaseAddress, @ptrFromInt(1)),
        .hCursor = LoadCursorA(null, @ptrFromInt(32512)),
        .lpszClassName = "ClipPad",
    });

    if (atom == 0) return;
    const style: i32 = WS_VISIBLE | WS_OVERLAPPEDWINDOW;
    const hwnd = CreateWindowExA(
        0,
        @ptrFromInt(@as(usize, @intCast(atom))),
        "ClipPad",
        style,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        null,
        null,
        null,
        null,
    ) orelse return;

    const hAccel = accel.CreateAcceleratorTableA(&accel_table, accel_table.len) orelse return;

    if (have_path) |p| {
        @memcpy(runtime_state.path[0..p.len], p);
        load();
        onAccelerator('L');
    }

    var msg: MSG = undefined;
    while (GetMessageA(&msg, null, 0, 0) > 0) {
        if (0 == accel.TranslateAcceleratorA(hwnd, hAccel, &msg)) {
            _ = TranslateMessage(&msg);
            _ = DispatchMessageA(&msg);
        }
    }
}

const std = @import("std");
const win = std.os.windows;
const WINAPI = win.WINAPI;

const comdlg = @import("comdlg.zig");
const fonts = @import("fonts.zig");
const accel = @import("accel.zig");

const default_beige = 0xC9D1D9; // 0xeff6f6 is hackernews beige

fn load() void {
    const file_handle = CreateFileA(&runtime_state.path, 0x80000000, 7, null, 3, 128, null) orelse return; // generic_read, share all, open_existing
    defer win.CloseHandle(file_handle);
    const len = win.GetFileSizeEx(file_handle) catch return;
    const content = default_heap.allocator().allocSentinel(u8, len, 0) catch return;
    defer default_heap.allocator().free(content);
    _ = win.ReadFile(file_handle, content, 0) catch return;
    _ = SetWindowTextA(runtime_state.edit, content);
}

fn save() void {
    const file_handle = CreateFileA(&runtime_state.path, 0x40000000, 7, null, 2, 128, null) orelse return; // generic_write share all, open_always
    defer win.CloseHandle(file_handle);
    const len = GetWindowTextLengthA(runtime_state.edit);
    if (len < 0) return;
    const content = default_heap.allocator().allocSentinel(u8, @intCast(len), 0) catch return;
    defer default_heap.allocator().free(content);
    _ = GetWindowTextA(runtime_state.edit, content, @intCast(content.len + 1));
    var index: usize = 0;
    while (index < content.len) {
        index += win.WriteFile(file_handle, content[index..], null) catch {
            break;
        };
    }
}

fn fork(path: ?[:0]const u8) void {
    var buf: [32767:0]u8 = undefined;
    const len = GetModuleFileNameA(null, &buf, buf.len); // copied `len` characters plus zero sentinel at index `len`

    if (len == 0) return;
    if (len == buf.len and .SUCCESS != win.kernel32.GetLastError()) return;
    std.debug.assert(buf[len] == 0);

    if (path) |p| {
        buf[len] = ' ';
        const suffix = buf[len + 1 ..];
        @memcpy(suffix[0..p.len], p);
        suffix[p.len] = 0;
        std.debug.assert(buf[len] == ' ');
        std.debug.assert(buf[len + p.len + 1] == 0);
    }

    var pin: win.PROCESS_INFORMATION = undefined;
    var inf: win.STARTUPINFOW = @bitCast(@as([@sizeOf(win.STARTUPINFOW)]u8, .{0} ** @sizeOf(win.STARTUPINFOW)));
    inf.cb = @sizeOf(win.STARTUPINFOW);

    _ = CreateProcessA(
        null,
        &buf,
        null,
        null,
        0,
        0,
        null,
        null,
        &inf,
        &pin,
    );
}

fn editProc(hwnd: *anyopaque, uMsg: u32, wParam: usize, lParam: isize) callconv(WINAPI) isize {
    switch (uMsg) {
        0x0102 => { // WM_CHAR
            if (wParam == 127 and 0x0800 & GetWindowLongPtrA(hwnd, -16) == 0) { // ctrl + backspace and not disabled
                var start: u32 = undefined;
                var end: u32 = undefined;
                _ = SendMessageA(hwnd, 0x00B0, @intFromPtr(&start), @bitCast(@as(usize, @intFromPtr(&end)))); // EM_GETSEL
                if (start == end) {
                    _ = SendMessageA(hwnd, 0x0100, 0x25, 0); // left down
                    _ = SendMessageA(hwnd, 0x0101, 0x25, 0); // left up
                    _ = SendMessageA(hwnd, 0x00B0, @intFromPtr(&start), 0); // EM_GETSEL
                    _ = SendMessageA(hwnd, 0x00B1, start, end); // EM_SETSEL
                }
                _ = SendMessageA(hwnd, 0x00C2, 1, @bitCast(@as(usize, @intFromPtr("".ptr)))); // EM_REPLACESEL
                return 0;
            }
        },
        0x020A, 0x020E => { // WM_MOUSEWHEEL, WM_MOUSEHWHEEL
            const Arg = packed struct(usize) {
                lo: u16,
                delta: i16,
                unused: if (@sizeOf(usize) == 8) u32 else u0,
                var accu: i16 = 0;
            };
            var arg: Arg = @bitCast(wParam);
            const send = 120 * @divTrunc(arg.delta + Arg.accu, 120);
            Arg.accu = arg.delta + Arg.accu - send;
            arg.delta = send;
            return CallWindowProcA(runtime_state.default_proc, hwnd, uMsg, @bitCast(arg), lParam);
        },
        else => {},
    }
    return CallWindowProcA(runtime_state.default_proc, hwnd, uMsg, wParam, lParam);
}

fn wndProc(hwnd: *anyopaque, uMsg: u32, wParam: usize, lParam: isize) callconv(WINAPI) isize {
    switch (uMsg) {
        0x0001 => { // WM_CREATE
            var rect: win.RECT = undefined;
            if (0 == GetClientRect(hwnd, &rect)) return -1; // don't use CREATESTRUCT since it's not client area
            const hEdit = CreateWindowExA(
                0,
                "Edit",
                null,
                WS_VISIBLE | WS_CHILD | WS_VSCROLL | WS_HSCROLL | ES_MULTILINE | ES_NOHIDESEL,
                0,
                0,
                rect.right - rect.left,
                rect.bottom - rect.top,
                hwnd,
                null,
                null,
                null,
            ) orelse return -1;
            const proc = SetWindowLongPtrA(hEdit, -4, @bitCast(@intFromPtr(&editProc)));
            const font_cfg = fonts.default_consolas;
            const hFont = fonts.CreateFontIndirectA(&font_cfg) orelse return -1;
            // const hFont: fonts.HFONT = @ptrCast(GetStockObject(16)); // SYSTEM_FIXED_FONT = 16
            runtime_state = .{
                .main = hwnd,
                .edit = hEdit,
                .font = hFont,
                .zoom = 100,
                .color = 0,
                .background = default_beige,
                .fullscreen = false,
                .path = .{0} ** 32767,
                .placement = .{},
                .default_proc = @ptrFromInt(@as(usize, @bitCast(proc))),
            };
            _ = SendMessageA(hEdit, 0x0030, @bitCast(@as(usize, @intFromPtr(hFont))), 1);
            _ = SendMessageA(hEdit, 0x00C5, 0, 0); // EM_LIMITTEXT = 0x00C5
            _ = SendMessageA(hEdit, 0x00D3, 0xffff, 0xffffffff); // EM_SETMARGINS = 0x00D3
            _ = SendMessageA(hEdit, 0x1500 + 10, 0x13, 0x13); // EM_SETEXTENDEDSTYLE = 0x1500 + 10
            _ = SetFocus(hEdit);
        },
        0x0005 => { // WM_SIZE
            const margins = if (runtime_state.fullscreen) .{ GetSystemMetrics(2), GetSystemMetrics(3) } else .{ 0, 0 };
            const client: [4]u16 = @bitCast(lParam);
            _ = SetWindowPos(runtime_state.edit, null, 0, 0, client[0] + margins[0], client[1] + margins[1], 0);
        },
        0x0007 => { // WM_SETFOCUS
            _ = SetFocus(runtime_state.edit);
        },
        0x0010 => { // WM_CLOSE
            const locked = (0x0800 & GetWindowLongPtrA(runtime_state.edit, -16) != 0);
            if (locked and 6 != MessageBoxA(hwnd, "Are you sure you want to close this note?", "Confirm close", 0x104)) return 0;
            PostQuitMessage(0);
        },
        0x0111 => { // WM_COMMAND
            if (wParam >> 16 == 1) onAccelerator(wParam);
        },
        0x0133, 0x0138 => { // WM_CTLCOLOREDIT, WM_CTRLCOLORSTATIC
            const beige = runtime_state.background;
            if (GetStockObject(18)) |b| { // DC_BRUSH
                const text_color = if (0x0133 == uMsg) runtime_state.color else GetSysColor(17); // COLOR_GRAYTEXT
                _ = SetTextColor(@ptrFromInt(wParam), text_color);
                _ = SetBkColor(@ptrFromInt(wParam), beige);
                _ = SetDCBrushColor(@ptrFromInt(wParam), beige);
                return @bitCast(@intFromPtr(b));
            }
        },
        else => {},
    }
    return DefWindowProcA(hwnd, uMsg, wParam, lParam);
}

fn onAccelerator(wParam: usize) void {
    const locked = (0x0800 & GetWindowLongPtrA(runtime_state.edit, -16) != 0);
    const key = wParam & 0xffff;
    switch (key) {
        '0' => {
            runtime_state.zoom = 100;
            _ = SendMessageA(runtime_state.edit, 0x0400 + 225, 0, 0); // EM_SETZOOM = 0x0400+225
        },
        '+', '-' => {
            runtime_state.zoom = if (key == '+') @min(500, runtime_state.zoom + 10) else @max(10, runtime_state.zoom - 10);
            _ = SendMessageA(runtime_state.edit, 0x0400 + 225, runtime_state.zoom, 100); // EM_SETZOOM = 0x0400+225
        },
        'K', 'T' => {
            var cols: [16]u32 = if (key == 'K') .{default_beige} ** 16 else .{0} ** 16;
            var inf: comdlg.CHOOSECOLORA = .{
                .hwndOwner = runtime_state.main,
                .rgbResult = if (key == 'K') runtime_state.background else runtime_state.color,
                .lpCustColors = &cols,
                .Flags = 0x103,
            };
            if (0 == comdlg.ChooseColorA(&inf)) return;
            if (key == 'K') {
                runtime_state.background = inf.rgbResult;
            } else {
                runtime_state.color = inf.rgbResult;
            }
        },
        'L' => {
            _ = SendMessageA(runtime_state.edit, 0x00CF, @intFromBool(!locked), 0); // EM_SETREADONLY = 0xF0CF
            updateTitle("ClipPad", !locked);
        },
        'N' => {
            fork(null);
        },
        'O' => {
            if (locked and 6 != MessageBoxA(runtime_state.main, "Are you sure you want to load a different note?", "Confirm load", 0x104)) return;
            var buf: comdlg.OPENFILENAMEA = .{
                .hwndOwner = runtime_state.main,
                .lpstrFile = (&runtime_state.path).ptr,
                .nMaxFile = (&runtime_state.path).len + 1,
                .Flags = 0x00001004, // OFN_FILEMUSTEXIST | OFN_READONLY
            };
            if (0 == comdlg.GetOpenFileNameA(&buf)) return;
            load();
            updateTitle("ClipPad", locked);
        },
        'R' => {
            if (0 == runtime_state.path[0]) return;
            if (locked and 6 != MessageBoxA(runtime_state.main, "Are you sure you want to reload this note?", "Confirm reload", 0x104)) return;
            load();
        },
        'S' => {
            var inf: comdlg.OPENFILENAMEA = .{
                .hwndOwner = runtime_state.main,
                .lpstrFilter = "All Files\x00*.*\x00\x00".ptr,
                .lpstrFile = (&runtime_state.path).ptr,
                .nMaxFile = (&runtime_state.path).len + 1,
                .Flags = 2, // OFN_OVERWRITEPROMPT
            };
            if (0 == comdlg.GetSaveFileNameA(&inf)) return;
            save();
            updateTitle("ClipPad", locked);
        },
        't' => {
            var buf: fonts.LOGFONTA = undefined;
            _ = GetObjectA(runtime_state.font, @sizeOf(fonts.LOGFONTA), &buf);
            var choose: comdlg.CHOOSEFONTA = .{
                .hwndOwner = runtime_state.main,
                .lpLogFont = &buf,
                .Flags = 0x0001040, // CF_FORCEFONTEXIST | CF_INITTOLOGFONTSTRUCT
            };
            if (0 == comdlg.ChooseFontA(&choose)) return;
            _ = changeFont(buf);
        },
        'W' => {
            _ = SendMessageA(runtime_state.main, 0x0010, 0, 0);
        },
        0xF11 => {
            toggleFullscreen(runtime_state.main);
        },
        else => {},
    }
}

fn updateTitle(comptime suffix: []const u8, locked: bool) void {
    // var buf: [256]u8 = .{0} ** 256;
    // _ = GetWindowTextA(runtime_state.edit, &buf, buf.len);
    // const start = start: for (0..buf.len) |i| {
    //     if (buf[i] != '\n' and buf[i] != '\r') break :start i;
    // } else break :start 0;
    // const suffix = " - ClipPad";
    // const sen = @min(
    //     buf.len - 1 - suffix.len,
    //     end: for (start..buf.len) |i| {
    //         if (buf[i] == '\n' or buf[i] == '\r' or buf[i] == 0) break :end i;
    //     } else break :end buf.len - 1,
    // );
    // for (suffix, sen..) |s, i| buf[i] = s;
    // buf[sen + suffix.len] = 0;
    // _ = SetWindowTextA(runtime_state.main, buf[start..].ptr);
    var buf: [256]u8 = (suffix ++ .{0} ** (256 - suffix.len)).*;
    if (locked) buf[suffix.len..][0.." (locked)".len].* = " (locked)".*;
    defer _ = SetWindowTextA(runtime_state.main, buf[0..255 :0]);
    if (0 == runtime_state.path[0]) return;
    const pbuf = &runtime_state.path;
    const basename = std.fs.path.basename(pbuf);
    const end = end: for (basename, 0..) |c, i| {
        buf[i] = c;
        if (c == 0) break :end i;
    } else break :end 0;
    if (locked) {
        const append = " - ".* ++ suffix ++ " (locked)";
        if (end + append.len < buf.len) {
            buf[end..][0 .. append.len + 1].* = (append ++ .{0}).*;
        }
    } else {
        const append = " - ".* ++ suffix;
        if (end + append.len < buf.len) {
            buf[end..][0 .. append.len + 1].* = (append ++ .{0}).*;
        }
    }
}

fn changeFont(buf: fonts.LOGFONTA) bool {
    const oldFont = runtime_state.font;
    const newFont = fonts.CreateFontIndirectA(&buf) orelse return false;
    defer _ = DeleteObject(oldFont);
    runtime_state.font = newFont;
    const brush: usize = @intFromPtr(newFont);
    _ = SendMessageA(runtime_state.edit, 0x0030, @bitCast(brush), 1);
    _ = SendMessageA(runtime_state.edit, 0x00D3, 0xffff, 0xffffffff); // EM_SETMARGINS = 0x00D3
    return true;
}

fn toggleFullscreen(hwnd: *const anyopaque) void {
    // from https://devblogs.microsoft.com/oldnewthing/20100412-00/?p=14353
    const style: u32 = @bitCast(GetWindowLongA(hwnd, -16)); // GWL_STYLE
    runtime_state.fullscreen = (0 != style & WS_OVERLAPPEDWINDOW);
    if (runtime_state.fullscreen) {
        var inf: MONITORINFO = .{};
        if (0 != GetWindowPlacement(hwnd, &runtime_state.placement) and 0 != GetMonitorInfoA(MonitorFromWindow(hwnd, 2), &inf)) {
            _ = SetWindowLongA(hwnd, -16, @bitCast(style & ~@as(u32, WS_OVERLAPPEDWINDOW)));
            _ = SetWindowPos(hwnd, null, inf.rcMonitor.left, inf.rcMonitor.top, inf.rcMonitor.right - inf.rcMonitor.left, inf.rcMonitor.bottom - inf.rcMonitor.top, 0x0220);
        }
    } else {
        _ = SetWindowLongA(hwnd, -16, @bitCast(style | @as(u32, WS_OVERLAPPEDWINDOW)));
        _ = SetWindowPlacement(hwnd, &runtime_state.placement);
        _ = SetWindowPos(hwnd, null, 0, 0, 0, 0, 0x0227);
    }
}

const CW_USEDEFAULT: i32 = @bitCast(@as(u32, 0x80000000));
const WS_OVERLAPPEDWINDOW = WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
const WS_VISIBLE = 0x10000000;
const WS_SYSMENU = 0x00080000;
const WS_CAPTION = 0x00C00000;
const WS_THICKFRAME = 0x00040000;
const WS_CHILD = 0x40000000;
const WS_MAXIMIZEBOX = 0x00010000;
const WS_MINIMIZEBOX = 0x00020000;
const WS_HSCROLL = 0x00100000;
const WS_VSCROLL = 0x00200000;
const ES_MULTILINE = 0x00000004;
const ES_NOHIDESEL = 0x00000100;

const WNDPROC = *const fn (*anyopaque, u32, usize, isize) callconv(WINAPI) isize;

pub const MSG = extern struct {
    hWnd: ?*anyopaque,
    message: u32,
    wParam: usize,
    lParam: isize,
    time: u32,
    pt: win.POINT,
    lPrivate: u32,
};
const WNDCLASSEXA = extern struct {
    cbSize: u32 = @sizeOf(@This()),
    style: u32 = 0,
    lpfnWndProc: *const fn (*anyopaque, u32, usize, isize) callconv(WINAPI) isize,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: *const anyopaque,
    hIcon: ?*anyopaque = null,
    hCursor: ?*anyopaque = null,
    hbrBackground: ?*anyopaque = null,
    lpszMenuName: ?[*:0]const u8 = null,
    lpszClassName: [*:0]const u8,
    hIconSm: ?*anyopaque = null,
};

extern "user32" fn GetMessageA(*MSG, ?*anyopaque, u32, u32) callconv(WINAPI) i32;
extern "user32" fn DispatchMessageA(*const MSG) callconv(WINAPI) isize;
extern "user32" fn TranslateMessage(*const MSG) callconv(WINAPI) isize;
extern "user32" fn SendMessageA(*const anyopaque, u32, usize, isize) callconv(WINAPI) isize;
extern "user32" fn PostMessageA(*const anyopaque, u32, usize, isize) callconv(WINAPI) isize;
extern "user32" fn DefWindowProcA(*anyopaque, u32, usize, isize) callconv(WINAPI) isize;
extern "user32" fn PostQuitMessage(i32) callconv(WINAPI) void;
extern "user32" fn LoadCursorA(?*anyopaque, ?*anyopaque) callconv(WINAPI) ?*anyopaque;
extern "user32" fn LoadIconA(?*anyopaque, *anyopaque) callconv(WINAPI) ?*anyopaque;
extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) u16;
extern "user32" fn SetWindowTextA(*anyopaque, ?[*:0]const u8) callconv(WINAPI) i32;
extern "user32" fn GetWindowTextA(*anyopaque, [*:0]u8, i32) callconv(WINAPI) i32;
extern "user32" fn GetWindowTextLengthA(*const anyopaque) callconv(WINAPI) i32;
extern "user32" fn AdjustWindowRect(*win.RECT, u32, i32) callconv(WINAPI) i32;
extern "user32" fn GetClientRect(*const anyopaque, *win.RECT) callconv(WINAPI) i32;
extern "user32" fn CreateWindowExA(
    u32, // extended style
    ?*const anyopaque, // class name/class atom
    ?[*:0]const u8, // window name
    u32, // basic style
    i32,
    i32,
    i32,
    i32, // x,y,w,h
    ?*anyopaque, // parent
    ?*anyopaque, // menu
    ?*anyopaque, // hInstance
    ?*anyopaque, // info to pass to WM_CREATE callback inside wndproc
) callconv(WINAPI) ?*anyopaque;
extern "user32" fn SetWindowPos(*const anyopaque, ?*const anyopaque, i32, i32, i32, i32, u32) callconv(WINAPI) i32;
extern "user32" fn SetFocus(*const anyopaque) callconv(WINAPI) *const anyopaque;
extern "user32" fn GetKeyState(i32) callconv(WINAPI) u16;
extern "user32" fn GetWindowLongPtrA(*const anyopaque, i32) callconv(WINAPI) isize;
extern "user32" fn SetWindowLongPtrA(*const anyopaque, i32, isize) callconv(WINAPI) isize;
extern "user32" fn GetWindowLongA(*const anyopaque, i32) callconv(WINAPI) i32;
extern "user32" fn SetWindowLongA(*const anyopaque, i32, i32) callconv(WINAPI) i32;
extern "user32" fn CallWindowProcA(WNDPROC, *anyopaque, u32, usize, isize) callconv(WINAPI) isize;
extern "user32" fn GetWindowPlacement(*const anyopaque, *WINDOWPLACEMENT) callconv(WINAPI) isize;
extern "user32" fn SetWindowPlacement(*const anyopaque, *const WINDOWPLACEMENT) callconv(WINAPI) isize;
const WINDOWPLACEMENT = extern struct {
    length: u32 = @sizeOf(@This()),
    flags: u32 = 0,
    showCmd: u32 = 0,
    ptMinPosition: win.POINT = @bitCast(@as([2]i32, .{0} ** 2)),
    ptMaxPosition: win.POINT = @bitCast(@as([2]i32, .{0} ** 2)),
    rcNormalPosition: win.RECT = @bitCast(@as([4]i32, .{0} ** 4)),
    rcDevice: win.RECT = @bitCast(@as([4]i32, .{0} ** 4)),
};

const HMONITOR = *opaque {};
const MONITORINFO = extern struct {
    cbSize: u32 = @sizeOf(@This()),
    rcMonitor: win.RECT = @bitCast(@as([4]i32, .{0} ** 4)),
    rcWork: win.RECT = @bitCast(@as([4]i32, .{0} ** 4)),
    dwFlags: u32 = 0,
};
extern "user32" fn MonitorFromWindow(*const anyopaque, u32) callconv(WINAPI) HMONITOR;
extern "user32" fn GetMonitorInfoA(HMONITOR, *MONITORINFO) callconv(WINAPI) i32;

extern "user32" fn GetSysColor(i32) callconv(WINAPI) u32;
extern "user32" fn MessageBoxA(?*const anyopaque, ?[*:0]const u8, ?[*:0]const u8, u32) callconv(WINAPI) i32;

extern "user32" fn GetSystemMetrics(i32) callconv(WINAPI) i32;
extern "user32" fn GetDpiForWindow(*const anyopaque) callconv(WINAPI) u32;

extern "gdi32" fn GetStockObject(i32) callconv(WINAPI) ?*anyopaque;
extern "gdi32" fn SetDCBrushColor(win.HDC, u32) callconv(WINAPI) u32;
extern "gdi32" fn SetBkColor(win.HDC, u32) callconv(WINAPI) u32;
extern "gdi32" fn SetTextColor(win.HDC, u32) callconv(WINAPI) u32;
extern "gdi32" fn DeleteObject(*anyopaque) callconv(WINAPI) i32;
extern "gdi32" fn GetObjectA(*const anyopaque, i32, *anyopaque) callconv(WINAPI) i32;

extern "kernel32" fn CreateFileA([*:0]const u8, u32, u32, ?*const win.SECURITY_ATTRIBUTES, u32, u32, ?*anyopaque) callconv(WINAPI) ?*anyopaque;
extern "kernel32" fn GetFileAttributesA([*:0]const u8) callconv(WINAPI) u32;
extern "kernel32" fn GetModuleFileNameA(?*const anyopaque, [*]u8, u32) callconv(WINAPI) u32;
extern "kernel32" fn CreateProcessA(
    lpApplicationName: ?[*:0]const u8,
    lpCommandLine: ?[*:0]u8,
    lpProcessAttributes: ?*win.SECURITY_ATTRIBUTES,
    lpThreadAttributes: ?*win.SECURITY_ATTRIBUTES,
    bInheritHandles: i32,
    dwCreationFlags: u32,
    lpEnvironment: ?*anyopaque,
    lpCurrentDirectory: ?[*:0]const u8,
    lpStartupInfo: *win.STARTUPINFOW,
    lpProcessInformation: *win.PROCESS_INFORMATION,
) callconv(WINAPI) i32;
