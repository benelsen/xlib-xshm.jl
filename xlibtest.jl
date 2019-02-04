using Xlib

dpy = XOpenDisplay(C_NULL)
scr = DefaultScreen(dpy)
w = DefaultRootWindow(dpy)



nprop = Ref{Cint}(100)
r = ccall((:XListProperties, Xlib._XLIB), Ptr{Xlib.Atom},
          (Ptr{Display}, Window, Ptr{Cint}),
          dpy, w, nprop)

nprop[]
props = unsafe_wrap(Array, r, nprop[])



a = Array{Ptr{Cchar}}(128)

window_name_return = Ref{Ptr{Cchar}}(a)
s = ccall((:XFetchName, Xlib._XLIB), Status,
          (Ptr{Display}, Window, Ptr{Ptr{Cchar}}),
          dpy, w, a)

unsafe_load(a[1])

unsafe_string(pointer(a))

window_name_return[]

unsafe_string(pointer(window_name_return[]))

unsafe_wrap(Array, window_name_return[], 4)



root_return = Ref{Window}()
parent_return = Ref{Window}()
children_return = Ref{Ptr{Window}}()
n_children_return = Ref{UInt32}()

ccall((:XQueryTree, Xlib._XLIB), Status,
    (Ptr{Display}, Window, Ptr{Window}, Ptr{Window}, Ptr{Ptr{Window}}, Ptr{Cuint}),
    dpy, w, root_return, parent_return, children_return, n_children_return)

root_return[]
parent_return[]

children_return

children = unsafe_wrap(Array, children_return[], 205)




address = ccall(:malloc, (Int64), (Int64, ), sizeof(XWindowAttributes))
ptr = Ptr{XWindowAttributes}(address)

ccall((:XGetWindowAttributes, Xlib._XLIB), Status,
          (Ptr{Display}, Window, Ptr{XWindowAttributes}),
          dpy, w, ptr)

winattr = unsafe_load(ptr)



using Xlib, Images, BenchmarkTools

d = XOpenDisplay(C_NULL)
s = DefaultScreen(d)
v = DefaultVisual(d, 0)
w = XDefaultRootWindow(d)

mutable struct XShmSegmentInfo
    shmseg::Culong
    shmid::Ptr{Void}
    shmaddr::Culong
    readOnly::Cint
end

xshmseginfo_address = ccall(:malloc, (Int64), (Int64, ), sizeof(XShmSegmentInfo))
xshmseginfoptr = Ptr{XShmSegmentInfo}(xshmseginfo_address)

ximgptr = ccall((:XShmCreateImage, "libXext.so"),
            Ptr{XImage},
            (Ptr{Display}, Ptr{Visual}, Cuint, Cint,    Ptr{Void}, Ptr{XShmSegmentInfo}, Cuint, Cuint),
            d,             v,           24,    ZPixmap, C_NULL,    xshmseginfoptr,          3840,  2160)
ximage = unsafe_load(ximgptr)

xshmseginfo = unsafe_load(xshmseginfoptr)

#define IPC_CREAT	01000		/* Create key if key does not exist. */
#define IPC_PRIVATE	((__key_t) 0)	/* Private key.  */
# shminfo.shmid = shmget (IPC_PRIVATE, image->bytes_per_line * image->height, IPC_CREAT|0777)

const IPC_CREAT = Clong(01000)
const IPC_PRIVATE = Clong(0)

xshmseginfo.shmid = ccall(:shmget,
    Ptr{Void},
    (Clong, Culong, Clong),
    IPC_PRIVATE, ximage.bytes_per_line * ximage.height, IPC_CREAT|0777)

# void *shmat(int shmid, const void *shmaddr, int shmflg);
ximage.data = ccall(:shmat, Ptr{Void}, (Cint, Cint, Cint), xshmseginfo.shmid, 0, 0)
xshmseginfo.shmaddr = ccall(:shmat, Ptr{Void}, (Cint, Cint, Cint), xshmseginfo.shmid, 0, 0)

xshmseginfo.readOnly = false

ccall((:XShmAttach, "libXext.so"), Status, (Ptr{Display}, Ptr{XShmSegmentInfo}), d, xshmseginfoptr)

ccall((:XShmGetImage, "libXext.so"),
    Status,
    (Ptr{Display}, Drawable, Ptr{XImage}, Cint, Cint, Culong),
     d,            w,        ximgptr,     0,    0,    AllPlanes)


# XShmDetach(display, shminfo)
# XDestroyImage(image)
# shmdt(shminfo.shmaddr)
# shmctl(shminfo.shmid, IPC_RMID, 0)



ccall((:XShmGetImage, libXext), Cint, ())

ximg = ccall((:XShmGetImage, _XLIB),
            Ptr{XImage},
            (Ptr{Display}, Drawable, Cint, Cint, Cuint, Cuint, Culong, Cint),
            dpy, d, x, y, width, height, plane_mask, format)





img = XGetImage(dpy, w, 0, 0, 2000, 2000, AllPlanes, ZPixmap)
image = unsafe_load(img)

ccall((:XFree, Xlib._XLIB), Cint, (Ptr{Int8},), image.data)
ccall((:XFree, Xlib._XLIB), Cint, (Ptr{XImage},), img)

gc()

imgnew = XGetSubImage(dpy, w, 0, 0, 2000, 2000, AllPlanes, ZPixmap, img, 0, 0)


data = unsafe_wrap(Array, image.data, (4, 2000, 2000))
datau = reinterpret(UInt8, data)
datas = reshape(datau, 4, 2000, 2000)
datap = permuteddimsview(datas, (1, 3, 2))

XDestroyImage(img)

@time getScreenshot()

nv = normedview(datap)
cv = colorview(RGB, nv[3, :, :], nv[2, :, :], nv[1, :, :])
