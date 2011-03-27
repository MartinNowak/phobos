/*
 * libev native API header
 *
 * Copyright (c) 2007,2008,2009,2010,2011 Marc Alexander Lehmann <libev@schmorp.de>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modifica-
 * tion, are permitted provided that the following conditions are met:
 *
 *   1.  Redistributions of source code must retain the above copyright notice,
 *       this list of conditions and the following disclaimer.
 *
 *   2.  Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MER-
 * CHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPE-
 * CIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTH-
 * ERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Alternatively, the contents of this file may be used under the terms of
 * the GNU General Public License ("GPL") version 2 or any later version,
 * in which case the provisions of the GPL are applicable instead of
 * the above. If you wish to allow the use of your version of this file
 * only under the terms of the GPL and not to allow others to use your
 * version of this file under the BSD license, indicate your decision
 * by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL. If you do not delete the
 * provisions above, a recipient may use your version of this file under
 * either the BSD or the GPL.
 */
module etc.c.libev;

extern(C):

/*****************************************************************************/

/* these priorities are inclusive, higher priorities will be invoked earlier */
enum EV_MINPRI = -2;
enum EV_MAXPRI = 2;

/*****************************************************************************/

alias double ev_tstamp;
import core.stdc.signal;
alias sig_atomic_t EV_ATOMIC_T;

version(Windows)
{
    import core.stdc.time;
}
else version(Posix)
{
    import core.sys.posix.sys.stat;
}

alias void ev_loop;

/*****************************************************************************/

/* eventmask, revents, events... */
enum {
  EV_UNDEF    = 0xFFFFFFFF, /* guaranteed to be invalid */
  EV_NONE     =       0x00, /* no events */
  EV_READ     =       0x01, /* ev_io detected read will not block */
  EV_WRITE    =       0x02, /* ev_io detected write will not block */
  EV__IOFDSET =       0x80, /* internal use only */
  EV_IO       =    EV_READ, /* alias for type-detection */
  EV_TIMER    = 0x00000100, /* timer timed out */
  EV_PERIODIC = 0x00000200, /* periodic timer timed out */
  EV_SIGNAL   = 0x00000400, /* signal was received */
  EV_CHILD    = 0x00000800, /* child/pid had status change */
  EV_STAT     = 0x00001000, /* stat data changed */
  EV_IDLE     = 0x00002000, /* event loop is idling */
  EV_PREPARE  = 0x00004000, /* event loop about to poll */
  EV_CHECK    = 0x00008000, /* event loop finished poll */
  EV_EMBED    = 0x00010000, /* embedded event loop needs sweep */
  EV_FORK     = 0x00020000, /* event loop resumed in child */
  EV_CLEANUP  = 0x00040000, /* event loop resumed in child */
  EV_ASYNC    = 0x00080000, /* async intra-loop signal */
  EV_CUSTOM   = 0x01000000, /* for use by user code */
  EV_ERROR    = 0x80000000  /* sent when an error occurs */
};

/* can be used to add custom fields to all watchers, while losing binary compatibility */
alias void* EV_COMMON;

template EV_CB(T)
{
    alias extern(C) void function(ev_loop* loop, T* w, int revents) EV_CB;
}

/*
 * struct member types:
 * private: you may look at them, but not change them,
 *          and they might not mean anything to you.
 * ro: can be read anytime, but only changed when the watcher isn't active.
 * rw: can be read and modified anytime, even when the watcher is active.
 *
 * some internal details that might be helpful for debugging:
 *
 * active is either 0, which means the watcher is not active,
 *           or the array index of the watcher (periodics, timers)
 *           or the array index + 1 (most other watchers)
 *           or simply 1 for watchers that aren't in some array.
 * pending is either 0, in which case the watcher isn't,
 *           or the array index + 1 in the pendings array.
 */

/* shared by all watchers */
mixin template EV_WATCHER(type)
{
    this(EV_CB!type cb)
    {
        this.cb = cb;
    }

    /* true when watcher is waiting for callback invocation */
    @property bool active() const { return this._active != 0; }
    /* true true when the watcher has been started */
    @property bool pending() const { return this._pending != 0; }

    EV_CB!type cb() { return this._cb; }

private:
    void cb(EV_CB!type cb) { this._cb = cb; }
    int _active; /* private */
    int _pending; /* private */
    int _priority; /* private */
public:
    EV_COMMON data; /* rw */
private:
    EV_CB!type _cb; /* private */
}

mixin template EV_WATCHER_LIST(type)
{
    mixin EV_WATCHER!(type);
    ev_watcher_list* next; /* private */
}

mixin template EV_WATCHER_TIME(type)
{
    mixin EV_WATCHER!(type);
    ev_tstamp at; /* private */
}

/* base class, nothing to see here unless you subclass */
struct ev_watcher
{
    mixin EV_WATCHER!(ev_watcher);
};

/* base class, nothing to see here unless you subclass */
struct ev_watcher_list
{
    mixin EV_WATCHER_LIST!(ev_watcher_list);
};

/* base class, nothing to see here unless you subclass */
struct ev_watcher_time
{
    mixin EV_WATCHER_TIME!(ev_watcher_time);
};

/* invoked when fd is either EV_READable or EV_WRITEable */
/* revent EV_READ, EV_WRITE */
struct ev_io
{
    this(EV_CB!ev_io cb, int fd, int events)
    {
        this.cb = cb;
        this.fd = fd;
        this.events = events | EV__IOFDSET;
    }

    mixin EV_WATCHER_LIST!(ev_io);

    int fd;     /* ro */
    int events; /* ro */
};

/* invoked after a specific time, repeatable (based on monotonic clock) */
/* revent EV_TIMEOUT */
struct ev_timer
{
    this(EV_CB!ev_timer cb, ev_tstamp after, ev_tstamp repeat)
    {
        this.cb = cb;
        this.at = after;
        this.repeat = repeat;
    }

    mixin EV_WATCHER_TIME!(ev_timer);

    ev_tstamp repeat; /* rw */
};

/* invoked at some specific time, possibly repeating at regular intervals (based on UTC) */
/* revent EV_PERIODIC */
struct ev_periodic
{
    this(EV_CB!ev_periodic cb, ev_tstamp offset, ev_tstamp interval, RCB reschedule_cb)
    {
        this.cb = cb;
        this.offset = offset;
        this.interval = interval;
        this.reschedule_cb = reschedule_cb;
    }

    mixin EV_WATCHER_TIME!(ev_periodic);

    ev_tstamp offset; /* rw */
    ev_tstamp interval; /* rw */
    alias ev_tstamp function(ev_periodic *w, ev_tstamp now) RCB;
    RCB reschedule_cb; /* rw */
};

/* invoked when the given signal has been received */
/* revent EV_SIGNAL */
struct ev_signal
{
    this(EV_CB!ev_signal cb, int signum)
    {
        this.cb = cb;
        this.signum = signum;
    }

    mixin EV_WATCHER_LIST!(ev_signal);

    int signum; /* ro */
};

/* invoked when sigchld is received and waitpid indicates the given pid */
/* revent EV_CHILD */
/* does not support priorities */
struct ev_child
{
    this(EV_CB!ev_child cb, int pid, int trace)
    {
        this.cb = cb;
        this.pid = pid;
        this.flags = !!(trace);
    }

    mixin EV_WATCHER_LIST!(ev_child);

    int flags;   /* private */
    int pid;     /* ro */
    int rpid;    /* rw, holds the received pid */
    int rstatus; /* rw, holds the exit status, use the macros from sys/wait.h */
};

/* st_nlink = 0 means missing file or other error */
version(Windows)
{
    // TODO alias for _stati64
}
else
{
    alias stat_t ev_statdata;
}

/* invoked each time the stat data changes for a given path */
/* revent EV_STAT */
struct ev_stat
{
    this(EV_CB!ev_stat cb, const(char)* path, ev_tstamp interval)
    {
        this.cb = cb;
        this.path = path;
        this.interval = interval;
        this.wd = -2;
    }

    mixin EV_WATCHER_LIST!(ev_stat);

    ev_timer timer;     /* private */
    ev_tstamp interval; /* ro */
    const(char) *path;   /* ro */
    ev_statdata prev;   /* ro */
    ev_statdata attr;   /* ro */

    int wd; /* wd for inotify, fd for kqueue */
};

/* invoked when the nothing else needs to be done, keeps the process from blocking */
/* revent EV_IDLE */
struct ev_idle
{
    this(EV_CB!ev_idle cb)
    {
        this.cb = cb;
    }

    mixin EV_WATCHER!(ev_idle);
};

/* invoked for each run of the mainloop, just before the blocking call */
/* you can still change events in any way you like */
/* revent EV_PREPARE */
struct ev_prepare
{
    this(EV_CB!ev_prepare cb)
    {
        this.cb = cb;
    }

    mixin EV_WATCHER!(ev_prepare);
};

/* invoked for each run of the mainloop, just after the blocking call */
/* revent EV_CHECK */
struct ev_check
{
    this(EV_CB!ev_check cb)
    {
        this.cb = cb;
    }

    mixin EV_WATCHER!(ev_check);
};

/* the callback gets invoked before check in the child process when a fork was detected */
/* revent EV_FORK */
struct ev_fork
{
    this(EV_CB!ev_fork cb)
    {
        this.cb = cb;
    }

    mixin EV_WATCHER!(ev_fork);
};

/* is invoked just before the loop gets destroyed */
/* revent EV_CLEANUP */
struct ev_cleanup
{
    this(EV_CB!ev_cleanup cb)
    {
        this.cb = cb;
    }

    mixin EV_WATCHER!(ev_cleanup);
};

/* used to embed an event loop inside another */
/* the callback gets invoked when the event loop has handled events, and can be 0 */
struct ev_embed
{
    this(EV_CB!ev_embed cb, ev_loop* other)
    {
        this.cb = cb;
        this.other = other;
    }

    mixin EV_WATCHER!(ev_embed);

    ev_loop *other; /* ro */
    ev_io io;              /* private */
    ev_prepare prepare;    /* private */
    ev_check check;        /* unused */
    ev_timer timer;        /* unused */
    ev_periodic periodic;  /* unused */
    ev_idle idle;          /* unused */
    ev_fork fork;          /* private */
    ev_cleanup cleanup;    /* unused */
};

/* invoked when somebody calls ev_async_send on the watcher */
/* revent EV_ASYNC */
struct ev_async
{
    this(EV_CB!ev_async cb)
    {
        this.cb = cb;
    }

    mixin EV_WATCHER!(ev_async);

    @property bool pending() const
    {
        return this.sent != 0;
    }

    EV_ATOMIC_T sent; /* private */
};


/* the presence of this union forces similar struct layout */
union ev_any_watcher
{
    ev_watcher w;
    ev_watcher_list wl;

    ev_io io;
    ev_timer timer;
    ev_periodic periodic;
    ev_signal signal;
    ev_child child;
    ev_stat stat;
    ev_idle idle;
    ev_prepare prepare;
    ev_check check;
    ev_fork fork;
    ev_cleanup cleanup;
    ev_embed embed;
    ev_async async;
};

/* flag bits for ev_default_loop and ev_loop_new */
enum {
  /* the default */
  EVFLAG_AUTO      = 0x00000000U, /* not quite a mask */
  /* flag bits */
  EVFLAG_NOENV     = 0x01000000U, /* do NOT consult environment */
  EVFLAG_FORKCHECK = 0x02000000U, /* check for a fork in each iteration */
  /* debugging/feature disable */
  EVFLAG_NOINOTIFY = 0x00100000U, /* do not attempt to use inotify */
  EVFLAG_SIGNALFD  = 0x00200000U, /* attempt to use signalfd */
  EVFLAG_NOSIGMASK = 0x00400000U  /* avoid modifying the signal mask */
};

/* method bits to be ored together */
enum {
  EVBACKEND_SELECT  = 0x00000001U, /* about anywhere */
  EVBACKEND_POLL    = 0x00000002U, /* !win */
  EVBACKEND_EPOLL   = 0x00000004U, /* linux */
  EVBACKEND_KQUEUE  = 0x00000008U, /* bsd */
  EVBACKEND_DEVPOLL = 0x00000010U, /* solaris 8 */ /* NYI */
  EVBACKEND_PORT    = 0x00000020U, /* solaris 10 */
  EVBACKEND_ALL     = 0x0000003FU, /* all known backends */
  EVBACKEND_MASK    = 0x0000FFFFU  /* all future backends */
};


int ev_version_major ();
int ev_version_minor ();

uint ev_supported_backends ();
uint ev_recommended_backends ();
uint ev_embeddable_backends ();

ev_tstamp ev_time ();
void ev_sleep (ev_tstamp delay); /* sleep for a while */

/* Sets the allocation function to use, works like realloc.
 * It is used to allocate and free memory.
 * If it returns zero when memory needs to be allocated, the library might abort
 * or take some potentially destructive action.
 * The default is your system realloc function.
 */
void ev_set_allocator (void* function(void *ptr, long size) cb);

/* set the callback function to call on a
 * retryable syscall error
 * (such as failed select, poll, epoll_wait)
 */
void ev_set_syserr_cb (void function(const(char)* msg) cb);

/* the default loop is the only one that handles signals and child watchers */
/* you can call this as often as you like */
ev_loop *ev_default_loop (uint flags = 0);

ev_loop *
ev_default_loop_uc ()
{
    extern(C) __gshared ev_loop* ev_default_loop_ptr;

    return ev_default_loop_ptr;
}

int
ev_is_default_loop (ev_loop* loop)
{
    return loop == ev_default_loop_uc();
}

/* create and destroy alternative loops that don't handle signals */
ev_loop* ev_loop_new (uint flags = 0);

ev_tstamp ev_now (ev_loop* loop); /* time w.r.t. timers and the eventloop, updated after each poll */


/* destroy event loops, also works for the default loop */
void ev_loop_destroy (ev_loop* loop);

/* this needs to be called after fork, to duplicate the loop */
/* when you want to re-use it in the child */
/* you can call it in either the parent or the child */
/* you can actually call it at any time, anywhere :) */
void ev_loop_fork (ev_loop* loop);

uint ev_backend (ev_loop* loop); /* backend in use by loop */

void ev_now_update (ev_loop* loop); /* update event loop time */

version(none)
{
    /* walk (almost) all watchers in the loop of a given type, invoking the */
    /* callback on every such watcher. The callback might stop the watcher, */
    /* but do nothing else with the loop */
    void ev_walk (ev_loop* loop, int types, void function(ev_loop* loop, int type, void *w) cb);
}


/* ev_run flags values */
enum {
  EVRUN_NOWAIT = 1, /* do not block/wait */
  EVRUN_ONCE   = 2  /* block *once* only */
};

/* ev_break how values */
enum {
  EVBREAK_CANCEL = 0, /* undo unloop */
  EVBREAK_ONE    = 1, /* unloop once */
  EVBREAK_ALL    = 2  /* unloop all loops */
};

void ev_run (ev_loop* loop, int flags = 0);
void ev_break (ev_loop* loop, int how = EVBREAK_ONE); /* break out of the loop */

/*
 * ref/unref can be used to add or remove a refcount on the mainloop. every watcher
 * keeps one reference. if you have a long-running watcher you never unregister that
 * should not keep ev_loop from running, unref() after starting, and ref() before stopping.
 */
void ev_ref   (ev_loop* loop);
void ev_unref (ev_loop* loop);

/*
 * convenience function, wait for a single event, without registering an event watcher
 * if timeout is < 0, do wait indefinitely
 */
void ev_once (ev_loop* loop, int fd, int events, ev_tstamp timeout,
              void function(int revents, void *arg) cb, void *arg);

uint ev_iteration (ev_loop* loop); /* number of loop iterations */
uint ev_depth     (ev_loop* loop); /* #ev_loop enters - #ev_loop leaves */
void         ev_verify    (ev_loop* loop); /* abort if loop data corrupted */

void ev_set_io_collect_interval (ev_loop* loop, ev_tstamp interval); /* sleep at least this time, default 0 */
void ev_set_timeout_collect_interval (ev_loop* loop, ev_tstamp interval); /* sleep at least this time, default 0 */

/* advanced stuff for threading etc. support, see docs */
void ev_set_userdata (ev_loop* loop, void *data);
void *ev_userdata (ev_loop* loop);
void ev_set_invoke_pending_cb (ev_loop* loop, void function(ev_loop* loop) invoke_pending_cb);
void ev_set_loop_release_cb (ev_loop* loop,
    void function(ev_loop* loop) release, void function(ev_loop* loop) acquire);

uint ev_pending_count (ev_loop* loop); /* number of pending events, if any */
void ev_invoke_pending (ev_loop* loop); /* invoke all pending watchers */

/*
 * stop/start the timer handling.
 */
void ev_suspend (ev_loop* loop);
void ev_resume  (ev_loop* loop);


/* these may evaluate ev multiple times, and the other arguments at most once */
/* either use ev_init + ev_TYPE_set, or the ev_TYPE_init macro, below, to first initialise a watcher */

/* stopping (enabling, adding) a watcher does nothing if it is already running */
/* stopping (disabling, deleting) a watcher does nothing unless its already running */

/* feeds an event into a watcher as if the event actually occured */
/* accepts any ev_watcher type */
void ev_feed_event     (ev_loop* loop, void *w, int revents);
void ev_feed_fd_event  (ev_loop* loop, int fd, int revents);

void ev_feed_signal    (int signum);
void ev_feed_signal_event (ev_loop* loop, int signum);

void ev_invoke         (ev_loop* loop, void *w, int revents);
int  ev_clear_pending  (ev_loop* loop, void *w);

void ev_io_start       (ev_loop* loop, ev_io *w);
void ev_io_stop        (ev_loop* loop, ev_io *w);

void ev_timer_start    (ev_loop* loop, ev_timer *w);
void ev_timer_stop     (ev_loop* loop, ev_timer *w);
/* stops if active and no repeat, restarts if active and repeating, starts if inactive and repeating */
void ev_timer_again    (ev_loop* loop, ev_timer *w);
/* return remaining time */
ev_tstamp ev_timer_remaining (ev_loop* loop, ev_timer *w);

void ev_periodic_start (ev_loop* loop, ev_periodic *w);
void ev_periodic_stop  (ev_loop* loop, ev_periodic *w);
void ev_periodic_again (ev_loop* loop, ev_periodic *w);

/* only supported in the default loop */
void ev_signal_start   (ev_loop* loop, ev_signal *w);
void ev_signal_stop    (ev_loop* loop, ev_signal *w);

/* only supported in the default loop */
version(Windows) {}
else
{
    void ev_child_start    (ev_loop* loop, ev_child *w);
    void ev_child_stop     (ev_loop* loop, ev_child *w);
 }

void ev_stat_start     (ev_loop* loop, ev_stat *w);
void ev_stat_stop      (ev_loop* loop, ev_stat *w);
void ev_stat_stat      (ev_loop* loop, ev_stat *w);

void ev_idle_start     (ev_loop* loop, ev_idle *w);
void ev_idle_stop      (ev_loop* loop, ev_idle *w);

void ev_prepare_start  (ev_loop* loop, ev_prepare *w);
void ev_prepare_stop   (ev_loop* loop, ev_prepare *w);

void ev_check_start    (ev_loop* loop, ev_check *w);
void ev_check_stop     (ev_loop* loop, ev_check *w);

void ev_fork_start     (ev_loop* loop, ev_fork *w);
void ev_fork_stop      (ev_loop* loop, ev_fork *w);

void ev_cleanup_start  (ev_loop* loop, ev_cleanup *w);
void ev_cleanup_stop   (ev_loop* loop, ev_cleanup *w);

/* only supported when loop to be embedded is in fact embeddable */
void ev_embed_start    (ev_loop* loop, ev_embed *w);
void ev_embed_stop     (ev_loop* loop, ev_embed *w);
void ev_embed_sweep    (ev_loop* loop, ev_embed *w);

void ev_async_start    (ev_loop* loop, ev_async *w);
void ev_async_stop     (ev_loop* loop, ev_async *w);
void ev_async_send     (ev_loop* loop, ev_async *w);
