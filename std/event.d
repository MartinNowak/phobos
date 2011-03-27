// Written in the D programming language

/*
        Copyright (C) 2011 Martin Nowak

        This software is provided 'as-is', without any express or implied
        warranty.  In no event will the authors be held liable for any damages
        arising from the use of this software.

        Permission is granted to anyone to use this software for any purpose,
        including commercial applications, and to alter it and redistribute it
        freely, subject to the following restrictions:

        1. The origin of this software must not be misrepresented; you must not
           claim that you wrote the original software. If you use this software
           in a product, an acknowledgment in the product documentation would be
           appreciated but is not required.
        2. Altered source versions must be plainly marked as such, and must not
           be misrepresented as being the original software.
        3. This notice may not be removed or altered from any source
           distribution.

        event.d 0.1
        March 2011
*/

/**
 * Authors: Martin Nowak
 * Source:  $(PHOBOSSRC std/event.d)
 * Macros:
 *      WIKI=Phobos/StdEvent
 */
module std.event;

debug=StdEvent;
debug(StdEvent) static import std.stdio;

import core.memory;
import std.algorithm, std.array, std.bitmanip, std.conv, std.exception;
import std.stream;
public import etc.c.libev;

version(unittest)
{
    import std.file, std.path;

    private string deleteme()
    {
        static _deleteme = "deleteme.dmd.unittest";
        static _first = true;

        if(_first)
        {
            version(Windows)
                _deleteme = std.path.join(std.process.getenv("TEMP"), _deleteme);
            else
                _deleteme = "/tmp/" ~ _deleteme;

            _first = false;
        }


        return _deleteme;
    }
}


/**
 */
class EventLoop
{
    this(uint flags = 0)
    {
        this(ev_loop_new(flags));
    }

    void run()
    {
        ev_run(this.loop);
    }

    alias Callback!(void, EventLoop, FileWatcher) FileWatcherCB;

    struct FileWatcher
    {
        void start()
        {
            ev_io_start(this.eventLoop.loop, &this.data.ev);
        }

        void stop()
        {
            ev_io_stop(this.eventLoop.loop, &this.data.ev);
        }

        @property File file() { return this.data.file; }
        @property bool active() { return this.data.ev.active; }
        @property bool pending() { return this.data.ev.pending; }

    private:

        EventLoop eventLoop() { return cast(EventLoop)this.data.ev.data; }

        this(Data* data)
        {
            this.data = data;
        }

        extern(C) static void fileEvent(ev_loop* loop, ev_io* ev, int revents)
        {
            auto fw = FileWatcher(cast(Data*)ev);
            fw.data.cb.call(fw.eventLoop, fw);
        }

        struct Data
        {
            this(EventLoop loop, File file, int events, FileWatcherCB cb)
            {
                enforce(file);
                this.ev = ev_io(&fileEvent, file.handle, events);
                this.ev.data = cast(void*)loop;
                this.file = file;
                this.cb = cb;
            }
            ev_io ev;
            FileWatcherCB cb;
            File file;
        }
        Data* data;
    }

    FileWatcher addWatcher(File file, int events, FileWatcherCB.Dg dg)
    {
        return this.addWatcher(file, events, FileWatcherCB(dg));
    }

    FileWatcher addWatcher(File file, int events, FileWatcherCB.Fn fn)
    {
        return this.addWatcher(file, events, FileWatcherCB(fn));
    }

    FileWatcher addWatcher(File file, int events, FileWatcherCB cb)
    {
        return FileWatcher(this.fileWatchers.construct(this, file, events, cb));
    }

    void removeWatcher(FileWatcher fw)
    {
        if (fw.active)
            fw.stop();
        this.fileWatchers.destroy(fw.data);
    }

protected:
    this(ev_loop* loop)
    {
        enforce(loop);
        this.loop = loop;
        this.fileWatchers.init(4096);
    }

private:
    ev_loop* loop;
    PoolAllocator!(EventLoop.FileWatcher.Data) fileWatchers;
}


unittest
{
    enum cont = "1234567890";

    auto file = new File(deleteme, FileMode.In | FileMode.OutNew);
    scope(exit) { assert(std.file.exists(deleteme)); std.file.remove(deleteme); }

    auto loop = new EventLoop();
    bool calledRead, calledWrite;

    void write(EventLoop loop, EventLoop.FileWatcher w)
    {
        assert(!calledRead);
        calledWrite = true;
        assert(w.file == file);
        file.writeLine(cont);
        file.seekSet(0);
        loop.removeWatcher(w);
    }

    void read(EventLoop loop, EventLoop.FileWatcher w)
    {
        assert(calledWrite);
        calledRead = true;
        assert(w.file == file);
        assert(w.file.readLine() == cont);
        loop.removeWatcher(w);
    }

    loop.addWatcher(file, EV_WRITE, &write).start();
    loop.addWatcher(file, EV_READ, &read).start();
    loop.run();
    assert(calledWrite && calledRead);
}


private:


struct Callback(R, Args...)
{
    alias R function(Args) Fn;
    alias R delegate(Args) Dg;

    this(Fn fn) { this.fn = fn; }
    this(Dg dg) { this.dg = dg; }

    R opCall(Args args)
    {
        if (this.p.high is null)
            return this.fn(args);
        else
            return this.dg(args);
    }

    R call(Args args) { return this.opCall(args); }

private:
    union
    {
        Fn fn;
        Dg dg;
        struct Ptrs { void* low, high; }
        Ptrs p;
    }
}


struct PoolAllocator(T)
{
    this(size_t chunkSize)
    {
        init(chunkSize);
    }

    void init(size_t chunkSize)
    {
        this.chunkSize = chunkSize;
        appendChunk();
    }

    T* construct(Args...)(Args args)
    {
        prefChunk = getFree();
        return chunks[prefChunk].construct(args);
    }

    void destroy(T* p)
    {
        prefChunk = findChunk(p);
        chunks[prefChunk].destroy(p);
        if (!chunks[prefChunk].freeCount)
            dropChunk(prefChunk);
    }

private:
    size_t getFree()
    {
        assert(prefChunk < chunks.length, to!string(chunks.length));
        if (chunks[prefChunk].freeCount)
            return prefChunk;
        else {
            auto free = find!("a.freeCount > 0")(chunks);
            return free.empty ? appendChunk() : chunks.length - free.length;
        }
    }

    size_t findChunk(T* p)
    {
        if (chunks[prefChunk].isFrom(p))
            return prefChunk;
        else {
            auto found = find!("a.isFrom(b)")(chunks, p);
            assert(!found.empty);
            return chunks.length - found.length;
        }
    }

    size_t appendChunk()
    {
        auto blk = GC.qalloc(chunkSize, GC.BlkAttr.NO_MOVE);
        chunks ~= ChunkAllocator!(T)(blk);
        return chunks.length - 1;
    }

    void dropChunk(size_t idx)
    {
        move(chunks[$-1], chunks[idx]);
        chunks.popBack;
        prefChunk = max(prefChunk, chunks.length - 1);
    }

    ChunkAllocator!(T)[] chunks;
    size_t chunkSize;
    size_t prefChunk;
}

unittest {
    int*[1000] ps;
    auto pool = PoolAllocator!(int)(64);
    foreach(i; 0 .. 1000)
        ps[i] = pool.construct(i);
    foreach_reverse(p; ps)
        pool.destroy(p);
}

struct ChunkAllocator(T)
{
    this(BlkInfo_ blk)
    {
        base = cast(T*)blk.base;
        top = base + blk.size / T.sizeof;
        _freeCount = capacity;
        used.length = _freeCount;
    }

    @property size_t capacity() const
    {
        return top - base;
    }

    @property bool isFrom(T* p) const
    {
        return base <= p && p < top;
    }

    @property size_t freeCount() const
    {
        return _freeCount;
    }

    T* construct(Args...)(Args args)
    {
        if (!freeCount)
            return null;

        auto idx = findFree();
        --_freeCount; used[idx] = true;
        scope(failure) { ++_freeCount; used[idx] = false; }
        return emplace(base + idx, args);
    }

    void destroy(T* p)
    in
    {
        assert(isFrom(p));
        assert((cast(ubyte*)p - cast(ubyte*)base) % T.sizeof == 0);
    }
    body
    {
        auto idx = p - base;
        assert(used[idx] == true);
        ++_freeCount; used[idx] = false;
        static if (is(typeof(p.__dtor()))) p.__dtor();
    }

private:
    size_t findFree() const
    {
        assert(_freeCount);
        foreach(i; 0 .. capacity)
            if (used[i] == false)
                return i;
        return capacity;
    }

    T* base, top;
    size_t _freeCount;
    BitArray used;
}


unittest {
    auto alc = ChunkAllocator!(int)(GC.qalloc(4096, GC.BlkAttr.NO_MOVE));
    int* p;
    foreach(i; 0 .. 1024) {
        p = alc.construct(0);
        assert(alc.isFrom(p));
    }
    assert(alc.freeCount == 0);
}
