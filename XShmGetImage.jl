using Xlib, Images

const IPC_CREAT = parse(Cuint, "01000", 8)
const IPC_PRIVATE = Cuint(0)

# ccall((:XShmQueryExtension, "libXext.so"), Status, (Ptr{Display},), d)
#
# begin
#     major = Ref{Cint}(9)
#     minor = Ref{Cint}(9)
#     pixmaps = Ref{Cint}(9)
#     ccall((:XShmQueryVersion, "libXext.so"), Status, (Ptr{Display}, Ref{Cint}, Ref{Cint}, Ref{Cint}), d, major, minor, pixmaps)
#     major[], minor[], pixmaps[]
# end

# typedef unsigned long ShmSeg;
# typedef struct {
#     ShmSeg shmseg;	/* resource id */
#     int shmid;		/* kernel id */
#     char *shmaddr;	/* address in client */
#     Bool readOnly;	/* how the server should attach it */
# } XShmSegmentInfo;
mutable struct XShmSegmentInfo
    shmseg::Culong
    shmid::Cint
    shmaddr::Ptr{Cuchar}
    readOnly::Bool
end

function setup(d, v, width, height, depth=24)
    xshmseginfo_address = ccall(:malloc, (Int64), (Int64, ), sizeof(XShmSegmentInfo))
    xshmseginfoptr = Ptr{XShmSegmentInfo}(xshmseginfo_address)

    ximgptr = ccall((:XShmCreateImage, "libXext.so"),
        Ptr{XImage},
        (Ptr{Display}, Ptr{Visual}, Cuint, Cint,    Ptr{Void}, Ptr{XShmSegmentInfo}, Cuint, Cuint),
         d,            v,           depth, ZPixmap, C_NULL,    xshmseginfoptr,       width, height)

    ximage = unsafe_load(ximgptr)
    xshmseginfo = unsafe_load(xshmseginfoptr)

    xshmseginfo.shmid = ccall(:shmget,
        Cint,
        (Cuint, Csize_t, Cuint),
        IPC_PRIVATE, ximage.bytes_per_line * ximage.height, IPC_CREAT | parse(Cuint, "0777", 8))

    ximage.data = ccall(:shmat, Ptr{Cuchar}, (Cint, Cuint, Cuint), xshmseginfo.shmid, 0, 0)
    xshmseginfo.shmaddr = ximage.data
    xshmseginfo.readOnly = false

    unsafe_store!(ximgptr, ximage)
    unsafe_store!(xshmseginfoptr, xshmseginfo)

    status = ccall((:XShmAttach, "libXext.so"),
        Status,
        (Ptr{Display}, Ptr{XShmSegmentInfo}),
        d, xshmseginfoptr)

    data = unsafe_wrap(Array, ximage.data, (4, width, height))
    datau = reinterpret(UInt8, data)
    datas = reshape(datau, 4, width, height)
    datap = permuteddimsview(datas, (1, 3, 2))

    return ximgptr, xshmseginfoptr, datap
end

function teardown()
    # XShmDetach(display, shminfo)
    # XDestroyImage(image)
    # shmdt(shminfo.shmaddr)
    # shmctl(shminfo.shmid, IPC_RMID, 0)
end

function refreshXImage(d, w, ximgptr, x = 0, y = 0)
    status = ccall((:XShmGetImage, "libXext.so"),
        Status,
        (Ptr{Display}, Drawable, Ptr{XImage}, Cint, Cint, Culong),
         d,            w,        ximgptr,     x,    y,    AllPlanes)
end

const d = XOpenDisplay(C_NULL)
const s = DefaultScreen(d)
const v = DefaultVisual(d, 0)
const w = XDefaultRootWindow(d)

const ximgptr, xshmseginfoptr, datap = setup(d, v, 1000, 1000)
const nv = normedview(datap)

refreshXImage(d, w, ximgptr, 300, 300)

cv = colorview(RGB, nv[3,:,:], nv[2,:,:], nv[1,:,:])
