const std = @import("std");
const win = std.os.windows;
const WINAPI = win.WINAPI;

pub extern "comdlg32" fn CommDlgExtendedError() callconv(WINAPI) u32;
pub extern "comdlg32" fn GetOpenFileNameA(*OPENFILENAMEA) callconv(WINAPI) i32;
pub extern "comdlg32" fn GetSaveFileNameA(*OPENFILENAMEA) callconv(WINAPI) i32;

pub const OFNHOOKPROC = fn (*const anyopaque, u32, usize, isize) callconv(WINAPI) usize;

pub const OPENFILENAMEA = extern struct {
    lStructSize: u32 = @sizeOf(OPENFILENAMEA),
    hwndOwner: ?*const anyopaque = null,
    hInstance: ?*const anyopaque = null,
    lpstrFilter: ?[*:0]const u8 = null,
    lpstrCustomFilter: ?[*:0]u8 = null,
    nMaxCustFilter: u32 = 0,
    nFilterIndex: u32 = 0,
    lpstrFile: [*:0]u8,
    nMaxFile: u32,
    lpstrFileTitle: ?[*:0]u8 = null,
    nMaxFileTitle: u32 = 0,
    lpstrInitialDir: ?[*:0]const u8 = null,
    lpstrTitle: ?[*:0]const u8 = null,
    Flags: u32 = 0,
    nFileOffset: u16 = 0,
    nFileExtension: u16 = 0,
    lpstrDefExt: ?[*:0]const u8 = null,
    lCustData: isize = 0,
    lpfnHook: ?*const OFNHOOKPROC = null,
    lpTemplateName: ?[*:0]const u8 = null,
    // lpEditInfo: ?*const anyopaque = null,
    // lpstrPrompt: ?[*:0]const u8 = null,
    pvReserved: ?*const anyopaque = null,
    dwReserved: u32 = 0,
    FlagsEx: u32 = 0,
};
